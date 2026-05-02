import SwiftOBD2
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI ring gauge visualization component
 *
 * Renders a circular arc gauge showing current value with color-coded progress.
 * Displays value and units in center, with progress arc colored based on
 * typical/warning/danger ranges. Adapts to metric/imperial units automatically.
 * Used throughout the app for visualizing live PID data.
 */
import SwiftUI

struct RingGaugeView: View {
  let model: GaugesViewModel.RingDisplayData

  private let startAngle: Angle = .radians((5.0 / 6.0) * .pi)  // ~300° (8 o’clock)
  private let sweepAngle: Angle = .radians((4.0 / 3.0) * .pi)  // 240°
  private var endAngle: Angle { Angle(radians: startAngle.radians + sweepAngle.radians) }

  private let lineWidthRatio: CGFloat = 0.25
  private let tickCount: Int = 21
  private let tickLengthRatio: CGFloat = 0.10
  private let tickThickness: CGFloat = 2

  private enum SplitPart { case first, second }

  private func splitDisplayText(_ part: SplitPart) -> String {
    let s = model.displayText
    guard let idx = s.firstIndex(of: " ") else { return part == .first ? s : "" }

    let first = String(s[..<idx])
    let second = String(s[s.index(after: idx)...])

    if part == .second { return second }

    // Clean number formatting of the leading portion
    let nf = NumberFormatter()
    nf.numberStyle = .decimal

    if let number = nf.number(from: first) {
      let out = NumberFormatter()
      out.numberStyle = .decimal
      out.usesGroupingSeparator = false
      out.minimumFractionDigits = nf.minimumFractionDigits
      out.maximumFractionDigits = nf.maximumFractionDigits
      return out.string(from: number) ?? first
    }
    return first
  }

  private var displayFirstLine: String { splitDisplayText(.first) }
  private var displaySecondLine: String { splitDisplayText(.second) }

  var body: some View {
    GeometryReader { proxy in
      // Use width as the master dimension so we can crop height without shrinking
      let dim = proxy.size.width
      let lineWidth = max(4, dim * lineWidthRatio)

      ZStack {

        // Base Track
        ArcShape(start: startAngle, end: endAngle)
          .inset(by: lineWidth / 2)
          .stroke(
            Color(UIColor.systemGray3),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        // Uncomment to restore colored segments:
        // band(typicalBand, color: .green, lineWidth: lineWidth)
        // band(warnBand,    color: .yellow, lineWidth: lineWidth)
        // band(dangerBand,  color: .red, lineWidth: lineWidth)

        if let progress = model.progress {
          let progressEnd = Angle(
            radians: startAngle.radians + sweepAngle.radians * progress.clamped01
          )

          ArcShape(start: startAngle, end: progressEnd)
            .inset(by: lineWidth / 2)
            .stroke(
              model.progressColor,
              style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .animation(.easeInOut(duration: 0.35), value: progress)
        }

        VStack(spacing: 4) {
          Text(displayFirstLine)
            .font(.headline.monospacedDigit())
            .minimumScaleFactor(0.6)
            .lineLimit(1)

          Text(displaySecondLine)
            .font(.subheadline.monospacedDigit())
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
      }
      .frame(width: dim, height: dim)
      .position(x: proxy.frame(in: .local).midX, y: dim / 2)
    }
    .accessibilityLabel(model.accessibilityLabel)
    .accessibilityValue(model.accessibilityValue)
  }
}

private struct ArcShape: InsettableShape {
  var start: Angle
  var end: Angle
  var insetAmount: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = max(0, min(rect.width, rect.height) / 2 - insetAmount)

    var p = Path()
    p.addArc(
      center: center,
      radius: radius,
      startAngle: start,
      endAngle: end,
      clockwise: false)
    return p
  }

  func inset(by amount: CGFloat) -> ArcShape {
    var c = self
    c.insetAmount += amount
    return c
  }
}

extension Double {
  fileprivate var clamped01: Double { max(0, min(1, self)) }
}
