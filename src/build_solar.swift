import Foundation
import ImageIO
import UniformTypeIdentifiers
let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:"outputs/Launch-Day-Cycle-HDR.heic") as CFURL,nil)!
// Native Apple Beach solar coordinates, with additional intermediate phases.
let hours=[12,0,5,6,7,8,9,10,14,15,16,17,18,19,20,22]
let anchors:[(Int,Double,Double)]=[(0,-25,70),(5,-12,78),(6,-6,84),(7,0,90),(8,8,98),(9,16,106),(10,25,115),(12,45,180),(14,25,245),(15,20,250),(16,12,258),(17,6,264),(18,0,270),(19,-6,276),(20,-12,282),(22,-25,295)]
let sequence:[[String:Any]]=anchors.map { ["i":hours.firstIndex(of:$0.0)!,"a":$0.1,"z":$0.2] }
let plist:[String:Any]=["ap":["l":0,"d":1],"si":sequence]
let md=CGImageMetadataCreateMutable()
precondition(CGImageMetadataRegisterNamespaceForPrefix(md,"http://ns.apple.com/namespace/1.0/" as CFString,"apple_desktop" as CFString,nil))
let encoded=try PropertyListSerialization.data(fromPropertyList:plist,format:.binary,options:0).base64EncodedString()
let tag=CGImageMetadataTagCreate("http://ns.apple.com/namespace/1.0/" as CFString,"apple_desktop" as CFString,"solar" as CFString,.string,encoded as CFString)!
precondition(CGImageMetadataSetTagWithPath(md,nil,"apple_desktop:solar" as CFString,tag))
let dst=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"outputs/Launch-Solar-HDR.heic") as CFURL,UTType.heic.identifier as CFString,hours.count,nil)!
for (i,hour) in hours.enumerated() {
 autoreleasepool {
  let index=hour==12 ? 0 : (hour<12 ? hour+1:hour)
  let base=CGImageSourceCreateImageAtIndex(src,index,[kCGImageSourceDecodeRequest:kCGImageSourceDecodeToSDR] as CFDictionary)!
  let props=[kCGImageDestinationLossyCompressionQuality:0.98] as CFDictionary
  if i==0 {CGImageDestinationAddImageAndMetadata(dst,base,md,props)} else {CGImageDestinationAddImage(dst,base,props)}
  let aux=CGImageSourceCopyAuxiliaryDataInfoAtIndex(src,index,kCGImageAuxiliaryDataTypeISOGainMap)!
  CGImageDestinationAddAuxiliaryDataInfo(dst,kCGImageAuxiliaryDataTypeISOGainMap,aux)
  print("Solar phase \(i+1)/\(hours.count), source hour \(hour)");fflush(stdout)
 }
}
precondition(CGImageDestinationFinalize(dst))
let json=try JSONSerialization.data(withJSONObject:plist,options:[.prettyPrinted,.sortedKeys]);try json.write(to:URL(fileURLWithPath:"work/solar-timeline.json"))
print("Solar HDR wallpaper saved")
