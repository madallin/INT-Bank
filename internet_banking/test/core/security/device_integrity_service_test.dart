import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/device_integrity_service.dart';

class _FakeProbe implements DevicePlatformProbe {
  _FakeProbe({
    this.su = false,
    this.cydia = false,
    this.debugger = false,
    this.frida = false,
    this.testKeys = false,
    this.emulator = false,
  });

  final bool su;
  final bool cydia;
  final bool debugger;
  final bool frida;
  final bool testKeys;
  final bool emulator;

  @override
  bool hasSuBinary() => su;

  @override
  bool hasCydiaApp() => cydia;

  @override
  bool isDebuggerAttached() => debugger;

  @override
  bool isFridaPortOpen() => frida;

  @override
  bool isTestKeysBuild() => testKeys;

  @override
  bool isEmulator() => emulator;
}

void main() {
  final service = DeviceIntegrityService();

  group('Clean Device Evaluation', () {
    test('Clean device yields score 0, not compromised and allow', () {
      final probe = _FakeProbe();
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isFalse);
      expect(result.detectedThreats, isEmpty);
      expect(result.threatScore, 0);
      expect(result.recommendedAction, IntegrityEnforcementAction.allow);
      expect(
        service.determineAction(result, strictMode: true),
        IntegrityEnforcementAction.allow,
      );
      expect(
        service.determineAction(result, strictMode: false),
        IntegrityEnforcementAction.allow,
      );
    });
  });

  group('Root and Jailbreak Detection', () {
    test('Rooted device with su binary terminates in strict mode', () {
      final probe = _FakeProbe(su: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.detectedThreats, [IntegrityThreatType.rootAccess]);
      expect(result.threatScore, 50);
      expect(
        result.recommendedAction,
        IntegrityEnforcementAction.terminateSession,
      );
    });

    test('Jailbreak artifacts alone terminate in strict mode', () {
      final probe = _FakeProbe(cydia: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.detectedThreats, [IntegrityThreatType.jailbreakArtifacts]);
      expect(result.threatScore, 50);
      expect(
        result.recommendedAction,
        IntegrityEnforcementAction.terminateSession,
      );
    });
  });

  group('Weighted Threat Scoring', () {
    test('Root combined with Frida yields maximum score of 100', () {
      final probe = _FakeProbe(su: true, frida: true);
      final result = service.performFullScan(probe: probe);

      expect(result.detectedThreats, [
        IntegrityThreatType.rootAccess,
        IntegrityThreatType.dynamicHookingDetected,
      ]);
      expect(result.threatScore, 100);
      expect(result.isCompromised, isTrue);
      expect(
        result.recommendedAction,
        IntegrityEnforcementAction.terminateSession,
      );
    });

    test('All signals combined clamp the score to 100', () {
      final probe = _FakeProbe(
        su: true,
        cydia: true,
        debugger: true,
        frida: true,
        testKeys: true,
        emulator: true,
      );
      final result = service.performFullScan(probe: probe);

      expect(result.detectedThreats.length, 6);
      expect(result.threatScore, 100);
    });
  });

  group('Dynamic Hooking Detection', () {
    test('Frida only yields score 50 and terminates in strict mode', () {
      final probe = _FakeProbe(frida: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.detectedThreats, [
        IntegrityThreatType.dynamicHookingDetected,
      ]);
      expect(result.threatScore, 50);
      expect(
        result.recommendedAction,
        IntegrityEnforcementAction.terminateSession,
      );
      expect(
        service.determineAction(result, strictMode: true),
        IntegrityEnforcementAction.terminateSession,
      );
    });

    test('Frida in non-strict mode downgrades termination to warning', () {
      final probe = _FakeProbe(frida: true);
      final result = service.performFullScan(probe: probe);

      expect(
        service.determineAction(result, strictMode: false),
        IntegrityEnforcementAction.warnUser,
      );
    });
  });

  group('Lower Severity Signals Map To Warnings', () {
    test('Debugger only yields warnUser', () {
      final probe = _FakeProbe(debugger: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.threatScore, 40);
      expect(result.recommendedAction, IntegrityEnforcementAction.warnUser);
    });

    test('Emulator only yields warnUser', () {
      final probe = _FakeProbe(emulator: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.threatScore, 25);
      expect(result.recommendedAction, IntegrityEnforcementAction.warnUser);
    });

    test('Test-keys build only yields warnUser', () {
      final probe = _FakeProbe(testKeys: true);
      final result = service.performFullScan(probe: probe);

      expect(result.isCompromised, isTrue);
      expect(result.threatScore, 30);
      expect(result.recommendedAction, IntegrityEnforcementAction.warnUser);
    });
  });

  group('Enforcement Mode Behavior', () {
    test('Non-strict mode downgrades termination to warning', () {
      final probe = _FakeProbe(su: true);
      final result = service.performFullScan(probe: probe);

      expect(
        service.determineAction(result, strictMode: true),
        IntegrityEnforcementAction.terminateSession,
      );
      expect(
        service.determineAction(result, strictMode: false),
        IntegrityEnforcementAction.warnUser,
      );
    });

    test('Warnings remain warnings in both modes', () {
      final probe = _FakeProbe(emulator: true);
      final result = service.performFullScan(probe: probe);

      expect(
        service.determineAction(result, strictMode: true),
        IntegrityEnforcementAction.warnUser,
      );
      expect(
        service.determineAction(result, strictMode: false),
        IntegrityEnforcementAction.warnUser,
      );
    });
  });

  group('Deterministic Scan Timestamp', () {
    test('Provided timestamp is preserved on the result', () {
      final probe = _FakeProbe(su: true);
      final fixed = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final result = service.performFullScan(
        probe: probe,
        scanTimestamp: fixed,
      );

      expect(result.scanTimestamp, fixed);
    });

    test('Omitted timestamp defaults to now without mutating provided values', () {
      final probe = _FakeProbe();
      final before = DateTime.now();
      final result = service.performFullScan(probe: probe);
      final after = DateTime.now();

      expect(
        result.scanTimestamp.isBefore(before) ||
            result.scanTimestamp.isAfter(after),
        isFalse,
      );
    });
  });
}
