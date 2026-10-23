import AppKit

/// The colors of a ``TitleEffectStyle``, read from hex with the style's fallbacks and resolved for one appearance.
struct TitleEffectColors {
    /// Color of a working title.
    let workingBase: CGColor

    /// Color of the highlight that sweeps across a working title.
    let workingHighlight: CGColor

    /// Color of the glyph while working.
    let glyphWorking: CGColor

    /// Color of the flash at its peak.
    let flash: CGColor

    /// The readable highlight stops as a closed loop: it ends on its first color, and holds at least two colors.
    let highlightLoop: [CGColor]

    /// Resolves `style` under `appearance`, which only matters for the label color fallback.
    init(style: TitleEffectStyle, appearance: NSAppearance) {
        var base = CGColor(gray: 1, alpha: 1)
        appearance.performAsCurrentDrawingAppearance {
            base = (TabBarColors.nsColor(hex: style.workingBaseHex) ?? .labelColor).cgColor
        }
        workingBase = base
        workingHighlight = TabBarColors.nsColor(hex: style.workingHighlightHex)?.cgColor ?? base
        glyphWorking = TabBarColors.nsColor(hex: style.glyphWorkingHex)?.cgColor ?? base
        flash = TabBarColors.nsColor(hex: style.flashHex)?.cgColor ?? CGColor(gray: 0, alpha: 0)

        var loop = style.highlightStopHexes.compactMap { TabBarColors.nsColor(hex: $0)?.cgColor }
        if loop.isEmpty {
            loop = [base]
        }
        if let first = loop.first, loop.count == 1 || loop.last != first {
            loop.append(first)
        }
        highlightLoop = loop
    }

    /// The gradient a highlighted title shows: the loop twice in a row, so it can slide one loop and start over seamlessly.
    var highlightGradient: [CGColor] {
        highlightLoop + highlightLoop.dropFirst()
    }

    /// The color of each glyph frame: the working color, or the loop's colors in turn while highlighted.
    func glyphFrameColors(for kind: TabActivity.Kind, frameCount: Int) -> [CGColor] {
        switch kind {
        case .working:
            return Array(repeating: glyphWorking, count: frameCount)
        case .highlight:
            // The loop repeats its first color at the end; that copy is not a frame of its own.
            let distinct = Array(highlightLoop.dropLast())
            return (0..<frameCount).map { distinct[$0 % distinct.count] }
        }
    }
}
