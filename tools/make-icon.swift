#!/usr/bin/env swift
//
// Renders the app icon as a 1024pt PNG. build.sh turns it into AppIcon.icns.
//
import AppKit
import CoreGraphics

let side = 1024
guard let context = CGContext(
    data: nil, width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let full = CGRect(x: 0, y: 0, width: side, height: side)

// macOS icons sit inside a rounded square with a margin.
let inset: CGFloat = 88
let plate = full.insetBy(dx: inset, dy: inset)
let radius: CGFloat = 200
let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

context.saveGState()
context.addPath(platePath)
context.clip()

// Deep space gradient.
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let bg = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1),
    CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
] as CFArray, locations: [0, 1])!
context.drawLinearGradient(bg, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])

// Cyan glow bleeding from the top-left.
let glow = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.31, green: 0.85, blue: 1.0, alpha: 0.55),
    CGColor(red: 0.31, green: 0.85, blue: 1.0, alpha: 0.0)
] as CFArray, locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: plate.minX + 120, y: plate.maxY - 100),
                           startRadius: 0, endCenter: CGPoint(x: plate.minX + 120, y: plate.maxY - 100),
                           endRadius: 620, options: [])

// Calendar grid: 7 columns x 5 rows of dots, with "today" lit up.
let cols = 7, rows = 5
let gridWidth = plate.width * 0.62
let step = gridWidth / CGFloat(cols - 1)
let originX = plate.midX - gridWidth / 2
let originY = plate.midY - step * CGFloat(rows - 1) / 2 - 40
let dot: CGFloat = 26

for row in 0..<rows {
    for col in 0..<cols {
        let center = CGPoint(x: originX + CGFloat(col) * step,
                             y: originY + CGFloat(rows - 1 - row) * step)
        let isToday = (row == 2 && col == 3)
        let size = isToday ? dot * 2.1 : dot
        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        if isToday {
            context.setShadow(offset: .zero, blur: 60,
                              color: CGColor(red: 0.31, green: 0.85, blue: 1.0, alpha: 0.95))
            context.setFillColor(CGColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 1))
            context.addPath(CGPath(roundedRect: rect, cornerWidth: size * 0.32, cornerHeight: size * 0.32, transform: nil))
            context.fillPath()
            context.setShadow(offset: .zero, blur: 0, color: nil)
        } else {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.34))
            context.fillEllipse(in: rect)
        }
    }
}

// Header bar above the grid.
let bar = CGRect(x: originX, y: originY + step * CGFloat(rows - 1) + 96, width: gridWidth * 0.52, height: 30)
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
context.addPath(CGPath(roundedRect: bar, cornerWidth: 15, cornerHeight: 15, transform: nil))
context.fillPath()

context.restoreGState()

// Hairline edge.
context.addPath(platePath)
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
context.setLineWidth(4)
context.strokePath()

guard let image = context.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
