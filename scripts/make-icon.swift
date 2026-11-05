import AppKit

let destination = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor(calibratedRed: 0.97, green: 0.92, blue: 0.81, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 200, yRadius: 200).fill()
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "PingFangSC-Semibold", size: 580) ?? NSFont.systemFont(ofSize: 580, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.16, alpha: 1)
]
let label = "在" as NSString
let size = label.size(withAttributes: attributes)
label.draw(at: NSPoint(x: (1024 - size.width) / 2, y: (1024 - size.height) / 2 + 14), withAttributes: attributes)
NSColor(calibratedRed: 0.88, green: 0.39, blue: 0.18, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 752, y: 756, width: 116, height: 116)).fill()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
