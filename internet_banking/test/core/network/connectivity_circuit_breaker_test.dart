import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/network/connectivity_circuit_breaker.dart';

void main() {
  DateTime fixedClock() => DateTime.utc(2024, 1, 1);

  ConnectivityCircuitBreaker buildBreaker({
    int timeoutThreshold = 3,
    int failureThreshold = 3,
    Duration baseCooldown = const Duration(seconds: 30),
    Duration maxCooldown = const Duration(minutes: 5),
    double backoffMultiplier = 2,
    NetworkStatus initialNetworkStatus = NetworkStatus.online,
  }) {
    return ConnectivityCircuitBreaker(
      clock: fixedClock,
      timeoutThreshold: timeoutThreshold,
      failureThreshold: failureThreshold,
      baseCooldown: baseCooldown,
      maxCooldown: maxCooldown,
      backoffMultiplier: backoffMultiplier,
      initialNetworkStatus: initialNetworkStatus,
    );
  }

  void tripOpen(ConnectivityCircuitBreaker breaker) {
    breaker.recordTimeout();
    breaker.recordTimeout();
    breaker.recordTimeout();
  }

  void reachHalfOpen(ConnectivityCircuitBreaker breaker) {
    tripOpen(breaker);
    breaker.advance(const Duration(seconds: 30));
  }

  group('ConnectivityCircuitBreaker initial state', () {
    test('starts closed, online, with hidden banner and zeroed counters', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.isClosed, isTrue);
      expect(breaker.networkStatus, NetworkStatus.online);
      expect(breaker.bannerState, ConnectivityBannerState.hidden);
      expect(breaker.bannerState.visible, isFalse);
      expect(breaker.bannerState.message, '');
      expect(breaker.remainingSeconds, 0);
      expect(breaker.consecutiveTimeouts, 0);
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.totalTimeouts, 0);
      expect(breaker.totalFailures, 0);
      expect(breaker.tripCount, 0);
      expect(breaker.currentCooldown, Duration.zero);
      expect(breaker.now, DateTime.utc(2024, 1, 1));
    });

    test('admits requests while closed', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      expect(breaker.admission, RequestAdmission.allowed);
      expect(breaker.isRequestAllowed, isTrue);
      expect(breaker.tryBeginRequest(), RequestAdmission.allowed);
    });
  });

  group('ConnectivityCircuitBreaker failure tracking', () {
    test('single timeout keeps circuit closed and tracks the streak', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      breaker.recordTimeout();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.consecutiveTimeouts, 1);
      expect(breaker.totalTimeouts, 1);
    });

    test('success resets consecutive timeout streak', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      breaker.recordTimeout();
      breaker.recordTimeout();
      breaker.recordSuccess();

      expect(breaker.consecutiveTimeouts, 0);
      expect(breaker.state, CircuitState.closed);

      breaker.recordTimeout();
      expect(breaker.consecutiveTimeouts, 1);
    });

    test('failure breaks timeout streak and starts a failure streak', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      breaker.recordTimeout();
      breaker.recordTimeout();
      breaker.recordFailure();

      expect(breaker.consecutiveTimeouts, 0);
      expect(breaker.consecutiveFailures, 1);
      expect(breaker.state, CircuitState.closed);
    });

    test('trips open after threshold consecutive timeouts', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      tripOpen(breaker);

      expect(breaker.state, CircuitState.open);
      expect(breaker.tripCount, 1);
      expect(breaker.totalTimeouts, 3);
      expect(breaker.consecutiveTimeouts, 0);
    });

    test('trips open after threshold consecutive failures', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.state, CircuitState.closed);

      breaker.recordFailure();
      expect(breaker.state, CircuitState.open);
      expect(breaker.tripCount, 1);
      expect(breaker.totalFailures, 3);
    });

    test('honors a custom timeout threshold', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker(
        timeoutThreshold: 2,
      );

      breaker.recordTimeout();
      expect(breaker.state, CircuitState.closed);

      breaker.recordTimeout();
      expect(breaker.state, CircuitState.open);
    });
  });

  group('ConnectivityCircuitBreaker open state', () {
    test('rejects requests fast while open and never records a probe', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);

      expect(breaker.admission, RequestAdmission.circuitOpen);
      expect(breaker.isRequestAllowed, isFalse);
      expect(breaker.tryBeginRequest(), RequestAdmission.circuitOpen);
      expect(breaker.isProbeInFlight, isFalse);
      expect(breaker.state, CircuitState.open);
    });

    test('exposes a visible banner with the cooldown countdown', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);

      final ConnectivityBannerState banner = breaker.bannerState;
      expect(banner.visible, isTrue);
      expect(banner.remainingSeconds, 30);
      expect(banner.message, 'Connection unstable. Retrying in 30s...');
      expect(breaker.currentBanner, banner);
    });

    test('counts the cooldown down as time advances', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);

      breaker.advance(const Duration(seconds: 10));
      expect(breaker.state, CircuitState.open);
      expect(breaker.remainingSeconds, 20);
      expect(breaker.bannerState.message, 'Connection unstable. Retrying in 20s...');

      breaker.advance(const Duration(seconds: 5));
      expect(breaker.remainingSeconds, 15);
      expect(breaker.bannerState.message, 'Connection unstable. Retrying in 15s...');
    });

    test('does not leave open before the cooldown elapses', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);

      breaker.advance(const Duration(seconds: 29, milliseconds: 999));

      expect(breaker.state, CircuitState.open);
      expect(breaker.remainingSeconds, 1);
    });

    test('transitions to halfOpen exactly when the cooldown elapses', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);

      breaker.advance(const Duration(seconds: 30));

      expect(breaker.state, CircuitState.halfOpen);
      expect(breaker.isHalfOpen, isTrue);
      expect(breaker.remainingSeconds, 0);
      expect(breaker.bannerState.message, 'Connection unstable. Retrying in 0s...');
    });

    test('remaining seconds round up to the next whole second', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker(
        baseCooldown: const Duration(milliseconds: 1500),
      );
      tripOpen(breaker);

      expect(breaker.remainingSeconds, 2);

      breaker.advance(const Duration(milliseconds: 500));
      expect(breaker.remainingSeconds, 1);
    });
  });

  group('ConnectivityCircuitBreaker halfOpen probes', () {
    test('allows exactly one probe request then rejects further calls', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      reachHalfOpen(breaker);

      expect(breaker.tryBeginRequest(), RequestAdmission.allowed);
      expect(breaker.isProbeInFlight, isTrue);
      expect(breaker.tryBeginRequest(), RequestAdmission.probeInFlight);
      expect(breaker.isRequestAllowed, isFalse);
    });

    test('successful probe resets circuit to closed and clears counters', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      reachHalfOpen(breaker);
      breaker.tryBeginRequest();

      breaker.recordSuccess();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.bannerState, ConnectivityBannerState.hidden);
      expect(breaker.consecutiveTimeouts, 0);
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.tripCount, 0);
      expect(breaker.currentCooldown, Duration.zero);
      expect(breaker.isProbeInFlight, isFalse);
    });

    test('failed probe reopens with exponential cooldown', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      reachHalfOpen(breaker);
      breaker.tryBeginRequest();

      breaker.recordFailure();

      expect(breaker.state, CircuitState.open);
      expect(breaker.tripCount, 2);
      expect(breaker.currentCooldown, const Duration(seconds: 60));
      expect(breaker.remainingSeconds, 60);
      expect(breaker.bannerState.message, 'Connection unstable. Retrying in 60s...');
    });

    test('timed out probe reopens the circuit', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      reachHalfOpen(breaker);
      breaker.tryBeginRequest();

      breaker.recordTimeout();

      expect(breaker.state, CircuitState.open);
      expect(breaker.currentCooldown, const Duration(seconds: 60));
    });

    test('caps exponential cooldown at maxCooldown', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker(
        baseCooldown: const Duration(seconds: 10),
        maxCooldown: const Duration(seconds: 25),
        backoffMultiplier: 3,
      );

      tripOpen(breaker);
      expect(breaker.currentCooldown, const Duration(seconds: 10));

      breaker.advance(const Duration(seconds: 10));
      breaker.tryBeginRequest();
      breaker.recordFailure();

      expect(breaker.currentCooldown, const Duration(seconds: 25));
      expect(breaker.remainingSeconds, 25);
    });

    test('advancing while halfOpen does not reopen or close the circuit', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      reachHalfOpen(breaker);

      breaker.advance(const Duration(minutes: 5));

      expect(breaker.state, CircuitState.halfOpen);
      expect(breaker.remainingSeconds, 0);
    });

    test('completes a full trip, halfOpen probe and recovery cycle', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();

      tripOpen(breaker);
      expect(breaker.state, CircuitState.open);

      breaker.advance(const Duration(seconds: 30));
      expect(breaker.state, CircuitState.halfOpen);

      expect(breaker.tryBeginRequest(), RequestAdmission.allowed);
      breaker.recordSuccess();
      expect(breaker.state, CircuitState.closed);
      expect(breaker.admission, RequestAdmission.allowed);
    });
  });

  group('ConnectivityCircuitBreaker network status', () {
    test('rejects requests while offline', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      breaker.updateNetworkStatus(NetworkStatus.offline);

      expect(breaker.networkStatus, NetworkStatus.offline);
      expect(breaker.tryBeginRequest(), RequestAdmission.networkOffline);
      expect(breaker.isRequestAllowed, isFalse);
    });

    test('rejects requests behind a captive portal', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker(
        initialNetworkStatus: NetworkStatus.captivePortal,
      );

      expect(breaker.tryBeginRequest(), RequestAdmission.networkOffline);
      expect(breaker.admission, RequestAdmission.networkOffline);
    });

    test('admits requests while latency is high but circuit is closed', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      breaker.updateNetworkStatus(NetworkStatus.highLatency);

      expect(breaker.networkStatus, NetworkStatus.highLatency);
      expect(breaker.tryBeginRequest(), RequestAdmission.allowed);
    });

    test('emits banner state when network status changes', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      final List<ConnectivityBannerState> events = <ConnectivityBannerState>[];
      breaker.bannerStream.listen(events.add);

      breaker.updateNetworkStatus(NetworkStatus.offline);

      expect(events, hasLength(1));
      expect(events.single.networkStatus, NetworkStatus.offline);
    });
  });

  group('ConnectivityCircuitBreaker observation and reset', () {
    test('banner stream emits on trip and on countdown advance', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      final List<ConnectivityBannerState> events = <ConnectivityBannerState>[];
      breaker.bannerStream.listen(events.add);

      tripOpen(breaker);
      expect(events, hasLength(1));
      expect(events.last.message, 'Connection unstable. Retrying in 30s...');

      breaker.advance(const Duration(seconds: 10));
      expect(events, hasLength(2));
      expect(events.last.message, 'Connection unstable. Retrying in 20s...');
    });

    test('reset returns an open circuit to closed and clears counters', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      tripOpen(breaker);
      breaker.advance(const Duration(seconds: 30));

      breaker.reset();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.bannerState, ConnectivityBannerState.hidden);
      expect(breaker.tripCount, 0);
      expect(breaker.consecutiveTimeouts, 0);
      expect(breaker.consecutiveFailures, 0);
      expect(breaker.currentCooldown, Duration.zero);
      expect(breaker.tryBeginRequest(), RequestAdmission.allowed);
    });

    test('describeBanner builds the expected messages', () {
      expect(
        ConnectivityCircuitBreaker.describeBanner(
          circuitState: CircuitState.open,
          remainingSeconds: 12,
          networkStatus: NetworkStatus.highLatency,
        ),
        'Connection unstable. Retrying in 12s...',
      );
      expect(
        ConnectivityCircuitBreaker.describeBanner(
          circuitState: CircuitState.halfOpen,
          remainingSeconds: 0,
          networkStatus: NetworkStatus.online,
        ),
        'Connection unstable. Retrying in 0s...',
      );
      expect(
        ConnectivityCircuitBreaker.describeBanner(
          circuitState: CircuitState.closed,
          remainingSeconds: 0,
          networkStatus: NetworkStatus.online,
        ),
        '',
      );
    });

    test('dispose stops emissions without throwing', () {
      final ConnectivityCircuitBreaker breaker = buildBreaker();
      final List<ConnectivityBannerState> events = <ConnectivityBannerState>[];
      breaker.bannerStream.listen(events.add);

      breaker.dispose();

      expect(
        () => breaker.updateNetworkStatus(NetworkStatus.offline),
        returnsNormally,
      );
      expect(
        () => breaker.advance(const Duration(seconds: 1)),
        returnsNormally,
      );
      expect(events, isEmpty);
    });
  });
}
