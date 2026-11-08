#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

let width = 1024
let height = 1024

let fileManager = FileManager.default
let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appIconDir = currentDirectory
    .appendingPathComponent("DualNBack")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

try fileManager.createDirectory(at: appIconDir, withIntermediateDirectories: true)

guard let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("No se pudo crear NSBitmapImageRep de 1024x1024")
}

bitmapRep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
    fatalError("No se pudo inicializar NSGraphicsContext")
}
NSGraphicsContext.current = graphicsContext
let ctx = graphicsContext.cgContext

// Invertimos el sistema de coordenadas Y para dibujar igual que en iOS (origen arriba-izquierda)
ctx.translateBy(x: 0, y: CGFloat(height))
ctx.scaleBy(x: 1.0, y: -1.0)

func cgColor(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) -> CGColor {
    CGColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

// 1. Fondo azul claro #85B8EE
ctx.setFillColor(cgColor(r: 133, g: 184, b: 238))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 2. Silueta blanca central de perfil de cabeza humana
let headRect = CGRect(x: 140, y: 120, width: 744, height: 784)
let w = headRect.width
let h = headRect.height
let ox = headRect.origin.x
let oy = headRect.origin.y

func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
    CGPoint(x: ox + w * nx, y: oy + h * ny)
}

let headPath = CGMutablePath()
headPath.move(to: pt(0.34, 0.96))
headPath.addQuadCurve(to: pt(0.64, 0.96), control: pt(0.49, 1.00))
headPath.addQuadCurve(to: pt(0.66, 0.78), control: pt(0.63, 0.86))
headPath.addQuadCurve(to: pt(0.82, 0.73), control: pt(0.80, 0.79))
headPath.addCurve(to: pt(0.84, 0.56), control1: pt(0.86, 0.68), control2: pt(0.82, 0.61))
headPath.addQuadCurve(to: pt(0.93, 0.49), control: pt(0.95, 0.54))
headPath.addQuadCurve(to: pt(0.82, 0.37), control: pt(0.88, 0.43))
headPath.addCurve(to: pt(0.42, 0.05), control1: pt(0.85, 0.16), control2: pt(0.66, 0.03))
headPath.addCurve(to: pt(0.16, 0.55), control1: pt(0.16, 0.07), control2: pt(0.06, 0.33))
headPath.addCurve(to: pt(0.34, 0.96), control1: pt(0.23, 0.69), control2: pt(0.31, 0.82))
headPath.closeSubpath()

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: 14),
    blur: 28,
    color: cgColor(r: 46, g: 107, b: 184, a: 0.28)
)
ctx.setFillColor(cgColor(r: 255, g: 255, b: 255))
ctx.addPath(headPath)
ctx.fillPath()
ctx.restoreGState()

// 3. Cuadrícula interna de 3x3 en la zona del cerebro (8 cuadros azul claro #A8CCF4 y 1 amarillo #FAD272)
let cellSize: CGFloat = 86
let cellSpacing: CGFloat = 20
let gridTotalWidth = (cellSize * 3) + (cellSpacing * 2)
let gridOriginX: CGFloat = (CGFloat(width) - gridTotalWidth) / 2.0 - 28
let gridOriginY: CGFloat = 278

let lightBlue = cgColor(r: 168, g: 204, b: 244) // #A8CCF4
let warmYellow = cgColor(r: 250, g: 210, b: 114) // #FAD272
let highlightedCellIndex = 2 // Esquina superior derecha de la cuadrícula

for row in 0..<3 {
    for col in 0..<3 {
        let index = row * 3 + col
        let cellX = gridOriginX + CGFloat(col) * (cellSize + cellSpacing)
        let cellY = gridOriginY + CGFloat(row) * (cellSize + cellSpacing)
        let rect = CGRect(x: cellX, y: cellY, width: cellSize, height: cellSize)
        let roundedPath = CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil)
        
        ctx.setFillColor(index == highlightedCellIndex ? warmYellow : lightBlue)
        ctx.addPath(roundedPath)
        ctx.fillPath()
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("No se pudo exportar PNG de 1024x1024")
}

let iconFileURL = appIconDir.appendingPathComponent("AppIcon.png")
try pngData.write(to: iconFileURL, options: .atomic)

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsURL = appIconDir.appendingPathComponent("Contents.json")
try contentsJSON.data(using: .utf8)?.write(to: contentsURL, options: .atomic)

print("AppIcon.png (1024x1024) y Contents.json generados exitosamente en \(appIconDir.path)")
