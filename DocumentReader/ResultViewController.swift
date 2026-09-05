import UIKit

/// Shows DocSDK.recognize JSON — same tabs / Result layout as Android ResultActivity.
final class ResultViewController: UIViewController {
    private let json: String
    private let summaryLabel = UILabel()
    private let fieldsStack = UIStackView()
    private let securitySummaryLabel = UILabel()
    private let securityStack = UIStackView()
    private let imagesStack = UIStackView()
    private let rawTextView = UITextView()
    private let scrollResult = UIScrollView()
    private let scrollSecurity = UIScrollView()
    private let scrollImages = UIScrollView()
    private let tabs = UISegmentedControl(items: ["Result", "Security", "Images", "Raw JSON"])

    /// Match Android item_field_row: weight 1 / 1.4 / fixed 64dp.
    private let sourceWidth: CGFloat = 64
    private let keyWeight: CGFloat = 1
    private let valueWeight: CGFloat = 1.4

    init(json: String) {
        self.json = json
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FPColor.bg
        title = "Result"
        applyNavAppearance()

        tabs.selectedSegmentIndex = 0
        tabs.selectedSegmentTintColor = FPColor.accent
        tabs.setTitleTextAttributes([.foregroundColor: FPColor.text], for: .normal)
        tabs.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        tabs.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabs)

        summaryLabel.text = ResultParser.summary(json)
        summaryLabel.textColor = FPColor.text
        summaryLabel.font = .systemFont(ofSize: 15)
        summaryLabel.numberOfLines = 0
        summaryLabel.isUserInteractionEnabled = true

        fieldsStack.axis = .vertical
        fieldsStack.spacing = 0
        fieldsStack.addArrangedSubview(fieldHeader())
        for row in ResultParser.rows(json) {
            fieldsStack.addArrangedSubview(fieldRow(row))
        }

        let resultCol = UIStackView(arrangedSubviews: [summaryLabel, fieldsStack])
        resultCol.axis = .vertical
        resultCol.spacing = 16
        resultCol.translatesAutoresizingMaskIntoConstraints = false
        scrollResult.addSubview(resultCol)
        scrollResult.translatesAutoresizingMaskIntoConstraints = false
        scrollResult.alwaysBounceVertical = true
        view.addSubview(scrollResult)

        securitySummaryLabel.text = ResultParser.securitySummary(json)
        securitySummaryLabel.textColor = FPColor.text
        securitySummaryLabel.font = .systemFont(ofSize: 15)
        securitySummaryLabel.numberOfLines = 0

        securityStack.axis = .vertical
        securityStack.spacing = 0
        securityStack.addArrangedSubview(securityHeader())
        let secRows = ResultParser.securityRows(json)
        if secRows.isEmpty {
            let empty = UILabel()
            empty.text = "No security checks in this response"
            empty.textColor = FPColor.muted
            empty.font = .systemFont(ofSize: 14)
            securityStack.addArrangedSubview(empty)
        } else {
            for row in secRows {
                securityStack.addArrangedSubview(securityRow(row))
            }
        }
        let securityCol = UIStackView(arrangedSubviews: [securitySummaryLabel, securityStack])
        securityCol.axis = .vertical
        securityCol.spacing = 16
        securityCol.translatesAutoresizingMaskIntoConstraints = false
        scrollSecurity.addSubview(securityCol)
        scrollSecurity.translatesAutoresizingMaskIntoConstraints = false
        scrollSecurity.alwaysBounceVertical = true
        scrollSecurity.isHidden = true
        view.addSubview(scrollSecurity)

        imagesStack.axis = .vertical
        imagesStack.spacing = 12
        populateImages()
        imagesStack.translatesAutoresizingMaskIntoConstraints = false
        scrollImages.addSubview(imagesStack)
        scrollImages.translatesAutoresizingMaskIntoConstraints = false
        scrollImages.alwaysBounceVertical = true
        scrollImages.isHidden = true
        view.addSubview(scrollImages)

        // Raw JSON scrolls itself (Android TextView-in-ScrollView equivalent without nested clip).
        rawTextView.text = ResultParser.pretty(json)
        rawTextView.textColor = FPColor.text
        rawTextView.backgroundColor = .clear
        rawTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        rawTextView.isEditable = false
        rawTextView.isSelectable = true
        rawTextView.isScrollEnabled = true
        rawTextView.alwaysBounceVertical = true
        rawTextView.showsVerticalScrollIndicator = true
        rawTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        rawTextView.textContainer.lineFragmentPadding = 0
        rawTextView.translatesAutoresizingMaskIntoConstraints = false
        rawTextView.isHidden = true
        view.addSubview(rawTextView)

        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tabs.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollResult.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 8),
            scrollResult.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollResult.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollResult.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            resultCol.topAnchor.constraint(equalTo: scrollResult.contentLayoutGuide.topAnchor, constant: 16),
            resultCol.leadingAnchor.constraint(equalTo: scrollResult.frameLayoutGuide.leadingAnchor, constant: 16),
            resultCol.trailingAnchor.constraint(equalTo: scrollResult.frameLayoutGuide.trailingAnchor, constant: -16),
            resultCol.bottomAnchor.constraint(equalTo: scrollResult.contentLayoutGuide.bottomAnchor, constant: -16),
            resultCol.widthAnchor.constraint(equalTo: scrollResult.frameLayoutGuide.widthAnchor, constant: -32),

            scrollSecurity.topAnchor.constraint(equalTo: scrollResult.topAnchor),
            scrollSecurity.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollSecurity.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollSecurity.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            securityCol.topAnchor.constraint(equalTo: scrollSecurity.contentLayoutGuide.topAnchor, constant: 16),
            securityCol.leadingAnchor.constraint(equalTo: scrollSecurity.frameLayoutGuide.leadingAnchor, constant: 16),
            securityCol.trailingAnchor.constraint(equalTo: scrollSecurity.frameLayoutGuide.trailingAnchor, constant: -16),
            securityCol.bottomAnchor.constraint(equalTo: scrollSecurity.contentLayoutGuide.bottomAnchor, constant: -16),
            securityCol.widthAnchor.constraint(equalTo: scrollSecurity.frameLayoutGuide.widthAnchor, constant: -32),

            scrollImages.topAnchor.constraint(equalTo: scrollResult.topAnchor),
            scrollImages.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollImages.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollImages.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imagesStack.topAnchor.constraint(equalTo: scrollImages.contentLayoutGuide.topAnchor, constant: 16),
            imagesStack.leadingAnchor.constraint(equalTo: scrollImages.frameLayoutGuide.leadingAnchor, constant: 16),
            imagesStack.trailingAnchor.constraint(equalTo: scrollImages.frameLayoutGuide.trailingAnchor, constant: -16),
            imagesStack.bottomAnchor.constraint(equalTo: scrollImages.contentLayoutGuide.bottomAnchor, constant: -16),
            imagesStack.widthAnchor.constraint(equalTo: scrollImages.frameLayoutGuide.widthAnchor, constant: -32),

            rawTextView.topAnchor.constraint(equalTo: scrollResult.topAnchor),
            rawTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rawTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rawTextView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func applyNavAppearance() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = FPColor.bg
        appearance.titleTextAttributes = [.foregroundColor: FPColor.text]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = FPColor.accent
    }

    private func populateImages() {
        let imgs = ResultParser.images(json)
        if imgs.isEmpty {
            let empty = UILabel()
            empty.text = "No images in this response"
            empty.textColor = FPColor.muted
            empty.font = .systemFont(ofSize: 14)
            imagesStack.addArrangedSubview(empty)
            return
        }
        let grouped = Dictionary(grouping: imgs) { $0.category.isEmpty ? "Image" : $0.category }
        let order = imgs.map { $0.category.isEmpty ? "Image" : $0.category }
        var seen = Set<String>()
        let categories = order.filter { seen.insert($0).inserted }
        for category in categories {
            guard let items = grouped[category] else { continue }
            let header = UILabel()
            header.text = category
            header.textColor = FPColor.accent
            header.font = .systemFont(ofSize: 15, weight: .bold)
            imagesStack.addArrangedSubview(header)
            for item in items {
                if !item.source.isEmpty {
                    let src = UILabel()
                    src.text = item.source
                    src.textColor = FPColor.muted
                    src.font = .systemFont(ofSize: 12)
                    imagesStack.addArrangedSubview(src)
                }
                let iv = UIImageView(image: item.image)
                iv.contentMode = .scaleAspectFit
                iv.clipsToBounds = true
                iv.setContentHuggingPriority(.defaultHigh, for: .vertical)
                iv.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
                let img = item.image
                if img.size.width > 0 {
                    iv.heightAnchor.constraint(
                        equalTo: iv.widthAnchor,
                        multiplier: img.size.height / img.size.width
                    ).isActive = true
                } else {
                    iv.heightAnchor.constraint(equalToConstant: 200).isActive = true
                }
                imagesStack.addArrangedSubview(iv)
            }
        }
    }

    @objc private func tabChanged() {
        let i = tabs.selectedSegmentIndex
        scrollResult.isHidden = i != 0
        scrollSecurity.isHidden = i != 1
        scrollImages.isHidden = i != 2
        rawTextView.isHidden = i != 3
    }

    private func securityHeader() -> UIView {
        weightedRow(
            key: headerLabel("Page"),
            value: headerLabel("Check"),
            source: headerLabel("Status"),
            verticalPad: 6
        )
    }

    private func securityRow(_ row: SecurityRow) -> UIView {
        let page = UILabel()
        page.text = row.page
        page.textColor = FPColor.muted
        page.font = .systemFont(ofSize: 13)
        page.numberOfLines = 0

        let check = UILabel()
        check.text = row.check
        check.textColor = FPColor.text
        check.font = .systemFont(ofSize: 13)
        check.numberOfLines = 0

        let status = UILabel()
        status.text = row.status
        status.textColor = FPColor.accent
        status.font = .systemFont(ofSize: 13)
        status.numberOfLines = 0

        return weightedRow(key: page, value: check, source: status, verticalPad: 6)
    }

    private func fieldHeader() -> UIView {
        weightedRow(
            key: headerLabel("Field"),
            value: headerLabel("Value"),
            source: headerLabel("Source"),
            verticalPad: 6
        )
    }

    private func headerLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = FPColor.muted
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        return label
    }

    private func fieldRow(_ row: FieldRow) -> UIView {
        let key = UILabel()
        key.text = row.key
        key.textColor = FPColor.muted
        key.font = .systemFont(ofSize: 13)
        key.numberOfLines = 0

        let value = UILabel()
        value.text = row.value
        value.textColor = FPColor.text
        value.font = .systemFont(ofSize: 13)
        value.numberOfLines = 0
        value.isUserInteractionEnabled = true

        let src = UILabel()
        src.text = row.source
        src.textColor = FPColor.accent
        src.font = .systemFont(ofSize: 11)
        src.numberOfLines = 0

        return weightedRow(key: key, value: value, source: src, verticalPad: 6)
    }

    /// Android layout_weight 1 / 1.4 + fixed 64dp source column.
    private func weightedRow(key: UIView, value: UIView, source: UIView, verticalPad: CGFloat) -> UIView {
        // Must share a common ancestor before activating relative width constraints
        // (otherwise Auto Layout throws → SIGABRT when pushing Result).
        let stack = UIStackView(arrangedSubviews: [key, value, source])
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: verticalPad, left: 0, bottom: verticalPad, right: 0)

        source.setContentHuggingPriority(.required, for: .horizontal)
        source.setContentCompressionResistancePriority(.required, for: .horizontal)
        source.widthAnchor.constraint(equalToConstant: sourceWidth).isActive = true

        key.setContentHuggingPriority(.defaultLow, for: .horizontal)
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        key.widthAnchor.constraint(equalTo: value.widthAnchor, multiplier: keyWeight / valueWeight)
            .isActive = true

        return stack
    }
}
