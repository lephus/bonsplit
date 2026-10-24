import AppKit

/// A title's text drawn as an alpha mask, laid out the way the title itself is.
///
/// The text wraps at words, the way a wrapping `NSTextField` lays it out, and the last allowed
/// line is cut at the tail with an ellipsis. With a limit of one line this cuts exactly where
/// SwiftUI cuts a one-line `Text`, so a tab title and its mask match pixel for pixel. The text
/// starts at the image's top-left corner with no padding. Only the alpha channel matters: the
/// text is drawn opaque whatever its own color.
struct TitleEffectTextMask: Equatable {
    /// The text with its fonts.
    let text: NSAttributedString

    /// The line limit: `1` for one line, more to wrap, `0` or less for no limit.
    let maximumNumberOfLines: Int

    /// Draws the mask at `size` points and `scale` pixels per point, or returns nil when there is nothing to draw.
    func image(size: CGSize, scale: CGFloat) -> CGImage? {
        let pixelWidth = Int((size.width * scale).rounded(.up))
        let pixelHeight = Int((size.height * scale).rounded(.up))
        guard text.length > 0, pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        let layout = layOut(width: size.width)

        // Flipped, in points, so TextKit draws its first line from the top-left corner.
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        layout.layoutManager.drawGlyphs(forGlyphRange: layout.layoutManager.glyphRange(for: layout.container), at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    /// The width, in points, of the text as the mask draws it `width` points wide: its widest line,
    /// with the ellipsis when the text is cut.
    func textWidth(width: CGFloat) -> CGFloat {
        guard text.length > 0, width > 0 else { return 0 }
        let layout = layOut(width: width)
        return layout.layoutManager.usedRect(for: layout.container).width
    }

    /// The text laid out `width` points wide, as the mask draws it. The storage owns the layout
    /// manager, so it is returned to keep the layout alive.
    private func layOut(width: CGFloat) -> (storage: NSTextStorage, layoutManager: NSLayoutManager, container: NSTextContainer) {
        let storage = NSTextStorage(attributedString: maskString())
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = max(0, maximumNumberOfLines)
        container.lineBreakMode = .byTruncatingTail
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        return (storage, layoutManager, container)
    }

    /// The text in opaque white, every paragraph wrapping at words so that the line limit alone
    /// decides where the text stops. A paragraph that truncates on its own cuts a few points
    /// earlier than SwiftUI does.
    private func maskString() -> NSAttributedString {
        let mask = NSMutableAttributedString(attributedString: text)
        let range = NSRange(location: 0, length: mask.length)
        mask.addAttribute(.foregroundColor, value: NSColor.white, range: range)
        mask.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let paragraph = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            mask.addAttribute(.paragraphStyle, value: paragraph, range: subrange)
        }
        return mask
    }
}
