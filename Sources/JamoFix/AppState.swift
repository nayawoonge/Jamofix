import Foundation
import SwiftUI
import ServiceManagement
import JamoFixCore

@MainActor
final class AppState: ObservableObject {

    // MARK: - 상태

    /// 전체 감시 켜기/끄기 (메뉴바 토글)
    @Published var globalEnabled: Bool {
        didSet { persist(); rebuildWatcher() }
    }
    @Published var folders: [WatchedFolder] {
        didSet { persist(); rebuildWatcher() }
    }
    @Published var settings: FixSettings {
        didSet { persist() }
    }
    /// 자동 수정하지 않고 사용자 확인을 기다리는 항목 (인코딩 깨짐 등)
    @Published var pendingPlans: [RenamePlan] = []
    /// 수동 스캔 결과 미리보기 (시트로 표시)
    @Published var previewPlans: [RenamePlan] = []
    @Published var showPreview = false
    @Published var history: [RenameRecord] = []
    @Published var lastActivity: String = L("대기 중", "Idle")
    @Published var fixedCount: Int = 0
    /// 로그인 시 자동 시작 (SMAppService — .app 번들에서만 동작)
    @Published var launchAtLogin: Bool = false

    /// 메뉴바(상단 상태바) 아이콘 표시 여부
    @Published var showMenuBarIcon: Bool {
        didSet { persistAppearance() }
    }
    /// Dock(하단) 아이콘 표시 여부. false면 .accessory로 전환해 Dock·앱 전환기에서 숨김
    @Published var showDockIcon: Bool {
        didSet { persistAppearance(); applyDockVisibility() }
    }

    /// .app 번들로 실행 중인지 (swift run이면 false — 자동 시작/알림 비활성)
    let isRunningInBundle = NotificationManager.isRunningInBundle

    /// AppDelegate가 실행 시점에 읽는 Dock 표시 기본값 (앱 로딩 순서상 UserDefaults 직접 참조)
    static let showDockIconKey = "showDockIcon"
    static let showMenuBarIconKey = "showMenuBarIcon"

    private let historyStore = HistoryStore()
    private var watcher: FolderWatcher?
    private var pendingChangedPaths: Set<String> = []
    private var debounceTask: Task<Void, Never>?

    // MARK: - 초기화

    init() {
        let defaults = UserDefaults.standard
        globalEnabled = defaults.object(forKey: "globalEnabled") as? Bool ?? true
        folders = Self.decode([WatchedFolder].self, from: defaults, key: "folders") ?? []
        settings = Self.decode(FixSettings.self, from: defaults, key: "settings") ?? FixSettings()
        showMenuBarIcon = defaults.object(forKey: Self.showMenuBarIconKey) as? Bool ?? true
        showDockIcon = defaults.object(forKey: Self.showDockIconKey) as? Bool ?? true
        history = historyStore.records
        if isRunningInBundle {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        rebuildWatcher()
    }

    // MARK: - 표시 옵션 (메뉴바 / Dock 아이콘)

    /// 메뉴바 아이콘 표시 설정. Dock도 숨겨진 상태에서 메뉴바까지 끄려 하면
    /// 앱에 접근할 수단이 사라지므로 Dock을 자동으로 되살린다.
    ///
    /// no-op 가드 필수: MenuBarExtra(isInserted:)가 body 평가 중 현재 값을 그대로
    /// 다시 write-back하는데, @Published는 값이 같아도 대입만 하면 objectWillChange를
    /// 발생시켜 무한 렌더 루프(100% CPU)에 빠진다. 값이 실제로 바뀔 때만 대입한다.
    func setShowMenuBarIcon(_ on: Bool) {
        guard on != showMenuBarIcon else { return }
        if !on && !showDockIcon {
            showDockIcon = true  // 최소 하나의 접근 경로 보장
        }
        showMenuBarIcon = on
    }

    /// Dock 아이콘 표시 설정. 같은 이유로 메뉴바가 꺼진 상태에서 Dock까지 끄면
    /// 메뉴바를 자동으로 되살린다.
    func setShowDockIcon(_ on: Bool) {
        guard on != showDockIcon else { return }
        if !on && !showMenuBarIcon {
            showMenuBarIcon = true
        }
        showDockIcon = on
    }

    /// Dock 표시 여부를 실제 activation policy에 반영.
    /// .regular = Dock에 표시, .accessory = Dock·Cmd-Tab에서 숨김 (메뉴바 유틸리티 모드)
    func applyDockVisibility() {
        guard let app = NSApp else { return }
        let target: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        if app.activationPolicy() != target {
            app.setActivationPolicy(target)
            if target == .regular {
                app.activate(ignoringOtherApps: true)
            }
        }
    }

    private func persistAppearance() {
        let defaults = UserDefaults.standard
        defaults.set(showMenuBarIcon, forKey: Self.showMenuBarIconKey)
        defaults.set(showDockIcon, forKey: Self.showDockIconKey)
    }

    // MARK: - 로그인 시 자동 시작

    func setLaunchAtLogin(_ enabled: Bool) {
        guard isRunningInBundle else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            lastActivity = L("자동 시작 설정 실패: \(error.localizedDescription)",
                             "Failed to set launch at login: \(error.localizedDescription)")
        }
    }

    // MARK: - 폴더 관리

    func addFolder(_ url: URL) {
        let path = url.path
        guard !folders.contains(where: { $0.path == path }) else { return }
        folders.append(WatchedFolder(path: path))
        // 새 폴더는 즉시 한 번 스캔 (자동 수정 정책 적용)
        scanAsWatch(folderURL: url, recursive: true)
    }

    func removeFolder(_ folder: WatchedFolder) {
        folders.removeAll { $0.id == folder.id }
        pendingPlans.removeAll { $0.url.path.hasPrefix(folder.path) }
    }

    func toggleFolder(_ folder: WatchedFolder) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].enabled.toggle()
    }

    // MARK: - 감시

    private func rebuildWatcher() {
        watcher?.stop()
        watcher = nil
        guard globalEnabled else {
            lastActivity = L("감시 꺼짐", "Watching off")
            return
        }
        let paths = folders.filter(\.enabled).map(\.path)
        guard !paths.isEmpty else {
            lastActivity = L("등록된 폴더 없음", "No folders added")
            return
        }
        let newWatcher = FolderWatcher(paths: paths) { [weak self] changed in
            Task { @MainActor in self?.enqueueChanged(changed) }
        }
        newWatcher.start()
        watcher = newWatcher
        lastActivity = L("폴더 \(paths.count)개 감시 중", "Watching \(paths.count) folder(s)")
    }

    private func enqueueChanged(_ paths: [String]) {
        pendingChangedPaths.formUnion(paths)
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.processChangedPaths()
        }
    }

    /// 변경된 개별 경로를 검사해 자동 수정 or 확인 대기열에 추가
    private func processChangedPaths() {
        let paths = pendingChangedPaths
        pendingChangedPaths = []

        let detect = NameAnalyzer.Options(fixNFD: true, fixMojibake: true, sanitizeWindows: false)
        var autoPlans: [RenamePlan] = []
        var confirmPlans: [RenamePlan] = []

        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            guard let plan = RenameEngine.planFor(url: URL(fileURLWithPath: path), options: detect) else { continue }
            if isAutoApplicable(plan.analysis) {
                autoPlans.append(plan)
            } else {
                confirmPlans.append(plan)
            }
        }

        applyPlans(autoPlans, notify: true)
        queueForConfirmation(confirmPlans)
    }

    /// 새 폴더 등록/시작 시 전체 스캔 — 감시 이벤트와 같은 자동 정책 적용
    func scanAsWatch(folderURL: URL, recursive: Bool) {
        let detect = NameAnalyzer.Options(fixNFD: true, fixMojibake: true, sanitizeWindows: false)
        let plans = RenameEngine.scan(folder: folderURL, recursive: recursive, options: detect)
        let auto = plans.filter { isAutoApplicable($0.analysis) }
        let confirm = plans.filter { !isAutoApplicable($0.analysis) }
        applyPlans(auto, notify: true)
        queueForConfirmation(confirm)
    }

    private func isAutoApplicable(_ analysis: NameAnalysis) -> Bool {
        analysis.issues.allSatisfy { issue in
            switch issue {
            case .nfd: return settings.autoFixNFD
            case .mojibake: return settings.autoFixMojibake
            case .windowsUnsafe: return false  // 윈도우 호환은 항상 수동 확인
            }
        }
    }

    // MARK: - 수동 스캔 (미리보기 → 승인)

    func manualScan(folder: WatchedFolder) {
        let options = NameAnalyzer.Options(
            fixNFD: true,
            fixMojibake: true,
            sanitizeWindows: settings.checkWindowsCompat
        )
        previewPlans = RenameEngine.scan(folder: folder.url, recursive: folder.recursive, options: options)
        showPreview = true
    }

    func manualScanAll() {
        let options = NameAnalyzer.Options(
            fixNFD: true,
            fixMojibake: true,
            sanitizeWindows: settings.checkWindowsCompat
        )
        previewPlans = folders.filter(\.enabled).flatMap {
            RenameEngine.scan(folder: $0.url, recursive: $0.recursive, options: options)
        }
        showPreview = true
    }

    // MARK: - 실행 / 되돌리기

    /// - Parameter notify: 백그라운드(감시) 경로에서 호출될 때만 true — 알림 센터 알림 발송
    func applyPlans(_ plans: [RenamePlan], notify: Bool = false) {
        guard !plans.isEmpty else { return }
        var errors: [(RenamePlan, Error)] = []
        let records = RenameEngine.apply(plans, errors: &errors)
        if !records.isEmpty {
            historyStore.add(records)
            history = historyStore.records
            fixedCount += records.count
            lastActivity = L("방금 \(records.count)개 수정됨", "Just fixed \(records.count)")
            // 처리된 항목은 대기열에서 제거
            let donePaths = Set(records.map(\.oldPath))
            pendingPlans.removeAll { donePaths.contains($0.url.path) }

            if notify, settings.notifyOnFix {
                let sample = records[0]
                NotificationManager.notify(
                    title: L("파일명 \(records.count)개 수정됨", "Fixed \(records.count) filename(s)"),
                    body: "\(HangulDisplay.visualize(sample.oldName)) → \(sample.newName)"
                )
            }
        }
        if !errors.isEmpty {
            lastActivity = L("\(errors.count)개 항목 수정 실패", "Failed to fix \(errors.count) item(s)")
        }
    }

    private func queueForConfirmation(_ plans: [RenamePlan]) {
        guard !plans.isEmpty else { return }
        let existing = Set(pendingPlans.map { $0.url.path })
        let fresh = plans.filter { !existing.contains($0.url.path) }
        pendingPlans.append(contentsOf: fresh)
        if !fresh.isEmpty {
            lastActivity = L("확인 필요한 항목 \(pendingPlans.count)개", "\(pendingPlans.count) item(s) need review")
            if settings.notifyOnFix {
                NotificationManager.notify(
                    title: L("확인이 필요한 파일명 \(fresh.count)개", "\(fresh.count) filename(s) need review"),
                    body: L("인코딩 깨짐 등 수동 확인이 필요한 항목이 있습니다",
                            "Some items (e.g. mojibake) need manual review")
                )
            }
        }
    }

    func undo(_ record: RenameRecord) {
        do {
            try RenameEngine.undo(record)
            historyStore.remove(record)
            history = historyStore.records
            lastActivity = L("되돌림: \(record.newName)", "Undone: \(record.newName)")
        } catch {
            lastActivity = L("되돌리기 실패: \(record.newName)", "Undo failed: \(record.newName)")
        }
    }

    func clearHistory() {
        historyStore.clear()
        history = []
    }

    // MARK: - 영속화

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(globalEnabled, forKey: "globalEnabled")
        Self.encode(folders, to: defaults, key: "folders")
        Self.encode(settings, to: defaults, key: "settings")
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, to defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
