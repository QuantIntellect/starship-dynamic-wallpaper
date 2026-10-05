import Foundation
import CoreGraphics
import ImageIO

enum VerificationError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case .invalid(let message): message } }
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw VerificationError.invalid(message) }
}
func verify(_ file: String) throws {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil) else {
        throw VerificationError.invalid("Cannot open image: \(file)")
    }
    let count = CGImageSourceGetCount(source)
    guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
          let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] else {
        throw VerificationError.invalid("Missing dynamic metadata")
    }
    var entries: [[String: Any]] = []
    var kind = ""
    for tag in tags {
        guard let name = CGImageMetadataTagCopyName(tag) as String?, ["h24", "solar"].contains(name) else { continue }
        try require(kind.isEmpty, "Ambiguous dynamic metadata")
        guard let value = CGImageMetadataTagCopyValue(tag) as? String,
              let data = Data(base64Encoded: value),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let timeline = plist[name == "h24" ? "ti" : "si"] as? [[String: Any]],
              let appearance = plist["ap"] as? [String: Int] else {
            throw VerificationError.invalid("Malformed dynamic metadata")
        }
        kind = name
        entries = timeline
        try require(appearance["l"] == 0 && appearance["d"] == 1, "Wrong light/dark fallback indices")
    }
    try require(kind == "solar" || kind == "h24", "No supported day-cycle metadata")
    try require(count == (kind == "solar" ? 16 : 24), "Unexpected frame count")
    try require(entries.count == count, "Timeline/frame count mismatch")
    let indices = entries.compactMap { $0["i"] as? Int }
    try require(Set(indices) == Set(0..<count) && indices.count == count, "Invalid or unmapped frame indices")
    if kind == "h24" {
        for hour in 0..<24 {
            guard let time = entries[hour]["t"] as? Double else { throw VerificationError.invalid("Missing clock time") }
            try require(abs(time - Double(hour) / 24) < 1e-8, "Incorrect clock timing")
        }
    } else {
        var previousAzimuth = -1.0
        for entry in entries {
            guard let altitude = entry["a"] as? Double, let azimuth = entry["z"] as? Double else {
                throw VerificationError.invalid("Missing solar coordinates")
            }
            try require((-90...90).contains(altitude) && (0...360).contains(azimuth), "Solar coordinate out of range")
            try require(azimuth > previousAzimuth, "Solar anchors out of order")
            previousAzimuth = azimuth
        }
    }
    var minimumHDR: Float = 100, maximumHDR: Float = 0
    for index in 0..<count {
        try autoreleasepool {
            guard let hdr = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR, kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                  let sdr = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
                throw VerificationError.invalid("Frame \(index) cannot be decoded")
            }
            try require(hdr.width == 4096 && hdr.height == 2304 && sdr.width == 4096 && sdr.height == 2304, "Unexpected frame dimensions")
            try require(hdr.contentHeadroom > 2.5 && hdr.contentHeadroom <= 4.05, "Invalid HDR headroom in frame \(index)")
            try require(sdr.contentHeadroom == 1, "Invalid SDR fallback")
            try require(CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, kCGImageAuxiliaryDataTypeISOGainMap) != nil, "Missing ISO HDR gain map")
            minimumHDR = min(minimumHDR, hdr.contentHeadroom)
            maximumHDR = max(maximumHDR, hdr.contentHeadroom)
        }
    }
    print("PASS \(file): \(count) frames; \(kind) timeline; 4096 x 2304; HDR headroom \(minimumHDR)...\(maximumHDR); all gain maps and SDR fallbacks decoded")
}

do {
    try require(CommandLine.arguments.count > 1, "Usage: verify wallpaper.heic [other.heic ...]")
    for file in CommandLine.arguments.dropFirst() { try verify(file) }
} catch {
    FileHandle.standardError.write(Data("Verification failed: \(error)\n".utf8))
    exit(1)
}
