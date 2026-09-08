import UIKit

/// Gallery still recognition — Front + optional Back (Linux Document Reader demo UX).
final class GalleryViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var frontImage: UIImage?
    private var backImage: UIImage?
    private var pickingBack = false
    private var loadingAlert: UIAlertController?

    private let frontSlot = ImagePickSlot(title: "Front", optional: false)
    private let backSlot = ImagePickSlot(title: "Back", optional: true)
    private let recognizeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "From Gallery"
        applyNavAppearance()

        frontSlot.onPick = { [weak self] in
            self?.pickingBack = false
            self?.presentPicker()
        }
        frontSlot.onClear = { [weak self] in
            self?.frontImage = nil
            self?.frontSlot.setImage(nil)
            self?.updateRecognizeEnabled()
        }
        backSlot.onPick = { [weak self] in
            self?.pickingBack = true
            self?.presentPicker()
        }
        backSlot.onClear = { [weak self] in
            self?.backImage = nil
            self?.backSlot.setImage(nil)
        }

        recognizeButton.setTitle("Recognize", for: .normal)
        recognizeButton.setTitleColor(.black, for: .normal)
        recognizeButton.backgroundColor = FPColor.accent
        recognizeButton.layer.cornerRadius = 12
        recognizeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        recognizeButton.addTarget(self, action: #selector(runRecognize), for: .touchUpInside)
        recognizeButton.isEnabled = false
        recognizeButton.alpha = 0.45

        let col = UIStackView(arrangedSubviews: [frontSlot, backSlot, recognizeButton])
        col.axis = .vertical
        col.spacing = 20
        col.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(col)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            col.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            col.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -24),
            col.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            frontSlot.heightAnchor.constraint(equalToConstant: 220),
            backSlot.heightAnchor.constraint(equalToConstant: 220),
            recognizeButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func applyNavAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = FPColor.bg
        appearance.titleTextAttributes = [.foregroundColor: FPColor.text]
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = FPColor.accent
    }

    private func updateRecognizeEnabled() {
        let ok = frontImage != nil
        recognizeButton.isEnabled = ok
        recognizeButton.alpha = ok ? 1 : 0.45
    }

    private func presentPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        let image: UIImage?
        if let url = info[.imageURL] as? URL {
            image = UIImage.loadForGallery(url: url)
        } else if let original = info[.originalImage] as? UIImage,
                  let data = original.jpegData(compressionQuality: 0.95) ?? original.pngData() {
            image = UIImage.loadForGallery(data: data)
        } else {
            image = (info[.originalImage] as? UIImage)?.fixOrientation().scaledForGallery()
        }
        guard let image else { return }
        if pickingBack {
            backImage = image
            backSlot.setImage(image)
        } else {
            frontImage = image
            frontSlot.setImage(image)
            updateRecognizeEnabled()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    @objc private func runRecognize() {
        guard let front = frontImage else { return }
        let back = backImage
        recognizeButton.isEnabled = false
        showBusy("Processing image")
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = CFAbsoluteTimeGetCurrent()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: true, wantAuthenticity: true)
            let json = DocSDK.recognizeFront(
                front,
                back: back,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            let hasTimeout = json.localizedCaseInsensitiveContains("timeout")
            let hasOcr = json.contains("\"ocr\"")
            let hasMrz = json.contains("\"mrz\"")
            NSLog(
                "DocSDKDemo gallery recognize ms=%d len=%d timeout=%d ocr=%d mrz=%d",
                ms, json.count, hasTimeout ? 1 : 0, hasOcr ? 1 : 0, hasMrz ? 1 : 0
            )
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let meta = docs.appendingPathComponent("last_recognize_meta.txt")
                let body = docs.appendingPathComponent("last_recognize.json")
                let summary =
                    "ms=\(ms) len=\(json.count) timeout=\(hasTimeout) ocr=\(hasOcr) mrz=\(hasMrz)\n"
                    + "head=\(String(json.prefix(400)))\n"
                try? summary.write(to: meta, atomically: true, encoding: .utf8)
                try? json.write(to: body, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async {
                self.hideBusy {
                    self.updateRecognizeEnabled()
                    if let deny, !deny.isEmpty {
                        let alert = UIAlertController(title: nil, message: deny, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            guard let nav = self.navigationController else { return }
                            nav.pushViewController(ResultViewController(json: json), animated: true)
                        })
                        self.present(alert, animated: true)
                        return
                    }
                    guard let nav = self.navigationController else { return }
                    nav.pushViewController(ResultViewController(json: json), animated: true)
                }
            }
        }
    }

    private func showBusy(_ msg: String) {
        if loadingAlert != nil { return }
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        present(alert, animated: true)
        loadingAlert = alert
    }

    private func hideBusy(completion: (() -> Void)? = nil) {
        guard let alert = loadingAlert else {
            completion?()
            return
        }
        loadingAlert = nil
        alert.dismiss(animated: true, completion: completion)
    }
}

/// Empty = flat surface + label only. Selected = image + X clear (no spinner / no decorative icon).
private final class ImagePickSlot: UIView {
    var onPick: (() -> Void)?
    var onClear: (() -> Void)?

    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private let preview = UIImageView()
    private let clearButton = UIButton(type: .system)

    init(title: String, optional: Bool) {
        super.init(frame: .zero)
        backgroundColor = FPColor.surface
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = FPColor.stroke.cgColor
        clipsToBounds = true

        titleLabel.text = title
        titleLabel.textColor = FPColor.accent
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        emptyLabel.text = optional ? "Tap to pick (optional)" : "Tap to pick"
        emptyLabel.textColor = FPColor.muted
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .clear
        preview.isHidden = true

        let xConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        clearButton.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
        clearButton.tintColor = .white
        clearButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        clearButton.layer.cornerRadius = 14
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickTapped(_:))))

        [titleLabel, emptyLabel, preview, clearButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 8),
            preview.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            preview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            clearButton.widthAnchor.constraint(equalToConstant: 28),
            clearButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage?) {
        preview.image = image
        let has = image != nil
        preview.isHidden = !has
        emptyLabel.isHidden = has
        clearButton.isHidden = !has
    }

    @objc private func pickTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        if !clearButton.isHidden, clearButton.frame.insetBy(dx: -8, dy: -8).contains(point) {
            return
        }
        onPick?()
    }

    @objc private func clearTapped() {
        onClear?()
    }
}
