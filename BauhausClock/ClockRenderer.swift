import AppKit
import CoreGraphics
import CoreText

// MARK: - Clock Renderer (Pure Core Graphics)

final class ClockRenderer {
    // MARK: - Hand Geometry

    /// Creates a leaf/lozenge hand path (pointed tip, wider middle, tapered base)
    static func leafHandPath(tipY: CGFloat, maxW: CGFloat, tailY: CGFloat, tailW: CGFloat) -> CGPath {
        let hw = maxW / 2
        let tw = tailW / 2
        let bulge = tipY + (tailY - tipY) * 0.38

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: tipY))
        // Right side
        path.addCurve(to: CGPoint(x: hw, y: bulge),
                      control1: CGPoint(x: hw * 0.3, y: tipY + 4),
                      control2: CGPoint(x: hw, y: bulge - 18))
        path.addCurve(to: CGPoint(x: tw, y: tailY),
                      control1: CGPoint(x: hw, y: bulge + 14),
                      control2: CGPoint(x: tw + 1, y: tailY - 8))
        // Bottom
        path.addLine(to: CGPoint(x: -tw, y: tailY))
        // Left side
        path.addCurve(to: CGPoint(x: -hw, y: bulge),
                      control1: CGPoint(x: -tw - 1, y: tailY - 8),
                      control2: CGPoint(x: -hw, y: bulge + 14))
        path.addCurve(to: CGPoint(x: 0, y: tipY),
                      control1: CGPoint(x: -hw, y: bulge - 18),
                      control2: CGPoint(x: -hw * 0.3, y: tipY + 4))
        path.closeSubpath()
        return path
    }

    // MARK: - Polar Helper

    static func polar(cx: CGFloat, cy: CGFloat, angleDeg: CGFloat, radius: CGFloat) -> CGPoint {
        let rad = (angleDeg - 90) * .pi / 180
        return CGPoint(x: cx + cos(rad) * radius, y: cy + sin(rad) * radius)
    }

    // MARK: - Metallic Gradient

    static func drawMetallicFill(_ ctx: CGContext, path: CGPath, pal: ClockPalette, bounds: CGRect) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        let colors = [pal.metalEdge.cgC, pal.metalMid.cgC, pal.metalHi.cgC,
                      pal.metalHi.cgC, pal.metalMid.cgC, pal.metalEdge.cgC] as CFArray
        let locs: [CGFloat] = [0, 0.20, 0.48, 0.52, 0.80, 1.0]

        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            ctx.drawLinearGradient(gradient,
                                  start: CGPoint(x: bounds.minX, y: bounds.midY),
                                  end: CGPoint(x: bounds.maxX, y: bounds.midY),
                                  options: [])
        }
        ctx.restoreGState()
    }

    // MARK: - Main Draw

    static func draw(in ctx: CGContext, size: CGSize, pal: ClockPalette, now: Date,
                     clockSize: String, showSeconds: Bool, night: Bool,
                     movement: String = "Mechanical") {

        let sz: CGFloat = clockSize == "Compact" ? 360 : 480
        let scale = min(size.width, size.height) / sz
        let cx = size.width / 2
        let cy = size.height / 2
        let fR = sz * 0.45 * scale

        // ── Background ──
        ctx.setFillColor(pal.bg.cgC)
        ctx.fill(CGRect(origin: .zero, size: size))

        // ── Grain Texture ──
        drawGrain(ctx, size: size, pal: pal)

        let cal = Calendar.current
        let h = CGFloat(cal.component(.hour, from: now) % 12)
        let m = CGFloat(cal.component(.minute, from: now))
        let s = CGFloat(cal.component(.second, from: now))
        let ms = CGFloat(cal.component(.nanosecond, from: now)) / 1_000_000

        let sFrac = s + ms / 1000

        // Second hand angle depends on movement type
        let secA: CGFloat
        switch movement {
        case "Quartz":
            secA = s * 6                              // discrete 1Hz tick
        case "Digital":
            secA = sFrac * 6                          // fully smooth
        default: // Mechanical — 8 steps/sec (28,800 bph)
            let totalMs = s * 1000 + ms
            secA = floor(totalMs / 125) * 0.75
        }

        let minA  = m * 6 + sFrac * 0.1
        let hourA = h * 30 + m * 0.5 + sFrac * (0.5 / 60)

        // ── Minute Ticks ──
        drawMinuteTicks(ctx, cx: cx, cy: cy, fR: fR, pal: pal, night: night)

        // ── Hour Indices ──
        drawHourIndices(ctx, cx: cx, cy: cy, fR: fR, pal: pal, night: night, scale: scale)

        // ── Minute Numerals (outer ring: 60, 05, 10 … 55) ──
        drawMinuteNumerals(ctx, cx: cx, cy: cy, fR: fR, sz: sz * scale, pal: pal, night: night)

        // ── Numerals ──
        drawNumerals(ctx, cx: cx, cy: cy, fR: fR, sz: sz * scale, pal: pal, night: night)

        // ── Hour Hand ──
        let hourPath = leafHandPath(tipY: -fR * 0.50, maxW: 10.5 * scale, tailY: fR * 0.10, tailW: 4 * scale)
        drawHand(ctx, path: hourPath, angle: hourA, cx: cx, cy: cy, pal: pal, night: night,
                 shadowDx: 1.5, shadowDy: 3, shadowBlur: 6, scale: scale,
                 highlightFrom: -fR * 0.48, highlightTo: fR * 0.06, highlightWidth: 1 * scale)

        // ── Minute Hand ──
        let minPath = leafHandPath(tipY: -fR * 0.76, maxW: 8 * scale, tailY: fR * 0.13, tailW: 3 * scale)
        drawHand(ctx, path: minPath, angle: minA, cx: cx, cy: cy, pal: pal, night: night,
                 shadowDx: 1.5, shadowDy: 3, shadowBlur: 6, scale: scale,
                 highlightFrom: -fR * 0.74, highlightTo: fR * 0.09, highlightWidth: 0.8 * scale)

        // ── Second Hand ──
        if showSeconds {
            drawSecondHand(ctx, angle: secA, cx: cx, cy: cy, fR: fR, pal: pal, night: night, scale: scale)
        }

        // ── Center Hub ──
        drawCenterHub(ctx, cx: cx, cy: cy, pal: pal, night: night, scale: scale)
    }

    // MARK: - Minute Ticks

    static func drawMinuteTicks(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, fR: CGFloat,
                                pal: ClockPalette, night: Bool) {
        ctx.saveGState()
        ctx.setStrokeColor(pal.idx.cgC)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.setAlpha(night ? 0.15 : 0.5)

        for i in 0..<60 {
            if i % 5 == 0 { continue }
            let a = CGFloat(i) * 6
            let p1 = polar(cx: cx, cy: cy, angleDeg: a, radius: fR * 0.84)
            let p2 = polar(cx: cx, cy: cy, angleDeg: a, radius: fR * 0.89)
            ctx.move(to: p1)
            ctx.addLine(to: p2)
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Hour Indices (Capsule)

    static func drawHourIndices(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, fR: CGFloat,
                                pal: ClockPalette, night: Bool, scale: CGFloat) {
        let len = fR * 0.085
        let w: CGFloat = 4.5 * scale

        for i in 0..<12 {
            let a = CGFloat(i) * 30
            let ctr = polar(cx: cx, cy: cy, angleDeg: a, radius: fR * 0.80)
            let rad = (a) * .pi / 180

            ctx.saveGState()
            ctx.translateBy(x: ctr.x, y: ctr.y)
            ctx.rotate(by: rad)

            // Shadow (positive height = down in flipped coords)
            if !night {
                ctx.setShadow(offset: CGSize(width: 0.5, height: 1.0), blur: 1.6,
                              color: NSColor.black.withAlphaComponent(0.22).cgColor)
            } else {
                // Night glow
                if let glow = pal.glow {
                    ctx.setShadow(offset: .zero, blur: 3 * scale, color: glow.withAlphaComponent(0.6).cgColor)
                }
            }

            // Border rect
            let borderRect = CGRect(x: -w, y: -len, width: w * 2, height: len * 2)
            let borderPath = CGPath(roundedRect: borderRect, cornerWidth: w, cornerHeight: w, transform: nil)
            ctx.setFillColor(pal.border.cgC)
            ctx.addPath(borderPath)
            ctx.fillPath()

            // Inner metallic fill
            ctx.setShadow(offset: .zero, blur: 0)
            let inset: CGFloat = 1.2 * scale
            let innerRect = CGRect(x: -w + inset, y: -len + inset, width: (w - inset) * 2, height: (len - inset) * 2)
            let innerPath = CGPath(roundedRect: innerRect, cornerWidth: w - inset, cornerHeight: w - inset, transform: nil)
            drawMetallicFill(ctx, path: innerPath, pal: pal, bounds: innerRect)

            ctx.restoreGState()
        }
    }

    // MARK: - Numerals

    static func drawNumerals(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, fR: CGFloat,
                             sz: CGFloat, pal: ClockPalette, night: Bool) {
        let fontSize = sz * 0.046
        let color = night ? (pal.glow ?? pal.num) : pal.num

        // Load Jost or fallback to system font
        let fontName = "Jost-Regular"
        let font: CTFont
        if let f = CTFontCreateWithName(fontName as CFString, fontSize, nil) as CTFont? {
            font = f
        } else {
            font = CTFontCreateWithName("HelveticaNeue" as CFString, fontSize, nil)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        for i in 0..<12 {
            let n = i == 0 ? 12 : i
            let a = CGFloat(i) * 30
            let np = polar(cx: cx, cy: cy, angleDeg: a, radius: fR * 0.65)

            let str = NSAttributedString(string: "\(n)", attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

            ctx.saveGState()

            if night, let glow = pal.glow {
                ctx.setShadow(offset: .zero, blur: 3, color: glow.withAlphaComponent(0.6).cgColor)
            }

            // CTLine draws with CG's native Y-up, so flip locally for text
            ctx.saveGState()
            ctx.translateBy(x: np.x, y: np.y)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: -bounds.width / 2 - bounds.origin.x,
                                       y: -bounds.height / 2 - bounds.origin.y)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
            ctx.restoreGState()
        }
    }

    // MARK: - Minute Numerals (outer rotated ring)

    static func drawMinuteNumerals(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, fR: CGFloat,
                                   sz: CGFloat, pal: ClockPalette, night: Bool) {
        let fontSize = sz * 0.034
        let base = night ? (pal.glow ?? pal.num) : pal.num
        let color = base.withAlphaComponent(night ? 0.45 : 0.6)

        let fontName = "Jost-Medium"
        let font: CTFont = (CTFontCreateWithName(fontName as CFString, fontSize, nil) as CTFont?)
            ?? CTFontCreateWithName("HelveticaNeue-Medium" as CFString, fontSize, nil)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        let radius = fR * 0.99
        for i in stride(from: 0, to: 60, by: 5) {
            let label = i == 0 ? "60" : String(format: "%02d", i)
            let a = CGFloat(i) * 6
            let rad = a * .pi / 180
            let np = polar(cx: cx, cy: cy, angleDeg: a, radius: radius)

            let str = NSAttributedString(string: label, attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

            ctx.saveGState()
            if night, let glow = pal.glow {
                ctx.setShadow(offset: .zero, blur: 3, color: glow.withAlphaComponent(0.4).cgColor)
            }
            // Rotate tangentially: "60" upright at top, numbers fan around the rim.
            // Flip the bottom half (minutes 20–40) so they stay upright like the
            // original ("30" reads right-way-up, not upside down).
            ctx.translateBy(x: np.x, y: np.y)
            var rot = rad
            if a > 90, a < 270 { rot -= .pi }
            ctx.rotate(by: rot)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: -bounds.width / 2 - bounds.origin.x,
                                       y: -bounds.height / 2 - bounds.origin.y)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
    }

    // MARK: - Hand Drawing

    static func drawHand(_ ctx: CGContext, path: CGPath, angle: CGFloat,
                         cx: CGFloat, cy: CGFloat, pal: ClockPalette, night: Bool,
                         shadowDx: CGFloat, shadowDy: CGFloat, shadowBlur: CGFloat,
                         scale: CGFloat,
                         highlightFrom: CGFloat, highlightTo: CGFloat, highlightWidth: CGFloat) {
        let rad = angle * .pi / 180

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        // Core Graphics Y is flipped vs SVG — rotate clockwise
        ctx.rotate(by: rad)

        // Shadow / glow
        if night {
            if let glow = pal.glow {
                ctx.setShadow(offset: .zero, blur: 6 * scale, color: glow.withAlphaComponent(0.6).cgColor)
            }
        } else {
            ctx.setShadow(offset: CGSize(width: shadowDx, height: shadowDy), blur: shadowBlur,
                          color: NSColor.black.withAlphaComponent(0.35).cgColor)
        }

        // Border (scaled up by 1.12)
        ctx.saveGState()
        ctx.scaleBy(x: 1.12, y: 1.12)
        ctx.setFillColor(pal.border.cgC)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()

        // Metallic fill
        ctx.setShadow(offset: .zero, blur: 0)
        let pathBounds = path.boundingBox
        drawMetallicFill(ctx, path: path, pal: pal, bounds: pathBounds)

        // Center highlight line
        ctx.setStrokeColor(pal.metalHi.withAlphaComponent(0.5).cgC)
        ctx.setLineWidth(highlightWidth)
        ctx.move(to: CGPoint(x: 0, y: highlightFrom))
        ctx.addLine(to: CGPoint(x: 0, y: highlightTo))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Second Hand

    static func drawSecondHand(_ ctx: CGContext, angle: CGFloat, cx: CGFloat, cy: CGFloat,
                               fR: CGFloat, pal: ClockPalette, night: Bool, scale: CGFloat) {
        let rad = angle * .pi / 180

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: rad)

        if night {
            if let glow = pal.glow {
                ctx.setShadow(offset: .zero, blur: 3 * scale, color: glow.withAlphaComponent(0.6).cgColor)
            }
        } else {
            ctx.setShadow(offset: CGSize(width: 0.6, height: 2), blur: 3.6,
                          color: NSColor.black.withAlphaComponent(0.25).cgColor)
        }

        ctx.setStrokeColor(pal.sec.cgC)
        ctx.setFillColor(pal.sec.cgC)

        // Tail portion
        ctx.setLineWidth(1.6 * scale)
        ctx.move(to: CGPoint(x: 0, y: fR * 0.22))
        ctx.addLine(to: CGPoint(x: 0, y: 0))
        ctx.strokePath()

        // Counterweight circle
        ctx.fillEllipse(in: CGRect(x: -3.5 * scale, y: fR * 0.17 - 3.5 * scale,
                                   width: 7 * scale, height: 7 * scale))

        // Main needle
        ctx.setLineWidth(1 * scale)
        ctx.move(to: CGPoint(x: 0, y: 0))
        ctx.addLine(to: CGPoint(x: 0, y: -fR * 0.88))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Center Hub

    static func drawCenterHub(_ ctx: CGContext, cx: CGFloat, cy: CGFloat,
                              pal: ClockPalette, night: Bool, scale: CGFloat) {
        ctx.saveGState()

        if night {
            if let glow = pal.glow {
                ctx.setShadow(offset: .zero, blur: 3 * scale, color: glow.withAlphaComponent(0.6).cgColor)
            }
        } else {
            ctx.setShadow(offset: CGSize(width: 0.8, height: 1.5), blur: 2.4,
                          color: NSColor.black.withAlphaComponent(0.3).cgColor)
        }

        let rings: [(CGFloat, NSColor)] = [
            (8 * scale, pal.capOuter),
            (6 * scale, pal.capMid),
            (4.5 * scale, pal.capInner),
            (2.5 * scale, pal.metalHi),
            (1 * scale, pal.capOuter),
        ]

        for (r, color) in rings {
            ctx.setFillColor(color.cgC)
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }

        ctx.restoreGState()
    }

    // MARK: - Grain Texture

    // Cached grain bitmap — the noise is static, so generate it once per size
    // instead of filling hundreds of thousands of 3×3 rects every frame.
    private static var grainCache: (w: Int, h: Int, image: CGImage)?

    static func drawGrain(_ ctx: CGContext, size: CGSize, pal: ClockPalette) {
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())
        guard w > 0, h > 0 else { return }

        let image: CGImage
        if let c = grainCache, c.w == w, c.h == h {
            image = c.image
        } else if let img = makeGrainImage(width: w, height: h) {
            image = img
            grainCache = (w, h, img)
        } else {
            return
        }

        ctx.saveGState()
        ctx.setBlendMode(.softLight)
        ctx.setAlpha(0.08)
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        ctx.restoreGState()
    }

    /// Builds the deterministic grain as a grayscale bitmap (same pattern as before:
    /// pre-seeded LCG noise in 3×3 blocks, column-major).
    private static func makeGrainImage(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        defer { buffer.deallocate() }

        let step = 3
        var seed: UInt32 = 7
        var x = 0
        while x < width {
            var y = 0
            while y < height {
                seed = seed &* 1103515245 &+ 12345
                let val = UInt8((seed >> 16) & 0xFF)
                let xEnd = min(x + step, width)
                let yEnd = min(y + step, height)
                var yy = y
                while yy < yEnd {
                    let row = yy * bytesPerRow
                    var xx = x
                    while xx < xEnd {
                        buffer[row + xx] = val
                        xx += 1
                    }
                    yy += 1
                }
                y += step
            }
            x += step
        }

        guard let bctx = CGContext(data: buffer, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        return bctx.makeImage()
    }
}
