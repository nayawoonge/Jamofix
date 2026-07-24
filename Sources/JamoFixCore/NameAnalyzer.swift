import Foundation
import CoreFoundation

/// 파일명에서 발견된 문제 유형
public enum IssueKind: String, Codable, CaseIterable {
    case nfd            // 자소분리 (NFD 정규화 상태)
    case mojibake       // 인코딩 깨짐 (CP949 바이트를 Latin-1 등으로 오해석)
    case windowsUnsafe  // 윈도우 비호환 (금지 문자, 예약어, 끝 공백/마침표)

    public var label: String {
        switch self {
        case .nfd: return L("자소분리", "Jamo split")
        case .mojibake: return L("인코딩 깨짐", "Mojibake")
        case .windowsUnsafe: return L("윈도우 비호환", "Windows-unsafe")
        }
    }
}

/// 파일명 하나에 대한 분석 결과
public struct NameAnalysis: Equatable {
    public let originalName: String
    public let proposedName: String
    public let issues: [IssueKind]
}

public enum NameAnalyzer {

    public struct Options {
        public var fixNFD: Bool
        public var fixMojibake: Bool
        public var sanitizeWindows: Bool

        public init(fixNFD: Bool = true, fixMojibake: Bool = true, sanitizeWindows: Bool = false) {
            self.fixNFD = fixNFD
            self.fixMojibake = fixMojibake
            self.sanitizeWindows = sanitizeWindows
        }
    }

    /// CP949 (Windows 한국어 코드페이지) 인코딩
    public static let cp949: String.Encoding = {
        let cf = CFStringEncoding(CFStringEncodings.dosKorean.rawValue)
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
    }()

    /// 파일명을 분석해 문제가 있으면 수정안을 반환. 문제 없으면 nil.
    public static func analyze(_ name: String, options: Options = Options()) -> NameAnalysis? {
        var issues: [IssueKind] = []
        var current = name

        // 1. 인코딩 깨짐 복구 (가장 먼저 — 복구 후 NFC 정규화가 이어질 수 있음)
        if options.fixMojibake, let repaired = repairMojibake(current) {
            issues.append(.mojibake)
            current = repaired
        }

        // 2. NFD → NFC 정규화 (자소분리 해결)
        //    주의: Swift의 == 는 정규화를 무시하고 비교하므로 반드시 스칼라 단위로 비교
        if options.fixNFD {
            let nfc = current.precomposedStringWithCanonicalMapping
            if !scalarEqual(nfc, current) {
                issues.append(.nfd)
                current = nfc
            }
        }

        // 3. 윈도우 비호환 문자/이름 정리
        if options.sanitizeWindows {
            let sanitized = sanitizeForWindows(current)
            if sanitized != current {
                issues.append(.windowsUnsafe)
                current = sanitized
            }
        }

        guard !issues.isEmpty, !current.isEmpty, !scalarEqual(current, name) else { return nil }
        return NameAnalysis(originalName: name, proposedName: current, issues: issues)
    }

    /// 유니코드 스칼라 단위의 엄격한 비교 (NFC/NFD 구분)
    public static func scalarEqual(_ a: String, _ b: String) -> Bool {
        a.unicodeScalars.elementsEqual(b.unicodeScalars)
    }

    // MARK: - Mojibake (인코딩 깨짐) 감지/복구

    /// CP949 바이트가 Latin-1/CP1252/MacRoman으로 잘못 해석된 파일명을 복구.
    /// 예: "¿ù°£º¸°í¼­.hwp" → "월간보고서.hwp"
    /// 확신이 없으면 nil (오탐 방지가 최우선).
    public static func repairMojibake(_ rawName: String) -> String? {
        // URL API를 거친 이름은 NFD로 분해돼 있음 (예: ù → u + 결합문자).
        // Latin-1 인코딩 시도가 실패하지 않도록 먼저 NFC로 재조합
        let name = rawName.precomposedStringWithCanonicalMapping

        // 이미 정상 한글이 있으면 깨진 이름으로 보지 않음
        guard hangulRatio(name) == 0 else { return nil }

        // Latin-1 상위 영역(0x80–0xFF) 문자가 2개 이상 있어야 의심
        let highLatin = name.unicodeScalars.filter { (0x80...0xFF).contains($0.value) }
        guard highLatin.count >= 2 else { return nil }

        let candidates: [String.Encoding] = [.isoLatin1, .windowsCP1252, .macOSRoman]
        for encoding in candidates {
            guard let bytes = name.data(using: encoding, allowLossyConversion: false),
                  let repaired = String(data: bytes, encoding: cp949),
                  !repaired.contains("\u{FFFD}")
            else { continue }

            // 복구 결과의 비ASCII 문자 중 한글 비율이 높아야 채택
            if hangulRatio(repaired) >= 0.5, !scalarEqual(repaired, name) {
                return repaired.precomposedStringWithCanonicalMapping
            }
        }
        return nil
    }

    /// 비ASCII 문자 중 한글(음절/자모/호환자모)의 비율
    static func hangulRatio(_ s: String) -> Double {
        var hangul = 0, nonASCII = 0
        for scalar in s.unicodeScalars {
            guard scalar.value > 0x7F else { continue }
            nonASCII += 1
            switch scalar.value {
            case 0xAC00...0xD7A3,   // 한글 음절
                 0x1100...0x11FF,   // 한글 자모
                 0x3130...0x318F,   // 호환 자모
                 0xA960...0xA97F,   // 자모 확장 A
                 0xD7B0...0xD7FF:   // 자모 확장 B
                hangul += 1
            default:
                break
            }
        }
        guard nonASCII > 0 else { return 0 }
        return Double(hangul) / Double(nonASCII)
    }

    // MARK: - 윈도우 호환성

    /// 윈도우 예약 장치 이름 (확장자를 뗀 이름 기준, 대소문자 무시)
    public static let windowsReservedNames: Set<String> = {
        var names: Set<String> = ["CON", "PRN", "AUX", "NUL"]
        for i in 1...9 {
            names.insert("COM\(i)")
            names.insert("LPT\(i)")
        }
        return names
    }()

    /// 윈도우에서 쓸 수 없는 문자/패턴을 안전한 형태로 치환
    public static func sanitizeForWindows(_ name: String) -> String {
        let forbidden: Set<Character> = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]
        var result = String(name.map { forbidden.contains($0) ? "_" : $0 })

        // 제어 문자 제거
        result = String(result.unicodeScalars.filter { $0.value >= 0x20 }.map(Character.init))

        // 끝의 공백/마침표 제거 (윈도우에서 잘림)
        while let last = result.last, last == " " || last == "." {
            result.removeLast()
        }

        // 예약어면 앞에 밑줄
        let stem = (result as NSString).deletingPathExtension
        if windowsReservedNames.contains(stem.uppercased()) {
            result = "_" + result
        }

        return result.isEmpty ? "_" : result
    }
}
