#!/usr/bin/env swift

import AppKit
import Foundation
import Vision

func usage() -> Never {
    fputs("Usage: inspect-store-shot.swift IMAGE [--require TEXT] [--forbid TEXT] [--corner-rgb RRGGBB]\n", stderr)
    exit(2)
}

guard CommandLine.arguments.count >= 2 else { usage() }

let imagePath = CommandLine.arguments[1]
var required: [String] = []
var forbidden: [String] = []
var expectedCornerRGB: String?
var index = 2
while index < CommandLine.arguments.count {
    guard index + 1 < CommandLine.arguments.count else { usage() }
    switch CommandLine.arguments[index] {
    case "--require":
        required.append(CommandLine.arguments[index + 1])
    case "--forbid":
        forbidden.append(CommandLine.arguments[index + 1])
    case "--corner-rgb":
        expectedCornerRGB = CommandLine.arguments[index + 1]
    default:
        usage()
    }
    index += 2
}

let imageURL = URL(fileURLWithPath: imagePath)
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["ja-JP", "en-US"]
request.usesLanguageCorrection = true

do {
    try VNImageRequestHandler(url: imageURL).perform([request])
} catch {
    fputs("ERROR: OCR failed for \(imagePath): \(error)\n", stderr)
    exit(1)
}

let recognized = (request.results ?? []).compactMap { observation in
    observation.topCandidates(1).first?.string
}

func normalized(_ value: String) -> String {
    value
        .precomposedStringWithCompatibilityMapping
        .lowercased()
        .filter { !$0.isWhitespace && !$0.isNewline }
}

let haystack = normalized(recognized.joined(separator: "\n"))
var failed = false

if let hex = expectedCornerRGB {
    guard hex.count == 6, let expected = Int(hex, radix: 16) else { usage() }
    guard
        let imageData = try? Data(contentsOf: imageURL),
        let bitmap = NSBitmapImageRep(data: imageData)
    else {
        fputs("ERROR: could not inspect image corners in \(imagePath)\n", stderr)
        exit(1)
    }
    let corners: [(Int, Int)] = [
        (0, 0),
        (bitmap.pixelsWide - 1, 0),
        (0, bitmap.pixelsHigh - 1),
        (bitmap.pixelsWide - 1, bitmap.pixelsHigh - 1),
    ]
    for (x, y) in corners {
        var components = [Int](repeating: 0, count: max(bitmap.samplesPerPixel, 3))
        bitmap.getPixel(&components, atX: x, y: y)
        let actual = (components[0] << 16) | (components[1] << 8) | components[2]
        if actual != expected {
            fputs(
                String(format: "ERROR: corner (%d,%d) in %@ is #%06X, expected #%06X\n", x, y, imagePath, actual, expected),
                stderr
            )
            failed = true
        }
    }
}
for needle in required where !haystack.contains(normalized(needle)) {
    fputs("ERROR: required UI text not recognized in \(imagePath): \(needle)\n", stderr)
    failed = true
}
for needle in forbidden where haystack.contains(normalized(needle)) {
    fputs("ERROR: forbidden overlay/text recognized in \(imagePath): \(needle)\n", stderr)
    failed = true
}

if failed {
    fputs("OCR: \(recognized.joined(separator: " | "))\n", stderr)
    exit(1)
}

print("PASS  \(imagePath)  OCR current-UI/overlay check")
