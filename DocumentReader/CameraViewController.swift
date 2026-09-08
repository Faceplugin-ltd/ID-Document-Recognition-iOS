import AVFoundation
import UIKit

/// Live preview using DocSDK.locateDocument (bounds + type score, no OCR).
/// User taps Capture when ready, then recognize.
final class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let cameraView = UIView()
    private let guideView = DocumentGuideView()
    private let percentLabel = UILabel()
    private let hintLabel = UILabel()
    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let processQueue = DispatchQueue(label: "docsdk.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var locating = false
    private var captured = false
    private var latestStill: UIImage?
    private var lastStillUpdateMs: TimeInterval = 0
    private let stillLock = NSLock()

    private let showThreshold = 50
    private let highThreshold = 85
    private let keepCaptureMin = 50
    private let locateMaxEdge: CGFloat = 480

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        guideView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        view.addSubview(guideView)

        percentLabel.text = "0%"
        percentLabel.textColor = FPColor.accent
        percentLabel.font = .systemFont(ofSize: 20, weight: .bold)
        percentLabel.textAlignment = .center
        percentLabel.backgroundColor = FPColor.accentDim
        percentLabel.layer.cornerRadius = 12
        percentLabel.clipsToBounds = true

        hintLabel.text = "Align the ID inside the frame"
        hintLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        captureButton.setTitle("Capture", for: .normal)
        captureButton.setTitleColor(.black, for: .normal)
        captureButton.backgroundColor = FPColor.accent
        captureButton.layer.cornerRadius = 12
        captureButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        captureButton.addTarget(self, action: #selector(onCapture), for: .touchUpInside)
        captureButton.isHidden = false
        captureButton.isEnabled = false

        let closeConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = FPColor.accentDim
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        [percentLabel, hintLabel, captureButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            guideView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            guideView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            guideView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            guideView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
            percentLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            percentLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            percentLabel.heightAnchor.constraint(equalToConstant: 36),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            hintLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -16),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            captureButton.widthAnchor.constraint(equalToConstant: 180),
            captureButton.heightAnchor.constraint(equalToConstant: 52),
            captureButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            captureButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        requestCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraView.bounds
        if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        processQueue.async { self.session.stopRunning() }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    if ok { self.startCamera() } else { self.finishDenied() }
                }
            }
        default:
            finishDenied()
        }
    }

    private func finishDenied() {
        let alert = UIAlertController(title: nil, message: "Camera permission is required", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) })
        present(alert, animated: true)
    }

    private func startCamera() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }
        if let conn = output.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = cameraView.bounds
        if let conn = preview.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        cameraView.layer.addSublayer(preview)
        previewLayer = preview
        processQueue.async { self.session.startRunning() }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if captured { return }
        if locating { return }
        locating = true
        defer { locating = false }

        guard let image = Self.image(from: sampleBuffer)?.fixOrientation() else { return }
        let locateBmp = image.scaled(maxEdge: locateMaxEdge)
        let locateJson = DocSDK.locateDocument(locateBmp)
        let scorePct = ResultParser.documentPercent(locateJson)
        let cornersLocate = ResultParser.documentCorners(locateJson)
        /* Score is type confidence (OneCandidate.P), not objArea fill.
         * Empty frames often return a desk/table quad with P=0. */
        let showOverlay = scorePct >= showThreshold && cornersLocate != nil
        let high = scorePct >= highThreshold

        if scorePct >= keepCaptureMin {
            let now = Date().timeIntervalSince1970 * 1000
            if high || now - lastStillUpdateMs > 500 {
                stillLock.lock()
                latestStill = image
                stillLock.unlock()
                lastStillUpdateMs = now
            }
        }

        let viewCorners: [CGPoint]? = {
            guard showOverlay, let corners = cornersLocate else { return nil }
            let iw = max(locateBmp.size.width, 1)
            let ih = max(locateBmp.size.height, 1)
            let inImage = corners.map {
                CGPoint(x: $0.x * image.size.width / iw, y: $0.y * image.size.height / ih)
            }
            return Self.mapUprightCornersToView(inImage, imageSize: image.size, viewSize: self.cameraView.bounds.size)
        }()

        DispatchQueue.main.async {
            if self.captured { return }
            self.percentLabel.text = "\(scorePct)%"
            if let viewCorners {
                self.guideView.setDetectedCorners(viewCorners)
            } else {
                self.guideView.clearDetection()
            }
            self.guideView.locked = high
            self.captureButton.isHidden = false
            self.captureButton.isEnabled = scorePct >= self.keepCaptureMin
            self.hintLabel.text = scorePct >= self.keepCaptureMin
                ? "Ready — tap Capture or keep holding"
                : "Align the ID inside the frame"
        }
    }

    @objc private func onCapture() {
        stillLock.lock()
        let still = latestStill
        stillLock.unlock()
        guard let still else { return }
        beginRecognize(still)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func beginRecognize(_ still: UIImage) {
        if captured { return }
        captured = true
        DispatchQueue.main.async {
            self.captureButton.isHidden = true
            self.hintLabel.text = "Reading document…"
        }
        processQueue.async {
            self.session.stopRunning()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: true, wantAuthenticity: true)
            let json = DocSDK.recognize(
                still,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            DispatchQueue.main.async {
                guard let nav = self.presentingViewController as? UINavigationController else {
                    self.dismiss(animated: true)
                    return
                }
                let openResult = {
                    nav.pushViewController(ResultViewController(json: json), animated: false)
                    self.dismiss(animated: true)
                }
                if let deny, !deny.isEmpty {
                    let alert = UIAlertController(title: nil, message: deny, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in openResult() })
                    self.present(alert, animated: true)
                } else {
                    openResult()
                }
            }
        }
    }

    /// Locate corners are in the upright bitmap. Preview is aspect-fill of that same
    /// portrait frame — do not use capture-device points (those are landscape buffer
    /// coords and swap X/Y on a portrait phone).
    private static func mapUprightCornersToView(
        _ corners: [CGPoint],
        imageSize: CGSize,
        viewSize: CGSize
    ) -> [CGPoint]? {
        guard corners.count >= 4,
              imageSize.width > 1, imageSize.height > 1,
              viewSize.width > 1, viewSize.height > 1 else { return nil }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let dx = (viewSize.width - imageSize.width * scale) / 2
        let dy = (viewSize.height - imageSize.height * scale) / 2
        /* Preview is top-down UIKit, but the locate bitmap matches the camera
         * buffer which is origin-bottom — flip Y so the quad sits on the ID. */
        return corners.map {
            CGPoint(x: $0.x * scale + dx, y: (imageSize.height - $0.y) * scale + dy)
        }
    }

    private static func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        /* Landscape sensor buffer in a portrait session needs a 90° CW display. */
        let orientation: UIImage.Orientation = w > h ? .right : .up
        return UIImage(cgImage: cg, scale: 1, orientation: orientation)
    }
}
