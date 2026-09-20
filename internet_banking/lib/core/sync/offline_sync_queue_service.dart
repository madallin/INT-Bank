enum QueuedActionStatus { pending, inFlight, synced, failed, conflict }

enum SyncAttemptOutcome { success, retryable, conflict, permanentFailure }

enum EnqueueStatus { enqueued, duplicate, rejectedUnsafe }

class QueuedAction {
  const QueuedAction({
    required this.actionId,
    required this.endpoint,
    required this.payload,
    required this.idempotencyKey,
    required this.timestamp,
    this.retryCount = 0,
    this.status = QueuedActionStatus.pending,
  });

  factory QueuedAction.fromJson(Map<String, Object?> json) {
    return QueuedAction(
      actionId: json['actionId']! as String,
      endpoint: json['endpoint']! as String,
      payload: Map<String, Object?>.from(
        json['payload']! as Map<Object?, Object?>,
      ),
      idempotencyKey: json['idempotencyKey']! as String,
      timestamp: DateTime.parse(json['timestamp']! as String),
      retryCount: json['retryCount']! as int,
      status: QueuedActionStatus.values.byName(json['status']! as String),
    );
  }

  final String actionId;
  final String endpoint;
  final Map<String, Object?> payload;
  final String idempotencyKey;
  final DateTime timestamp;
  final int retryCount;
  final QueuedActionStatus status;

  QueuedAction copyWith({
    String? actionId,
    String? endpoint,
    Map<String, Object?>? payload,
    String? idempotencyKey,
    DateTime? timestamp,
    int? retryCount,
    QueuedActionStatus? status,
  }) {
    return QueuedAction(
      actionId: actionId ?? this.actionId,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'actionId': actionId,
      'endpoint': endpoint,
      'payload': payload,
      'idempotencyKey': idempotencyKey,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'status': status.name,
    };
  }
}

class SyncAttemptResult {
  const SyncAttemptResult({required this.outcome, this.message});

  const SyncAttemptResult.success()
      : outcome = SyncAttemptOutcome.success,
        message = null;

  const SyncAttemptResult.retryable({this.message})
      : outcome = SyncAttemptOutcome.retryable;

  const SyncAttemptResult.conflict({this.message})
      : outcome = SyncAttemptOutcome.conflict;

  const SyncAttemptResult.permanentFailure({this.message})
      : outcome = SyncAttemptOutcome.permanentFailure;

  final SyncAttemptOutcome outcome;
  final String? message;
}

class RetrySchedule {
  const RetrySchedule({
    required this.actionId,
    required this.attempt,
    required this.delay,
  });

  final String actionId;
  final int attempt;
  final Duration delay;

  @override
  bool operator ==(Object other) {
    return other is RetrySchedule &&
        other.actionId == actionId &&
        other.attempt == attempt &&
        other.delay == delay;
  }

  @override
  int get hashCode => Object.hash(actionId, attempt, delay);
}

class EnqueueResult {
  const EnqueueResult({required this.status, required this.action});

  final EnqueueStatus status;
  final QueuedAction action;

  bool get isEnqueued => status == EnqueueStatus.enqueued;

  bool get isDuplicate => status == EnqueueStatus.duplicate;
}

class DrainReport {
  const DrainReport({
    required this.wasOnline,
    required this.syncedActionIds,
    required this.conflictActionIds,
    required this.failedActionIds,
    required this.retrySchedules,
    required this.skippedActionIds,
    required this.remainingPendingCount,
  });

  final bool wasOnline;
  final List<String> syncedActionIds;
  final List<String> conflictActionIds;
  final List<String> failedActionIds;
  final List<RetrySchedule> retrySchedules;
  final List<String> skippedActionIds;
  final int remainingPendingCount;

  int get processedCount =>
      syncedActionIds.length +
      conflictActionIds.length +
      failedActionIds.length +
      retrySchedules.length;

  bool get hasFailures =>
      failedActionIds.isNotEmpty || conflictActionIds.isNotEmpty;
}

class ReconciliationReport {
  const ReconciliationReport({
    required this.reconciledActionIds,
    required this.resetActionIds,
    required this.syncedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.conflictCount,
  });

  final List<String> reconciledActionIds;
  final List<String> resetActionIds;
  final int syncedCount;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;

  int get totalCount =>
      syncedCount + pendingCount + failedCount + conflictCount;
}

abstract class OfflineSyncNetworkAdapter {
  Future<SyncAttemptResult> send(QueuedAction action);
}

abstract class OfflineSyncStorageAdapter {
  Future<void> persist(List<QueuedAction> actions);

  Future<List<QueuedAction>> restore();
}

abstract class OfflineSyncConnectivityAdapter {
  bool get isOnline;
}

class OfflineSyncQueueService {
  OfflineSyncQueueService({
    required OfflineSyncNetworkAdapter networkAdapter,
    required OfflineSyncStorageAdapter storageAdapter,
    required OfflineSyncConnectivityAdapter connectivityAdapter,
    Duration baseBackoff = const Duration(seconds: 2),
    Duration maxBackoff = const Duration(minutes: 5),
    int maxRetryAttempts = 3,
    Set<String>? allowedEndpoints,
    DateTime Function()? clock,
  })  : _networkAdapter = networkAdapter,
        _storageAdapter = storageAdapter,
        _connectivityAdapter = connectivityAdapter,
        _baseBackoff = baseBackoff,
        _maxBackoff = maxBackoff,
        _maxRetryAttempts = maxRetryAttempts,
        _allowedEndpoints = allowedEndpoints,
        _clock = clock ?? DateTime.now {
    if (maxRetryAttempts < 1) {
      throw ArgumentError.value(
        maxRetryAttempts,
        'maxRetryAttempts',
        'must be at least 1',
      );
    }
    if (baseBackoff <= Duration.zero) {
      throw ArgumentError.value(
        baseBackoff,
        'baseBackoff',
        'must be positive',
      );
    }
    if (maxBackoff < baseBackoff) {
      throw ArgumentError.value(
        maxBackoff,
        'maxBackoff',
        'must be greater than or equal to baseBackoff',
      );
    }
  }

  final OfflineSyncNetworkAdapter _networkAdapter;
  final OfflineSyncStorageAdapter _storageAdapter;
  final OfflineSyncConnectivityAdapter _connectivityAdapter;
  final Duration _baseBackoff;
  final Duration _maxBackoff;
  final int _maxRetryAttempts;
  final Set<String>? _allowedEndpoints;
  final DateTime Function() _clock;

  final List<QueuedAction> _actions = <QueuedAction>[];
  int _idSequence = 0;
  bool _initialized = false;

  Duration get baseBackoff => _baseBackoff;

  Duration get maxBackoff => _maxBackoff;

  int get maxRetryAttempts => _maxRetryAttempts;

  bool get isOnline => _connectivityAdapter.isOnline;

  int get length => _actions.length;

  int get pendingCount => _countByStatus(QueuedActionStatus.pending);

  List<QueuedAction> get actions =>
      List<QueuedAction>.unmodifiable(_actions);

  List<QueuedAction> get pendingActions => List<QueuedAction>.unmodifiable(
        _actions.where((QueuedAction action) =>
            action.status == QueuedActionStatus.pending),
      );

  QueuedAction? findByActionId(String actionId) {
    final int index = _indexOfActionId(actionId);
    return index < 0 ? null : _actions[index];
  }

  QueuedAction? findByIdempotencyKey(String idempotencyKey) {
    final int? index = _indexOfIdempotencyKey(idempotencyKey);
    return index == null ? null : _actions[index];
  }

  bool containsIdempotencyKey(String idempotencyKey) =>
      _indexOfIdempotencyKey(idempotencyKey) != null;

  Future<void> initialize() async {
    await _ensureInitialized();
  }

  Future<EnqueueResult> enqueue({
    required String endpoint,
    required Map<String, Object?> payload,
    required String idempotencyKey,
    String? actionId,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();

    final int? existingIndex = _indexOfIdempotencyKey(idempotencyKey);
    if (existingIndex != null) {
      return EnqueueResult(
        status: EnqueueStatus.duplicate,
        action: _actions[existingIndex],
      );
    }

    final String resolvedActionId = actionId ?? 'action-$_idSequence';
    _idSequence++;

    final QueuedAction candidate = QueuedAction(
      actionId: resolvedActionId,
      endpoint: endpoint,
      payload: Map<String, Object?>.unmodifiable(payload),
      idempotencyKey: idempotencyKey,
      timestamp: timestamp ?? _clock(),
    );

    if (!_isEndpointAllowed(endpoint)) {
      return EnqueueResult(
        status: EnqueueStatus.rejectedUnsafe,
        action: candidate,
      );
    }

    _actions.add(candidate);
    await _persist();
    return EnqueueResult(status: EnqueueStatus.enqueued, action: candidate);
  }

  Future<DrainReport> drain() async {
    await _ensureInitialized();

    if (!_connectivityAdapter.isOnline) {
      return DrainReport(
        wasOnline: false,
        syncedActionIds: const <String>[],
        conflictActionIds: const <String>[],
        failedActionIds: const <String>[],
        retrySchedules: const <RetrySchedule>[],
        skippedActionIds: List<String>.unmodifiable(
          _actions.map((QueuedAction action) => action.actionId),
        ),
        remainingPendingCount: pendingCount,
      );
    }

    final List<String> skippedActionIds = List<String>.unmodifiable(
      _actions
          .where((QueuedAction action) =>
              action.status != QueuedActionStatus.pending)
          .map((QueuedAction action) => action.actionId),
    );

    final List<String> snapshotIds = _actions
        .where((QueuedAction action) =>
            action.status == QueuedActionStatus.pending)
        .map((QueuedAction action) => action.actionId)
        .toList(growable: false);

    final List<String> syncedActionIds = <String>[];
    final List<String> conflictActionIds = <String>[];
    final List<String> failedActionIds = <String>[];
    final List<RetrySchedule> retrySchedules = <RetrySchedule>[];

    for (final String actionId in snapshotIds) {
      final int index = _indexOfActionId(actionId);
      if (index < 0) {
        continue;
      }
      final QueuedAction current = _actions[index];
      if (current.status != QueuedActionStatus.pending) {
        continue;
      }

      final QueuedAction inFlight = current.copyWith(
        status: QueuedActionStatus.inFlight,
      );
      _actions[index] = inFlight;
      await _persist();

      SyncAttemptResult result;
      try {
        result = await _networkAdapter.send(inFlight);
      } catch (error) {
        result = SyncAttemptResult.retryable(message: error.toString());
      }

      switch (result.outcome) {
        case SyncAttemptOutcome.success:
          _actions[index] = inFlight.copyWith(
            status: QueuedActionStatus.synced,
          );
          syncedActionIds.add(actionId);
          break;
        case SyncAttemptOutcome.conflict:
          _actions[index] = inFlight.copyWith(
            status: QueuedActionStatus.conflict,
          );
          conflictActionIds.add(actionId);
          break;
        case SyncAttemptOutcome.permanentFailure:
          _actions[index] = inFlight.copyWith(
            status: QueuedActionStatus.failed,
          );
          failedActionIds.add(actionId);
          break;
        case SyncAttemptOutcome.retryable:
          final int nextRetryCount = inFlight.retryCount + 1;
          if (nextRetryCount >= _maxRetryAttempts) {
            _actions[index] = inFlight.copyWith(
              retryCount: nextRetryCount,
              status: QueuedActionStatus.failed,
            );
            failedActionIds.add(actionId);
          } else {
            _actions[index] = inFlight.copyWith(
              retryCount: nextRetryCount,
              status: QueuedActionStatus.pending,
            );
            retrySchedules.add(
              RetrySchedule(
                actionId: actionId,
                attempt: nextRetryCount,
                delay: backoffForRetryCount(inFlight.retryCount),
              ),
            );
          }
          break;
      }

      await _persist();
    }

    return DrainReport(
      wasOnline: true,
      syncedActionIds: List<String>.unmodifiable(syncedActionIds),
      conflictActionIds: List<String>.unmodifiable(conflictActionIds),
      failedActionIds: List<String>.unmodifiable(failedActionIds),
      retrySchedules: List<RetrySchedule>.unmodifiable(retrySchedules),
      skippedActionIds: skippedActionIds,
      remainingPendingCount: pendingCount,
    );
  }

  Duration backoffForRetryCount(int retryCount) {
    if (retryCount <= 0) {
      return _baseBackoff;
    }
    if (retryCount >= 32) {
      return _maxBackoff;
    }
    final Duration candidate = _baseBackoff * (1 << retryCount);
    return candidate > _maxBackoff ? _maxBackoff : candidate;
  }

  Future<ReconciliationReport> reconcile({
    required Set<String> acknowledgedIdempotencyKeys,
    bool resetOrphanedInFlight = true,
  }) async {
    await _ensureInitialized();

    final List<String> reconciledActionIds = <String>[];
    final List<String> resetActionIds = <String>[];

    for (int index = 0; index < _actions.length; index++) {
      final QueuedAction action = _actions[index];
      if (acknowledgedIdempotencyKeys.contains(action.idempotencyKey)) {
        if (action.status != QueuedActionStatus.synced) {
          _actions[index] = action.copyWith(
            status: QueuedActionStatus.synced,
          );
          reconciledActionIds.add(action.actionId);
        }
      } else if (resetOrphanedInFlight &&
          action.status == QueuedActionStatus.inFlight) {
        _actions[index] = action.copyWith(
          status: QueuedActionStatus.pending,
        );
        resetActionIds.add(action.actionId);
      }
    }

    if (reconciledActionIds.isNotEmpty || resetActionIds.isNotEmpty) {
      await _persist();
    }

    return ReconciliationReport(
      reconciledActionIds: List<String>.unmodifiable(reconciledActionIds),
      resetActionIds: List<String>.unmodifiable(resetActionIds),
      syncedCount: _countByStatus(QueuedActionStatus.synced),
      pendingCount: _countByStatus(QueuedActionStatus.pending),
      failedCount: _countByStatus(QueuedActionStatus.failed),
      conflictCount: _countByStatus(QueuedActionStatus.conflict),
    );
  }

  Future<int> requeueFailed() async {
    await _ensureInitialized();

    int requeued = 0;
    for (int index = 0; index < _actions.length; index++) {
      final QueuedAction action = _actions[index];
      if (action.status == QueuedActionStatus.failed) {
        _actions[index] = action.copyWith(
          status: QueuedActionStatus.pending,
          retryCount: 0,
        );
        requeued++;
      }
    }
    if (requeued > 0) {
      await _persist();
    }
    return requeued;
  }

  Future<bool> resolveConflict(String actionId) async {
    await _ensureInitialized();

    final int index = _indexOfActionId(actionId);
    if (index < 0) {
      return false;
    }
    if (_actions[index].status != QueuedActionStatus.conflict) {
      return false;
    }
    _actions[index] = _actions[index].copyWith(
      status: QueuedActionStatus.pending,
      retryCount: 0,
    );
    await _persist();
    return true;
  }

  Future<int> clearSynced() async {
    await _ensureInitialized();

    final int before = _actions.length;
    _actions.removeWhere(
      (QueuedAction action) => action.status == QueuedActionStatus.synced,
    );
    final int removed = before - _actions.length;
    if (removed > 0) {
      await _persist();
    }
    return removed;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final List<QueuedAction> restored = await _storageAdapter.restore();
    _actions
      ..clear()
      ..addAll(restored);
    _idSequence = _actions.length;
  }

  Future<void> _persist() async {
    await _storageAdapter.persist(List<QueuedAction>.unmodifiable(_actions));
  }

  bool _isEndpointAllowed(String endpoint) {
    final Set<String>? allowed = _allowedEndpoints;
    return allowed == null || allowed.contains(endpoint);
  }

  int _countByStatus(QueuedActionStatus status) {
    int count = 0;
    for (final QueuedAction action in _actions) {
      if (action.status == status) {
        count++;
      }
    }
    return count;
  }

  int? _indexOfIdempotencyKey(String idempotencyKey) {
    for (int index = 0; index < _actions.length; index++) {
      if (_actions[index].idempotencyKey == idempotencyKey) {
        return index;
      }
    }
    return null;
  }

  int _indexOfActionId(String actionId) {
    for (int index = 0; index < _actions.length; index++) {
      if (_actions[index].actionId == actionId) {
        return index;
      }
    }
    return -1;
  }
}
