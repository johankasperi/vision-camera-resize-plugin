@objc(VisionCameraResizePlugin)
class VisionCameraResizePlugin: NSObject, FrameProcessorPluginBase {
    @objc
    public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {
        
        
        return frame
    }
}
