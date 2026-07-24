// README용 배너 이미지 생성 (docs/images/banner.png)
// 사용: swift Scripts/make-banner.swift

import AppKit

let W = 1280, H = 440
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let w = CGFloat(W), h = CGFloat(H)

// 배경 그라데이션
NSGradient(
    starting: NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.20, alpha: 1),
    ending: NSColor(calibratedRed: 0.15, green: 0.10, blue: 0.28, alpha: 1)
)!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -50)

// 앱 아이콘 카드 (왼쪽)
let iconSize: CGFloat = 200
let iconRect = NSRect(x: 110, y: (h - iconSize) / 2, width: iconSize, height: iconSize)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 44, yRadius: 44)
NSColor(calibratedWhite: 0, alpha: 0.35).setFill()
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.5)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSGradient(
    starting: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.96, alpha: 1),
    ending: NSColor(calibratedRed: 0.42, green: 0.24, blue: 0.86, alpha: 1)
)!.draw(in: iconPath, angle: -60)
NSShadow().set()

let han = "한" as NSString
let hanFont = NSFont.systemFont(ofSize: iconSize * 0.5, weight: .bold)
let hanAttrs: [NSAttributedString.Key: Any] = [.font: hanFont, .foregroundColor: NSColor.white]
let hanSize = han.size(withAttributes: hanAttrs)
han.draw(
    at: NSPoint(x: iconRect.midX - hanSize.width / 2, y: iconRect.midY - hanSize.height / 2),
    withAttributes: hanAttrs
)

// 텍스트 (오른쪽)
let titleX: CGFloat = 380
let title = "JamoFix" as NSString
title.draw(at: NSPoint(x: titleX, y: 250), withAttributes: [
    .font: NSFont.systemFont(ofSize: 92, weight: .bold),
    .foregroundColor: NSColor.white,
])

let subtitle = "한글 파일명 자소분리·인코딩 깨짐 자동 해결" as NSString
subtitle.draw(at: NSPoint(x: titleX + 4, y: 190), withAttributes: [
    .font: NSFont.systemFont(ofSize: 30, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.75),
])

// before → after 예시 (모노스페이스)
let mono = NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
let broken = "ㅎㅏㄴㄱㅡㄹ.txt" as NSString
broken.draw(at: NSPoint(x: titleX + 4, y: 110), withAttributes: [
    .font: mono,
    .foregroundColor: NSColor(calibratedRed: 1, green: 0.5, blue: 0.5, alpha: 0.95),
])
let brokenW = broken.size(withAttributes: [.font: mono]).width
let arrow = "→" as NSString
arrow.draw(at: NSPoint(x: titleX + 4 + brokenW + 20, y: 108), withAttributes: [
    .font: NSFont.systemFont(ofSize: 26, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.6),
])
let fixed = "한글.txt" as NSString
fixed.draw(at: NSPoint(x: titleX + 4 + brokenW + 60, y: 110), withAttributes: [
    .font: mono,
    .foregroundColor: NSColor(calibratedRed: 0.5, green: 1, blue: 0.7, alpha: 0.95),
])

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "docs/images/banner.png"))
print("생성 완료: docs/images/banner.png")
