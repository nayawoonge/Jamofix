// JamoFixCore 자체 검증 러너 — Xcode(XCTest) 없이 CLT만으로 실행 가능
// 실행: swift run jamofix-selftest

import Foundation
import JamoFixCore

var passed = 0
var failed = 0

func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    if condition {
        passed += 1
        print("  ✅ \(name)")
    } else {
        failed += 1
        print("  ❌ \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

func section(_ title: String) {
    print("\n[\(title)]")
}

// MARK: - NFD (자소분리)

section("NFD 자소분리 감지/수정")

let nfc = "한글파일.txt"
let nfd = nfc.decomposedStringWithCanonicalMapping
check(!NameAnalyzer.scalarEqual(nfc, nfd), "NFD/NFC 스칼라 상이 전제")

if let result = NameAnalyzer.analyze(nfd) {
    check(result.issues == [.nfd], "NFD 이슈 감지", "\(result.issues)")
    check(NameAnalyzer.scalarEqual(result.proposedName, nfc), "NFC로 정규화")
} else {
    check(false, "NFD 이름 분석 결과 존재")
}

check(NameAnalyzer.analyze("한글파일.txt") == nil, "정상 NFC 이름은 무이슈")
check(NameAnalyzer.analyze("english-file_2.pdf") == nil, "영문 이름은 무이슈")

// MARK: - Mojibake (인코딩 깨짐)

section("인코딩 깨짐(mojibake) 복구")

let original = "월간보고서.hwp"
if let cp949Data = original.data(using: NameAnalyzer.cp949),
   let garbled = String(data: cp949Data, encoding: .isoLatin1) {
    print("  (깨진 이름 재현: \(garbled))")
    if let repaired = NameAnalyzer.repairMojibake(garbled) {
        check(NameAnalyzer.scalarEqual(repaired, original), "Latin-1 오해석 복구", "\(repaired)")
    } else {
        check(false, "Latin-1 오해석 복구", "복구 제안 없음")
    }
    if let result = NameAnalyzer.analyze(garbled) {
        check(result.issues.contains(.mojibake), "mojibake 이슈 태깅")
        check(NameAnalyzer.scalarEqual(result.proposedName, original), "분석 경로로도 복구")
    } else {
        check(false, "깨진 이름 분석 결과 존재")
    }
} else {
    check(false, "CP949 왕복 재현")
}

// URL API를 거치면 이름이 NFD로 분해됨 (ù → u+결합문자) — 이 상태에서도 복구돼야 함
if let cp949Data = original.data(using: NameAnalyzer.cp949),
   let garbled = String(data: cp949Data, encoding: .isoLatin1) {
    let decomposedGarble = garbled.decomposedStringWithCanonicalMapping
    if let repaired = NameAnalyzer.repairMojibake(decomposedGarble) {
        check(NameAnalyzer.scalarEqual(repaired, original), "NFD 분해된 깨진 이름도 복구")
    } else {
        check(false, "NFD 분해된 깨진 이름도 복구", "복구 제안 없음")
    }
}

check(NameAnalyzer.repairMojibake("정상파일.txt") == nil, "정상 한글은 오탐 없음")
check(NameAnalyzer.repairMojibake("café résumé.txt") == nil, "유럽어 이름은 오탐 없음")

// MARK: - 윈도우 호환성

section("윈도우 호환성 검사")

if let result = NameAnalyzer.analyze("보고서: 최종?.txt", options: .init(sanitizeWindows: true)) {
    check(result.issues == [.windowsUnsafe], "금지 문자 이슈 감지")
    check(result.proposedName == "보고서_ 최종_.txt", "금지 문자 치환", result.proposedName)
} else {
    check(false, "금지 문자 이름 분석 결과 존재")
}

check(NameAnalyzer.sanitizeForWindows("CON.txt") == "_CON.txt", "예약어 CON")
check(NameAnalyzer.sanitizeForWindows("con.txt") == "_con.txt", "예약어 소문자")
check(NameAnalyzer.sanitizeForWindows("LPT1") == "_LPT1", "예약어 LPT1")
check(NameAnalyzer.sanitizeForWindows("이름. ") == "이름", "끝 공백/마침표 제거")
check(NameAnalyzer.sanitizeForWindows("이름...") == "이름", "연속 마침표 제거")
check(NameAnalyzer.sanitizeForWindows("정상 파일명 (1).txt") == "정상 파일명 (1).txt", "정상 이름 무변경")

// MARK: - RenameEngine (실제 파일시스템)

section("RenameEngine 파일시스템 동작")

func withTempDir(_ body: (URL) throws -> Void) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("JamoFixSelfTest-\(UUID().uuidString)")
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir)
    } catch {
        check(false, "임시 디렉토리 테스트", "\(error)")
    }
}

withTempDir { tempDir in
    // NFD 파일 생성 → 스캔 → 적용 → 디렉토리 엔트리가 NFC인지 확인 → 되돌리기
    let nfdName = "테스트파일.txt".decomposedStringWithCanonicalMapping
    try "hello".write(to: tempDir.appendingPathComponent(nfdName), atomically: true, encoding: .utf8)

    let plans = RenameEngine.scan(folder: tempDir, recursive: true, options: .init())
    check(plans.count == 1, "NFD 파일 스캔 감지", "\(plans.count)개")

    var errors: [(RenamePlan, Error)] = []
    let records = RenameEngine.apply(plans, errors: &errors)
    check(errors.isEmpty && records.count == 1, "rename 실행", "\(errors.map { "\($0.1)" })")

    let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
    let isNFC = contents.count == 1 && NameAnalyzer.scalarEqual(
        contents[0].precomposedStringWithCanonicalMapping, contents[0]
    )
    let scalars = contents.first.map { $0.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ") } ?? ""
    check(isNFC, "디렉토리 엔트리가 NFC", scalars)

    if let record = records.first {
        try RenameEngine.undo(record)
        let restored = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        check(restored.count == 1, "되돌리기")
    }
}

withTempDir { tempDir in
    // 폴더와 그 안의 파일이 모두 NFD → 깊은 것부터 rename돼야 함
    let dirURL = tempDir.appendingPathComponent("폴더".decomposedStringWithCanonicalMapping)
    try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    try "x".write(
        to: dirURL.appendingPathComponent("문서.txt".decomposedStringWithCanonicalMapping),
        atomically: true, encoding: .utf8
    )

    let plans = RenameEngine.scan(folder: tempDir, recursive: true, options: .init())
    check(plans.count == 2, "중첩 NFD 스캔", "\(plans.count)개")
    check(
        plans.count == 2 && plans[0].url.pathComponents.count > plans[1].url.pathComponents.count,
        "깊은 경로 우선 정렬"
    )

    var errors: [(RenamePlan, Error)] = []
    let records = RenameEngine.apply(plans, errors: &errors)
    check(errors.isEmpty && records.count == 2, "중첩 rename 실행", "\(errors.map { "\($0.1)" })")
}

withTempDir { tempDir in
    // rename 루프 방지 회귀 테스트 (v0.1.0 버그):
    // 디스크는 이미 NFC인데 FSEvents가 옛 NFD 경로로 이벤트를 준 상황.
    // APFS는 정규화 무시 조회라 NFD 경로도 "존재"하지만, 디스크 엔트리를
    // 재검증하므로 계획이 만들어지면 안 된다.
    let nfcPath = tempDir.path + "/정상파일.txt"
    let fd = nfcPath.withCString { open($0, O_CREAT | O_WRONLY, 0o644) }
    close(fd)

    let nfdPath = tempDir.path + "/" + "정상파일.txt".decomposedStringWithCanonicalMapping
    check(FileManager.default.fileExists(atPath: nfdPath), "전제: NFD 경로로도 조회됨 (APFS 정규화 무시)")

    let plan = RenameEngine.planFor(url: URL(fileURLWithPath: nfdPath), options: .init())
    check(plan == nil, "NFC 디스크 + NFD 이벤트 경로 → 오탐/루프 없음")

    // 반대로 디스크가 진짜 NFD면 계획이 나와야 함
    let realNFDPath = tempDir.path + "/" + "분리된파일.txt".decomposedStringWithCanonicalMapping
    let fd2 = realNFDPath.withCString { open($0, O_CREAT | O_WRONLY, 0o644) }
    close(fd2)
    let plan2 = RenameEngine.planFor(url: URL(fileURLWithPath: realNFDPath), options: .init())
    check(plan2 != nil, "진짜 NFD 디스크 엔트리는 계획 생성")
}

section("로컬라이제이션")

// 시스템 언어에 따라 한/영 중 하나가 나오되, 빈 문자열은 아니어야 함
let sample = L("폴더", "Folders")
check(sample == "폴더" || sample == "Folders", "L() 언어 선택", sample)
check(!IssueKind.nfd.label.isEmpty, "IssueKind.label 비어있지 않음")
// 현재 시스템 언어 상태 출력 (참고용)
print("  (현재 Loc.isKorean = \(Loc.isKorean), 예시 label = \(IssueKind.nfd.label))")

section("자소분리 시각화")

let visualized = HangulDisplay.visualize("한글.txt".decomposedStringWithCanonicalMapping)
check(visualized == "ㅎㅏㄴㄱㅡㄹ.txt", "NFD → 보이는 자소분리", visualized)
check(HangulDisplay.visualize("한글.txt") == "한글.txt", "NFC는 그대로")
check(HangulDisplay.visualize("test.txt") == "test.txt", "영문은 그대로")

section("RenameEngine 충돌 처리")

withTempDir { tempDir in
    // 이름 충돌 시 " (1)" 회피 로직
    let existing = tempDir.appendingPathComponent("문서.txt")
    try "a".write(to: existing, atomically: true, encoding: .utf8)
    let candidate = RenameEngine.availablePath(for: tempDir.path + "/문서.txt")
    let candidateName = (candidate as NSString).lastPathComponent
    check(candidateName == "문서 (1).txt", "충돌 회피 이름", candidateName)
}

// MARK: - 결과

print("\n──────────────────────────")
print("통과 \(passed) / 실패 \(failed)")
exit(failed == 0 ? 0 : 1)
