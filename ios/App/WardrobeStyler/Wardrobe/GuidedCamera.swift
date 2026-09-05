// Guided camera for garments (PLAN §4.3 camera guidance, §6 "Capture": AVCaptureSession with a garment-frame overlay and spoken/visual hints).
// The capture is cropped to the framing rectangle so the Vision cutout sees exactly what the user framed.
import AVFoundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraController: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var device: AVCaptureDevice?
    private var captureContinuation: CheckedContinuation<UIImage, Error>?
    /// Set by the preview so captures can be cropped to the overlay frame.
    var previewLayer: AVCaptureVideoPreviewLayer?
    var frameRectInLayer: CGRect = .zero

    var isRunning = false
    var authorizationDenied = false
    var averageLuma: Double = 128
    var torchOn = false
    var lastError: String?

    var lightingHint: String? {
        if averageLuma < 55 { return "Too dark: add light or turn on the torch" }
        if averageLuma > 225 { return "Too bright: move out of direct light" }
        return nil
    }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { authorizationDenied = true; return }
        case .denied, .restricted:
            authorizationDenied = true; return
        default: break
        }
        configureIfNeeded()
        queue.async { [session] in session.startRunning() }
        isRunning = true
    }

    func stop() {
        queue.async { [session] in session.stopRunning() }
        isRunning = false
        setTorch(false)
    }

    private var configured = false
    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) else {
            lastError = "No back camera"; session.commitConfiguration(); return
        }
        device = cam
        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        for output in [photoOutput as AVCaptureOutput, videoOutput] {
            if let c = output.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        }
        session.commitConfiguration()
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        torchOn = on
    }

    /// Captures a photo and crops it to the overlay frame (falls back to the full photo if the mapping fails).
    func capture() async throws -> UIImage {
        try await withCheckedThrowingContinuation { c in
            captureContinuation = c
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if let c = photoOutput.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    fileprivate func finish(_ result: Result<UIImage, Error>) {
        captureContinuation?.resume(with: result)
        captureContinuation = nil
    }

    fileprivate func crop(_ image: UIImage) -> UIImage {
        guard let layer = previewLayer, frameRectInLayer.width > 0 else { return image }
        // Normalise orientation first so the crop is applied to an upright bitmap.
        let upright = UIGraphicsImageRenderer(size: image.size, format: { let f = UIGraphicsImageRendererFormat.default(); f.scale = 1; return f }()).image { _ in image.draw(at: .zero) }
        guard let cg = upright.cgImage else { return image }
        let r = layer.metadataOutputRectConverted(fromLayerRect: frameRectInLayer)
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: r.minX * w, y: r.minY * h, width: r.width * w, height: r.height * h).integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width > 50, rect.height > 50, let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            if let error { finish(.failure(error)); return }
            guard let data, let image = UIImage(data: data) else { finish(.failure(NSError(domain: "camera", code: 1, userInfo: [NSLocalizedDescriptionKey: "no photo data"]))); return }
            finish(.success(crop(image)))
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Average luma of the Y plane on a coarse grid, ~4 times a second, for the lighting hint.
        guard Int(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 4) != Int((CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds - 1.0 / 30) * 4) else { return }
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pb, 0) else { return }
        let w = CVPixelBufferGetWidthOfPlane(pb, 0), h = CVPixelBufferGetHeightOfPlane(pb, 0), rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
        var sum = 0, n = 0
        var y = 0
        while y < h { var x = 0; while x < w { sum += Int(base.load(fromByteOffset: y * rowBytes + x, as: UInt8.self)); n += 1; x += 32 }; y += 32 }
        let avg = n > 0 ? Double(sum) / Double(n) : 128
        Task { @MainActor in self.averageLuma = avg }
    }
}

struct CameraPreview: UIViewRepresentable {
    let controller: CameraController
    let frameRect: CGRect // in the preview's own coordinates

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = controller.session
        v.previewLayer.videoGravity = .resizeAspectFill
        controller.previewLayer = v.previewLayer
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        controller.previewLayer = uiView.previewLayer
        controller.frameRectInLayer = frameRect
    }
}

struct GuidedCameraView: View {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var controller = CameraController()
    @State private var capturing = false
    @State private var tipIndex = 0
    private let tips = ["Lay the garment flat or hang it on a plain wall", "Fill the frame with one item", "Avoid shadows and busy backgrounds"]

    var body: some View {
        GeometryReader { geo in
            let frame = framingRect(in: geo.size)
            ZStack {
                CameraPreview(controller: controller, frameRect: frame).ignoresSafeArea()
                // Dim everything outside the frame.
                Rectangle().fill(.black.opacity(0.55))
                    .mask(Rectangle().overlay(RoundedRectangle(cornerRadius: 18).frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY).blendMode(.destinationOut)))
                    .ignoresSafeArea()
                RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.9), lineWidth: 2).frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
                cornerMarks(frame)

                VStack {
                    HStack {
                        Button("Cancel") { dismiss() }.foregroundStyle(.white)
                        Spacer()
                        Button { controller.setTorch(!controller.torchOn) } label: { Image(systemName: controller.torchOn ? "bolt.fill" : "bolt.slash") }.foregroundStyle(.white)
                    }
                    .padding()
                    Spacer()
                    VStack(spacing: 6) {
                        if let hint = controller.lightingHint {
                            Label(hint, systemImage: "sun.max").font(.subheadline).foregroundStyle(.yellow)
                        } else {
                            Text(tips[tipIndex]).font(.subheadline).foregroundStyle(.white)
                        }
                        if controller.authorizationDenied { Text("Camera access is off. Enable it in Settings → Wardrobe Styler.").font(.footnote).foregroundStyle(.orange) }
                        if let e = controller.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
                    }
                    .padding(.horizontal).padding(.bottom, 8)
                    Button { Task { await shoot() } } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                            Circle().fill(.white).frame(width: 62, height: 62)
                            if capturing { ProgressView().tint(.black) }
                        }
                    }
                    .disabled(capturing || !controller.isRunning)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(.black)
        .task { await controller.start() }
        .onDisappear { controller.stop() }
        .task {
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(4)); tipIndex = (tipIndex + 1) % tips.count }
        }
    }

    /// A 3:4 frame with side margins, centred a little above the shutter.
    private func framingRect(in size: CGSize) -> CGRect {
        let w = size.width * 0.86
        let h = min(w * 4 / 3, size.height * 0.62)
        return CGRect(x: (size.width - w) / 2, y: size.height * 0.12, width: w, height: h)
    }

    private func cornerMarks(_ f: CGRect) -> some View {
        let len: CGFloat = 26, lw: CGFloat = 4
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                let x = i % 2 == 0 ? f.minX : f.maxX
                let y = i < 2 ? f.minY : f.maxY
                Path { p in
                    p.move(to: CGPoint(x: x, y: y + (i < 2 ? len : -len))); p.addLine(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + (i % 2 == 0 ? len : -len), y: y))
                }
                .stroke(.white, style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }
        }
    }

    private func shoot() async {
        capturing = true
        defer { capturing = false }
        do {
            let image = try await controller.capture()
            onImage(image)
            dismiss()
        } catch {
            controller.lastError = error.localizedDescription
        }
    }
}
