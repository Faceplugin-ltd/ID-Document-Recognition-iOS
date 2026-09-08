import UIKit

/// Sample host for DocSDK.
///
/// Init (background thread): getMachineCode → setActivation → initSDK.
/// Replace licenseKey with an FP1.… key issued for **your** bundle identifier.
///
/// Home tiles: Camera | Gallery | About
class ViewController: UIViewController {
    /// FP1.… from FacePlugin for this app's bundle identifier (`com.faceplugin.documentreader`).
    private let licenseKey =
        "FP1.RlBMMQMAAQAZ9Zwi8fHG33dpwB8MAgAAugTVCCTnRx8neRXi7q3IQx09+pM/07ZLOE3uhGCXIfQq/jt8i6+oovCghJsTnzx+LbraSzYnYKhFM+8ZpCt5x6/YNgVNh2Wrdq336ehT9ZmWagxWEm/T4sJw0IlrJwxz+uDS01X95P0og2hQy61Rqh6Q2lCsRpBVj6tVpVU7Q4BcnL43JHUZyFIFzZVhgakFrzZ1v2yMX7hZubx1vsVTDS8XZjOEjNyIs2B7th1XczBQV9jRo/Hzq9IFypKxF+w0kqKeiCGgXtEkpVnhH0q2d3Ol3Hwd7VCvN4rwAfXA4LRpBqMMXgN0iFb4GaZ/5RrcuiWGHt6Se1XRdLaVcYeiafY9i0dGnKpWoYC6Wcc3w7Ud9tt/JH3ZCW0VSX3mhbwizb9aUFpfewQ1233B2QkyydYrmcW9WdRyuIITCZl7lxL4Bu+rMuNvYImrbjnPtUMErhwldzp5/KpVD2n8ZuhQVqo/nvxKVkhu49jA5rncA99rBR/j8PA8tQnrkJA/UzbnGZKe5vaUZHHbc2f/8hoyFAd+bYsgWBBGm98d/JoFNeKA/Lj9qBz/96Vhsb31X/g69Mg2FjeKLmPNLRBsdtB5Gq451Ng7SqVBhSLu3izjcEPw0ZNvfgp41+RXMoxr3HrJ0Nrxe+DjbsVVEhXboNK5UoW0K+YwDpRBssLUBD2v0A5O46pNVDj8BjG6P26LADCBiAJCAUUBMF7fdBJVN4bynNDBBmW66ebB8UiHQWqr3JXWGS4yX+ANEOKFA8x241i0loqcmVGGkNRTdDEuE8T4WaDU9WqBAkIAsgWLPid1PUQVJZVceswxeHuK+NkbA4temoT2sYADekl3tZEA2YA4Ax8Z02A3xY1cT7gAnQz6fMxwoRmYKzZevDQ="

    private let statusLabel = UILabel()
    private var sdkReady = false
    private var loadingAlert: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupHome()
        activateSDK()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupHome() {
        let logo = UIButton(type: .custom)
        logo.setImage(UIImage(named: "FacePluginLogo")?.withRenderingMode(.alwaysOriginal), for: .normal)
        logo.imageView?.contentMode = .scaleAspectFit
        logo.contentHorizontalAlignment = .fill
        logo.contentVerticalAlignment = .fill
        logo.adjustsImageWhenHighlighted = true
        logo.accessibilityLabel = "FacePlugin"
        logo.addTarget(self, action: #selector(openSite), for: .touchUpInside)

        let title = UILabel()
        title.text = "FacePlugin DocumentReader"
        title.textColor = FPColor.text
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textAlignment = .center

        let camera = makeCard(title: "CAMERA", systemImage: "camera.fill", action: #selector(openCamera))
        let gallery = makeCard(title: "GALLERY", systemImage: "photo.on.rectangle", action: #selector(openGallery))
        let about = makeCard(title: "ABOUT", systemImage: "info.circle.fill", action: #selector(openAbout))

        let grid = UIStackView(arrangedSubviews: [camera, gallery, about])
        grid.axis = .horizontal
        grid.spacing = 10
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false

        let body = UIStackView(arrangedSubviews: [logo, title, grid])
        body.axis = .vertical
        body.alignment = .center
        body.spacing = 16
        body.setCustomSpacing(28, after: title)
        body.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "Loading native SDK…"
        statusLabel.textColor = FPColor.text
        statusLabel.numberOfLines = 3
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = FPColor.statusInfo
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(body)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logo.widthAnchor.constraint(equalToConstant: 120),
            logo.heightAnchor.constraint(equalToConstant: 120),
            grid.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            grid.heightAnchor.constraint(equalToConstant: 112),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func makeCard(title: String, systemImage: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = FPColor.purple
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.addTarget(self, action: action, for: .touchUpInside)
        card.addTarget(self, action: #selector(cardHighlight(_:)), for: [.touchDown, .touchDragEnter])
        card.addTarget(self, action: #selector(cardUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let icon = UIImageView(image: UIImage(systemName: systemImage))
        icon.tintColor = FPColor.text
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.textColor = FPColor.text
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.translatesAutoresizingMaskIntoConstraints = false

        let col = UIStackView(arrangedSubviews: [icon, label])
        col.axis = .vertical
        col.alignment = .center
        col.spacing = 8
        col.isUserInteractionEnabled = false
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),
            col.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            col.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            col.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 4),
            col.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -4),
        ])
        return card
    }

    @objc private func cardHighlight(_ sender: UIControl) {
        sender.alpha = 0.75
    }

    @objc private func cardUnhighlight(_ sender: UIControl) {
        sender.alpha = 1
    }

    private func activateSDK() {
        updateStatus("Loading native SDK…", color: FPColor.statusInfo)
        DispatchQueue.global(qos: .userInitiated).async {
            let machine = DocSDK.getMachineCode()
            let act = Int(DocSDK.setActivation(self.licenseKey))
            let initRc = act == 0 ? Int(DocSDK.initSDK()) : act
            self.sdkReady = initRc == 0
            NSLog(
                "DocSDKDemo machine=%@ init=%d ready=%@",
                machine, initRc, self.sdkReady ? "y" : "n"
            )
            DispatchQueue.main.async {
                if self.sdkReady {
                    let label = LicenseStatus.current().label
                    self.updateStatus("Ready · \(label)", color: FPColor.statusOk)
                    self.maybeSelfTest()
                } else {
                    let msg: String
                    switch initRc {
                    case 1: msg = "License invalid"
                    case 2: msg = "License expired"
                    case 3: msg = "SDK not activated"
                    case 4: msg = "Initialization failed"
                    case 5: msg = "No database found"
                    case 6: msg = "Database loading error"
                    default: msg = "SDK not ready: \(initRc)"
                    }
                    self.updateStatus(msg, color: FPColor.statusError)
                }
            }
        }
    }

    private func updateStatus(_ text: String, color: UIColor) {
        statusLabel.text = text
        statusLabel.backgroundColor = color
    }

    private func ensureReady() -> Bool {
        if sdkReady { return true }
        presentAlert("SDK not ready")
        return false
    }

    @objc private func openCamera() {
        guard ensureReady() else { return }
        let vc = CameraViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func openGallery() {
        guard ensureReady() else { return }
        navigationController?.pushViewController(GalleryViewController(), animated: true)
    }

    @objc private func openAbout() {
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }

    @objc private func openSite() {
        if let url = URL(string: "https://faceplugin.com") {
            UIApplication.shared.open(url)
        }
    }

    private func recognizeAndShow(_ image: UIImage) {
        showBusy("Processing image")
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = CFAbsoluteTimeGetCurrent()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: true, wantAuthenticity: true)
            let json = DocSDK.recognize(
                image,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            let hasTimeout = json.localizedCaseInsensitiveContains("timeout")
            let hasOcr = json.contains("\"ocr\"")
            let hasMrz = json.contains("\"mrz\"")
            NSLog(
                "DocSDKDemo recognize ms=%d len=%d timeout=%d ocr=%d mrz=%d head=%@",
                ms, json.count,
                hasTimeout ? 1 : 0,
                hasOcr ? 1 : 0,
                hasMrz ? 1 : 0,
                String(json.prefix(240)) as NSString
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
                    if let deny, !deny.isEmpty {
                        self.presentAlert(deny)
                    }
                    guard let nav = self.navigationController else { return }
                    nav.pushViewController(ResultViewController(json: json), animated: true)
                }
            }
        }
    }

    /// Hidden self-test: Xcode/env `process_path` = absolute path to a JPEG on device.
    private func maybeSelfTest() {
        guard sdkReady else { return }
        guard let path = ProcessInfo.processInfo.environment["process_path"], !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard let image = UIImage.loadForGallery(url: url) else {
            NSLog("DocSDKDemo self-test could not decode %@", path)
            return
        }
        NSLog("DocSDKDemo self-test start path=%@", path)
        // Defer past first layout so launch/activate is not blocked by the busy alert.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recognizeAndShow(image)
        }
    }

    private func showBusy(_ msg: String) {
        if loadingAlert != nil { return }
        let alert = UIAlertController(title: nil, message: "\n\(msg)", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = FPColor.accent
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 16),
        ])
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

    private func presentAlert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
