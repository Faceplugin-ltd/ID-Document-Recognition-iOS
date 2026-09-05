import UIKit

final class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "About"
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = FPColor.bg
        appearance.titleTextAttributes = [.foregroundColor: FPColor.text]
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = FPColor.accent

        let logo = UIButton(type: .custom)
        logo.setImage(UIImage(named: "FacePluginLogo")?.withRenderingMode(.alwaysOriginal), for: .normal)
        logo.imageView?.contentMode = .scaleAspectFit
        logo.contentHorizontalAlignment = .fill
        logo.contentVerticalAlignment = .fill
        logo.adjustsImageWhenHighlighted = true
        logo.accessibilityLabel = "FacePlugin"
        logo.addTarget(self, action: #selector(openSite), for: .touchUpInside)

        let company = UILabel()
        company.text = "FacePlugin"
        company.textColor = FPColor.text
        company.font = .systemFont(ofSize: 22, weight: .bold)
        company.textAlignment = .center

        let product = UILabel()
        product.text = "Document Reader SDK"
        product.textColor = FPColor.accent
        product.font = .systemFont(ofSize: 15)
        product.textAlignment = .center

        let licenseLabel = UILabel()
        licenseLabel.text = "License: …"
        licenseLabel.textColor = FPColor.text
        licenseLabel.font = .systemFont(ofSize: 13)
        licenseLabel.textAlignment = .center
        licenseLabel.numberOfLines = 0
        let licenseCard = wrapCard(licenseLabel)

        let companyBody = card(
            "FacePlugin builds on-device identity technology — document recognition, face matching, and liveness — so biometric data never has to leave the phone."
        )
        let productBody = card(
            "This app demos the Document Reader SDK for iOS: ID cards, passports, and driver licenses with OCR, MRZ, barcode, and optional authenticity checks. Everything runs fully on-premise."
        )

        let site = UIButton(type: .system)
        site.setTitle("faceplugin.com", for: .normal)
        site.setTitleColor(FPColor.accent, for: .normal)
        site.addTarget(self, action: #selector(openSite), for: .touchUpInside)

        let copy = UILabel()
        copy.text = "© 2026 FacePlugin. All rights reserved."
        copy.textColor = FPColor.muted
        copy.font = .systemFont(ofSize: 12)
        copy.textAlignment = .center

        let col = UIStackView(arrangedSubviews: [logo, company, product, licenseCard, companyBody, productBody, site, copy])
        col.axis = .vertical
        col.spacing = 16
        col.alignment = .center
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
            col.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 24),
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            col.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -24),
            col.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            logo.widthAnchor.constraint(equalToConstant: 120),
            logo.heightAnchor.constraint(equalToConstant: 120),
            licenseCard.widthAnchor.constraint(equalTo: col.widthAnchor),
            companyBody.widthAnchor.constraint(equalTo: col.widthAnchor),
            productBody.widthAnchor.constraint(equalTo: col.widthAnchor),
        ])

        DispatchQueue.global(qos: .userInitiated).async {
            let status = LicenseStatus.current()
            let text = "License: \(status.label)"
            DispatchQueue.main.async {
                licenseLabel.text = text
            }
        }
    }

    private func wrapCard(_ label: UILabel) -> UIView {
        label.translatesAutoresizingMaskIntoConstraints = false
        let box = UIView()
        box.backgroundColor = FPColor.surface
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = FPColor.stroke.cgColor
        box.clipsToBounds = true
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])
        return box
    }

    private func card(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.textColor = FPColor.text
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let box = UIView()
        box.backgroundColor = FPColor.surface
        box.layer.cornerRadius = 16
        box.layer.borderWidth = 1
        box.layer.borderColor = FPColor.stroke.cgColor
        box.clipsToBounds = true
        box.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
        ])
        return box
    }

    @objc private func openSite() {
        if let url = URL(string: "https://faceplugin.com") {
            UIApplication.shared.open(url)
        }
    }
}
