import SwiftUI

@main
struct JamoFixApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        // 메인 창 (Dock에서 열림)
        Window("JamoFix", id: "main") {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 440)
        }

        // 메뉴바 상주 아이콘
        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.globalEnabled
                  ? "character.textbox.ko"
                  : "pause.circle")
        }
        .menuBarExtraStyle(.menu)
    }
}
