import SwiftUI
@preconcurrency import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Camera preview background
            if viewModel.isAuthorized {
                if viewModel.captureSession.isRunning {
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
                } else {
                    // Simulator or no camera device - show test image
                    ZStack {
                        // Test background image for filter demonstration
                        SimulatorCameraBackground()
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

                        // Filter overlay
                        filterOverlay
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        // Simulation indicator
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Text("SIM")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(themeManager.primaryColor)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 100)
                            }
                        }
                    }
                }
            } else {
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
                // Night vision effect
                ZStack {
                    Rectangle()
                        .fill(Color.green)
                        .blendMode(.multiply)
                        .opacity(0.4)

                    Rectangle()
                        .fill(Color.green)
                        .blendMode(.overlay)
                        .opacity(0.2)

                    // Noise pattern
                    Rectangle()
                        .fill(Color.white)
                        .opacity(0.05)
                        .blendMode(.overlay)
                }
            case .thermal:
                // Thermal imaging effect
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple, Color.red, Color.orange, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.colorBurn)
                        .opacity(0.6)

                    Rectangle()
                        .fill(Color.orange)
                        .blendMode(.overlay)
                        .opacity(0.3)
                }
            case .infrared:
                // Infrared effect
                ZStack {
                    Rectangle()
                        .fill(Color.red)
                        .blendMode(.multiply)
                        .opacity(0.5)

                    Rectangle()
                        .fill(Color.purple)
                        .blendMode(.overlay)
                        .opacity(0.2)

                    // IR glow effect
                    Rectangle()
                        .fill(Color.white)
                        .blendMode(.softLight)
                        .opacity(0.1)
                }
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
                        .stroke(themeManager.primaryColor, lineWidth: 3)
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(themeManager.primaryColor.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.primaryColor)
                }
            }

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
    @Published @MainActor var isRecording = false
    @Published @MainActor var zoomLevel: CGFloat = 1.0
    @Published @MainActor var currentFilter: CameraFilter = .normal

    private var baseZoomLevel: CGFloat = 1.0

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()

    enum CameraFilter: String, CaseIterable {
        case normal = "NORMAL"
        case thermal = "THERMAL"
        case nightVision = "NIGHT"
        case infrared = "INFRARED"
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
                return
            }

            guard let device = AVCaptureDevice.default(for: .video) else {
                print("No camera device available - running on iOS Simulator")
                await MainActor.run {
                    // For simulator, we'll show as authorized with simulation mode
                    isAuthorized = true
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                // Access MainActor properties within MainActor context
                await MainActor.run {
                    let session = captureSession
                    let output = photoOutput

                    // Configure session
                    session.beginConfiguration()

                    // Remove any existing inputs/outputs
                    session.inputs.forEach { session.removeInput($0) }
                    session.outputs.forEach { session.removeOutput($0) }

                    if session.canAddInput(input) {
                        session.addInput(input)
                    }

                    if session.canAddOutput(output) {
                        session.addOutput(output)
                    }

                    // Set session preset for better quality
                    if session.canSetSessionPreset(.photo) {
                        session.sessionPreset = .photo
                    }

                    session.commitConfiguration()
                    isAuthorized = true

                    // Start session on background queue
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                    }
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
                await MainActor.run {
                    handleError(error)
                    isAuthorized = false
                }
            }
        }
    }

    @MainActor
    func capturePhoto() {
        // Check if we have an active camera connection (real device)
        guard captureSession.isRunning,
              let connection = photoOutput.connection(with: .video),
              connection.isActive else {
            print("Photo capture: No active camera connection (simulator mode)")
            return
        }

        let settings = AVCapturePhotoSettings()
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

            // Apply audio feedback for filter change
            objectWillChange.send()
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
        // Apply zoom to actual camera device if running
        guard captureSession.isRunning,
              let device = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return
        }

        do {
            try device.device.lockForConfiguration()

            // Respect device's actual zoom capabilities
            let maxZoom = device.device.activeFormat.videoMaxZoomFactor
            let actualZoom = max(1.0, min(maxZoom, zoom))

            device.device.videoZoomFactor = actualZoom
            device.device.unlockForConfiguration()
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

struct SimulatorCameraBackground: View {
    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.3),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Test pattern elements
            VStack(spacing: 40) {
                // Top section - building silhouettes
                HStack(spacing: 20) {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 60, height: 80)
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 40, height: 60)
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 80, height: 100)
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 50, height: 70)
                }

                // Middle section - terrain
                HStack(spacing: 15) {
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 30, height: 30)
                    Circle()
                        .fill(Color.brown.opacity(0.5))
                        .frame(width: 40, height: 40)
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 60, height: 20)
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 35, height: 35)
                }

                // Bottom section - ground pattern
                HStack(spacing: 10) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 30, height: 15)
                    }
                }
            }

            // Add some "heat signatures" for thermal testing
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.red.opacity(0.4))
                        .frame(width: 25, height: 25)
                        .padding(.trailing, 40)
                        .padding(.top, 60)
                }
                Spacer()
                HStack {
                    Circle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .padding(.leading, 50)
                    Spacer()
                }
                Spacer()
            }

            // Grid overlay for targeting
            Path { path in
                let spacing: CGFloat = 50
                // Vertical lines
                for x in stride(from: 0, through: 400, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: 800))
                }
                // Horizontal lines
                for y in stride(from: 0, through: 800, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: 400, y: y))
                }
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle photo capture completion
        print("Photo captured")
    }
}