#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    fputs("ERROR: \(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 4 else {
    fail("Usage: flatten-store-shot.swift INPUT.png OUTPUT.png RRGGBB")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let hex = CommandLine.arguments[3]
guard hex.count == 6, let rgb = Int(hex, radix: 16) else {
    fail("background must be six hexadecimal RGB digits")
}

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let input = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fail("could not decode \(inputURL.path)")
}
let colorSpace = CGColorSpaceCreateDeviceRGB()

let width = input.width
let height = input.height
let bytesPerRow = width * 4
var pixels = Data(count: bytesPerRow * height)
var flattened: CGImage?

pixels.withUnsafeMutableBytes { buffer in
    guard let context = CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return
    }

    let red = CGFloat((rgb >> 16) & 0xFF) / 255
    let green = CGFloat((rgb >> 8) & 0xFF) / 255
    let blue = CGFloat(rgb & 0xFF) / 255
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setBlendMode(.normal)
    context.interpolationQuality = .none
    context.draw(input, in: CGRect(x: 0, y: 0, width: width, height: height))
    flattened = context.makeImage()
}

guard let flattened else { fail("could not create RGB bitmap context") }
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fail("could not create \(outputURL.path)")
}

CGImageDestinationAddImage(destination, flattened, nil)
guard CGImageDestinationFinalize(destination) else {
    fail("could not encode \(outputURL.path)")
}
