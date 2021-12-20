import Accelerate

@objc(VisionCameraResizePlugin)
class VisionCameraResizePlugin: NSObject, FrameProcessorPluginBase {
    
    @objc
    public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {
        guard let cropX = args[0] as? Int,
            let cropY = args[1] as? Int,
            let cropWidth = args[2] as? Int,
            let cropHeight = args[3] as? Int,
            let scaleWidth = args[4] as? Int,
            let scaleHeight = args[5] as? Int,
            let cvImageBuffer = CMSampleBufferGetImageBuffer(frame.buffer),
            let pixelBuffer = resizePixelBuffer(cvImageBuffer, cropX: cropX, cropY: cropY, cropWidth: cropWidth, cropHeight: cropHeight, scaleWidth: scaleWidth, scaleHeight: scaleHeight) else {
            return nil
        }
        
        var formatDesc: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc)
        if formatDesc == nil {
            return nil
        }

        var sampleTimingInfo: CMSampleTimingInfo = CMSampleTimingInfo()
        sampleTimingInfo.presentationTimeStamp = CMTime.zero
        sampleTimingInfo.duration = CMTime.invalid
        sampleTimingInfo.decodeTimeStamp = CMTime.invalid
        var sampleBuffer: CMSampleBuffer? = nil
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescription: formatDesc!,
                sampleTiming: &sampleTimingInfo,
                sampleBufferOut: &sampleBuffer);
        
        let newFrame = Frame(buffer: sampleBuffer, orientation: frame.orientation)

        return newFrame
    }    
    
    /**
     First crops the pixel buffer, then resizes it.
     Source: https://github.com/iwantooxxoox/openface/blob/master/openface/CVPixelBuffer%2BHelpers.swift#L46
     */
    static func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                                  cropX: Int,
                                  cropY: Int,
                                  cropWidth: Int,
                                  cropHeight: Int,
                                  scaleWidth: Int,
                                  scaleHeight: Int) -> CVPixelBuffer? {
        
        CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
            print("Error: could not get pixel buffer base address")
            return nil
        }
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
        let offset = cropY*srcBytesPerRow + cropX*4
        var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                      height: vImagePixelCount(cropHeight),
                                      width: vImagePixelCount(cropWidth),
                                      rowBytes: srcBytesPerRow)
        
        let destBytesPerRow = scaleWidth*4
        guard let destData = malloc(scaleHeight*destBytesPerRow) else {
            print("Error: out of memory")
            return nil
        }
        var destBuffer = vImage_Buffer(data: destData,
                                       height: vImagePixelCount(scaleHeight),
                                       width: vImagePixelCount(scaleWidth),
                                       rowBytes: destBytesPerRow)
        
        let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
        CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        if error != kvImageNoError {
            print("Error:", error)
            free(destData)
            return nil
        }
        
        let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
            if let ptr = ptr {
                free(UnsafeMutableRawPointer(mutating: ptr))
            }
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
        var dstPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(nil, scaleWidth, scaleHeight,
                                                  pixelFormat, destData,
                                                  destBytesPerRow, releaseCallback,
                                                  nil, nil, &dstPixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: could not create new pixel buffer")
            free(destData)
            return nil
        }
        return dstPixelBuffer
    }
}
