import 'package:flutter/foundation.dart';

/// Reason code selected by a cardholder when raising a transaction dispute.
enum DisputeReason {
  unrecognizedTransaction,
  duplicateCharge,
  incorrectAmount,
  goodsNotReceived,
  atmCashNotDispensed,
}

/// Lifecycle status of a dispute ticket.
enum DisputeStatus {
  submitted,
  underReview,
  provisionalCreditIssued,
  resolved,
  rejected,
}

/// Immutable result describing whether a transaction may be disputed.
@immutable
class DisputeEligibility {
  final bool isEligible;
  final bool isExpired;
  final int daysSinceTransaction;
  final bool shouldSuggestCardFreeze;

  const DisputeEligibility({
    required this.isEligible,
    required this.isExpired,
    required this.daysSinceTransaction,
    required this.shouldSuggestCardFreeze,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DisputeEligibility &&
        other.isEligible == isEligible &&
        other.isExpired == isExpired &&
        other.daysSinceTransaction == daysSinceTransaction &&
        other.shouldSuggestCardFreeze == shouldSuggestCardFreeze;
  }

  @override
  int get hashCode => Object.hash(
        isEligible,
        isExpired,
        daysSinceTransaction,
        shouldSuggestCardFreeze,
      );

  @override
  String toString() =>
      'DisputeEligibility(isEligible: $isEligible, isExpired: $isExpired, '
      'daysSinceTransaction: $daysSinceTransaction, '
      'shouldSuggestCardFreeze: $shouldSuggestCardFreeze)';
}

/// Immutable record of a single transaction dispute and its progress.
@immutable
class DisputeTicket {
  final String id;
  final String transactionId;
  final DisputeReason reason;
  final DisputeStatus status;
  final DateTime openedAt;
  final DateTime updatedAt;
  final bool isCardFrozenSuggested;

  const DisputeTicket({
    required this.id,
    required this.transactionId,
    required this.reason,
    required this.status,
    required this.openedAt,
    required this.updatedAt,
    required this.isCardFrozenSuggested,
  });

  DisputeTicket copyWith({
    String? id,
    String? transactionId,
    DisputeReason? reason,
    DisputeStatus? status,
    DateTime? openedAt,
    DateTime? updatedAt,
    bool? isCardFrozenSuggested,
  }) {
    return DisputeTicket(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      openedAt: openedAt ?? this.openedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCardFrozenSuggested: isCardFrozenSuggested ?? this.isCardFrozenSuggested,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DisputeTicket &&
        other.id == id &&
        other.transactionId == transactionId &&
        other.reason == reason &&
        other.status == status &&
        other.openedAt == openedAt &&
        other.updatedAt == updatedAt &&
        other.isCardFrozenSuggested == isCardFrozenSuggested;
  }

  @override
  int get hashCode => Object.hash(
        id,
        transactionId,
        reason,
        status,
        openedAt,
        updatedAt,
        isCardFrozenSuggested,
      );

  @override
  String toString() =>
      'DisputeTicket(id: $id, transactionId: $transactionId, reason: $reason, '
      'status: $status, isCardFrozenSuggested: $isCardFrozenSuggested)';
}

/// Domain service implementing the transaction dispute and chargeback flow.
///
/// Every time dependent operation accepts the current time explicitly so the
/// behaviour is fully deterministic and reproducible in tests.
class TransactionDisputeService {
  const TransactionDisputeService();

  /// Visa and Mastercard scheme window within which a dispute must be raised.
  static const int schemeWindowDays = 120;

  /// Evaluates whether a transaction dated [transactionDate] may be disputed
  /// at [now].
  ///
  /// The elapsed time is measured in whole UTC days so that partial days do not
  /// inflate the count. A transaction dated in the future is never eligible.
  /// When [reason] is [DisputeReason.unrecognizedTransaction] the caller is
  /// advised to suggest freezing the card.
  DisputeEligibility checkEligibility({
    required DateTime transactionDate,
    required DateTime now,
    DisputeReason? reason,
  }) {
    final int daysSinceTransaction = _wholeDaysBetween(transactionDate, now);
    final bool isExpired = daysSinceTransaction > schemeWindowDays;
    final bool isEligible =
        daysSinceTransaction >= 0 && daysSinceTransaction <= schemeWindowDays;
    return DisputeEligibility(
      isEligible: isEligible,
      isExpired: isExpired,
      daysSinceTransaction: daysSinceTransaction,
      shouldSuggestCardFreeze: reason == DisputeReason.unrecognizedTransaction,
    );
  }

  /// Opens a new dispute ticket for [transactionId].
  ///
  /// Throws a [StateError] when the transaction is ineligible or has fallen
  /// outside the scheme window. The ticket identifier is deterministic and
  /// derived from the transaction, reason and [now].
  DisputeTicket openDispute({
    required String transactionId,
    required DisputeReason reason,
    required DateTime transactionDate,
    required DateTime now,
  }) {
    final DisputeEligibility eligibility = checkEligibility(
      transactionDate: transactionDate,
      now: now,
      reason: reason,
    );
    if (!eligibility.isEligible) {
      throw StateError(
        'Transaction $transactionId is not eligible for dispute '
        '(daysSinceTransaction: ${eligibility.daysSinceTransaction}, '
        'isExpired: ${eligibility.isExpired}).',
      );
    }
    return DisputeTicket(
      id: _buildTicketId(transactionId, reason, now),
      transactionId: transactionId,
      reason: reason,
      status: DisputeStatus.submitted,
      openedAt: now,
      updatedAt: now,
      isCardFrozenSuggested: reason == DisputeReason.unrecognizedTransaction,
    );
  }

  /// Moves [ticket] to [next], updating the modification timestamp to [now].
  ///
  /// Throws a [StateError] for any transition that [canTransition] rejects,
  /// which includes every transition out of the terminal states.
  DisputeTicket transition(
    DisputeTicket ticket,
    DisputeStatus next, {
    required DateTime now,
  }) {
    if (!canTransition(ticket.status, next)) {
      throw StateError(
        'Invalid dispute transition from ${ticket.status} to $next '
        'for ticket ${ticket.id}.',
      );
    }
    return ticket.copyWith(status: next, updatedAt: now);
  }

  /// Reports whether a dispute may move from [from] to [to].
  ///
  /// The allowed graph is:
  /// submitted -> underReview | rejected
  /// underReview -> provisionalCreditIssued | rejected
  /// provisionalCreditIssued -> resolved | rejected
  /// resolved and rejected are terminal.
  bool canTransition(DisputeStatus from, DisputeStatus to) {
    switch (from) {
      case DisputeStatus.submitted:
        return to == DisputeStatus.underReview || to == DisputeStatus.rejected;
      case DisputeStatus.underReview:
        return to == DisputeStatus.provisionalCreditIssued ||
            to == DisputeStatus.rejected;
      case DisputeStatus.provisionalCreditIssued:
        return to == DisputeStatus.resolved || to == DisputeStatus.rejected;
      case DisputeStatus.resolved:
      case DisputeStatus.rejected:
        return false;
    }
  }

  /// Returns the number of whole UTC days between [from] and [to].
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final DateTime fromUtc = DateTime.utc(from.year, from.month, from.day);
    final DateTime toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  /// Builds a stable ticket identifier from [transactionId], [reason] and
  /// [now] using a 32-bit FNV-1a hash of the normalized key material.
  static String _buildTicketId(
    String transactionId,
    DisputeReason reason,
    DateTime now,
  ) {
    final String seed = '$transactionId|${reason.name}|'
        '${now.toUtc().toIso8601String()}';
    final int hash = _fnv1a32(seed);
    return 'DSP-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// Computes the 32-bit FNV-1a hash of [input].
  static int _fnv1a32(String input) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
