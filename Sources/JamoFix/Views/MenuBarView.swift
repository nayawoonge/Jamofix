import SwiftUI
import JamoFixCore

struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("파일명 감시", isOn: $state.globalEnabled)

        Text(state.lastActivity)

        Divider()

        if state.folders.isEmpty {
            Text("등록된 폴더 없음")
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
            Button("확인 필요한 항목 \(state.pendingPlans.count)개 보기…") {
                openMainWindow()
            }
        }

        Button("전체 스캔 (미리보기)") {
            state.manualScanAll()
            openMainWindow()
        }
        .disabled(state.folders.isEmpty)

        Divider()

        Button("메인 창 열기") { openMainWindow() }
        Button("종료") { NSApp.terminate(nil) }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
