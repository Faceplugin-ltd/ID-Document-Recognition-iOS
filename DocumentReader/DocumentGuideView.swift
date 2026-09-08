import UIKit

/// Overlay for DocSDK.locateDocument corners (preview coordinates).
final class DocumentGuideView: UIView {
    private var detected: [CGPoint]?
    var locked: Bool = false {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = .clear
    }

    func clearDetection() {
        detected = nil
        setNeedsDisplay()
    }

    func setDetectedCorners(_ corners: [CGPoint]?) {
        if let corners, corners.count >= 4, isUsable(corners) {
            detected = Array(corners.prefix(4))
        } else {
            detected = nil
        }
        setNeedsDisplay()
    }

    private func isUsable(_ corners: [CGPoint]) -> Bool {
        ResultParser.isPlausibleCardQuad(corners)
    }

    override func draw(_ rect: CGRect) {
        guard let corners = detected, corners.count >= 4,
              let ctx = UIGraphicsGetCurrentContext() else { return }
        let path = UIBezierPath()
        path.move(to: corners[0])
        for p in corners.dropFirst() { path.addLine(to: p) }
        path.close()

        FPColor.overlay.setFill()
        ctx.fill(bounds)
        ctx.setBlendMode(.clear)
        path.fill()
        ctx.setBlendMode(.normal)

        (locked ? FPColor.accent : FPColor.muted).setStroke()
        path.lineWidth = locked ? 8 : 5
        path.lineJoinStyle = .round
        path.stroke()
    }
}
