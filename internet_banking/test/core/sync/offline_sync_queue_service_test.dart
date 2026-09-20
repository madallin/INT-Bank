import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/sync/offline_sync_queue_service.dart';

class InMemoryStorageAdapter implements OfflineSyncStorageAdapter {
  List<QueuedAction> stored = <QueuedAction>[];
  int persistCalls = 0;

  @override
  Future<List<QueuedAction>> restore() async =>
      List<QueuedAction>.from(stored);

  @override
  Future<void> persist(List<QueuedAction> actions) async {
    persistCalls++;
    stored = List<QueuedAction>.from(actions);
  }
}

class RecordingNetworkAdapter implements OfflineSyncNetworkAdapter {
  RecordingNetworkAdapter(this.handler);

  final SyncAttemptResult Function(QueuedAction action) handler;
  final List<QueuedAction> sent = <QueuedAction>[];
  int sendCalls = 0;

  @override
  Future<SyncAttemptResult> send(QueuedAction action) async {
    sendCalls++;
    sent.add(action);
    return handler(action);
  }
}

class FakeConnectivityAdapter implements OfflineSyncConnectivityAdapter {
  FakeConnectivityAdapter({this.online = true});

  bool online;

  @override
  bool get isOnline => online;
}

class Harness {
  Harness({
    SyncAttemptResult Function(QueuedAction action)? handler,
    bool online = true,
    InMemoryStorageAdapter? storage,
    Duration baseBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 8),
    int maxRetryAttempts = 3,
    Set<String>? allowedEndpoints,
    DateTime Function()? clock,
  }) {
    this.storage = storage ?? InMemoryStorageAdapter();
    connectivity = FakeConnectivityAdapter(online: online);
    network = RecordingNetworkAdapter(
      handler ?? (QueuedAction action) => const SyncAttemptResult.success(),
    );
    service = OfflineSyncQueueService(
      networkAdapter: network,
      storageAdapter: this.storage,
      connectivityAdapter: connectivity,
      baseBackoff: baseBackoff,
      maxBackoff: maxBackoff,
      maxRetryAttempts: maxRetryAttempts,
      allowedEndpoints: allowedEndpoints,
      clock: clock ?? () => DateTime.utc(2026, 1, 1),
    );
  }

  late final InMemoryStorageAdapter storage;
  late final FakeConnectivityAdapter connectivity;
  late final RecordingNetworkAdapter network;
  late final OfflineSyncQueueService service;

  Future<EnqueueResult> enqueue({
    String endpoint = '/transactions/tag',
    Map<String, Object?> payload = const <String, Object?>{'tag': 'travel'},
    String idempotencyKey = 'key-1',
  }) {
    return service.enqueue(
      endpoint: endpoint,
      payload: payload,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  group('QueuedAction model', () {
    test('defaults to pending with zero retries', () {
      final QueuedAction action = QueuedAction(
        actionId: 'a1',
        endpoint: '/x',
        payload: const <String, Object?>{'k': 'v'},
        idempotencyKey: 'k1',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      expect(action.status, QueuedActionStatus.pending);
      expect(action.retryCount, 0);
    });

    test('toJson and fromJson round trip preserves every field', () {
      final QueuedAction action = QueuedAction(
        actionId: 'a1',
        endpoint: '/budgets/update',
        payload: <String, Object?>{'limit': 500, 'currency': 'RON'},
        idempotencyKey: 'k1',
        timestamp: DateTime.utc(2026, 5, 6, 7, 8, 9),
        retryCount: 2,
        status: QueuedActionStatus.failed,
      );

      final QueuedAction restored = QueuedAction.fromJson(action.toJson());

      expect(restored.actionId, 'a1');
      expect(restored.endpoint, '/budgets/update');
      expect(restored.payload, <String, Object?>{
        'limit': 500,
        'currency': 'RON',
      });
      expect(restored.idempotencyKey, 'k1');
      expect(restored.timestamp, DateTime.utc(2026, 5, 6, 7, 8, 9));
      expect(restored.retryCount, 2);
      expect(restored.status, QueuedActionStatus.failed);
    });

    test('copyWith replaces only the supplied fields', () {
      final QueuedAction action = QueuedAction(
        actionId: 'a1',
        endpoint: '/x',
        payload: const <String, Object?>{'k': 'v'},
        idempotencyKey: 'k1',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      final QueuedAction updated = action.copyWith(
        status: QueuedActionStatus.inFlight,
        retryCount: 4,
      );

      expect(updated.actionId, 'a1');
      expect(updated.idempotencyKey, 'k1');
      expect(updated.status, QueuedActionStatus.inFlight);
      expect(updated.retryCount, 4);
    });
  });

  group('Enqueue and deduplication', () {
    test('enqueue stores a pending action with deterministic id and time', () async {
      final Harness harness = Harness();

      final EnqueueResult result = await harness.enqueue();

      expect(result.status, EnqueueStatus.enqueued);
      expect(result.isEnqueued, isTrue);
      expect(result.action.actionId, 'action-0');
      expect(result.action.status, QueuedActionStatus.pending);
      expect(result.action.timestamp, DateTime.utc(2026, 1, 1));
      expect(harness.service.length, 1);
      expect(harness.storage.persistCalls, 1);
    });

    test('duplicate idempotency key does not enqueue twice', () async {
      final Harness harness = Harness();

      final EnqueueResult first = await harness.enqueue(idempotencyKey: 'dup');
      final EnqueueResult second = await harness.enqueue(idempotencyKey: 'dup');

      expect(first.isEnqueued, isTrue);
      expect(second.isDuplicate, isTrue);
      expect(second.action.actionId, first.action.actionId);
      expect(harness.service.length, 1);
      expect(harness.service.pendingCount, 1);
      expect(harness.storage.persistCalls, 1);
    });

    test('unsafe endpoint is rejected and never stored', () async {
      final Harness harness = Harness(
        allowedEndpoints: <String>{'/transactions/tag'},
      );

      final EnqueueResult result = await harness.enqueue(
        endpoint: '/accounts/nickname',
      );

      expect(result.status, EnqueueStatus.rejectedUnsafe);
      expect(result.isEnqueued, isFalse);
      expect(harness.service.length, 0);
      expect(harness.storage.persistCalls, 0);
    });

    test('null allowedEndpoints permits any safe endpoint', () async {
      final Harness harness = Harness();

      await harness.enqueue(endpoint: '/anything/goes');
      await harness.enqueue(
        endpoint: '/budgets/update',
        idempotencyKey: 'key-2',
      );

      expect(harness.service.length, 2);
    });

    test('explicit actionId and timestamp are honored', () async {
      final Harness harness = Harness();
      final DateTime explicit = DateTime.utc(2030, 3, 4, 5, 6, 7);

      final EnqueueResult result = await harness.enqueue(
        idempotencyKey: 'key-explicit',
      );
      final EnqueueResult explicitResult = await harness.service.enqueue(
        endpoint: '/transactions/tag',
        payload: const <String, Object?>{'tag': 'food'},
        idempotencyKey: 'key-explicit-2',
        actionId: 'custom-id',
        timestamp: explicit,
      );

      expect(result.action.actionId, 'action-0');
      expect(explicitResult.action.actionId, 'custom-id');
      expect(explicitResult.action.timestamp, explicit);
    });
  });

  group('FIFO ordering', () {
    test('actions preserve insertion order', () async {
      final Harness harness = Harness();

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.enqueue(idempotencyKey: 'k2');
      await harness.enqueue(idempotencyKey: 'k3');

      expect(
        harness.service.actions
            .map((QueuedAction action) => action.idempotencyKey)
            .toList(),
        <String>['k1', 'k2', 'k3'],
      );
      expect(
        harness.service.actions
            .map((QueuedAction action) => action.actionId)
            .toList(),
        <String>['action-0', 'action-1', 'action-2'],
      );
    });

    test('drain sends actions sequentially in FIFO order', () async {
      final Harness harness = Harness();

      await harness.enqueue(
        endpoint: '/a',
        idempotencyKey: 'k1',
      );
      await harness.enqueue(
        endpoint: '/b',
        idempotencyKey: 'k2',
      );
      await harness.enqueue(
        endpoint: '/c',
        idempotencyKey: 'k3',
      );

      await harness.service.drain();

      expect(
        harness.network.sent
            .map((QueuedAction action) => action.idempotencyKey)
            .toList(),
        <String>['k1', 'k2', 'k3'],
      );
    });
  });

  group('Offline gating', () {
    test('drain while offline performs no network work', () async {
      final Harness harness = Harness(online: false);

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.enqueue(idempotencyKey: 'k2');

      final DrainReport report = await harness.service.drain();

      expect(report.wasOnline, isFalse);
      expect(harness.network.sendCalls, 0);
      expect(report.skippedActionIds.length, 2);
      expect(report.remainingPendingCount, 2);
      expect(harness.service.pendingCount, 2);
    });

    test('drain resumes once connectivity is restored', () async {
      final Harness harness = Harness(online: false);

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.service.drain();
      expect(harness.network.sendCalls, 0);

      harness.connectivity.online = true;
      final DrainReport report = await harness.service.drain();

      expect(report.wasOnline, isTrue);
      expect(report.syncedActionIds.length, 1);
      expect(harness.service.pendingCount, 0);
    });
  });

  group('Drain outcomes and status transitions', () {
    test('success marks the action synced and exposes inFlight while sending', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => const SyncAttemptResult.success(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      final DrainReport report = await harness.service.drain();

      expect(harness.network.sent.single.status, QueuedActionStatus.inFlight);
      expect(report.syncedActionIds, <String>['action-0']);
      expect(report.processedCount, 1);
      expect(harness.service.actions.single.status, QueuedActionStatus.synced);
      expect(harness.service.pendingCount, 0);
    });

    test('conflict marks conflict and is never silently dropped', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) =>
            const SyncAttemptResult.conflict(message: 'version mismatch'),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      final DrainReport report = await harness.service.drain();

      expect(report.conflictActionIds, <String>['action-0']);
      expect(report.hasFailures, isTrue);
      expect(harness.service.findByActionId('action-0')!.status,
          QueuedActionStatus.conflict);
      expect(harness.service.length, 1);
    });

    test('permanent failure marks failed immediately', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) =>
            const SyncAttemptResult.permanentFailure(message: 'bad request'),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      final DrainReport report = await harness.service.drain();

      expect(report.failedActionIds, <String>['action-0']);
      expect(harness.service.findByActionId('action-0')!.status,
          QueuedActionStatus.failed);
    });

    test('retryable failure increments retry count and schedules backoff', () async {
      final Harness harness = Harness(
        baseBackoff: const Duration(seconds: 2),
        maxBackoff: const Duration(seconds: 30),
        handler: (QueuedAction action) => const SyncAttemptResult.retryable(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      final DrainReport report = await harness.service.drain();

      final QueuedAction action = harness.service.actions.single;
      expect(action.status, QueuedActionStatus.pending);
      expect(action.retryCount, 1);
      expect(
        report.retrySchedules,
        <RetrySchedule>[
          const RetrySchedule(
            actionId: 'action-0',
            attempt: 1,
            delay: Duration(seconds: 2),
          ),
        ],
      );
      expect(report.remainingPendingCount, 1);
    });

    test('retry limit is enforced before marking failed', () async {
      final Harness harness = Harness(
        maxRetryAttempts: 3,
        handler: (QueuedAction action) => const SyncAttemptResult.retryable(),
      );

      await harness.enqueue(idempotencyKey: 'k1');

      await harness.service.drain();
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
      expect(harness.service.actions.single.retryCount, 1);

      await harness.service.drain();
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
      expect(harness.service.actions.single.retryCount, 2);

      final DrainReport third = await harness.service.drain();
      expect(third.failedActionIds, <String>['action-0']);
      expect(harness.service.actions.single.status, QueuedActionStatus.failed);
      expect(harness.service.actions.single.retryCount, 3);
    });

    test('network exception is treated as a retryable failure', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => throw StateError('socket down'),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      final DrainReport report = await harness.service.drain();

      expect(report.retrySchedules.length, 1);
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
      expect(harness.service.actions.single.retryCount, 1);
    });

    test('mixed outcomes produce a complete report', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) {
          switch (action.endpoint) {
            case '/ok':
              return const SyncAttemptResult.success();
            case '/conflict':
              return const SyncAttemptResult.conflict();
            case '/permanent':
              return const SyncAttemptResult.permanentFailure();
            default:
              return const SyncAttemptResult.retryable();
          }
        },
      );

      await harness.enqueue(endpoint: '/ok', idempotencyKey: 'k1');
      await harness.enqueue(endpoint: '/conflict', idempotencyKey: 'k2');
      await harness.enqueue(endpoint: '/permanent', idempotencyKey: 'k3');
      await harness.enqueue(endpoint: '/retry', idempotencyKey: 'k4');

      final DrainReport report = await harness.service.drain();

      expect(report.syncedActionIds.length, 1);
      expect(report.conflictActionIds.length, 1);
      expect(report.failedActionIds.length, 1);
      expect(report.retrySchedules.length, 1);
      expect(report.processedCount, 4);
      expect(report.remainingPendingCount, 1);
    });

    test('already terminal actions are skipped on later drains', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => const SyncAttemptResult.success(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.service.drain();
      final DrainReport second = await harness.service.drain();

      expect(second.processedCount, 0);
      expect(second.skippedActionIds, <String>['action-0']);
      expect(harness.network.sendCalls, 1);
    });
  });

  group('Deterministic exponential backoff', () {
    test('backoff grows exponentially from the base delay', () {
      final Harness harness = Harness(
        baseBackoff: const Duration(seconds: 1),
        maxBackoff: const Duration(seconds: 60),
      );

      expect(
        harness.service.backoffForRetryCount(0),
        const Duration(seconds: 1),
      );
      expect(
        harness.service.backoffForRetryCount(1),
        const Duration(seconds: 2),
      );
      expect(
        harness.service.backoffForRetryCount(2),
        const Duration(seconds: 4),
      );
      expect(
        harness.service.backoffForRetryCount(3),
        const Duration(seconds: 8),
      );
    });

    test('backoff is capped at maxBackoff', () {
      final Harness harness = Harness(
        baseBackoff: const Duration(seconds: 1),
        maxBackoff: const Duration(seconds: 5),
      );

      expect(
        harness.service.backoffForRetryCount(3),
        const Duration(seconds: 5),
      );
      expect(
        harness.service.backoffForRetryCount(40),
        const Duration(seconds: 5),
      );
    });

    test('constructor validates retry and backoff configuration', () {
      expect(
        () => Harness(maxRetryAttempts: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Harness(baseBackoff: Duration.zero),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Harness(
          baseBackoff: const Duration(seconds: 5),
          maxBackoff: const Duration(seconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Persistence adapter integration', () {
    test('every enqueue and drain transition is persisted', () async {
      final Harness harness = Harness();

      await harness.enqueue(idempotencyKey: 'k1');
      expect(harness.storage.persistCalls, 1);

      await harness.service.drain();
      expect(harness.storage.persistCalls, 3);
      expect(harness.storage.stored.single.status, QueuedActionStatus.synced);
    });

    test('initialize restores a previously persisted queue', () async {
      final InMemoryStorageAdapter storage = InMemoryStorageAdapter();
      final DateTime seededTime = DateTime.utc(2026, 2, 2);
      storage.stored = <QueuedAction>[
        QueuedAction(
          actionId: 'seeded',
          endpoint: '/transactions/tag',
          payload: const <String, Object?>{'tag': 'bills'},
          idempotencyKey: 'seeded-key',
          timestamp: seededTime,
        ),
      ];

      final Harness harness = Harness(storage: storage);
      await harness.service.initialize();

      expect(harness.service.length, 1);
      expect(
        harness.service.findByIdempotencyKey('seeded-key')!.payload,
        <String, Object?>{'tag': 'bills'},
      );
    });

    test('deduplication survives restore from storage', () async {
      final InMemoryStorageAdapter storage = InMemoryStorageAdapter();
      storage.stored = <QueuedAction>[
        QueuedAction(
          actionId: 'seeded',
          endpoint: '/transactions/tag',
          payload: const <String, Object?>{'tag': 'bills'},
          idempotencyKey: 'seeded-key',
          timestamp: DateTime.utc(2026, 2, 2),
        ),
      ];

      final Harness harness = Harness(storage: storage);
      final EnqueueResult result = await harness.service.enqueue(
        endpoint: '/transactions/tag',
        payload: const <String, Object?>{'tag': 'bills'},
        idempotencyKey: 'seeded-key',
      );

      expect(result.isDuplicate, isTrue);
      expect(harness.service.length, 1);
    });
  });

  group('Reconciliation', () {
    test('acknowledged idempotency keys are reconciled to synced', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => const SyncAttemptResult.conflict(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.service.drain();
      expect(harness.service.actions.single.status, QueuedActionStatus.conflict);

      final ReconciliationReport report = await harness.service.reconcile(
        acknowledgedIdempotencyKeys: <String>{'k1'},
      );

      expect(report.reconciledActionIds, <String>['action-0']);
      expect(report.syncedCount, 1);
      expect(report.conflictCount, 0);
      expect(harness.service.actions.single.status, QueuedActionStatus.synced);
    });

    test('orphaned inFlight actions are reset to pending', () async {
      final InMemoryStorageAdapter storage = InMemoryStorageAdapter();
      storage.stored = <QueuedAction>[
        QueuedAction(
          actionId: 'orphan',
          endpoint: '/transactions/tag',
          payload: const <String, Object?>{'tag': 'bills'},
          idempotencyKey: 'orphan-key',
          timestamp: DateTime.utc(2026, 2, 2),
          status: QueuedActionStatus.inFlight,
        ),
      ];

      final Harness harness = Harness(storage: storage);
      final ReconciliationReport report = await harness.service.reconcile(
        acknowledgedIdempotencyKeys: const <String>{},
      );

      expect(report.resetActionIds, <String>['orphan']);
      expect(report.pendingCount, 1);
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
    });

    test('orphaned inFlight actions can be left untouched', () async {
      final InMemoryStorageAdapter storage = InMemoryStorageAdapter();
      storage.stored = <QueuedAction>[
        QueuedAction(
          actionId: 'orphan',
          endpoint: '/transactions/tag',
          payload: const <String, Object?>{'tag': 'bills'},
          idempotencyKey: 'orphan-key',
          timestamp: DateTime.utc(2026, 2, 2),
          status: QueuedActionStatus.inFlight,
        ),
      ];

      final Harness harness = Harness(storage: storage);
      final ReconciliationReport report = await harness.service.reconcile(
        acknowledgedIdempotencyKeys: const <String>{},
        resetOrphanedInFlight: false,
      );

      expect(report.resetActionIds, isEmpty);
      expect(harness.service.actions.single.status, QueuedActionStatus.inFlight);
    });

    test('reconciliation report counts every status bucket', () async {
      final Harness harness = Harness();

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.enqueue(idempotencyKey: 'k2');

      final ReconciliationReport report = await harness.service.reconcile(
        acknowledgedIdempotencyKeys: <String>{'k1'},
      );

      expect(report.reconciledActionIds, <String>['action-0']);
      expect(report.syncedCount, 1);
      expect(report.pendingCount, 1);
      expect(report.failedCount, 0);
      expect(report.conflictCount, 0);
      expect(report.totalCount, 2);
    });
  });

  group('Manual recovery helpers', () {
    test('requeueFailed resets failed actions back to pending', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) =>
            const SyncAttemptResult.permanentFailure(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.service.drain();
      expect(harness.service.actions.single.status, QueuedActionStatus.failed);

      final int requeued = await harness.service.requeueFailed();

      expect(requeued, 1);
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
      expect(harness.service.actions.single.retryCount, 0);
    });

    test('resolveConflict reopens a conflicted action', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => const SyncAttemptResult.conflict(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.service.drain();

      final bool resolved = await harness.service.resolveConflict('action-0');

      expect(resolved, isTrue);
      expect(harness.service.actions.single.status, QueuedActionStatus.pending);
    });

    test('resolveConflict ignores unknown and non-conflict actions', () async {
      final Harness harness = Harness();

      await harness.enqueue(idempotencyKey: 'k1');

      expect(await harness.service.resolveConflict('missing'), isFalse);
      expect(await harness.service.resolveConflict('action-0'), isFalse);
    });

    test('clearSynced removes synced actions only', () async {
      final Harness harness = Harness(
        handler: (QueuedAction action) => const SyncAttemptResult.success(),
      );

      await harness.enqueue(idempotencyKey: 'k1');
      await harness.enqueue(idempotencyKey: 'k2');
      await harness.service.drain();

      final int removed = await harness.service.clearSynced();

      expect(removed, 2);
      expect(harness.service.length, 0);
      expect(harness.storage.stored, isEmpty);
    });
  });
}
