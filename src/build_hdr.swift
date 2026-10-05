import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
let inputURL=URL(fileURLWithPath:"outputs/Launch-Day-Cycle.heic")
let source=CGImageSourceCreateWithURL(inputURL as CFURL,nil)!
let count=CGImageSourceGetCount(source)
let outputURL=URL(fileURLWithPath:"outputs/Launch-Day-Cycle-HDR.heic")
let dest=CGImageDestinationCreateWithURL(outputURL as CFURL,UTType.heic.identifier as CFString,count,nil)!
let sRGB=CGColorSpace(name:CGColorSpace.sRGB)!
let linear=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
let bitmap=CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue
let ci=CIContext(options:[.cacheIntermediates:false])
let metadata=CGImageSourceCopyMetadataAtIndex(source,0,nil)!
func smooth(_ a:Float,_ b:Float,_ x:Float)->Float { let t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t) }
func linearize(_ x:Float)->Float { x<=0.04045 ? x/12.92:pow((x+0.055)/1.055,2.4) }
try FileManager.default.createDirectory(atPath:"work/hdr-frames",withIntermediateDirectories:true)
for index in 0..<count {
    try autoreleasepool {
        let base=CGImageSourceCreateImageAtIndex(source,index,[kCGImageSourceDecodeRequest:kCGImageSourceDecodeToSDR] as CFDictionary)!
        let w=base.width,h=base.height,n=w*h
        let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:sRGB,bitmapInfo:bitmap)!
        ctx.draw(base,in:CGRect(x:0,y:0,width:w,height:h))
        let bytes=ctx.data!.assumingMemoryBound(to:UInt8.self)
        var pixels=[Float16](repeating:1,count:n*4)
        var maxLuminance:Float=1
        let hour=index==0 ? 12 : (index<=12 ? index-1 : index)
        let daylight=smooth(6,10,Float(hour))*(1-smooth(16,20,Float(hour)))
        for y in 0..<h {
            let py=Float(y)/Float(h)
            for x in 0..<w {
                let px=Float(x)/Float(w),p=y*w+x,q=p*4
                let r=Float(bytes[q])/255,g=Float(bytes[q+1])/255,b=Float(bytes[q+2])/255
                let lum=0.2126*r+0.7152*g+0.0722*b
                let fx=(px-(0.490-0.012*(py-0.47)))/0.009
                let flame=exp(-0.5*fx*fx)*smooth(0.461,0.484,py)*(1-smooth(0.709,0.744,py))
                let dx=(px-0.493)/0.13,dy=(py-0.698)/0.09
                let bounce=exp(-0.5*(dx*dx+dy*dy))*smooth(0.03,0.25,r-b)*0.8
                let emission=max(flame,bounce)*smooth(0.48,0.98,max(r,g,b))
                let diffuse=smooth(0.58,0.97,lum)*daylight*0.45
                let gain=1+3.1*emission+diffuse
                let rr=min(4,linearize(r)*gain),gg=min(4,linearize(g)*gain),bb=min(4,linearize(b)*gain)
                pixels[q]=Float16(rr);pixels[q+1]=Float16(gg);pixels[q+2]=Float16(bb)
                maxLuminance=max(maxLuminance,rr*0.2126+gg*0.7152+bb*0.0722)
            }
        }
        let data=pixels.withUnsafeBytes{Data($0)} as CFData
        let hdr=CGImage(headroom:maxLuminance,width:w,height:h,bitsPerComponent:16,bitsPerPixel:64,bytesPerRow:w*8,space:linear,bitmapInfo:[.floatComponents,.byteOrder16Little,CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)],provider:CGDataProvider(data:data)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
        let url=URL(fileURLWithPath:String(format:"work/hdr-frames/%02d.heic",index))
        try ci.writeHEIFRepresentation(of:CIImage(cgImage:base),to:url,format:.RGBA8,colorSpace:sRGB,options:[.hdrImage:CIImage(cgImage:hdr),kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:0.96])
        let paired=CGImageSourceCreateWithURL(url as CFURL,nil)!
        guard let aux=CGImageSourceCopyAuxiliaryDataInfoAtIndex(paired,0,kCGImageAuxiliaryDataTypeISOGainMap) else {fatalError("Missing HDR gain map")}
        let properties=[kCGImageDestinationLossyCompressionQuality:0.96] as CFDictionary
        if index==0 {CGImageDestinationAddImageAndMetadata(dest,base,metadata,properties)}
        else {CGImageDestinationAddImage(dest,base,properties)}
        CGImageDestinationAddAuxiliaryDataInfo(dest,kCGImageAuxiliaryDataTypeISOGainMap,aux)
        print("HDR \(hour):00 · headroom \(maxLuminance) · gain map attached");fflush(stdout)
    }
}
guard CGImageDestinationFinalize(dest) else {fatalError("Cannot finalize HDR wallpaper")}
print("Saved \(outputURL.path)")
