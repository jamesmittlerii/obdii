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
  let pid: OBDPID
  let measurement: MeasurementResult?

  private let startAngle: Angle = .radians((5.0 / 6.0) * .pi)  // ~300° (8 o’clock)
  private let sweepAngle: Angle = .radians((4.0 / 3.0) * .pi)  // 240°
  private var endAngle: Angle { Angle(radians: startAngle.radians + sweepAngle.radians) }

  private let lineWidthRatio: CGFloat = 0.25
  private let tickCount: Int = 21
  private let tickLengthRatio: CGFloat = 0.10
  private let tickThickness: CGFloat = 2

  private var colorUnitSystem: MeasurementUnit {
    if let m = measurement { return measurementUnit(from: m.unit) }
    return ConfigData.shared.units
  }

  private var combinedRange: ValueRange {
    let ranges = [pid.typicalRange, pid.warningRange, pid.dangerRange].compactMap { $0 }
    let fallback = pid.typicalRange ?? ValueRange(min: 0, max: 1)

    let metricMin = ranges.map(\.min).min() ?? fallback.min
    let metricMax = ranges.map(\.max).max() ?? fallback.max
    var combined = ValueRange(min: metricMin, max: metricMax)

    // Convert only if the PID defines explicit units
    if let units = pid.units, measurement != nil {
      combined = combined.converted(from: units, to: colorUnitSystem)
    }
    return combined
  }

  private var typicalBand: ValueRange? { pid.typicalRange(for: colorUnitSystem) }
  private var warnBand: ValueRange? { pid.warningRange(for: colorUnitSystem) }
  private var dangerBand: ValueRange? { pid.dangerRange(for: colorUnitSystem) }

  private var value: Double? { measurement?.value }

  private var displayText: String {
    measurement.map { pid.formatted(measurement: $0, includeUnits: true) }
      ?? "— \(pid.unitLabel(for: colorUnitSystem))"
  }

  private enum SplitPart { case first, second }

  private func splitDisplayText(_ part: SplitPart) -> String {
    let s = displayText
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
      let dim = min(proxy.size.width, proxy.size.height)
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

        if let v = value {
          let normalized = combinedRange.normalizedPosition(for: v).clamped01
          let progressEnd = Angle(
            radians: startAngle.radians + sweepAngle.radians * normalized
          )

          ArcShape(start: startAngle, end: progressEnd)
            .inset(by: lineWidth / 2)
            .stroke(
              progressColor(for: v),
              style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .animation(.easeInOut(duration: 0.35), value: v)
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
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .accessibilityLabel(pid.name)
    .accessibilityValue(displayText)
  }

  private func measurementUnit(from unit: Unit) -> MeasurementUnit {
    switch unit {
    case is UnitTemperature:
      return unit == UnitTemperature.fahrenheit ? .imperial : .metric
    case is UnitSpeed:
      return unit == UnitSpeed.milesPerHour ? .imperial : .metric
    case is UnitPressure:
      return unit == UnitPressure.poundsForcePerSquareInch ? .imperial : .metric
    case is UnitLength:
      return unit == UnitLength.miles ? .imperial : .metric
    default:
      return .metric
    }
  }

  private func band(_ range: ValueRange?, color: Color, lineWidth: CGFloat) -> some View {
    guard let r = range else { return AnyView(EmptyView()) }

    let start = angle(for: r.min, in: combinedRange)
    let end = angle(for: r.max, in: combinedRange)

    return AnyView(
      ArcShape(start: start, end: end)
        .inset(by: lineWidth / 2)
        .stroke(
          color.opacity(0.25),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    )
  }

  private func angle(for value: Double, in range: ValueRange) -> Angle {
    let n = range.normalizedPosition(for: value).clamped01
    return Angle(radians: startAngle.radians + sweepAngle.radians * n)
  }

  private func progressColor(for value: Double) -> Color {
    pid.color(for: value, unit: colorUnitSystem)
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
