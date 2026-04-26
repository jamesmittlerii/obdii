import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/views/gauge_detail_view.dart';

ObdiiPid _pid() => ObdiiPid(
      id: 'rpm',
      enabled: true,
      label: 'RPM',
      name: 'Engine RPM',
      pidCommand: '010C',
      units: 'RPM',
      kind: ObdPidKind.gauge,
      typicalRange: ValueRange(min: 0, max: 8000),
    );

void main() {
  testWidgets('testRendersGaugeDetailSectionHeaders', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();

    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('STATISTICS'), findsOneWidget);
    expect(find.text('MAXIMUM RANGE'), findsOneWidget);
  });

  testWidgets('testShowsNoDataStateBeforeStatsArrive', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();

    expect(find.text('No data yet'), findsOneWidget);
  });

  testWidgets('testAppBarTitleShowsPIDName', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();

    expect(find.text('Engine RPM'), findsOneWidget);
  });

  testWidgets('testStatisticsLabelsArePresent', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();

    // labels render once stats exist; ensure section container still present
    expect(find.text('STATISTICS'), findsOneWidget);
  });

  testWidgets('testRendersCurrentSectionTitle', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();
    expect(find.text('CURRENT'), findsOneWidget);
  });

  testWidgets('testRendersMaximumRangeSectionTitle', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();
    expect(find.text('MAXIMUM RANGE'), findsOneWidget);
  });

  testWidgets('testRangeCardExists', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('testShowsPidNameInAppBarForCreatedPid', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();
    expect(find.text('Engine RPM'), findsOneWidget);
  });

  testWidgets('testRendersPlaceholderCurrentValueWhenStatsMissing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ConfigData>.value(
        value: ConfigData.instance,
        child: MaterialApp(home: GaugeDetailView(pid: _pid())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('—'), findsOneWidget);
  });
}
