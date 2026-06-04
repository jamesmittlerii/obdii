// Port of OnboardingScreen.kt — intro scrim and bottom-nav highlight.

import 'package:flutter/material.dart';

import '../screenmodels/onboarding_screen_model.dart';

typedef OnboardingCompleteCallback = void Function(bool startDemo);

class OnboardingContentScrim extends StatelessWidget {
  const OnboardingContentScrim({
    super.key,
    required this.pageIndex,
    required this.onPageIndexChange,
    required this.onComplete,
    /// Space reserved above the system inset so the card clears the tab bar.
    required this.bottomInset,
  });

  final int pageIndex;
  final ValueChanged<int> onPageIndexChange;
  final OnboardingCompleteCallback onComplete;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final page = OnboardingScreenModel.pages[pageIndex];
    final compact = OnboardingScreenModel.usesCompactScrim(pageIndex);
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!compact)
          ColoredBox(color: Colors.black.withValues(alpha: 0.52))
        else
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.42,
              widthFactor: 1,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onComplete(false),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: compact
                          ? theme.colorScheme.onSurface
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: SingleChildScrollView(
                          child: _OnboardingCard(
                            pageIndex: pageIndex,
                            page: page,
                            theme: theme,
                            onPageIndexChange: onPageIndexChange,
                            onComplete: onComplete,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.pageIndex,
    required this.page,
    required this.theme,
    required this.onPageIndexChange,
    required this.onComplete,
  });

  final int pageIndex;
  final OnboardingPage page;
  final ThemeData theme;
  final ValueChanged<int> onPageIndexChange;
  final OnboardingCompleteCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF6F7FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF172033).withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(page.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(page.body, style: theme.textTheme.bodyLarge),
            _OnboardingPageHints(pageIndex: pageIndex),
            if (OnboardingScreenModel.showWelcomeSummary(pageIndex)) ...[
              const SizedBox(height: 14),
              const _OnboardingWelcomeSummary(),
            ],
            const SizedBox(height: 16),
            _OnboardingPageIndicators(selectedIndex: pageIndex),
            const SizedBox(height: 16),
            _OnboardingActions(
              pageIndex: pageIndex,
              onPageIndexChange: onPageIndexChange,
              onComplete: onComplete,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingNavHighlight extends StatelessWidget {
  const OnboardingNavHighlight({super.key, required this.highlightedIndex});

  final int? highlightedIndex;

  static const _tabCount = 5;

  @override
  Widget build(BuildContext context) {
    if (highlightedIndex == null) return const SizedBox.shrink();

    final highlightColor = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: List.generate(_tabCount, (idx) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: idx == highlightedIndex
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: highlightColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: highlightColor, width: 2.5),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageHints extends StatelessWidget {
  const _OnboardingPageHints({required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final kind = OnboardingScreenModel.pages[pageIndex].kind;
    switch (kind) {
      case OnboardingPageKind.tabTour:
        if (OnboardingScreenModel.isGaugesDashboardPage(pageIndex)) {
          return const Padding(
            padding: EdgeInsets.only(top: 14),
            child: _OnboardingGaugesLayoutHint(),
          );
        }
        return const SizedBox.shrink();
      case OnboardingPageKind.gaugePicker:
        return const Padding(
          padding: EdgeInsets.only(top: 14),
          child: _OnboardingGaugePickerHint(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OnboardingGaugesLayoutHint extends StatelessWidget {
  const _OnboardingGaugesLayoutHint();

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ring vs list', style: labelStyle),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Gauges')),
            ButtonSegment(value: 1, label: Text('List')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: 10),
        const _OnboardingHintBullet(
          'Gauges shows circular ring tiles; List shows compact rows.',
        ),
        const _OnboardingHintBullet(
          'Drag a gauge on the dashboard to reorder in either view.',
        ),
      ],
    );
  }
}

class _OnboardingGaugePickerHint extends StatelessWidget {
  const _OnboardingGaugePickerHint();

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('On this screen', style: labelStyle),
        const SizedBox(height: 8),
        const _OnboardingHintBullet('Use switches to enable or disable gauges.'),
        const _OnboardingHintBullet(
          'Drag rows under Enabled to set dashboard order.',
        ),
        const _OnboardingHintBullet('Search finds any PID in the library.'),
      ],
    );
  }
}

class _OnboardingHintBullet extends StatelessWidget {
  const _OnboardingHintBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _OnboardingWelcomeSummary extends StatelessWidget {
  const _OnboardingWelcomeSummary();

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What you can do', style: labelStyle),
        const SizedBox(height: 8),
        for (final point in OnboardingScreenModel.welcomeSummaryPoints)
          _OnboardingHintBullet(point),
      ],
    );
  }
}

class _OnboardingPageIndicators extends StatelessWidget {
  const _OnboardingPageIndicators({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(OnboardingScreenModel.pages.length, (index) {
        final selected = index == selectedIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: selected ? 10 : 8,
            height: selected ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  const _OnboardingActions({
    required this.pageIndex,
    required this.onPageIndexChange,
    required this.onComplete,
  });

  final int pageIndex;
  final ValueChanged<int> onPageIndexChange;
  final OnboardingCompleteCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (OnboardingScreenModel.isDemoPage(pageIndex)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => onComplete(true),
            child: const Text('Try Demo'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => onComplete(false),
            child: const Text('Get started without Demo'),
          ),
        ],
      );
    }

    if (OnboardingScreenModel.isLastPage(pageIndex)) {
      return const SizedBox.shrink();
    }

    return FilledButton(
      onPressed: () => onPageIndexChange(pageIndex + 1),
      child: const Text('Next'),
    );
  }
}
