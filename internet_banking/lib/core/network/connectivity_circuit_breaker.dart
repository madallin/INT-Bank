import 'dart:async';
import 'dart:math' as math;

enum NetworkStatus {
  online,
  offline,
  captivePortal,
  highLatency,
}

enum CircuitState {
  closed,
  open,
  halfOpen,
}

enum RequestOutcome {
  success,
  timeout,
  failure,
}

enum RequestAdmission {
  allowed,
  circuitOpen,
  networkOffline,
  probeInFlight,
}

class ConnectivityBannerState {
  const ConnectivityBannerState({
    required this.visible,
    required this.message,
    required this.remainingSeconds,
    required this.circuitState,
    required this.networkStatus,
  });

  static const ConnectivityBannerState hidden = ConnectivityBannerState(
    visible: false,
    message: '',
    remainingSeconds: 0,
    circuitState: CircuitState.closed,
    networkStatus: NetworkStatus.online,
  );

  final bool visible;
  final String message;
  final int remainingSeconds;
  final CircuitState circuitState;
  final NetworkStatus networkStatus;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ConnectivityBannerState &&
        other.visible == visible &&
        other.message == message &&
        other.remainingSeconds == remainingSeconds &&
        other.circuitState == circuitState &&
        other.networkStatus == networkStatus;
  }

  @override
  int get hashCode => Object.hash(
        visible,
        message,
        remainingSeconds,
        circuitState,
        networkStatus,
      );

  @override
  String toString() {
    return 'ConnectivityBannerState(visible: $visible, message: $message, '
        'remainingSeconds: $remainingSeconds, circuitState: $circuitState, '
        'networkStatus: $networkStatus)';
  }
}

class ConnectivityCircuitBreaker {
  ConnectivityCircuitBreaker({
    DateTime Function()? clock,
    this.timeoutThreshold = defaultTimeoutThreshold,
    this.failureThreshold = defaultFailureThreshold,
    this.baseCooldown = defaultBaseCooldown,
    this.maxCooldown = defaultMaxCooldown,
    this.backoffMultiplier = defaultBackoffMultiplier,
    NetworkStatus initialNetworkStatus = NetworkStatus.online,
  })  : assert(timeoutThreshold > 0),
        assert(failureThreshold > 0),
        assert(backoffMultiplier >= 1),
        assert(maxCooldown >= baseCooldown),
        _clock = clock ?? DateTime.now,
        _now = (clock ?? DateTime.now)(),
        _networkStatus = initialNetworkStatus {
    _syncBanner(force: true);
  }

  static const int defaultTimeoutThreshold = 3;
  static const int defaultFailureThreshold = 3;
  static const Duration defaultBaseCooldown = Duration(seconds: 30);
  static const Duration defaultMaxCooldown = Duration(minutes: 5);
  static const double defaultBackoffMultiplier = 2;

  final DateTime Function() _clock;
  final int timeoutThreshold;
  final int failureThreshold;
  final Duration baseCooldown;
  final Duration maxCooldown;
  final double backoffMultiplier;

  final StreamController<ConnectivityBannerState> _bannerController =
      StreamController<ConnectivityBannerState>.broadcast(sync: true);

  DateTime _now;
  CircuitState _state = CircuitState.closed;
  NetworkStatus _networkStatus;
  DateTime? _openedAt;
  Duration _currentCooldown = Duration.zero;
  int _consecutiveTimeouts = 0;
  int _consecutiveFailures = 0;
  int _totalTimeouts = 0;
  int _totalFailures = 0;
  int _tripCount = 0;
  bool _probeInFlight = false;
  ConnectivityBannerState _lastBanner = ConnectivityBannerState.hidden;

  CircuitState get state => _state;
  NetworkStatus get networkStatus => _networkStatus;
  bool get isClosed => _state == CircuitState.closed;
  bool get isOpen => _state == CircuitState.open;
  bool get isHalfOpen => _state == CircuitState.halfOpen;
  bool get isProbeInFlight => _probeInFlight;
  int get consecutiveTimeouts => _consecutiveTimeouts;
  int get consecutiveFailures => _consecutiveFailures;
  int get totalTimeouts => _totalTimeouts;
  int get totalFailures => _totalFailures;
  int get tripCount => _tripCount;
  Duration get currentCooldown => _currentCooldown;
  DateTime get now => _now;
  Stream<ConnectivityBannerState> get bannerStream => _bannerController.stream;
  ConnectivityBannerState get currentBanner => _lastBanner;

  Duration get remainingCooldown {
    final DateTime? openedAt = _openedAt;
    if (_state != CircuitState.open || openedAt == null) {
      return Duration.zero;
    }
    final Duration remaining = _currentCooldown - _now.difference(openedAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get remainingSeconds {
    final int millis = remainingCooldown.inMilliseconds;
    if (millis <= 0) {
      return 0;
    }
    return (millis + 999) ~/ 1000;
  }

  ConnectivityBannerState get bannerState {
    final bool visible = _state != CircuitState.closed;
    final int seconds = visible ? remainingSeconds : 0;
    return ConnectivityBannerState(
      visible: visible,
      message: visible
          ? describeBanner(
              circuitState: _state,
              remainingSeconds: seconds,
              networkStatus: _networkStatus,
            )
          : '',
      remainingSeconds: seconds,
      circuitState: _state,
      networkStatus: _networkStatus,
    );
  }

  static String describeBanner({
    required CircuitState circuitState,
    required int remainingSeconds,
    required NetworkStatus networkStatus,
  }) {
    switch (circuitState) {
      case CircuitState.closed:
        return '';
      case CircuitState.open:
      case CircuitState.halfOpen:
        return 'Connection unstable. Retrying in ${remainingSeconds}s...';
    }
  }

  RequestAdmission get admission => _evaluateAdmission(claimProbe: false);

  bool get isRequestAllowed => admission == RequestAdmission.allowed;

  RequestAdmission tryBeginRequest() => _evaluateAdmission(claimProbe: true);

  void recordOutcome(RequestOutcome outcome) {
    switch (outcome) {
      case RequestOutcome.success:
        _handleSuccess();
      case RequestOutcome.timeout:
        _handleTimeout();
      case RequestOutcome.failure:
        _handleFailure();
    }
  }

  void recordSuccess() => recordOutcome(RequestOutcome.success);

  void recordTimeout() => recordOutcome(RequestOutcome.timeout);

  void recordFailure() => recordOutcome(RequestOutcome.failure);

  void updateNetworkStatus(NetworkStatus status) {
    if (_networkStatus == status) {
      return;
    }
    _networkStatus = status;
    _syncBanner(force: true);
  }

  void advance(Duration delta) {
    assert(!delta.isNegative);
    _now = _now.add(delta);
    _maybeTransitionFromOpen();
    _syncBanner();
  }

  void tick(Duration delta) => advance(delta);

  void refresh() {
    _now = _clock();
    _maybeTransitionFromOpen();
    _syncBanner();
  }

  void reset() {
    _state = CircuitState.closed;
    _openedAt = null;
    _currentCooldown = Duration.zero;
    _consecutiveTimeouts = 0;
    _consecutiveFailures = 0;
    _tripCount = 0;
    _probeInFlight = false;
    _syncBanner(force: true);
  }

  void dispose() {
    _bannerController.close();
  }

  RequestAdmission _evaluateAdmission({required bool claimProbe}) {
    _maybeTransitionFromOpen();
    if (_networkStatus == NetworkStatus.offline ||
        _networkStatus == NetworkStatus.captivePortal) {
      return RequestAdmission.networkOffline;
    }
    switch (_state) {
      case CircuitState.closed:
        return RequestAdmission.allowed;
      case CircuitState.open:
        return RequestAdmission.circuitOpen;
      case CircuitState.halfOpen:
        if (_probeInFlight) {
          return RequestAdmission.probeInFlight;
        }
        if (claimProbe) {
          _probeInFlight = true;
        }
        return RequestAdmission.allowed;
    }
  }

  void _handleSuccess() {
    _probeInFlight = false;
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      _openedAt = null;
      _currentCooldown = Duration.zero;
      _tripCount = 0;
    }
    _consecutiveTimeouts = 0;
    _consecutiveFailures = 0;
    _syncBanner(force: true);
  }

  void _handleTimeout() {
    _totalTimeouts++;
    if (_state == CircuitState.open) {
      return;
    }
    if (_state == CircuitState.halfOpen) {
      _trip();
      return;
    }
    _consecutiveTimeouts++;
    _consecutiveFailures = 0;
    if (_consecutiveTimeouts >= timeoutThreshold) {
      _trip();
    }
  }

  void _handleFailure() {
    _totalFailures++;
    if (_state == CircuitState.open) {
      return;
    }
    if (_state == CircuitState.halfOpen) {
      _trip();
      return;
    }
    _consecutiveFailures++;
    _consecutiveTimeouts = 0;
    if (_consecutiveFailures >= failureThreshold) {
      _trip();
    }
  }

  void _trip() {
    _state = CircuitState.open;
    _probeInFlight = false;
    _openedAt = _now;
    _currentCooldown = _cooldownFor(_tripCount);
    _tripCount++;
    _consecutiveTimeouts = 0;
    _consecutiveFailures = 0;
    _syncBanner(force: true);
  }

  Duration _cooldownFor(int exponent) {
    final double raw = baseCooldown.inMilliseconds.toDouble() *
        math.pow(backoffMultiplier, exponent).toDouble();
    final int capped = raw >= maxCooldown.inMilliseconds
        ? maxCooldown.inMilliseconds
        : raw.round();
    return Duration(milliseconds: capped);
  }

  void _maybeTransitionFromOpen() {
    if (_state != CircuitState.open) {
      return;
    }
    final DateTime? openedAt = _openedAt;
    if (openedAt == null) {
      return;
    }
    if (_now.difference(openedAt) >= _currentCooldown) {
      _state = CircuitState.halfOpen;
      _probeInFlight = false;
    }
  }

  void _syncBanner({bool force = false}) {
    final ConnectivityBannerState next = bannerState;
    if (!force && next == _lastBanner) {
      return;
    }
    _lastBanner = next;
    if (!_bannerController.isClosed) {
      _bannerController.add(next);
    }
  }
}
