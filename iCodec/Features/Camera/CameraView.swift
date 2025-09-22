import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Camera preview background
            if viewModel.isAuthorized {
                CameraPreview(session: viewModel.captureSession)
                    .ignoresSafeArea()
            } else {
                themeManager.backgroundColor
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
        HStack(spacing: 40) {
            // Filter button
            CodecButton(title: "FILTER", action: {
                viewModel.toggleFilter()
            }, style: .secondary, size: .medium)

            // Capture button
            Button(action: {
                viewModel.capturePhoto()
            }) {
                ZStack {
                    Circle()
                        .stroke(themeManager.primaryColor, lineWidth: 3)
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(themeManager.primaryColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
            }

            // Mode button
            CodecButton(title: viewModel.currentFilter.rawValue, action: {
                viewModel.cycleFilter()
            }, style: .primary, size: .medium)
        }
        .padding(.bottom, 30)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

@MainActor
class CameraViewModel: BaseViewModel {
    @Published var isAuthorized = false
    @Published var isRecording = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var currentFilter: CameraFilter = .normal

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()

    enum CameraFilter: String, CaseIterable {
        case normal = "NORMAL"
        case thermal = "THERMAL"
        case nightVision = "NIGHT"
        case infrared = "INFRARED"
    }

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            isAuthorized = true

            Task {
                captureSession.startRunning()
            }
        } catch {
            handleError(error)
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate())
    }

    func toggleFilter() {
        // Simulate filter toggle
        isRecording.toggle()
    }

    func cycleFilter() {
        let filters = CameraFilter.allCases
        if let currentIndex = filters.firstIndex(of: currentFilter) {
            let nextIndex = (currentIndex + 1) % filters.count
            currentFilter = filters[nextIndex]
        }
    }
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Handle photo capture completion
        print("Photo captured")
    }
}