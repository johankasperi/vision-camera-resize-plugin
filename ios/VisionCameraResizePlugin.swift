import Accelerate
import CoreGraphics

@objc(VisionCameraResizePlugin)
class VisionCameraResizePlugin: NSObject, FrameProcessorPluginBase {
    
    private static var gCIContext: CIContext?
    private static var ciContext: CIContext? {
        get {
            if gCIContext == nil {
                guard let defaultDevice = MTLCreateSystemDefaultDevice() else { return nil }
                gCIContext = CIContext(mtlDevice: defaultDevice)
            }
            return gCIContext
        }
    }


    @objc
    public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {
        guard let cropX = args[0] as? Int,
            let cropY = args[1] as? Int,
            let cropWidth = args[2] as? Int,
            let cropHeight = args[3] as? Int,
              let sampleBuffer = croppedSampleBuffer(frame.buffer, with: CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)) else {
            return nil
        }
        
        let newFrame = Frame(buffer: sampleBuffer, orientation: frame.orientation)

        return newFrame
    }
    
    
    
    /**
     * Crops `CMSampleBuffer` to a specified rect. This will not alter the original data. Currently this
     * method only handles `CMSampleBufferRef` with RGB color space.
     * Source: https://github.com/FirebaseExtended/mlkit-material-ios/blob/master/ShowcaseApp/ShowcaseAppSwift/Common/ImageUtilities.swift
     *
     * @param sampleBuffer The original `CMSampleBuffer`.
     * @param rect The rect to crop to.
     * @return A `CMSampleBuffer` cropped to the given rect.
     */
    static func croppedSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                   with rect: CGRect) -> CMSampleBuffer? {
      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

      CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)

      let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
      let width = CVPixelBufferGetWidth(imageBuffer)
      let bytesPerPixel = bytesPerRow / width
      guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
      let baseAddressStart = baseAddress.assumingMemoryBound(to: UInt8.self)

      var cropX = Int(rect.origin.x)
      let cropY = Int(rect.origin.y)

      // Start pixel in RGB color space can't be odd.
      if cropX % 2 != 0 {
        cropX += 1
      }

      let cropStartOffset = Int(cropY * bytesPerRow + cropX * bytesPerPixel)

      var pixelBuffer: CVPixelBuffer!
      var error: CVReturn

      // Initiates pixelBuffer.
      let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
      let options = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferWidthKey: rect.size.width,
        kCVPixelBufferHeightKey: rect.size.height
        ] as [CFString : Any]

      error = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                           Int(rect.size.width),
                                           Int(rect.size.height),
                                           pixelFormat,
                                           &baseAddressStart[cropStartOffset],
                                           Int(bytesPerRow),
                                           nil,
                                           nil,
                                           options as CFDictionary,
                                           &pixelBuffer)
      if error != kCVReturnSuccess {
        print("Crop CVPixelBufferCreateWithBytes error \(Int(error))")
        return nil
      }

      // Cropping using CIImage.
      var ciImage = CIImage(cvImageBuffer: imageBuffer)
      ciImage = ciImage.cropped(to: rect)
      // CIImage is not in the original point after cropping. So we need to pan.
      ciImage = ciImage.transformed(by: CGAffineTransform(translationX: CGFloat(-cropX), y: CGFloat(-cropY)))

      ciContext!.render(ciImage, to: pixelBuffer!)

      // Prepares sample timing info.
      var sampleTime = CMSampleTimingInfo()
      sampleTime.duration = CMSampleBufferGetDuration(sampleBuffer)
      sampleTime.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      sampleTime.decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)

      var videoInfo: CMVideoFormatDescription!
      error = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                           imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
      if error != kCVReturnSuccess {
        print("CMVideoFormatDescriptionCreateForImageBuffer error \(Int(error))")
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        return nil
      }

      // Creates `CMSampleBufferRef`.
      var resultBuffer: CMSampleBuffer?
      error = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer,
                                                 dataReady: true,
                                                 makeDataReadyCallback: nil,
                                                 refcon: nil,
                                                 formatDescription: videoInfo,
                                                 sampleTiming: &sampleTime,
                                                 sampleBufferOut: &resultBuffer)
      if error != kCVReturnSuccess {
        print("CMSampleBufferCreateForImageBuffer error \(Int(error))")
      }
      CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
      return resultBuffer
    }
}
