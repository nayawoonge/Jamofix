import SwiftUI
import JamoFixCore

struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle(L("파일명 감시", "Watch filenames"), isOn: $state.globalEnabled)

        Text(state.lastActivity)

        Divider()

        if state.folders.isEmpty {
            Text(L("등록된 폴더 없음", "No folders added"))
        } else {
            ForEach(state.folders) { folder in
                Toggle(folder.displayName, isOn: Binding(
                    get: { folder.enabled },
                    set: { _ in state.toggleFolder(folder) }
                ))
            }
        }

        Divider()

        if !state.pendingPlans.isEmpty {
            Button(L("확인 필요한 항목 \(state.pendingPlans.count)개 보기…",
                     "Review \(state.pendingPlans.count) pending item(s)…")) {
                openMainWindow()
            }
        }

        Button(L("전체 스캔 (미리보기)", "Scan All (preview)")) {
            state.manualScanAll()
            openMainWindow()
        }
        .disabled(state.folders.isEmpty)

        Divider()

        Button(L("메인 창 열기", "Open Main Window")) { openMainWindow() }
        Button(L("종료", "Quit")) { NSApp.terminate(nil) }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
