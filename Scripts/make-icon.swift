// 앱 아이콘(.icns) 생성 스크립트 — Xcode 없이 실행 가능
// 사용: swift Scripts/make-icon.swift [출력디렉토리]

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetPath = outDir + "/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)
    // macOS 아이콘 스타일: 여백 있는 라운드 사각형
    let inset = s * 0.06
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.21, yRadius: s * 0.21)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.96, alpha: 1),
        ending: NSColor(calibratedRed: 0.42, green: 0.24, blue: 0.86, alpha: 1)
    )!
    gradient.draw(in: path, angle: -60)

    // 중앙에 "한" — 자소가 "조합된" 상태를 상징
    let text = "한" as NSString
    let font = NSFont.systemFont(ofSize: s * 0.52, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attrs)
    text.draw(
        at: NSPoint(x: (s - textSize.width) / 2, y: (s - textSize.height) / 2),
        withAttributes: attrs
    )

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in specs {
    try render(size: size).write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

// iconset → icns 변환 (iconutil은 macOS 기본 포함)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", outDir + "/AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("생성 완료: \(outDir)/AppIcon.icns")
    try? FileManager.default.removeItem(atPath: iconsetPath)
} else {
    print("iconutil 실패 (exit \(process.terminationStatus))")
    exit(1)
}
