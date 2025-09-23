import SwiftUI
@preconcurrency import AVFoundation
import Photos
import AudioToolbox

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Camera preview background
            if viewModel.isAuthorized && viewModel.cameraAvailable {
                // Real camera preview
                CameraPreview(session: viewModel.captureSession)
                    .ignoresSafeArea()
                    .scaleEffect(viewModel.zoomLevel)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    viewModel.updateZoom(value)
                                }
                                .onEnded { value in
                                    viewModel.finalizeZoom(value)
                                },
                            TapGesture(count: 2)
                                .onEnded {
                                    viewModel.resetZoom()
                                }
                        )
                    )
                    .overlay(
                        filterOverlay
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    )
            } else if !viewModel.isAuthorized {
                // Permission not granted
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.primaryColor.opacity(0.6))

                    Text("CAMERA ACCESS REQUIRED")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.textColor)
                        .fontWeight(.bold)

                    Text("Enable camera access in Settings")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))

                    CodecButton(title: "RETRY", action: {
                        viewModel.requestPermission()
                    }, style: .primary, size: .medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.backgroundColor)
                .ignoresSafeArea()
            } else {
                // Camera not available (simulator or no camera)
                VStack(spacing: 20) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.primaryColor.opacity(0.6))

                    Text("CAMERA NOT AVAILABLE")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.textColor)
                        .fontWeight(.bold)

                    Text("Real device required for camera access")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.backgroundColor)
                .ignoresSafeArea()
            }

            // HUD Overlay
            VStack {
                // Top HUD elements
                topHUDBar

                Spacer()

                // Center crosshair
                crosshair

                Spacer()

                // Bottom controls
                bottomControls
            }
            .overlay(
                ScanlineOverlay()
                    .opacity(0.3)
            )
        }
        .onAppear {
            viewModel.requestPermission()
        }
    }

    private var filterOverlay: some View {
        ZStack {
            switch viewModel.currentFilter {
            case .normal:
                Color.clear
            case .nightVision:
                NightVisionOverlay(themeManager: themeManager)
            }
        }
    }

    private var topHUDBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CAMERA MODE")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text(viewModel.isRecording ? "REC ●" : "STANDBY")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(viewModel.isRecording ? themeManager.errorColor : themeManager.successColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("ZOOM: \(String(format: "%.1fx", viewModel.zoomLevel))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(viewModel.zoomLevel > 1.0 ? themeManager.accentColor : themeManager.textColor)
                    .fontWeight(viewModel.zoomLevel > 1.0 ? .bold : .regular)

                Text("ISO: AUTO")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var crosshair: some View {
        ZStack {
            Rectangle()
                .stroke(themeManager.primaryColor, lineWidth: 1)
                .frame(width: 120, height: 80)

            // Center dot
            Circle()
                .fill(themeManager.accentColor)
                .frame(width: 4, height: 4)

            // Corner markers
            ForEach(0..<4, id: \.self) { corner in
                cornerMarker(corner: corner)
            }
        }
    }

    private func cornerMarker(corner: Int) -> some View {
        let offset: CGFloat = 50
        let positions: [(x: CGFloat, y: CGFloat)] = [
            (-offset, -offset), (offset, -offset),
            (-offset, offset), (offset, offset)
        ]

        return Rectangle()
            .fill(themeManager.primaryColor)
            .frame(width: 12, height: 2)
            .offset(x: positions[corner].x, y: positions[corner].y)
    }

    private var bottomControls: some View {
        HStack(spacing: 30) {
            // Filter mode display/cycle button
            CodecButton(title: viewModel.currentFilter.rawValue, action: {
                TacticalSoundPlayer.playNavigation()
                viewModel.cycleFilter()
            }, style: .primary, size: .medium)

            // Capture button
            Button(action: {
                TacticalSoundPlayer.playAction()
                viewModel.capturePhoto()
            }) {
                ZStack {
                    Circle()
                        .stroke(viewModel.cameraAvailable ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(viewModel.cameraAvailable ? themeManager.primaryColor.opacity(0.2) : themeManager.primaryColor.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: viewModel.cameraAvailable ? "camera.fill" : "camera.slash")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.cameraAvailable ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.5))
                }
            }
            .disabled(!viewModel.cameraAvailable)

            // Toggle recording
            Button(action: {
                TacticalSoundPlayer.playAction()
                viewModel.toggleRecording()
            }) {
                Text(viewModel.isRecording ? "STOP" : "REC")
                    .font(.system(size: 14, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor)
                    .frame(width: 60, height: 40) // Fixed width to prevent resizing
                    .background((viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.isRecording ? themeManager.secondaryColor : themeManager.primaryColor, lineWidth: 1)
                    )
                    .overlay(
                        ScanlineOverlay()
                            .opacity(0.3)
                    )
            }
        }
        .padding(.bottom, 30)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Store layer in view for frame updates
        view.layer.name = "previewLayer"

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

class CameraViewModel: BaseViewModel {
    @Published @MainActor var isAuthorized = false
    @Published @MainActor var cameraAvailable = false
    @Published @MainActor var isRecording = false
    @Published @MainActor var zoomLevel: CGFloat = 1.0
    @Published @MainActor var currentFilter: CameraFilter = .normal
    @Published @MainActor var exposureBias: Float = 0.0
    @Published @MainActor var isoValue: Float = 0.0

    private var baseZoomLevel: CGFloat = 1.0

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?

    enum CameraFilter: String, CaseIterable {
        case normal = "NORMAL"
        case nightVision = "NIGHT VISION"
    }

    @MainActor
    func requestPermission() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            print("Current camera authorization status: \(status)")

            switch status {
            case .authorized:
                print("Camera already authorized, setting up camera")
                setupCamera()
            case .notDetermined:
                print("Camera permission not determined, requesting access")
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                print("Camera access granted: \(granted)")
                if granted {
                    setupCamera()
                } else {
                    isAuthorized = false
                }
            case .denied, .restricted:
                print("Camera access denied or restricted")
                isAuthorized = false
            @unknown default:
                print("Unknown camera authorization status")
                isAuthorized = false
            }
        }
    }

    nonisolated private func setupCamera() {
        Task {
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                print("Camera permission not granted")
                await MainActor.run {
                    isAuthorized = false
                    cameraAvailable = false
                }
                return
            }

            // Check for available camera device
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
                               AVCaptureDevice.default(for: .video) else {
                print("No camera device available")
                await MainActor.run {
                    isAuthorized = true
                    cameraAvailable = false
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                await MainActor.run {
                    currentDevice = device
                    let session = captureSession
                    let output = photoOutput

                    // Configure session
                    session.beginConfiguration()

                    // Remove any existing inputs/outputs
                    session.inputs.forEach { session.removeInput($0) }
                    session.outputs.forEach { session.removeOutput($0) }

                    // Add input
                    if session.canAddInput(input) {
                        session.addInput(input)
                    } else {
                        print("Cannot add camera input")
                        session.commitConfiguration()
                        isAuthorized = true
                        cameraAvailable = false
                        return
                    }

                    // Add photo output
                    if session.canAddOutput(output) {
                        session.addOutput(output)

                        // Configure photo output settings
                        if #available(iOS 16.0, *) {
                            // Use new maxPhotoDimensions API for iOS 16+
                            output.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
                        } else {
                            // Use deprecated API for iOS 15 and below
                            if output.isHighResolutionCaptureEnabled {
                                output.isHighResolutionCaptureEnabled = true
                            }
                        }
                    } else {
                        print("Cannot add photo output")
                        session.commitConfiguration()
                        isAuthorized = true
                        cameraAvailable = false
                        return
                    }

                    // Set session preset for best quality
                    if session.canSetSessionPreset(.photo) {
                        session.sessionPreset = .photo
                    } else if session.canSetSessionPreset(.high) {
                        session.sessionPreset = .high
                    }

                    session.commitConfiguration()
                    isAuthorized = true
                    cameraAvailable = true

                    print("Camera setup successful")

                    // Start session on background queue
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                        print("Camera session started")
                    }
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
                await MainActor.run {
                    handleError(error)
                    isAuthorized = true
                    cameraAvailable = false
                }
            }
        }
    }

    @MainActor
    func capturePhoto() {
        print("Capture photo requested")

        // Check if we have an active camera connection
        guard cameraAvailable && captureSession.isRunning else {
            print("Photo capture: Camera not available or session not running")
            return
        }

        guard let connection = photoOutput.connection(with: .video), connection.isActive else {
            print("Photo capture: No active video connection")
            return
        }

        // Configure photo settings
        let settings: AVCapturePhotoSettings

        // Use HEIF format if available (better quality, smaller size)
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }

        // Enable high resolution capture if available
        if #available(iOS 16.0, *) {
            // Use new maxPhotoDimensions API for iOS 16+
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            // Use deprecated API for iOS 15 and below
            settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
        }

        // Set flash mode to auto
        if let device = currentDevice, device.hasFlash {
            settings.flashMode = .auto
        }

        print("Capturing photo with settings: \(settings)")

        // Play camera shutter sound
        AudioServicesPlaySystemSound(1108) // Camera shutter sound

        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate())
    }

    @MainActor
    func toggleRecording() {
        isRecording.toggle()
        // In a real implementation, start/stop video recording here
    }

    @MainActor
    func cycleFilter() {
        let filters = CameraFilter.allCases
        if let currentIndex = filters.firstIndex(of: currentFilter) {
            let nextIndex = (currentIndex + 1) % filters.count
            currentFilter = filters[nextIndex]

            // Apply camera settings for night vision
            if currentFilter == .nightVision {
                enableNightVisionMode()
            } else {
                disableNightVisionMode()
            }

            // Apply audio feedback for filter change
            objectWillChange.send()
        }
    }

    private func enableNightVisionMode() {
        guard cameraAvailable, let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            // Set exposure bias to brighten image
            let maxBias = device.maxExposureTargetBias
            let targetBias = min(maxBias, 2.0) // Increase exposure
            device.setExposureTargetBias(targetBias) { time in
                print("🌙 Night vision exposure adjusted")
            }

            // Set higher ISO for low light
            let maxISO = device.activeFormat.maxISO
            let targetISO = min(maxISO, 1600) // High ISO for low light
            device.setExposureModeCustom(duration: device.exposureDuration, iso: targetISO) { time in
                print("🌙 Night vision ISO set to: \(targetISO)")
            }

            exposureBias = targetBias
            isoValue = targetISO

            device.unlockForConfiguration()
            print("🌙 Night vision mode enabled")
        } catch {
            print("Failed to enable night vision: \(error)")
        }
    }

    private func disableNightVisionMode() {
        guard cameraAvailable, let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            // Reset exposure to auto
            device.exposureMode = .autoExpose
            exposureBias = 0.0
            isoValue = 0.0

            device.unlockForConfiguration()
            print("🌙 Night vision mode disabled")
        } catch {
            print("Failed to disable night vision: \(error)")
        }
    }

    @MainActor
    func updateZoom(_ gestureValue: CGFloat) {
        // Calculate new zoom level based on base + gesture multiplier
        let newZoom = max(1.0, min(8.0, baseZoomLevel * gestureValue))
        zoomLevel = newZoom

        // Apply zoom to actual camera device if available
        applyZoomToDevice(newZoom)
    }

    @MainActor
    func finalizeZoom(_ gestureValue: CGFloat) {
        // Update base zoom level after gesture ends
        let finalZoom = max(1.0, min(8.0, baseZoomLevel * gestureValue))
        baseZoomLevel = finalZoom
        zoomLevel = finalZoom
        applyZoomToDevice(finalZoom)

        // Play tactical sound for zoom change
        TacticalSoundPlayer.playNavigation()
    }

    private func applyZoomToDevice(_ zoom: CGFloat) {
        // Apply zoom to actual camera device if available
        guard cameraAvailable, captureSession.isRunning, let device = currentDevice else {
            return
        }

        do {
            try device.lockForConfiguration()

            // Respect device's actual zoom capabilities
            let maxZoom = device.activeFormat.videoMaxZoomFactor
            let actualZoom = max(1.0, min(maxZoom, zoom))

            device.videoZoomFactor = actualZoom
            device.unlockForConfiguration()

            print("Applied zoom: \(actualZoom)x (max: \(maxZoom)x)")
        } catch {
            print("Failed to apply zoom: \(error)")
        }
    }

    @MainActor
    func resetZoom() {
        baseZoomLevel = 1.0
        zoomLevel = 1.0
        applyZoomToDevice(1.0)
        TacticalSoundPlayer.playNavigation()
    }
}


private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Unable to create image data from photo")
            return
        }

        print("Photo captured successfully, size: \(imageData.count) bytes")

        // Save to photo library
        savePhotoToLibrary(imageData: imageData)
    }

    private func savePhotoToLibrary(imageData: Data) {
        // Request photo library permission if needed
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performPhotoSave(imageData: imageData)
                case .denied, .restricted:
                    print("Photo library access denied")
                case .notDetermined:
                    print("Photo library access not determined")
                @unknown default:
                    print("Unknown photo library authorization status")
                }
            }
        }
    }

    private func performPhotoSave(imageData: Data) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Photo saved to library successfully")
                    // Play success sound
                    TacticalSoundPlayer.playSuccess()
                } else if let error = error {
                    print("❌ Failed to save photo: \(error.localizedDescription)")
                } else {
                    print("❌ Failed to save photo: Unknown error")
                }
            }
        }
    }
}

struct NightVisionOverlay: View {
    let themeManager: ThemeManager
    @State private var noiseOffset: CGFloat = 0
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Green tint for night vision
            Rectangle()
                .fill(Color.green)
                .blendMode(.overlay)
                .opacity(0.3)

            // Brightness boost effect
            Rectangle()
                .fill(Color.white)
                .blendMode(.overlay)
                .opacity(0.1)

            // Noise pattern for realistic night vision grain
            NoisePattern(offset: noiseOffset)
                .blendMode(.overlay)
                .opacity(0.15)
                .onAppear {
                    withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
                        noiseOffset = 100
                    }
                }

            // Scanning lines effect
            ScanLinesOverlay(offset: scanlineOffset)
                .blendMode(.overlay)
                .opacity(0.2)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        scanlineOffset = 1000
                    }
                }

            // Vignette effect for authentic night vision look
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
            .blendMode(.multiply)

            // Corner display indicators
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NV")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .fontWeight(.bold)

                        Text("GAIN: AUTO")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LOW LIGHT")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))

                        Text("IR: ON")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()
            }
        }
    }
}

struct NoisePattern: View {
    let offset: CGFloat

    var body: some View {
        Canvas { context, size in
            // Create noise pattern
            for _ in 0..<200 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height) + offset
                let adjustedY = y.truncatingRemainder(dividingBy: size.height)

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: adjustedY, width: 1, height: 1)),
                    with: .color(.white)
                )
            }
        }
    }
}

struct ScanLinesOverlay: View {
    let offset: CGFloat

    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 4
            let lineHeight: CGFloat = 1

            for i in stride(from: 0, through: size.height + lineSpacing, by: lineSpacing) {
                let y = i + offset.truncatingRemainder(dividingBy: lineSpacing)
                let adjustedY = y.truncatingRemainder(dividingBy: size.height + lineSpacing)

                if adjustedY >= 0 && adjustedY <= size.height {
                    context.fill(
                        Path(CGRect(x: 0, y: adjustedY, width: size.width, height: lineHeight)),
                        with: .color(.green.opacity(0.1))
                    )
                }
            }
        }
    }
}