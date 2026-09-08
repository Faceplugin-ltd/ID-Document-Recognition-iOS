import ImageIO
import UIKit

extension UIImage {
    /// Decode-time downscale via ImageIO (Android Utils.getBitmap inSampleSize).
    /// Never loads a full HEIC/JPEG into RAM then redraws.
    static func loadForGallery(
        data: Data,
        maxWidth: CGFloat = 1920,
        maxHeight: CGFloat = 1080
    ) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)?.fixOrientation().scaled(maxEdge: max(maxWidth, maxHeight))
        }
        let maxPixel = Int(max(maxWidth, maxHeight))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)?.fixOrientation().scaled(maxEdge: CGFloat(maxPixel))
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    static func loadForGallery(
        url: URL,
        maxWidth: CGFloat = 1920,
        maxHeight: CGFloat = 1080
    ) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return loadForGallery(data: data, maxWidth: maxWidth, maxHeight: maxHeight)
    }

    func scaled(maxEdge: CGFloat) -> UIImage {
        let longest = max(size.width * scale, size.height * scale)
        guard longest > maxEdge, longest > 0 else {
            if scale == 1 { return self }
            return redrawn(size: CGSize(width: size.width * scale, height: size.height * scale))
        }
        let factor = maxEdge / longest
        let newSize = CGSize(
            width: max(1, (size.width * scale) * factor),
            height: max(1, (size.height * scale) * factor)
        )
        return redrawn(size: newSize)
    }

    /// Downscale gallery picks toward ~1920×1080 pixel size (Android Utils target).
    func scaledForGallery(maxWidth: CGFloat = 1920, maxHeight: CGFloat = 1080) -> UIImage {
        let pw = size.width * scale
        let ph = size.height * scale
        let sx = pw / maxWidth
        let sy = ph / maxHeight
        let factor = max(sx, sy)
        if factor <= 1 {
            return scale == 1 ? self : redrawn(size: CGSize(width: pw, height: ph))
        }
        return redrawn(size: CGSize(width: max(1, pw / factor), height: max(1, ph / factor)))
    }

    func fixOrientation() -> UIImage {
        if imageOrientation == .up && scale == 1 { return self }
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        return redrawn(size: pixelSize)
    }

    /// Always draw at scale 1 so point size == pixel size for DocSDK JPEG encode.
    private func redrawn(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
