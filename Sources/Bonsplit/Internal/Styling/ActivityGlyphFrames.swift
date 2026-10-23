import AppKit
import CoreText

/// The activity glyph's frames, `· ✢ ✳ ✶ ✻ ✽`, drawn as images with each glyph centered on its ink.
struct ActivityGlyphFrames {
    /// The glyphs in the order they cycle, as Claude Code cycles them.
    static let glyphs = ["\u{00B7}", "\u{2722}", "\u{2733}", "\u{2736}", "\u{273B}", "\u{273D}"]

    /// The frame a still glyph rests on: ✻.
    static let stillFrameIndex = 4

    /// Point size of the glyph font.
    let pointSize: CGFloat

    /// Draws one square image per glyph, frame `i` in `colors[i]`, at `scale` pixels per point.
    func images(colors: [CGColor], scale: CGFloat) -> [CGImage] {
        guard colors.count == Self.glyphs.count, pointSize > 0, scale > 0 else { return [] }
        let side = (pointSize * 1.25).rounded(.up)
        let font = NSFont.systemFont(ofSize: pointSize)
        return zip(Self.glyphs, colors).compactMap { glyph, color in
            image(of: glyph, font: font, color: color, side: side, scale: scale)
        }
    }

    private func image(of glyph: String, font: NSFont, color: CGColor, side: CGFloat, scale: CGFloat) -> CGImage? {
        let pixels = Int((side * scale).rounded(.up))
        // sRGB, like the title colors: a device RGB image is not color matched and drifts on wide-gamut displays.
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: pixels,
                  height: pixels,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: attributes))
        let ink = CTLineGetImageBounds(line, context)
        context.textPosition = CGPoint(x: side / 2 - ink.midX, y: side / 2 - ink.midY)
        CTLineDraw(line, context)
        return context.makeImage()
    }
}
