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
                        .overlay(
                            filterOverlay
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        )
                } else {
                    // Simulator or no camera device - show placeholder
                    ZStack {
                        Color.black.ignoresSafeArea()

                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundColor(themeManager.primaryColor.opacity(0.6))

                            Text("CAMERA SIMULATION")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(themeManager.textColor)
                                .fontWeight(.bold)

                            Text("Running on simulator or no camera available")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                        }
                        .overlay(
                            filterOverlay
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        )
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
        Rectangle()
            .fill(filterColor)
            .blendMode(filterBlendMode)
            .opacity(filterOpacity)
    }

    private var filterColor: Color {
        switch viewModel.currentFilter {
        case .normal:
            return Color.clear
        case .nightVision:
            return Color.green
        case .thermal:
            return Color.orange
        case .infrared:
            return Color.red
        }
    }

    private var filterBlendMode: BlendMode {
        switch viewModel.currentFilter {
        case .normal:
            return .normal
        case .nightVision:
            return .multiply
        case .thermal:
            return .colorBurn
        case .infrared:
            return .multiply
        }
    }

    private var filterOpacity: Double {
        switch viewModel.currentFilter {
        case .normal:
            return 0.0
        case .nightVision:
            return 0.3
        case .thermal:
            return 0.4
        case .infrared:
            return 0.35
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
                    .foregroundColor(themeManager.textColor)

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
            CodecButton(title: viewModel.isRecording ? "STOP" : "REC", action: {
                TacticalSoundPlayer.playAction()
                viewModel.toggleRecording()
            }, style: viewModel.isRecording ? .secondary : .primary, size: .medium)
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
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle photo capture completion
        print("Photo captured")
    }
}