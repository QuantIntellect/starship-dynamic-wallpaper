import Foundation
import ImageIO
import UniformTypeIdentifiers

// All variants are pixelwise grades. No resampling, synthesized geometry or retouching.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("work/source.jpg")
let outputURL = root.appendingPathComponent("outputs/Launch-Day-Cycle.heic")
let previewOnly = CommandLine.arguments.contains("--preview")
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let original = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
precondition(original.width == 4096 && original.height == 2304, "This grade is designed for the included 4096 x 2304 launch image.")
let width = previewOnly ? 1280 : original.width
let height = previewOnly ? 720 : original.height
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)!
context.interpolationQuality = .high
context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
let count = width * height
let originalBytes = Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: count * 4))

struct Grade {
    let time: Float
    let rgb: SIMD3<Float>
    let saturation: Float
    let gamma: Float
    let glow: Float
}
let anchors: [Grade] = [
    Grade(time: 0, rgb: SIMD3(0.25,0.34,0.51), saturation: 0.64, gamma: 1.12, glow: 0.95),
    Grade(time: 4, rgb: SIMD3(0.27,0.35,0.53), saturation: 0.65, gamma: 1.10, glow: 0.94),
    Grade(time: 5, rgb: SIMD3(0.42,0.44,0.65), saturation: 0.66, gamma: 1.04, glow: 0.84),
    Grade(time: 6, rgb: SIMD3(0.68,0.58,0.70), saturation: 0.77, gamma: 1.00, glow: 0.68),
    Grade(time: 7, rgb: SIMD3(0.90,0.78,0.73), saturation: 0.88, gamma: 0.99, glow: 0.39),
    Grade(time: 8, rgb: SIMD3(0.98,0.91,0.87), saturation: 0.96, gamma: 1.00, glow: 0.18),
    Grade(time: 10, rgb: SIMD3(1,1,1), saturation: 1, gamma: 1, glow: 0),
    Grade(time: 14, rgb: SIMD3(1,1,1), saturation: 1, gamma: 1, glow: 0),
    Grade(time: 16, rgb: SIMD3(1.015,0.92,0.79), saturation: 1.00, gamma: 1.01, glow: 0.12),
    Grade(time: 17, rgb: SIMD3(0.96,0.76,0.59), saturation: 0.96, gamma: 1.04, glow: 0.28),
    Grade(time: 18, rgb: SIMD3(0.79,0.55,0.58), saturation: 0.81, gamma: 1.06, glow: 0.60),
    Grade(time: 19, rgb: SIMD3(0.48,0.42,0.65), saturation: 0.70, gamma: 1.08, glow: 0.85),
    Grade(time: 20, rgb: SIMD3(0.30,0.37,0.57), saturation: 0.66, gamma: 1.10, glow: 0.92),
    Grade(time: 22, rgb: SIMD3(0.25,0.34,0.51), saturation: 0.64, gamma: 1.12, glow: 0.95),
    Grade(time: 24, rgb: SIMD3(0.25,0.34,0.51), saturation: 0.64, gamma: 1.12, glow: 0.95)
]
func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b-a)*t }
func smooth(_ lo: Float, _ hi: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x-lo)/(hi-lo))); return t*t*(3-2*t)
}
func gradeAt(_ hour: Int) -> Grade {
    let h = Float(hour)
    let i = anchors.indices.dropLast().first { h >= anchors[$0].time && h <= anchors[$0+1].time }!
    let a = anchors[i], b = anchors[i+1]
    let t = smooth(a.time,b.time,h)
    return Grade(time:h, rgb:a.rgb+(b.rgb-a.rgb)*t, saturation:lerp(a.saturation,b.saturation,t), gamma:lerp(a.gamma,b.gamma,t), glow:lerp(a.glow,b.glow,t))
}
func writeImage(_ image: CGImage, to url: URL, type: CFString = UTType.jpeg.identifier as CFString, quality: Double = 0.93) {
    let dst = CGImageDestinationCreateWithURL(url as CFURL,type,1,nil)!
    CGImageDestinationAddImage(dst,image,[kCGImageDestinationLossyCompressionQuality:quality] as CFDictionary)
    precondition(CGImageDestinationFinalize(dst),"Image encoding failed")
}
func scaled(_ image: CGImage, width w: Int) -> CGImage {
    let h = w * image.height / image.width
    let ctx = CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:colorSpace,bitmapInfo:bitmapInfo)!
    ctx.interpolationQuality = .high
    ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
    return ctx.makeImage()!
}
// Preserve existing flame and the light it already casts; never add new flames.
var glowMask = [Float](repeating:0,count:count)
for y in 0..<height {
    let py = Float(y)/Float(height)
    for x in 0..<width {
        let px = Float(x)/Float(width), p = y*width+x, q = p*4
        let r = Float(originalBytes[q])/255, b = Float(originalBytes[q+2])/255
        let warm = smooth(0.015,0.23,r-b) * smooth(0.15,0.80,r)
        let dx = (px-0.493)/0.135, dy = (py-0.698)/0.092
        let bounce = exp(-0.5*(dx*dx+dy*dy)) * warm * 0.82
        let fx = (px-(0.490-0.012*(py-0.47)))/0.009
        let flame = exp(-0.5*fx*fx) * smooth(0.461,0.484,py) * (1-smooth(0.709,0.744,py)) * smooth(0.20,0.85,r)
        glowMask[p] = min(1,max(flame,bounce))
    }
}
func render(_ hour: Int) -> CGImage {
    let grade = gradeAt(hour)
    if grade.glow == 0 && !previewOnly { return original }
    var bytes = originalBytes
    for p in 0..<count {
        let q = p*4
        let rgb = SIMD3(Float(originalBytes[q]),Float(originalBytes[q+1]),Float(originalBytes[q+2]))/255
        let luma = rgb.x*0.2126+rgb.y*0.7152+rgb.z*0.0722
        let neutral = SIMD3<Float>(repeating:luma)
        let saturated = neutral + (rgb-neutral)*grade.saturation
        var c = SIMD3(pow(saturated.x,grade.gamma),pow(saturated.y,grade.gamma),pow(saturated.z,grade.gamma))*grade.rgb
        let preserve = glowMask[p]*grade.glow
        c = c+(rgb-c)*preserve
        bytes[q] = UInt8(clamping:Int((min(1,max(0,c.x))*255).rounded()))
        bytes[q+1] = UInt8(clamping:Int((min(1,max(0,c.y))*255).rounded()))
        bytes[q+2] = UInt8(clamping:Int((min(1,max(0,c.z))*255).rounded()))
    }
    let data = Data(bytes) as CFData
    return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),provider:CGDataProvider(data:data)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
let previewDirectory = root.appendingPathComponent("work/previews")
try FileManager.default.createDirectory(at:previewDirectory,withIntermediateDirectories:true)
// Put the unchanged original at primary index zero, independently of the clock order.
let hours = [12] + Array(0..<24).filter { $0 != 12 }
var destination: CGImageDestination?
if !previewOnly {
    destination = CGImageDestinationCreateWithURL(outputURL as CFURL,UTType.heic.identifier as CFString,hours.count,nil)!
}
let schedule: [[String:Any]] = (0..<24).map { hour in ["t":Double(hour)/24,"i":hours.firstIndex(of:hour)!] }
let plist: [String:Any] = ["ti":schedule,"ap":["l":0,"d":hours.firstIndex(of:0)!]]
let metadata = CGImageMetadataCreateMutable()
var error: Unmanaged<CFError>?
precondition(CGImageMetadataRegisterNamespaceForPrefix(metadata,"http://ns.apple.com/namespace/1.0/" as CFString,"apple_desktop" as CFString,&error))
let encoded = try PropertyListSerialization.data(fromPropertyList:plist,format:.binary,options:0).base64EncodedString()
let tag = CGImageMetadataTagCreate("http://ns.apple.com/namespace/1.0/" as CFString,"apple_desktop" as CFString,"h24" as CFString,.string,encoded as CFString)!
precondition(CGImageMetadataSetTagWithPath(metadata,nil,"apple_desktop:h24" as CFString,tag))
for (index,hour) in hours.enumerated() {
    autoreleasepool {
        let frame = render(hour)
        writeImage(scaled(frame,width:1280),to:previewDirectory.appendingPathComponent(String(format:"%02d.jpg",hour)))
        if let destination {
            let properties = [kCGImageDestinationLossyCompressionQuality:0.96] as CFDictionary
            if index == 0 { CGImageDestinationAddImageAndMetadata(destination,frame,metadata,properties) }
            else { CGImageDestinationAddImage(destination,frame,properties) }
        }
        print("Rendered \(hour):00 at \(width) × \(height)")
        fflush(stdout)
    }
}
if let destination { precondition(CGImageDestinationFinalize(destination),"HEIC finalize failed") }
let json = try JSONSerialization.data(withJSONObject:plist,options:[.prettyPrinted,.sortedKeys])
try json.write(to:root.appendingPathComponent("work/timeline.json"))
print(previewOnly ? "Preview grades ready" : "Saved \(outputURL.path)")
