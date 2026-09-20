/// Threat categories detected during a device integrity scan.
enum IntegrityThreatType {
  rootAccess,
  jailbreakArtifacts,
  debuggerAttached,
  dynamicHookingDetected,
  testKeysBuild,
  emulatorEnvironment,
}

/// Enforcement action recommended for the detected threat profile.
enum IntegrityEnforcementAction { allow, warnUser, terminateSession }

/// Immutable outcome of a device integrity scan.
class IntegrityScanResult {
  const IntegrityScanResult({
    required this.isCompromised,
    required this.detectedThreats,
    required this.threatScore,
    required this.recommendedAction,
    required this.scanTimestamp,
  });

  final bool isCompromised;
  final List<IntegrityThreatType> detectedThreats;
  final int threatScore;
  final IntegrityEnforcementAction recommendedAction;
  final DateTime scanTimestamp;
}

/// Injectable platform probe interface for integrity signals.
abstract class DevicePlatformProbe {
  bool hasSuBinary();
  bool hasCydiaApp();
  bool isDebuggerAttached();
  bool isFridaPortOpen();
  bool isTestKeysBuild();
  bool isEmulator();
}

/// Evaluates device integrity signals and recommends enforcement.
class DeviceIntegrityService {
  const DeviceIntegrityService();

  static const Map<IntegrityThreatType, int> threatWeights = {
    IntegrityThreatType.rootAccess: 50,
    IntegrityThreatType.jailbreakArtifacts: 50,
    IntegrityThreatType.dynamicHookingDetected: 50,
    IntegrityThreatType.debuggerAttached: 40,
    IntegrityThreatType.testKeysBuild: 30,
    IntegrityThreatType.emulatorEnvironment: 25,
  };

  static const Set<IntegrityThreatType> criticalThreats = {
    IntegrityThreatType.rootAccess,
    IntegrityThreatType.jailbreakArtifacts,
    IntegrityThreatType.dynamicHookingDetected,
  };

  /// Runs a full scan over [probe]. [scanTimestamp] is injectable for
  /// deterministic tests and defaults to the current time when omitted.
  IntegrityScanResult performFullScan({
    required DevicePlatformProbe probe,
    DateTime? scanTimestamp,
  }) {
    final threats = <IntegrityThreatType>[];

    if (probe.hasSuBinary()) {
      threats.add(IntegrityThreatType.rootAccess);
    }
    if (probe.hasCydiaApp()) {
      threats.add(IntegrityThreatType.jailbreakArtifacts);
    }
    if (probe.isDebuggerAttached()) {
      threats.add(IntegrityThreatType.debuggerAttached);
    }
    if (probe.isFridaPortOpen()) {
      threats.add(IntegrityThreatType.dynamicHookingDetected);
    }
    if (probe.isTestKeysBuild()) {
      threats.add(IntegrityThreatType.testKeysBuild);
    }
    if (probe.isEmulator()) {
      threats.add(IntegrityThreatType.emulatorEnvironment);
    }

    var rawScore = 0;
    for (final threat in threats) {
      rawScore += threatWeights[threat]!;
    }
    final score = rawScore > 100 ? 100 : rawScore;

    final timestamp = scanTimestamp ?? DateTime.now();
    final result = IntegrityScanResult(
      isCompromised: threats.isNotEmpty,
      detectedThreats: List.unmodifiable(threats),
      threatScore: score,
      recommendedAction: IntegrityEnforcementAction.allow,
      scanTimestamp: timestamp,
    );

    // The stored recommendation reflects strict-mode enforcement by default.
    final action = determineAction(result, strictMode: true);

    return IntegrityScanResult(
      isCompromised: result.isCompromised,
      detectedThreats: result.detectedThreats,
      threatScore: result.threatScore,
      recommendedAction: action,
      scanTimestamp: result.scanTimestamp,
    );
  }

  /// Maps a [result] to an enforcement action. Strict mode terminates on a
  /// score of 50 or more or any critical threat; non-strict mode downgrades
  /// termination to a warning while still allowing clean devices.
  IntegrityEnforcementAction determineAction(
    IntegrityScanResult result, {
    bool strictMode = true,
  }) {
    if (result.detectedThreats.isEmpty) {
      return IntegrityEnforcementAction.allow;
    }

    final hasCritical = result.detectedThreats.any(criticalThreats.contains);
    final shouldTerminate = result.threatScore >= 50 || hasCritical;

    if (shouldTerminate) {
      return strictMode
          ? IntegrityEnforcementAction.terminateSession
          : IntegrityEnforcementAction.warnUser;
    }

    return IntegrityEnforcementAction.warnUser;
  }
}
