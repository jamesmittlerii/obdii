/**
 * Port of OnboardingScreen.kt / onboarding_overlay.dart — intro scrim and bottom-nav highlight.
 */

import SwiftUI

struct OnboardingContentScrim: View {
  let pageIndex: Int
  let onPageIndexChange: (Int) -> Void
  let onComplete: (Bool) -> Void

  private static let cardBackground = Color(red: 246 / 255, green: 247 / 255, blue: 251 / 255)
  private static let cardBorder = Color(red: 23 / 255, green: 32 / 255, blue: 51 / 255).opacity(0.1)
  private static let navGap: CGFloat = 12

  var body: some View {
    let page = OnboardingScreenModel.pages[pageIndex]
    let compact = OnboardingScreenModel.usesCompactScrim(pageIndex)

    GeometryReader { proxy in
      let bottomInset = proxy.safeAreaInsets.bottom + 49 + Self.navGap

      ZStack(alignment: .bottom) {
        if compact {
          VStack(spacing: 0) {
            Color.black.opacity(0.2)
              .frame(height: proxy.size.height * 0.42)
            Spacer(minLength: 0)
          }
        } else {
          Color.black.opacity(0.52)
        }

        VStack(spacing: 0) {
          HStack {
            Spacer()
            Button("Skip") { onComplete(false) }
              .foregroundStyle(compact ? Color.primary : Color.white)
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)

          Spacer(minLength: 0)

          ScrollView {
            onboardingCard(page: page)
              .padding(.horizontal, 20)
          }
          .frame(maxHeight: max(0, proxy.size.height - bottomInset - 56))
        }
        .padding(.bottom, bottomInset)
      }
      .ignoresSafeArea()
    }
  }

  @ViewBuilder
  private func onboardingCard(page: OnboardingPage) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(page.title)
        .font(.title2)
        .fontWeight(.semibold)

      Text(page.body)
        .font(.body)
        .padding(.top, 10)

      onboardingPageHints

      if OnboardingScreenModel.showWelcomeSummary(pageIndex) {
        onboardingWelcomeSummary
          .padding(.top, 14)
      }

      onboardingPageIndicators
        .padding(.top, 16)

      onboardingActions
        .padding(.top, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Self.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Self.cardBorder, lineWidth: 1)
        )
    )
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var onboardingPageHints: some View {
    switch OnboardingScreenModel.pages[pageIndex].kind {
    case .tabTour:
      if OnboardingScreenModel.isGaugesDashboardPage(pageIndex) {
        onboardingGaugesLayoutHint
          .padding(.top, 14)
      }
    case .gaugePicker:
      onboardingGaugePickerHint
        .padding(.top, 14)
    default:
      EmptyView()
    }
  }

  private var onboardingGaugesLayoutHint: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Ring vs list")
        .font(.subheadline)
        .fontWeight(.semibold)

      Picker("Ring vs list", selection: .constant(GaugesDisplayMode.gauges)) {
        ForEach(GaugesDisplayMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .disabled(true)

      OnboardingHintBullet("Gauges shows circular ring tiles; List shows compact rows.")
      OnboardingHintBullet("Drag a gauge on the dashboard to reorder in either view.")
    }
  }

  private var onboardingGaugePickerHint: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("On this screen")
        .font(.subheadline)
        .fontWeight(.semibold)

      OnboardingHintBullet("Use switches to enable or disable gauges.")
      OnboardingHintBullet("Drag rows under Enabled to set dashboard order.")
      OnboardingHintBullet("Search finds any PID in the library.")
    }
  }

  private var onboardingWelcomeSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("What you can do")
        .font(.subheadline)
        .fontWeight(.semibold)

      ForEach(OnboardingScreenModel.welcomeSummaryPoints, id: \.self) { point in
        OnboardingHintBullet(point)
      }
    }
  }

  private var onboardingPageIndicators: some View {
    HStack(spacing: 8) {
      ForEach(OnboardingScreenModel.pages.indices, id: \.self) { index in
        let selected = index == pageIndex
        Circle()
          .fill(selected ? Color.accentColor : Color.primary.opacity(0.25))
          .frame(width: selected ? 10 : 8, height: selected ? 10 : 8)
      }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var onboardingActions: some View {
    if OnboardingScreenModel.isDemoPage(pageIndex) {
      Button("Try Demo") { onComplete(true) }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)

      Button("Get started without Demo") { onComplete(false) }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    } else if !OnboardingScreenModel.isLastPage(pageIndex) {
      Button("Next") { onPageIndexChange(pageIndex + 1) }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }
  }
}

struct OnboardingNavHighlight: View {
  let highlightedIndex: Int?

  var body: some View {
    if let highlightedIndex {
      HStack(spacing: 4) {
        ForEach(0..<5, id: \.self) { index in
          Group {
            if index == highlightedIndex {
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 2.5)
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                )
            } else {
              Color.clear
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.horizontal, 2)
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
      .frame(height: 49)
      .allowsHitTesting(false)
    }
  }
}

private struct OnboardingHintBullet: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      Text("• ")
        .fontWeight(.bold)
      Text(text)
        .font(.subheadline)
    }
  }
}
