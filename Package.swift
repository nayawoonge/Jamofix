// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JamoFix",
    platforms: [.macOS(.v13)],
    targets: [
        // 코어 로직 (분석/감시/rename) — UI 없이 테스트 가능
        .target(name: "JamoFixCore"),
        // 메뉴바 + 윈도우 SwiftUI 앱
        .executableTarget(
            name: "JamoFix",
            dependencies: ["JamoFixCore"]
        ),
        // Xcode 없이(CLT만으로) 코어 로직을 검증하는 자체 테스트 러너
        // 실행: swift run jamofix-selftest
        .executableTarget(
            name: "jamofix-selftest",
            dependencies: ["JamoFixCore"]
        ),
    ]
)
