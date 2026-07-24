import Foundation

/// NFD 자소분리 상태를 "눈에 보이게" 만드는 표시 헬퍼.
///
/// macOS는 NFD 파일명도 조합해서 렌더링하므로 사용자 눈에는 정상으로 보인다.
/// 결합 자모(U+1100 블록)를 호환 자모(U+3130 블록)로 바꾸면 렌더러가 조합하지
/// 못해 "ㅎㅏㄴㄱㅡㄹ.txt"처럼 윈도우에서 깨질 모습 그대로 보여줄 수 있다.
public enum HangulDisplay {

    // 초성 U+1100–U+1112 → 호환 자모
    private static let choseong: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    // 종성 U+11A8–U+11C2 → 호환 자모
    private static let jongseong: [Character] = [
        "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ",
        "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ",
        "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    /// 결합 자모를 호환 자모로 치환해 자소분리 상태를 시각화.
    /// NFC 문자열은 그대로 반환된다.
    public static func visualize(_ name: String) -> String {
        var out = ""
        for scalar in name.unicodeScalars {
            switch scalar.value {
            case 0x1100...0x1112:
                out.append(choseong[Int(scalar.value - 0x1100)])
            case 0x1161...0x1175:
                // 중성 U+1161–U+1175는 호환 자모 U+314F–U+3163과 순서가 같음
                out.unicodeScalars.append(Unicode.Scalar(0x314F + (scalar.value - 0x1161))!)
            case 0x11A8...0x11C2:
                out.append(jongseong[Int(scalar.value - 0x11A8)])
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// 이름이 자소분리(NFD) 상태인지
    public static func isDecomposed(_ name: String) -> Bool {
        !NameAnalyzer.scalarEqual(name, name.precomposedStringWithCanonicalMapping)
    }
}
