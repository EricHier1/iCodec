import SwiftUI
@preconcurrency import AVFoundation
import Photos
import AudioToolbox
import Combine
import CoreLocation

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
                    .id("camera-preview-\(viewModel.cameraAvailable ? 1 : 0)") // Force recreation when availability changes
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
                    .onTapGesture { location in
                        viewModel.focusAt(location: location)
                    }
                    .overlay(
                        filterOverlay
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        ARWaypointOverlay(viewModel: viewModel, themeManager: themeManager)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .opacity(viewModel.showARWaypoints ? 1 : 0)
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
                    Image(systemName: "camera")
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
            print("📷 CameraView appeared")
            viewModel.handleViewAppeared()
        }
        .onDisappear {
            print("📷 CameraView disappeared")
            viewModel.handleViewDisappeared()
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

                Text("STANDBY")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.successColor)
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

                    Image(systemName: viewModel.cameraAvailable ? "camera.fill" : "camera")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.cameraAvailable ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.5))
                }
            }
            .disabled(!viewModel.cameraAvailable)

            // AR Waypoints toggle button
            CodecButton(
                title: viewModel.showARWaypoints ? "AR ON" : "AR OFF",
                action: {
                    TacticalSoundPlayer.playNavigation()
                    viewModel.toggleARWaypoints()
                },
                style: viewModel.showARWaypoints ? .primary : .secondary,
                size: .medium
            )
        }
        .padding(.bottom, 30)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewFrame()
    }
}

class CameraPreviewUIView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        setupPreviewLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPreviewLayer() {
        backgroundColor = UIColor.black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        print("📷 📺 Preview layer added to view")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewFrame()
    }

    func updatePreviewFrame() {
        DispatchQueue.main.async {
            let newFrame = self.bounds
            self.previewLayer.frame = newFrame
            print("📷 📺 Preview layer frame updated to: \(newFrame)")

            // Ensure the preview layer is visible and properly configured
            if newFrame != .zero {
                self.previewLayer.isHidden = false

                // Force layer to update
                self.previewLayer.setNeedsDisplay()
                self.setNeedsDisplay()

                print("📷 📺 Preview layer visibility: \(!self.previewLayer.isHidden)")
            }
        }
    }
}

class CameraViewModel: BaseViewModel {
    @Published @MainActor var isAuthorized = false
    @Published @MainActor var cameraAvailable = false
    @Published @MainActor var zoomLevel: CGFloat = 1.0
    @Published @MainActor var currentFilter: CameraFilter = .normal
    @Published @MainActor var exposureBias: Float = 0.0
    @Published @MainActor var isoValue: Float = 0.0
    @Published @MainActor var showARWaypoints = false
    @Published @MainActor var userLocation: CLLocation?
    @Published @MainActor var userHeading: CLHeading?

    private var baseZoomLevel: CGFloat = 1.0
    private var locationManager: CLLocationManager?
    private var locationDelegate: CameraLocationDelegate?

    nonisolated let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    private var sessionObservers: Set<AnyCancellable> = []

    enum CameraFilter: String, CaseIterable {
        case normal = "NORMAL"
        case nightVision = "NIGHT VISION"
    }

    @MainActor
    func requestPermission() {
        print("📷 Requesting camera permission...")

        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            print("📷 Current camera authorization status: \(status)")

            switch status {
            case .authorized:
                print("📷 Camera already authorized, setting up camera")
                await setupCamera()
            case .notDetermined:
                print("📷 Camera permission not determined, requesting access")
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                print("📷 Camera access granted: \(granted)")
                if granted {
                    await setupCamera()
                } else {
                    isAuthorized = false
                    cameraAvailable = false
                }
            case .denied, .restricted:
                print("📷 Camera access denied or restricted")
                isAuthorized = false
                cameraAvailable = false
            @unknown default:
                print("📷 Unknown camera authorization status")
                isAuthorized = false
                cameraAvailable = false
            }
        }
    }

    @MainActor
    private func setupCamera() async {
        print("📷 Starting minimal camera setup...")

        // Ultra-simple setup
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            print("📷 ❌ Camera permission not granted")
            isAuthorized = false
            cameraAvailable = false
            return
        }

        // Get the simplest camera device
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("📷 ❌ No camera device available")
            isAuthorized = true
            cameraAvailable = false
            return
        }

        do {
            // Stop any existing session first
            if captureSession.isRunning {
                captureSession.stopRunning()
            }

            // Create input
            let input = try AVCaptureDeviceInput(device: device)

            // Store device reference
            currentDevice = device

            print("📷 Configuring session...")

            // Configure session
            captureSession.beginConfiguration()

            // Remove all existing inputs/outputs
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }

            // Add new input and output
            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)

                // Use highest quality preset
                if captureSession.canSetSessionPreset(.photo) {
                    captureSession.sessionPreset = .photo
                } else {
                    captureSession.sessionPreset = .high
                }

                // Configure photo output for maximum quality
                if #available(iOS 16.0, *) {
                    // Use maxPhotoDimensions for iOS 16+
                    photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? CMVideoDimensions(width: 4032, height: 3024)
                } else {
                    // Fallback for iOS 15
                    photoOutput.isHighResolutionCaptureEnabled = true
                }

                captureSession.commitConfiguration()

                print("📷 ✅ Camera configured successfully")

                // Setup session interruption observers
                setupSessionObservers()

                // Start session and update UI
                let session = captureSession
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                        print("📷 Camera session startRunning() called")

                        // Wait a moment for session to actually start
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isAuthorized = true
                            self.cameraAvailable = true
                            print("📷 ✅ Camera session started and UI updated")

                            // Force a view refresh to ensure preview appears
                            self.objectWillChange.send()

                            continuation.resume()
                        }
                    }
                }
            } else {
                print("📷 ❌ Cannot add input/output")
                captureSession.commitConfiguration()
                isAuthorized = true
                cameraAvailable = false
            }
        } catch {
            print("📷 ❌ Setup error: \(error)")
            isAuthorized = true
            cameraAvailable = false
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

        // Use high quality photo settings
        let settings = AVCapturePhotoSettings()

        // Enable highest quality capture
        if #available(iOS 16.0, *) {
            // Use maxPhotoDimensions for iOS 16+
            if let device = currentDevice {
                settings.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? CMVideoDimensions(width: 4032, height: 3024)
            }
        } else {
            // Fallback for iOS 15
            settings.isHighResolutionPhotoEnabled = true
        }

        // Only set flash if device supports it
        if let device = currentDevice, device.hasFlash {
            settings.flashMode = .off
        }

        print("Capturing photo with settings: \(settings)")

        // Play camera shutter sound
        AudioServicesPlaySystemSound(1108) // Camera shutter sound

        // Create delegate instance that will handle the photo with current filter
        let delegate = PhotoCaptureDelegate(filter: currentFilter)
        currentPhotoDelegate = delegate // Keep strong reference
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }


    @MainActor
    func cycleFilter() {
        let filters = CameraFilter.allCases
        if let currentIndex = filters.firstIndex(of: currentFilter) {
            let nextIndex = (currentIndex + 1) % filters.count
            currentFilter = filters[nextIndex]
            // No camera modifications - just UI overlay changes
            objectWillChange.send()
        }
    }

    @MainActor
    func toggleARWaypoints() {
        showARWaypoints.toggle()

        if showARWaypoints {
            setupLocationTracking()
        } else {
            stopLocationTracking()
        }
    }

    @MainActor
    private func setupLocationTracking() {
        locationManager = CLLocationManager()
        locationDelegate = CameraLocationDelegate(
            onLocationUpdate: { [weak self] location in
                Task { @MainActor in
                    self?.userLocation = location
                }
            },
            onHeadingUpdate: { [weak self] heading in
                Task { @MainActor in
                    self?.userHeading = heading
                }
            }
        )
        locationManager?.delegate = locationDelegate
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.startUpdatingLocation()
        locationManager?.startUpdatingHeading()
    }

    @MainActor
    private func stopLocationTracking() {
        locationManager?.stopUpdatingLocation()
        locationManager?.stopUpdatingHeading()
        locationManager = nil
        locationDelegate = nil
    }

    // Removed night vision hardware modifications to prevent crashes
    // Night vision is now just a visual overlay effect

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
        guard let device = currentDevice else {
            print("UI zoom: \(zoom)x (no device)")
            return
        }

        do {
            try device.lockForConfiguration()

            // Apply zoom factor safely within device limits
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8.0)
            let clampedZoom = max(1.0, min(maxZoom, zoom))
            device.videoZoomFactor = clampedZoom

            // Auto-focus after zoom change for better image quality
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }

            // Optionally adjust exposure for better image quality at zoom
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            print("Hardware zoom applied: \(clampedZoom)x with refocus")

        } catch {
            print("Failed to apply zoom: \(error)")
            // Fallback to UI zoom only
            print("UI zoom: \(zoom)x")
        }
    }

    @MainActor
    func resetZoom() {
        baseZoomLevel = 1.0
        zoomLevel = 1.0
        applyZoomToDevice(1.0)
        TacticalSoundPlayer.playNavigation()
    }

    @MainActor
    func focusAt(location: CGPoint) {
        guard let device = currentDevice else {
            print("No camera device available for focus")
            return
        }

        do {
            try device.lockForConfiguration()

            // Convert tap location to device coordinates (0-1 range)
            // Note: This is a simplified conversion - in a full implementation,
            // you'd need to account for preview layer bounds and orientation
            let focusPoint = CGPoint(x: location.x / UIScreen.main.bounds.width,
                                   y: location.y / UIScreen.main.bounds.height)

            // Set focus point if supported
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }

            // Set exposure point if supported
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            print("Focus applied at point: \(focusPoint)")
            TacticalSoundPlayer.playNavigation()

        } catch {
            print("Failed to focus at location: \(error)")
        }
    }

    @MainActor
    func handleViewAppeared() {
        print("📷 Handle view appeared")

        // Always request permission check first
        requestPermission()

        // Ensure camera session is running after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.ensureCameraRunning()
        }

        // Double-check after a longer delay if still not working
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.isAuthorized && !self.cameraAvailable {
                print("📷 ⚠️ Camera still not available after 1s, forcing restart")
                self.restartCamera()
            } else if self.isAuthorized && self.cameraAvailable {
                // Camera is available but preview might not be showing - force refresh
                print("📷 🔄 Forcing preview refresh")
                self.objectWillChange.send()
            }
        }
    }

    @MainActor
    func handleViewDisappeared() {
        print("📷 Handle view disappeared")
        // Don't stop the session completely, just note that view disappeared
    }

    @MainActor
    func ensureCameraRunning() {
        guard isAuthorized else {
            print("📷 Camera not authorized, cannot ensure running")
            return
        }

        let session = captureSession
        if !session.isRunning {
            print("📷 Camera session not running, restarting...")
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    print("📷 ✅ Camera session restarted")
                    self.cameraAvailable = true
                }
            }
        } else {
            print("📷 ✅ Camera session already running")
            cameraAvailable = true
        }
    }

    @MainActor
    func restartCamera() {
        print("📷 🔄 Force restarting camera...")

        // Reset state
        cameraAvailable = false

        // Stop current session
        let session = captureSession
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
                DispatchQueue.main.async {
                    // Restart setup after stopping
                    Task {
                        await self.setupCamera()
                    }
                }
            }
        } else {
            // If not running, just setup again
            Task {
                await setupCamera()
            }
        }
    }

    @MainActor
    private func setupSessionObservers() {
        // Clear any existing observers
        sessionObservers.removeAll()

        // Observe session interruptions
        NotificationCenter.default
            .publisher(for: .AVCaptureSessionWasInterrupted)
            .sink { [weak self] notification in
                print("📷 ⚠️ Camera session was interrupted")
                if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason {
                    print("📷 Interruption reason: \(reason)")
                }
                DispatchQueue.main.async {
                    self?.cameraAvailable = false
                }
            }
            .store(in: &sessionObservers)

        // Observe session resumption
        NotificationCenter.default
            .publisher(for: .AVCaptureSessionInterruptionEnded)
            .sink { [weak self] _ in
                print("📷 ✅ Camera session interruption ended")
                DispatchQueue.main.async {
                    self?.ensureCameraRunning()
                }
            }
            .store(in: &sessionObservers)

        // Observe runtime errors
        NotificationCenter.default
            .publisher(for: .AVCaptureSessionRuntimeError)
            .sink { [weak self] notification in
                print("📷 ❌ Camera session runtime error")
                if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error {
                    print("📷 Runtime error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self?.restartCamera()
                }
            }
            .store(in: &sessionObservers)
    }

    deinit {
        sessionObservers.removeAll()
    }
}


private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let filter: CameraViewModel.CameraFilter

    init(filter: CameraViewModel.CameraFilter) {
        self.filter = filter
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📷 Photo output delegate called")

        if let error = error {
            print("📷 ❌ Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("📷 ❌ Unable to create image data from photo")
            return
        }

        print("📷 ✅ Photo captured successfully, size: \(imageData.count) bytes")

        // Apply filter if needed
        let finalImageData: Data
        if filter == .nightVision {
            finalImageData = applyNightVisionFilter(to: imageData) ?? imageData
        } else {
            finalImageData = imageData
        }

        // Save to photo library
        savePhotoToLibrary(imageData: finalImageData)
    }

    private func applyNightVisionFilter(to imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let ciImage = CIImage(image: uiImage) else {
            return nil
        }

        let context = CIContext()

        // Apply green tint for night vision effect
        let colorMatrix = CIFilter(name: "CIColorMatrix")
        colorMatrix?.setValue(ciImage, forKey: kCIInputImageKey)

        // Green tint matrix - amplify green, reduce red and blue
        colorMatrix?.setValue(CIVector(x: 0.3, y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorMatrix?.setValue(CIVector(x: 0.6, y: 1.2, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix?.setValue(CIVector(x: 0.1, y: 0, z: 0.3, w: 0), forKey: "inputBVector")
        colorMatrix?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        guard let outputImage = colorMatrix?.outputImage else {
            return nil
        }

        // Increase brightness and contrast for night vision look
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(outputImage, forKey: kCIInputImageKey)
        colorControls?.setValue(0.3, forKey: kCIInputBrightnessKey) // Brighten
        colorControls?.setValue(1.3, forKey: kCIInputContrastKey) // Increase contrast
        colorControls?.setValue(1.2, forKey: kCIInputSaturationKey) // Boost saturation

        guard let finalImage = colorControls?.outputImage,
              let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else {
            return nil
        }

        let processedImage = UIImage(cgImage: cgImage)
        return processedImage.jpegData(compressionQuality: 0.95)
    }

    private func savePhotoToLibrary(imageData: Data) {
        print("📷 💾 Requesting photo library access...")

        // Request photo library permission if needed
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            print("📷 💾 Photo library authorization status: \(status)")

            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("📷 💾 Photo library access authorized - saving photo")
                    self.performPhotoSave(imageData: imageData)
                case .limited:
                    print("📷 💾 Photo library access limited - saving photo")
                    self.performPhotoSave(imageData: imageData)
                case .denied:
                    print("📷 ❌ Photo library access denied")
                case .restricted:
                    print("📷 ❌ Photo library access restricted")
                case .notDetermined:
                    print("📷 ❓ Photo library access not determined")
                @unknown default:
                    print("📷 ❓ Unknown photo library authorization status")
                }
            }
        }
    }

    private func performPhotoSave(imageData: Data) {
        print("📷 💾 Starting photo save process...")

        PHPhotoLibrary.shared().performChanges({
            print("📷 💾 Creating photo asset...")
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("📷 ✅ Photo saved to library successfully!")
                    // Play success sound
                    TacticalSoundPlayer.playSuccess()
                } else if let error = error {
                    print("📷 ❌ Failed to save photo: \(error.localizedDescription)")
                } else {
                    print("📷 ❌ Failed to save photo: Unknown error")
                }
            }
        }
    }
}

struct NightVisionOverlay: View {
    let themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Simple green tint - no complex effects
            Rectangle()
                .fill(Color.green)
                .blendMode(.overlay)
                .opacity(0.2)

            // Simple corner indicator
            VStack {
                HStack {
                    Text("NIGHT VISION")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()
            }
        }
    }
}

// Removed StaticNoisePattern to prevent any potential animation issues

// MARK: - AR Waypoint Overlay
struct ARWaypointOverlay: View {
    @ObservedObject var viewModel: CameraViewModel
    let themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(SharedDataManager.shared.mapViewModel.waypoints) { waypoint in
                    if let position = calculateWaypointScreenPosition(
                        waypoint: waypoint,
                        userLocation: viewModel.userLocation,
                        heading: viewModel.userHeading,
                        screenSize: geometry.size
                    ) {
                        ARWaypointMarker(
                            waypoint: waypoint,
                            distance: calculateDistance(to: waypoint),
                            themeManager: themeManager
                        )
                        .position(position)
                    }
                }
            }
        }
    }

    private func calculateDistance(to waypoint: Waypoint) -> Double {
        guard let userLocation = viewModel.userLocation else { return 0 }
        let waypointLocation = CLLocation(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )
        return userLocation.distance(from: waypointLocation)
    }

    private func calculateWaypointScreenPosition(
        waypoint: Waypoint,
        userLocation: CLLocation?,
        heading: CLHeading?,
        screenSize: CGSize
    ) -> CGPoint? {
        guard let userLocation = userLocation,
              let heading = heading else {
            return nil
        }

        let waypointLocation = CLLocation(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )

        // Calculate bearing from user to waypoint
        let bearing = calculateBearing(
            from: userLocation.coordinate,
            to: waypoint.coordinate
        )

        // Calculate relative angle (difference between device heading and waypoint bearing)
        var relativeAngle = bearing - heading.trueHeading
        if relativeAngle > 180 { relativeAngle -= 360 }
        if relativeAngle < -180 { relativeAngle += 360 }

        // Only show waypoints within ±60 degrees of view
        let fovHorizontal: Double = 60.0
        guard abs(relativeAngle) <= fovHorizontal else {
            return nil
        }

        // Map angle to screen position (-60 to +60 degrees maps to 0 to screenWidth)
        let normalizedX = (relativeAngle + fovHorizontal) / (fovHorizontal * 2)
        let x = normalizedX * screenSize.width

        // Calculate vertical position based on distance
        // Closer waypoints appear lower on screen, farther ones higher
        let distance = userLocation.distance(from: waypointLocation)
        let maxDistance: Double = 5000 // 5km
        let distanceFactor = min(distance / maxDistance, 1.0)
        let y = screenSize.height * (0.3 + distanceFactor * 0.4) // Position between 30-70% of screen height

        return CGPoint(x: x, y: y)
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}

struct ARWaypointMarker: View {
    let waypoint: Waypoint
    let distance: Double
    let themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 4) {
            // Waypoint icon
            ZStack {
                Circle()
                    .fill(markerColor.opacity(0.3))
                    .frame(width: 40, height: 40)

                Circle()
                    .stroke(markerColor, lineWidth: 2)
                    .frame(width: 40, height: 40)

                Text(waypoint.id)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .shadow(color: .black.opacity(0.5), radius: 4)

            // Waypoint label
            VStack(spacing: 2) {
                Text(waypoint.name)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .shadow(color: .black.opacity(0.7), radius: 2)

                Text(formatDistance(distance))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
                    .shadow(color: .black.opacity(0.7), radius: 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
        }
    }

    private var markerColor: Color {
        switch waypoint.type {
        case .objective:
            return themeManager.errorColor
        case .checkpoint:
            return themeManager.warningColor
        case .intel:
            return themeManager.accentColor
        case .extraction:
            return themeManager.successColor
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}

// MARK: - Location Delegate
private class CameraLocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocationUpdate: (CLLocation) -> Void
    let onHeadingUpdate: (CLHeading) -> Void

    init(onLocationUpdate: @escaping (CLLocation) -> Void, onHeadingUpdate: @escaping (CLHeading) -> Void) {
        self.onLocationUpdate = onLocationUpdate
        self.onHeadingUpdate = onHeadingUpdate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onHeadingUpdate(newHeading)
    }
}