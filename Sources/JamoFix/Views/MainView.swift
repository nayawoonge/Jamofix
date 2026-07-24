import SwiftUI
import JamoFixCore

struct MainView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            FoldersTab()
                .tabItem { Label(L("폴더", "Folders"), systemImage: "folder") }
            PendingTab()
                .tabItem {
                    Label(L("확인 대기", "Pending"), systemImage: "exclamationmark.triangle")
                }
                .badge(state.pendingPlans.count)
            HistoryTab()
                .tabItem { Label(L("히스토리", "History"), systemImage: "clock.arrow.circlepath") }
            SettingsTab()
                .tabItem { Label(L("설정", "Settings"), systemImage: "gearshape") }
        }
        .padding()
        .sheet(isPresented: $state.showPreview) {
            PreviewSheet()
                .environmentObject(state)
        }
    }
}

// MARK: - 폴더 탭

struct FoldersTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(L("전체 감시", "Watch all"), isOn: $state.globalEnabled)
                    .toggleStyle(.switch)
                Spacer()
                Text(state.lastActivity)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            List {
                ForEach(state.folders) { folder in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { folder.enabled },
                            set: { _ in state.toggleFolder(folder) }
                        ))
                        .labelsHidden()

                        VStack(alignment: .leading) {
                            Text(folder.displayName)
                                .fontWeight(.medium)
                            Text(folder.recursive ? L("하위 폴더 포함", "Includes subfolders") : L("이 폴더만", "This folder only"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L("스캔", "Scan")) { state.manualScan(folder: folder) }
                        Button(role: .destructive) {
                            state.removeFolder(folder)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .overlay {
                if state.folders.isEmpty {
                    ContentUnavailableCompat(
                        title: L("감시할 폴더를 추가하세요", "Add a folder to watch"),
                        subtitle: L("추가한 폴더에서 자소분리·인코딩 깨짐이 자동으로 감지됩니다",
                                    "Jamo splits and mojibake are detected automatically in added folders")
                    )
                }
            }

            HStack {
                Button {
                    pickFolder()
                } label: {
                    Label(L("폴더 추가", "Add Folder"), systemImage: "plus")
                }
                Spacer()
                Button(L("전체 스캔 (미리보기)", "Scan All (preview)")) { state.manualScanAll() }
                    .disabled(state.folders.isEmpty)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L("감시 폴더로 추가", "Add as watched folder")
        if panel.runModal() == .OK {
            for url in panel.urls {
                state.addFolder(url)
            }
        }
    }
}

// MARK: - 확인 대기 탭 (인코딩 깨짐 등 수동 승인 항목)

struct PendingTab: View {
    @EnvironmentObject var state: AppState
    @State private var selected: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("자동 수정하기엔 확신이 낮아 확인이 필요한 항목입니다 (인코딩 깨짐 복구 등)",
                   "Items that need review before fixing (e.g. mojibake recovery)"))
                .font(.callout)
                .foregroundStyle(.secondary)

            PlanListView(plans: state.pendingPlans, selected: $selected)
                .overlay {
                    if state.pendingPlans.isEmpty {
                        ContentUnavailableCompat(
                            title: L("확인할 항목 없음", "Nothing to review"),
                            subtitle: L("감시 중 확신이 낮은 수정 제안이 생기면 여기에 쌓입니다",
                                        "Low-confidence fix suggestions collected while watching appear here")
                        )
                    }
                }

            HStack {
                Button(L("모두 선택", "Select All")) { selected = Set(state.pendingPlans.map(\.id)) }
                Button(L("선택 해제", "Deselect")) { selected = [] }
                Spacer()
                Button(L("선택 항목 무시", "Ignore Selected")) {
                    state.pendingPlans.removeAll { selected.contains($0.id) }
                    selected = []
                }
                Button(L("선택 항목 수정", "Fix Selected")) {
                    let plans = state.pendingPlans.filter { selected.contains($0.id) }
                    state.applyPlans(plans)
                    state.pendingPlans.removeAll { selected.contains($0.id) }
                    selected = []
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
    }
}

// MARK: - 미리보기 시트 (수동 스캔 결과)

struct PreviewSheet: View {
    @EnvironmentObject var state: AppState
    @State private var selected: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("스캔 결과 — 변경할 항목을 선택하세요", "Scan results — select items to fix"))
                .font(.headline)

            PlanListView(plans: state.previewPlans, selected: $selected)
                .overlay {
                    if state.previewPlans.isEmpty {
                        ContentUnavailableCompat(
                            title: L("문제 없음 ✨", "All good ✨"),
                            subtitle: L("모든 파일명이 정상입니다", "All filenames look fine")
                        )
                    }
                }

            HStack {
                Button(L("모두 선택", "Select All")) { selected = Set(state.previewPlans.map(\.id)) }
                Spacer()
                Button(L("닫기", "Close")) { state.showPreview = false }
                    .keyboardShortcut(.cancelAction)
                Button(L("선택 항목 수정", "Fix Selected")) {
                    let plans = state.previewPlans.filter { selected.contains($0.id) }
                    state.applyPlans(plans)
                    state.showPreview = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 400)
        .onAppear {
            // 기본은 전체 선택
            selected = Set(state.previewPlans.map(\.id))
        }
    }
}

// MARK: - 공용: 계획 목록

struct PlanListView: View {
    let plans: [RenamePlan]
    @Binding var selected: Set<UUID>

    var body: some View {
        List(plans) { plan in
            HStack(alignment: .top) {
                Toggle("", isOn: Binding(
                    get: { selected.contains(plan.id) },
                    set: { isOn in
                        if isOn { selected.insert(plan.id) } else { selected.remove(plan.id) }
                    }
                ))
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // NFD 이름은 "ㅎㅏㄴㄱㅡㄹ.txt"처럼 분리된 모습 그대로 표시
                        // (윈도우로 보냈을 때 깨질 모습)
                        Text(HangulDisplay.visualize(plan.analysis.originalName))
                            .strikethrough(color: .secondary)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        Text(plan.analysis.proposedName)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 4) {
                        ForEach(plan.analysis.issues, id: \.self) { issue in
                            Text(issue.label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(issueColor(issue).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        Text(plan.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func issueColor(_ issue: IssueKind) -> Color {
        switch issue {
        case .nfd: return .blue
        case .mojibake: return .orange
        case .windowsUnsafe: return .purple
        }
    }
}

// MARK: - 히스토리 탭

struct HistoryTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(state.history) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            // 수정 전 NFD 이름은 분리된 모습 그대로 표시
                            Text(HangulDisplay.visualize(record.oldName))
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(record.newName)
                                .fontWeight(.medium)
                        }
                        Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.issues.map(\.label).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("되돌리기", "Undo")) { state.undo(record) }
                }
                .padding(.vertical, 2)
            }
            .overlay {
                if state.history.isEmpty {
                    ContentUnavailableCompat(
                        title: L("기록 없음", "No history"),
                        subtitle: L("파일명이 수정되면 여기에 기록되고 언제든 되돌릴 수 있습니다",
                                    "Fixes are recorded here and can be undone anytime")
                    )
                }
            }

            HStack {
                Text(L("총 \(state.history.count)건", "\(state.history.count) total"))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L("기록 지우기", "Clear History"), role: .destructive) { state.clearHistory() }
                    .disabled(state.history.isEmpty)
            }
        }
    }
}

// MARK: - 설정 탭

struct SettingsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section(L("일반", "General")) {
                Toggle(L("로그인 시 자동 시작", "Launch at login"), isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                .disabled(!state.isRunningInBundle)
                if !state.isRunningInBundle {
                    Text(L("개발 실행(swift run)에서는 사용할 수 없습니다. Scripts/package.sh로 만든 앱에서 켜세요.",
                           "Unavailable in dev runs (swift run). Enable it in an app built with Scripts/package.sh."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(L("백그라운드 수정 시 알림", "Notify on background fixes"), isOn: $state.settings.notifyOnFix)
                Text(L("감시 중인 폴더에서 파일명이 자동 수정되거나 확인이 필요한 항목이 생기면 알림 센터로 알려줍니다.",
                       "Sends a Notification Center alert when files are auto-fixed or need review in watched folders."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("자동 수정", "Auto-fix")) {
                Toggle(L("자소분리(NFD) 자동 수정", "Auto-fix jamo split (NFD)"), isOn: $state.settings.autoFixNFD)
                Text(L("감시 중인 폴더에서 자소분리된 파일명을 발견하면 즉시 NFC로 정규화합니다. 안전한 변환입니다.",
                       "Normalizes jamo-split names to NFC immediately when found. This conversion is safe."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L("인코딩 깨짐 자동 수정", "Auto-fix mojibake"), isOn: $state.settings.autoFixMojibake)
                Text(L("⚠️ 깨진 파일명(예: ¿ù°£º¸°í¼­.hwp)을 자동 복구합니다. 드물게 오탐 가능성이 있어 기본은 수동 확인입니다.",
                       "⚠️ Auto-recovers corrupted names (e.g. ¿ù°£º¸°í¼­.hwp). Rare false positives are possible, so manual review is the default."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("수동 스캔", "Manual scan")) {
                Toggle(L("윈도우 비호환 문자 검사 포함", "Include Windows-compatibility check"), isOn: $state.settings.checkWindowsCompat)
                Text(L("스캔 시 윈도우 금지 문자(\\ / : * ? \" < > |), 예약어(CON 등), 끝 공백/마침표도 검사해 치환을 제안합니다.",
                       "When scanning, also checks Windows-forbidden characters (\\ / : * ? \" < > |), reserved names (CON, etc.), and trailing spaces/dots, and proposes replacements."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 공용: 빈 상태 표시 (macOS 13 호환)

struct ContentUnavailableCompat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
