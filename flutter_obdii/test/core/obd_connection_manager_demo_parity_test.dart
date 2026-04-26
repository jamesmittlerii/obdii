import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';

Future<T?> _waitForValue<T>(
  T? Function() getter, {
  Duration timeout = const Duration(seconds: 4),
  Duration poll = const Duration(milliseconds: 100),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    final v = getter();
    if (v != null) return v;
    await Future.delayed(poll);
  }
  return getter();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = OBDConnectionManager.instance;
  final config = ConfigData.instance;
  final registry = PidInterestRegistry.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await config.load();
    config.connectionType = ConnectionType.demo;
    manager.initialize();
    await manager.connect();
  });

  tearDown(() async {
    manager.disconnect();
    await Future.delayed(const Duration(milliseconds: 50));
  });

  test('demo MIL parity: always 7 DTC and 10+ readiness monitors', () async {
    final token = registry.makeToken();
    registry.replace({'0101'}, token);
    await manager.connect();

    final status = await _waitForValue<obd2lib.Status>(() => manager.milStatus);
    expect(status, isNotNull);
    expect(status!.milOn, isTrue);
    expect(status.dtcCount, 7);
    expect(status.monitors.length, greaterThanOrEqualTo(10));

    await registry.clear(token);
  });

  test('demo DTC parity: expected 7 Swift mock codes', () async {
    final token = registry.makeToken();
    registry.replace({'03'}, token);
    await manager.connect();

    final codes = await _waitForValue<List<obd2lib.TroubleCodeMetadata>>(
      () => manager.troubleCodes,
    );
    expect(codes, isNotNull);
    final actual = codes!.map((e) => e.code).toSet();
    expect(
      actual,
      equals({
        'P0300',
        'P0170',
        'P0101',
        'P0104',
        'P0207',
        'P0411',
        'P0420',
      }),
    );

    await registry.clear(token);
  });

  test('demo Fuel parity: both banks share same status code', () async {
    final token = registry.makeToken();
    registry.replace({'0103'}, token);
    await manager.connect();

    final status = await _waitForValue<List<obd2lib.StatusCodeMetadata?>>(
      () => manager.fuelStatus,
    );
    expect(status, isNotNull);
    expect(status!.length, greaterThanOrEqualTo(2));
    expect(status[0], isNotNull);
    expect(status[1], isNotNull);
    expect(status[0]!.code, status[1]!.code);
    expect({'1', '2', '3'}.contains(status[0]!.code), isTrue);

    await registry.clear(token);
  });
}
