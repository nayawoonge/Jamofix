import SwiftUI

/// 실행 직후 Dock 표시 정책을 적용하기 위한 델리게이트.
/// SwiftUI 뷰가 그려지기 전에 activation policy를 정해야 Dock 아이콘이
/// 잠깐 떴다 사라지는 깜빡임을 막을 수 있다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppState보다 먼저 실행될 수 있으므로 UserDefaults를 직접 참조
        let showDock = UserDefaults.standard.object(forKey: AppState.showDockIconKey) as? Bool ?? true
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
    }
}

@main
struct JamoFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        // 메인 창 (Dock 또는 메뉴바에서 열림)
        Window("JamoFix", id: "main") {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 640, minHeight: 440)
        }

        // 메뉴바 상주 아이콘 — showMenuBarIcon으로 표시/숨김 (안전장치는 setter가 담당)
        MenuBarExtra(isInserted: Binding(
            get: { state.showMenuBarIcon },
            set: { state.setShowMenuBarIcon($0) }
        )) {
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
