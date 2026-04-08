#!/bin/bash
# Quick placeholder app icon: orange background with white kebab emoji.
# Requires only macOS built-ins (sips + sourcecode via swift).
set -euo pipefail

OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/iOS/DoenerApp/Resources/Assets.xcassets/AppIcon.appiconset"
OUT_FILE="$OUT_DIR/icon-1024.png"

mkdir -p "$OUT_DIR"

swift - <<'SWIFT'
import Foundation
import AppKit

let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Background gradient (orange)
let gradient = NSGradient(colors: [
    NSColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1),
    NSColor(red: 0.95, green: 0.35, blue: 0.05, alpha: 1)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// Emoji
let emoji = "🥙" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 720),
]
let textSize = emoji.size(withAttributes: attrs)
let rect = NSRect(
    x: (CGFloat(size) - textSize.width) / 2,
    y: (CGFloat(size) - textSize.height) / 2 - 40,
    width: textSize.width,
    height: textSize.height
)
emoji.draw(in: rect, withAttributes: attrs)

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

let outPath = ProcessInfo.processInfo.environment["OUT_FILE"]!
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
SWIFT

echo "Icon: $OUT_FILE"
