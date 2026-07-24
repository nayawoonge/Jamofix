import Foundation
import UserNotifications

/// 알림 센터 연동.
/// 주의: UNUserNotificationCenter는 .app 번들 밖(swift run)에서 호출하면 크래시하므로
/// 반드시 번들 여부를 확인하고 사용한다.
enum NotificationManager {

    /// .app 번들로 실행 중인지 (swift run 개발 실행이면 false)
    static var isRunningInBundle: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    static func notify(title: String, body: String) {
        guard isRunningInBundle else { return }
        let center = UNUserNotificationCenter.current()
        // 최초 1회만 실제 권한 요청이 뜨고 이후는 no-op
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
