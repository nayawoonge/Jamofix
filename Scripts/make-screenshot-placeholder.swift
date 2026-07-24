// 스크린샷 자리표시자 생성 — 실제 캡처로 교체하기 전 README 레이아웃 확인용
// 사용: swift Scripts/make-screenshot-placeholder.swift

import AppKit

let shots: [(file: String, title: String)] = [
    ("screenshot-folders", "폴더 탭 — 감시 폴더 등록"),
    ("screenshot-preview", "미리보기 — 변경 전/후 확인"),
    ("screenshot-menubar", "메뉴바 — 토글 & 상태"),
]

for shot in shots {
    let W = 1000, H = 640
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let w = CGFloat(W), h = CGFloat(H)

    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill()

    // 점선 테두리
    let border = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: w - 48, height: h - 48), xRadius: 16, yRadius: 16)
    border.lineWidth = 3
    border.setLineDash([12, 8], count: 2, phase: 0)
    NSColor(calibratedWhite: 0.4, alpha: 1).setStroke()
    border.stroke()

    let cam = "🖼" as NSString
    let camAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 80)]
    let camSize = cam.size(withAttributes: camAttrs)
    cam.draw(at: NSPoint(x: w / 2 - camSize.width / 2, y: h / 2 + 30), withAttributes: camAttrs)

    let title = shot.title as NSString
    let tAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 1),
    ]
    let tSize = title.size(withAttributes: tAttrs)
    title.draw(at: NSPoint(x: w / 2 - tSize.width / 2, y: h / 2 - 30), withAttributes: tAttrs)

    let hint = "여기에 실제 스크린샷을 넣으세요" as NSString
    let hAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1),
    ]
    let hSize = hint.size(withAttributes: hAttrs)
    hint.draw(at: NSPoint(x: w / 2 - hSize.width / 2, y: h / 2 - 70), withAttributes: hAttrs)

    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "docs/images/\(shot.file).png"))
    print("생성: docs/images/\(shot.file).png")
}
