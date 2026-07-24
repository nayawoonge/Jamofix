import Foundation

/// 경량 로컬라이제이션. 시스템 기본 언어가 한국어면 한국어, 그 외에는 영어를 반환.
///
/// Xcode(.xcstrings/.strings) 없이 CLT만으로 완결되도록 호출부에 두 언어를 함께 둔다.
/// 예: `Text(L("폴더", "Folders"))`
public func L(_ ko: String, _ en: String) -> String {
    Loc.isKorean ? ko : en
}

public enum Loc {
    /// 시스템 선호 언어가 한국어인지. 앱 실행 중에는 바뀌지 않으므로 1회 계산해 캐시.
    public static let isKorean: Bool = {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("ko")
    }()
}
