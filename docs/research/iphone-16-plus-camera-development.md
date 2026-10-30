# iPhone 16 Plus camera: developer guide

Research date: October 29, 2026.
Scope: Public Apple application programming interfaces (APIs). No iPhone was attached.
The examples below were reviewed against documentation but were not compiled or run.
Hardware notes: [Technical research](iphone-16-plus-camera.md).

## Development principle

Discover capabilities on the phone and the installed operating system.
Do not maintain a table that assumes a model name guarantees every capture combination.
Check support again after changing the input, active format, session preset, or outputs.
A supported individual feature does not prove a combination is supported.

## Frameworks and architecture

| Framework or type | Purpose |
|---|---|
| AVFoundation | Discover cameras; configure exposure, focus, outputs, and capture |
| AVKit capture events | Handle physical capture controls |
| Core Image | Develop raw files and process images |
| Metal | Custom graphics and compute processing |
| PhotoKit | Save, retrieve, and manage assets in Photos |
| Vision and Core ML | Analyze image buffers with supported models |
| ARKit | Camera-based tracking and supported depth or face experiences |
| LockedCameraCapture | Provide a camera experience while the phone is locked |

A normal graph is camera input -> AVCaptureSession -> photo, movie, or frame output.
Use AVCapturePhotoOutput for photographs.
Use AVCaptureMovieFileOutput for a straightforward movie workflow.
Use AVCaptureVideoDataOutput plus AVAssetWriter when the app needs frame processing and custom encoding.
AVCaptureVideoPreviewLayer supplies a preview without requiring the app to copy each frame.

Keep configuration and startRunning() off the main thread.
Apple's current AVCam sample uses a dedicated actor.
Serialize session mutations and avoid configuration changes racing with capture.
Retain capture delegates until their operations finish.
Handle interruptions, runtime errors, permission changes, and background transitions.
The iOS Simulator cannot validate actual camera formats.

Sources: [AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app),
[Frame output](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput).

## Device selection is a functional choice

Discover physical and virtual devices:

```swift
let discovery = AVCaptureDevice.DiscoverySession(
    deviceTypes: [
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInDualWideCamera,
        .builtInTrueDepthCamera
    ],
    mediaType: .video,
    position: .unspecified
)
```

A physical wide or ultra-wide camera is the usual starting point for deterministic manual capture.
The dual-wide virtual device manages lens switching and can calculate stereo depth.
Its zoom value is not necessarily the same scale as the Camera app's displayed zoom.
Inspect the device's switch factors and display multiplier where the operating system exposes them.

Apple explicitly documents these restrictions on the dual-wide virtual device:

- Custom exposure mode and manual exposure brackets are unsupported.
- Arbitrary locked lens positions are unsupported.
- Arbitrary locked white-balance gains are unsupported.
- Camera switching can change individual camera settings, even when the overall state is locked.

A physical lens can therefore be necessary when a virtual camera seems to reject valid manual controls.
A default back camera is not necessarily the camera type your feature requires.

Sources: [Choosing a capture device](https://developer.apple.com/documentation/avfoundation/choosing-a-capture-device),
[Dual-wide restrictions](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtindualwidecamera).

## Resolution and deferred capture

Use the .photo session preset for high-resolution photographs.
Read activeFormat.supportedMaxPhotoDimensions.
Set photoOutput.maxPhotoDimensions to an advertised value before starting the session.
Set AVCapturePhotoSettings.maxPhotoDimensions for the individual request.
Check the resolved result: requested dimensions are a maximum, not a guaranteed delivered size.
Do not assume that available video dimensions describe available still dimensions.

Common 4:3 sizes to recognize are 4032 x 3024, 5712 x 4284, and 8064 x 6048.
They correspond approximately to 12, 24, and 48 MP.
These are recognition examples, not observed outputs from an attached iPhone 16 Plus.

Apple's 2025 developer-support answer states that 24 MP capture requires deferred processing and Photos write access.
The output delivers an AVCaptureDeferredPhotoProxy, not the final photograph.
Save the proxy as the correct PhotoKit resource and obtain the final processed asset through Photos.
A preview proxy must not be treated as the finished 24 MP image.
Requesting 24 MP dimensions alone does not complete this workflow.

Apple's 2026 high-resolution presentation continues to describe deferred processing for 24 MP capture.
It also describes an iOS 27 responsiveness change for the iPhone 16 and 17 families.
Validate behavior against the target operating system rather than assuming the 2025 behavior never changes.

Useful properties include:

- maxPhotoQualityPrioritization and photoQualityPrioritization.
- isAutoDeferredPhotoDeliverySupported and isAutoDeferredPhotoDeliveryEnabled.
- isResponsiveCaptureSupported and isResponsiveCaptureEnabled.
- isFastCapturePrioritizationSupported and isFastCapturePrioritizationEnabled.
- captureReadiness and the capture readiness coordinator.

Responsive capture overlaps work. It does not make an individual exposure instantaneous.
Configure expensive pipeline options before starting the session.

Sources: [Maximum dimensions](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotodimensions),
[Apple engineer's 24 MP answer](https://developer.apple.com/forums/thread/792999),
[Deferred delivery](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/isautodeferredphotodeliveryenabled),
[High-resolution session](https://developer.apple.com/videos/play/wwdc2026/304/).

## Bayer raw and a custom rendering pipeline

Connect the input and AVCapturePhotoOutput before reading availableRawPhotoPixelFormatTypes.
An empty array before connection does not prove that the camera lacks raw support.
Distinguish isBayerRAWPixelFormat from isAppleProRAWPixelFormat.
ProRAW is not a supported iPhone 16 Plus capture path.
Do not force isAppleProRAWEnabled when isAppleProRAWSupported is false.

A request can use this pattern after configuration:

```swift
let bayerType = photoOutput.availableRawPhotoPixelFormatTypes.first {
    AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
}

if let bayerType {
    let settings = AVCapturePhotoSettings(rawPixelFormatType: bayerType)
    photoOutput.capturePhoto(with: settings, delegate: retainedCaptureDelegate)
}
```

This fragment assumes the surrounding app handles permissions, session setup, and delegate lifetime.
Inspect photo.isRawPhoto and fileDataRepresentation() in the callback.
Raw plus processed capture can deliver separate callbacks for the two representations.
A 48 MP sensor and high-resolution processed capture do not establish 48 MP Bayer raw delivery.
The exact raw resolution and available lenses remain device-test questions in this report.

Use CIRAWFilter to develop the original DNG.
Its controls include exposure, white balance, noise reduction, sharpening, tone mapping, and lens correction where supported.
A custom rendering workflow can preserve the original and store edits as separate parameters.
Use a consistent working color space and adequate intermediate precision.
Store the rendering version with edits if later decoder changes must not change old photographs unexpectedly.

An engineering sequence for an original look is:

1. Preserve the original raw file and its metadata.
2. Decode into a defined linear working space.
3. Apply exposure, white balance, and a calibrated color transform.
4. Apply tone rendering and custom effects.
5. Convert into the destination color space.
6. Export with a profile and the required metadata.

This sequence is a suggested architecture. It does not describe Chromagraph's unpublished implementation.
Raw capture bypasses much of Apple's finished-photo rendering, but still needs sensor and color interpretation.

Sources: [Raw capture](https://developer.apple.com/documentation/avfoundation/capturing-photos-in-raw-and-apple-proraw-formats),
[Raw format availability](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/availablerawphotopixelformattypes-5fatm),
[CIRAWFilter](https://developer.apple.com/documentation/coreimage/cirawfilter).

## Manual exposure, focus, and white balance

Check isExposureModeSupported(.custom), focus capabilities, and white-balance capabilities before changing them.
Call lockForConfiguration(), make supported changes, then unlockForConfiguration().
Clamp sensitivity and exposure duration to the selected format's ranges.
Do not hard-code an assumed minimum sensitivity or maximum shutter time.
The displayed ISO value is a sensitivity setting, not direct access to the sensor's complete gain circuitry.

Use setExposureModeCustom(duration:iso:completionHandler:) for explicit duration and sensitivity.
Use supported lens-position and white-balance-gain controls on the chosen physical device.
A normalized lens position is not a focus distance in meters.
Clamp white-balance gains to the supported interval.
Changing exposure can also affect frame-duration limits.

Critical documented behavior: balanced photo quality can temporarily override exposure for multi-image fusion.
Apple says to use .speed photoQualityPrioritization when the capture must honor manual or locked exposure values.
This trades computational processing for control; it is not a universal quality preference.

Source: [Manual exposure contract](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setexposuremodecustom(duration:iso:completionhandler:)).

## Video, color, and performance

Inspect each AVCaptureDevice.Format rather than selecting only by width and height.
Check videoSupportedFrameRateRanges, supportedColorSpaces, isVideoHDRSupported, and stabilization support.
Set frame-duration limits consistently with the selected format.
Choose supported pixel formats and codec settings for the actual output.
Apple's stock video feature list does not promise identical combinations to third-party apps.

Uncompressed does not mean raw sensor data.
A CVPixelBuffer containing YCbCr or BGRA normally contains an already developed image.
The public iPhone 16 Plus workflow does not establish a Bayer raw video stream.

Apple's pixel-format note recommends avoiding an unnecessary BGRA conversion.
Use suitable native YCbCr buffers and a CVMetalTextureCache when the processing design allows it.
Maintain correct full-range versus video-range interpretation.
Preserve primaries, transfer functions, and matrix coefficients.
For HDR, retain supported 10-bit data and the required HDR metadata through rendering and encoding.
A custom flat curve cannot recover highlights already clipped in the input.

Avoid copying or converting every frame on the CPU.
Bound the number of in-flight buffers and expensive processing tasks.
For live analysis, prefer dropping stale work to building an ever-growing queue.
For recording, manage backpressure and timestamps explicitly.
Observe thermal and system-pressure conditions and reduce workload when necessary.

Use AVCaptureDevice.RotationCoordinator for capture and preview orientation.
Apply separate preview and capture angles where appropriate.
Handle front-camera mirroring deliberately.
Geometric distortion correction changes the field of view and resamples the image.
For calibrated computer vision, inspect intrinsics and lens-calibration data instead of deriving them from a 26 mm equivalent label.
The format's videoFieldOfView reports a horizontal angle. Do not assume it equals the advertised 120-degree lens specification.
Enable isCameraIntrinsicMatrixDeliveryEnabled only when the connection supports it.

Sources: [Device formats](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format),
[Video frame output](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput),
[Pixel formats](https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput),
[HDR metadata](https://developer.apple.com/documentation/technotes/tn3145-hdr-video-metadata),
[Rotation coordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator),
[Geometric correction](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isgeometricdistortioncorrectionsupported),
[Field of view](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview),
[Camera intrinsics](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/iscameraintrinsicmatrixdeliverysupported).

## Depth, spatial capture, and multiple cameras

For depth photos, choose a depth-capable device and enable delivery on the output and individual settings.
For streaming depth, inspect supportedDepthDataFormats and use AVCaptureDepthDataOutput.
Use AVCaptureDataOutputSynchronizer when processing matched video and depth samples.
Inspect AVDepthData, its calibration, units, and orientation.
A disparity map and a metric depth map are different representations.

The rear dual-wide device supports stereo-disparity depth.
The front builtInTrueDepthCamera exposes depth capabilities beyond the front color camera alone.
Selecting .builtInWideAngleCamera at the front does not automatically activate the full TrueDepth workflow.
The phone lacks rear LiDAR scene depth.

For spatial video, find a format with isSpatialVideoCaptureSupported, then enable supported spatial capture on the movie output.
Use the system's spatial pipeline rather than assuming two independently recorded movies form a valid spatial asset.

AVCaptureMultiCamSession supports simultaneous capture with restrictions.
Inspect isMultiCamSupported, supported device sets, compatible formats, hardwareCost, and systemPressureCost.
Do not assume two 4K60 HDR streams or the highest-resolution still modes can run together.

Sources: [Depth photos](https://developer.apple.com/documentation/avfoundation/capturing-photos-with-depth),
[Dual-wide capabilities](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtindualwidecamera),
[TrueDepth selection](https://developer-mdn.apple.com/library/archive/documentation/DeviceInformation/Reference/iOSDeviceCompatibility/Cameras/Cameras.html),
[Spatial capture](https://developer.apple.com/videos/play/wwdc2024/10166/),
[Multi-camera sample](https://developer.apple.com/documentation/avfoundation/avmulticampip-capturing-from-multiple-cameras),
[Multi-camera session](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession).

## Camera Control and locked capture

For the physical shutter event, use AVCaptureEventInteraction or the matching SwiftUI capture-event API.
For light-press and slide controls, use AVCaptureControl subclasses.
System controls include AVCaptureSystemZoomSlider and AVCaptureSystemExposureBiasSlider.
Custom sliders and pickers can drive supported capture or rendering settings.
Check session.supportsControls, canAddControl(), and maxControlsCount.
Provide the session controls delegate and keep app controls synchronized with the system overlay.

Launching the app through Camera Control requires a LockedCameraCapture extension.
The extension is a separate capture environment with restricted access:

- It cannot access the network.
- It cannot read or write the App Group shared container.
- Its own container is erased on suspension.
- Use the capture session's sessionContentURL or PhotoKit for captured content.
- It needs an active capture experience with hardware event handling.

Do not store irreplaceable captures only in the extension's ordinary temporary container.
Transition to the containing app for work that needs broader access.

Sources: [Camera Control integration](https://developer.apple.com/documentation/avfoundation/enhancing-your-app-experience-with-the-camera-control),
[Capture control session](https://developer-mdn.apple.com/videos/play/wwdc2025/253/),
[Locked capture](https://developer.apple.com/documentation/lockedcameracapture/creating-a-camera-experience-for-the-lock-screen).

## Permissions and storage

Declare NSCameraUsageDescription and request camera access when capture is needed.
Declare NSMicrophoneUsageDescription and request microphone access if recording sound.
Camera permission does not grant microphone permission.
Choose PhotoKit authorization according to whether the app only saves or also reads library content.
Use NSPhotoLibraryAddUsageDescription or NSPhotoLibraryUsageDescription as required by that workflow.
Saving ordinary files in the app's private storage does not itself require Photos access.
Deferred processing has additional Photos integration requirements.

Use a system picker when the user only needs to select existing assets.
Add location metadata only through an intentional location-permission workflow.
Preserve metadata needed for rendering, but make sharing behavior clear.

Sources: [Capture authorization](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media),
[PhotoKit privacy](https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app),
[Deferred 24 MP requirements](https://developer.apple.com/forums/thread/792999).

## Capability probe for a real phone

Run this inside an authorized iOS app, on the queue or actor that owns camera configuration.
Stop any other capture session in that app first.
The probe connects each device independently. It does not prove combined-mode support.
It does not capture images or measure timing.
The snippet targets iOS 18 or later and has not been compiled in this Linux workspace.

```swift
import AVFoundation
import CoreMedia

@available(iOS 18.0, *)
func printCameraCapabilities() throws {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
        print("Grant camera permission before running this probe.")
        return
    }

    let devices = AVCaptureDevice.DiscoverySession(
        deviceTypes: [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInDualWideCamera,
            .builtInTrueDepthCamera
        ],
        mediaType: .video,
        position: .unspecified
    ).devices

    for device in devices {
        let session = AVCaptureSession()
        let output = AVCapturePhotoOutput()
        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        guard session.canSetSessionPreset(.photo),
              session.canAddInput(input) else {
            session.commitConfiguration()
            continue
        }
        session.sessionPreset = .photo
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            continue
        }
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        session.commitConfiguration()

        print("DEVICE:", device.localizedName, device.deviceType.rawValue)
        print("POSITION:", device.position.rawValue)
        print("CUSTOM EXPOSURE:", device.isExposureModeSupported(.custom))
        print("PRORAW:", output.isAppleProRAWSupported)
        print("DEPTH:", output.isDepthDataDeliverySupported)
        print("DEFERRED:", output.isAutoDeferredPhotoDeliverySupported)
        print("CAMERA CONTROL:", session.supportsControls)
        print("RAW TYPES:", output.availableRawPhotoPixelFormatTypes)
        for rawType in output.availableRawPhotoPixelFormatTypes {
            print("BAYER:", rawType,
                  AVCapturePhotoOutput.isBayerRAWPixelFormat(rawType))
        }

        for format in device.formats {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let rates = format.videoSupportedFrameRateRanges.map {
                "\($0.minFrameRate)...\($0.maxFrameRate)"
            }
            let photoSizes = format.supportedMaxPhotoDimensions.map {
                "\($0.width)x\($0.height)"
            }
            print("FORMAT:", size.width, size.height, rates)
            print("PHOTO SIZES:", photoSizes)
            print("ISO:", format.minISO, format.maxISO)
            print("EXPOSURE SECONDS:",
                  CMTimeGetSeconds(format.minExposureDuration),
                  CMTimeGetSeconds(format.maxExposureDuration))
            print("HDR:", format.isVideoHDRSupported)
            print("COLOR SPACES:", format.supportedColorSpaces)
            print("MULTICAM:", format.isMultiCamSupported)
            print("SPATIAL:", format.isSpatialVideoCaptureSupported)
        }

        session.beginConfiguration()
        session.removeOutput(output)
        session.removeInput(input)
        session.commitConfiguration()
    }
}
```

The raw-format list belongs to the connected current configuration.
To evaluate a different active format, reconfigure it and query support again.
To verify raw dimensions, capture an actual DNG and inspect its image dimensions and raw metadata.
Do not assume this probe confirms the delivered size merely because it lists large processed-photo dimensions.

## Validation plan

1. Record the model identifier, operating system build, app build, and selected device and format.
2. Capture original processed and raw files for each supported physical lens and intended mode.
3. Record delivered dimensions, raw metadata, exposure, white balance, and color profiles.
4. Measure shutter delay, processing delay, dropped frames, memory, and thermal behavior.
5. Test movement, low light, bright highlights, close focus, lens switching, and HDR export.
6. Test permissions, interruptions, rotation, background transitions, and locked capture.
7. Save the results and original files with their exact configuration.

## Remaining questions

No device-specific runtime dump or original iPhone 16 Plus DNG was available.
Raw dimensions, all lens combinations, actual sensitivity limits, and sustainable workloads remain unmeasured.
The presence of an API in the current software development kit does not prove support on this phone.
