import Foundation

/// 실행 전의 rename 계획 (미리보기 항목)
public struct RenamePlan: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let analysis: NameAnalysis

    public init(url: URL, analysis: NameAnalysis) {
        self.id = UUID()
        self.url = url
        self.analysis = analysis
    }

    /// 목적지 경로. 주의: URL.appendingPathComponent는 한글을 NFD로 분해하므로
    /// 반드시 String 연결로 구성해 NFC 바이트를 보존한다.
    public var newPath: String {
        url.deletingLastPathComponent().path + "/" + analysis.proposedName
    }
}

public enum RenameEngine {

    /// 폴더를 스캔해 수정이 필요한 항목의 계획 목록을 반환 (실제 변경 없음 — dry-run)
    public static func scan(folder: URL, recursive: Bool, options: NameAnalyzer.Options) -> [RenamePlan] {
        let fm = FileManager.default
        var enumerationOptions: FileManager.DirectoryEnumerationOptions = [
            .skipsPackageDescendants, .skipsHiddenFiles,
        ]
        if !recursive {
            enumerationOptions.insert(.skipsSubdirectoryDescendants)
        }
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: enumerationOptions
        ) else { return [] }

        var plans: [RenamePlan] = []
        for case let url as URL in enumerator {
            if let plan = planFor(url: url, options: options) {
                plans.append(plan)
            }
        }
        // 깊은 경로부터 rename해야 상위 폴더의 rename이 하위 항목 경로를 무효화하지 않음
        return plans.sorted { $0.url.pathComponents.count > $1.url.pathComponents.count }
    }

    /// 단일 경로에 대한 rename 계획 (문제 없으면 nil)
    public static func planFor(url: URL, options: NameAnalyzer.Options) -> RenamePlan? {
        let name = url.lastPathComponent
        // iCloud 미다운로드 플레이스홀더는 건드리지 않음
        guard !name.hasSuffix(".icloud"), !name.hasPrefix(".") else { return nil }
        // 1차: 경로 문자열 기준 빠른 검사
        guard NameAnalyzer.analyze(name, options: options) != nil else { return nil }

        // 2차: 디스크의 실제 엔트리 이름으로 재검증.
        // 경로 문자열은 믿을 수 없다 — FSEvents는 rename "이전"의 NFD 경로로 이벤트를
        // 보내는데, APFS는 정규화를 무시하고 조회하므로 이미 NFC로 고쳐진 파일이
        // NFD 경로로도 존재하는 것처럼 보인다. 이걸 그대로 믿으면 같은 파일을
        // 무한히 다시 rename하는 루프가 생긴다 (v0.1.0에서 실제 발생).
        guard let diskName = onDiskName(of: url),
              !diskName.hasSuffix(".icloud"), !diskName.hasPrefix("."),
              let analysis = NameAnalyzer.analyze(diskName, options: options)
        else { return nil }

        let parentPath = url.deletingLastPathComponent().path
        return RenamePlan(
            url: URL(fileURLWithPath: parentPath + "/" + diskName),
            analysis: analysis
        )
    }

    /// 디스크에 실제 저장된 디렉토리 엔트리 이름 (경로 문자열의 정규화 형태와 무관).
    /// 항목이 존재하지 않으면 nil.
    public static func onDiskName(of url: URL) -> String? {
        let parent = url.deletingLastPathComponent().path
        let target = url.lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: parent) else { return nil }
        // Swift의 == 는 정규화를 무시한 비교이므로 NFD/NFC 어느 형태로 와도 매칭됨
        return entries.first { $0 == target }
    }

    /// 계획들을 실행. 성공한 항목의 기록을 반환 (실패 항목은 errors에 수집)
    public static func apply(_ plans: [RenamePlan], errors: inout [(RenamePlan, Error)]) -> [RenameRecord] {
        var records: [RenameRecord] = []
        for plan in plans {
            do {
                records.append(try applyOne(plan))
            } catch {
                errors.append((plan, error))
            }
        }
        return records
    }

    /// 계획 하나를 실행
    public static func applyOne(_ plan: RenamePlan) throws -> RenameRecord {
        let fm = FileManager.default
        let src = plan.url
        let parent = src.deletingLastPathComponent().path
        var dstPath = plan.newPath

        guard fm.fileExists(atPath: src.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let destExists = fm.fileExists(atPath: dstPath)
        let sameFile = destExists && isSameFile(src, URL(fileURLWithPath: dstPath))

        if destExists && !sameFile {
            // 목적지에 "다른" 파일이 이미 있으면 " (1)" 식으로 회피
            dstPath = availablePath(for: dstPath)
        }

        if sameFile {
            // APFS는 정규화를 무시하고 같은 파일로 취급하므로 임시 이름을 경유한 2단계 rename
            let tmpPath = parent + "/.jamofix-tmp-" + UUID().uuidString
            try rawRename(from: src.path, to: tmpPath)
            do {
                try rawRename(from: tmpPath, to: dstPath)
            } catch {
                // 실패 시 원상 복구 시도
                try? rawRename(from: tmpPath, to: src.path)
                throw error
            }
        } else {
            try rawRename(from: src.path, to: dstPath)
        }

        return RenameRecord(
            oldPath: src.path,
            newPath: dstPath,
            issues: plan.analysis.issues
        )
    }

    /// 기록을 되돌림 (newPath → oldPath)
    public static func undo(_ record: RenameRecord) throws {
        let fm = FileManager.default
        let current = URL(fileURLWithPath: record.newPath)
        let original = URL(fileURLWithPath: record.oldPath)
        guard fm.fileExists(atPath: record.newPath) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let originalExists = fm.fileExists(atPath: record.oldPath)
        let sameFile = originalExists && isSameFile(current, original)
        if originalExists && !sameFile {
            throw CocoaError(.fileWriteFileExists)
        }
        if sameFile {
            // NFC → NFD 복원도 APFS 정규화-무시 특성 때문에 2단계 rename 필요
            let tmpPath = (record.newPath as NSString).deletingLastPathComponent
                + "/.jamofix-tmp-" + UUID().uuidString
            try rawRename(from: record.newPath, to: tmpPath)
            try rawRename(from: tmpPath, to: record.oldPath)
        } else {
            try rawRename(from: record.newPath, to: record.oldPath)
        }
    }

    /// POSIX rename을 직접 호출해 파일명 바이트를 그대로 보존.
    ///
    /// 중요: FileManager.moveItem과 URL 경로 API는 내부적으로 fileSystemRepresentation을
    /// 거치며 파일명을 다시 NFD로 분해하므로 NFC 정규화 목적에는 쓸 수 없다.
    /// String 경로 + withCString은 UTF-8 스칼라를 정규화 없이 그대로 전달한다.
    /// RENAME_EXCL 플래그로 목적지가 이미 있으면 덮어쓰지 않고 실패시킨다 (레이스 방지).
    static func rawRename(from srcPath: String, to dstPath: String) throws {
        let result = srcPath.withCString { s in
            dstPath.withCString { d in
                renamex_np(s, d, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            let code = Int(errno)
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: code,
                userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(Int32(code)))]
            )
        }
    }

    /// 두 경로가 같은 파일(inode)을 가리키는지 (APFS 정규화 무시 특성 대응)
    static func isSameFile(_ a: URL, _ b: URL) -> Bool {
        guard
            let idA = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
            let idB = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        else { return false }
        return idA.isEqual(idB)
    }

    /// "이름 (1).ext" 식으로 비어 있는 경로를 찾음 (String 기반 — NFC 보존)
    public static func availablePath(for path: String) -> String {
        let fm = FileManager.default
        let ns = path as NSString
        let ext = ns.pathExtension
        let stemPath = ns.deletingPathExtension
        var counter = 1
        while true {
            var candidate = "\(stemPath) (\(counter))"
            if !ext.isEmpty { candidate += ".\(ext)" }
            if !fm.fileExists(atPath: candidate) { return candidate }
            counter += 1
        }
    }
}
