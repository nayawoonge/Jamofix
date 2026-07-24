import Foundation

/// 감시 대상으로 등록된 폴더
public struct WatchedFolder: Codable, Identifiable, Equatable {
    public var id: UUID
    public var path: String
    public var enabled: Bool
    public var recursive: Bool

    public init(id: UUID = UUID(), path: String, enabled: Bool = true, recursive: Bool = true) {
        self.id = id
        self.path = path
        self.enabled = enabled
        self.recursive = recursive
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var displayName: String { (path as NSString).abbreviatingWithTildeInPath }
}

/// 자동 수정 동작 설정
public struct FixSettings: Codable, Equatable {
    /// 자소분리(NFD)를 감지 즉시 자동 수정
    public var autoFixNFD: Bool
    /// 인코딩 깨짐도 자동 수정 (기본은 수동 확인 — 오탐 위험이 있으므로)
    public var autoFixMojibake: Bool
    /// 수동 스캔 시 윈도우 비호환 문자도 검사
    public var checkWindowsCompat: Bool
    /// 백그라운드 자동 수정 시 알림 센터로 알림
    public var notifyOnFix: Bool

    public init(
        autoFixNFD: Bool = true,
        autoFixMojibake: Bool = false,
        checkWindowsCompat: Bool = false,
        notifyOnFix: Bool = true
    ) {
        self.autoFixNFD = autoFixNFD
        self.autoFixMojibake = autoFixMojibake
        self.checkWindowsCompat = checkWindowsCompat
        self.notifyOnFix = notifyOnFix
    }

    // 이전 버전 설정 파일에 없던 키는 기본값으로 (설정 초기화 방지)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoFixNFD = try container.decodeIfPresent(Bool.self, forKey: .autoFixNFD) ?? true
        autoFixMojibake = try container.decodeIfPresent(Bool.self, forKey: .autoFixMojibake) ?? false
        checkWindowsCompat = try container.decodeIfPresent(Bool.self, forKey: .checkWindowsCompat) ?? false
        notifyOnFix = try container.decodeIfPresent(Bool.self, forKey: .notifyOnFix) ?? true
    }
}

/// 실행된 rename 기록 (되돌리기용)
public struct RenameRecord: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var oldPath: String
    public var newPath: String
    public var issues: [IssueKind]

    public init(id: UUID = UUID(), date: Date = Date(), oldPath: String, newPath: String, issues: [IssueKind]) {
        self.id = id
        self.date = date
        self.oldPath = oldPath
        self.newPath = newPath
        self.issues = issues
    }

    public var oldName: String { (oldPath as NSString).lastPathComponent }
    public var newName: String { (newPath as NSString).lastPathComponent }
}
