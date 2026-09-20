import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum SplitMethod { equally, customAmounts, percentages }

@immutable
class SplitParticipant {
  final String id;
  final String name;
  final double? customAmount;
  final double? percentage;
  final bool paidBy;

  const SplitParticipant({
    required this.id,
    required this.name,
    this.customAmount,
    this.percentage,
    this.paidBy = false,
  });

  SplitParticipant copyWith({
    String? id,
    String? name,
    double? customAmount,
    double? percentage,
    bool? paidBy,
  }) {
    return SplitParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      customAmount: customAmount ?? this.customAmount,
      percentage: percentage ?? this.percentage,
      paidBy: paidBy ?? this.paidBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SplitParticipant &&
        other.id == id &&
        other.name == name &&
        other.customAmount == customAmount &&
        other.percentage == percentage &&
        other.paidBy == paidBy;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, customAmount, percentage, paidBy);

  @override
  String toString() =>
      'SplitParticipant(id: $id, name: $name, customAmount: $customAmount, '
      'percentage: $percentage, paidBy: $paidBy)';
}

@immutable
class SplitShare {
  final String participantId;
  final String participantName;
  final double amount;
  final int cents;
  final double percentage;

  const SplitShare({
    required this.participantId,
    required this.participantName,
    required this.amount,
    required this.cents,
    required this.percentage,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SplitShare &&
        other.participantId == participantId &&
        other.participantName == participantName &&
        other.amount == amount &&
        other.cents == cents &&
        other.percentage == percentage;
  }

  @override
  int get hashCode => Object.hash(
        participantId,
        participantName,
        amount,
        cents,
        percentage,
      );

  @override
  String toString() =>
      'SplitShare(participantId: $participantId, amount: $amount, '
      'cents: $cents, percentage: $percentage)';
}

@immutable
class BillSplitCalculation {
  final double totalAmount;
  final String currency;
  final SplitMethod method;
  final List<SplitShare> shares;

  const BillSplitCalculation({
    required this.totalAmount,
    this.currency = 'RON',
    required this.method,
    required this.shares,
  });

  int get totalCents => (totalAmount * 100).round();

  int get sumOfSharesCents =>
      shares.fold<int>(0, (int sum, SplitShare share) => sum + share.cents);

  double get sumOfShares => sumOfSharesCents / 100;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BillSplitCalculation) return false;
    if (other.totalAmount != totalAmount ||
        other.currency != currency ||
        other.method != method ||
        other.shares.length != shares.length) {
      return false;
    }
    for (int i = 0; i < shares.length; i++) {
      if (other.shares[i] != shares[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(totalAmount, currency, method, Object.hashAll(shares));

  @override
  String toString() => 'BillSplitCalculation(totalAmount: $totalAmount, '
      'currency: $currency, method: $method, shares: $shares)';
}

@immutable
class PaymentRequestData {
  final String requestId;
  final String payerId;
  final String debtorId;
  final String debtorName;
  final double amount;
  final String currency;
  final String note;
  final DateTime createdAt;

  const PaymentRequestData({
    required this.requestId,
    required this.payerId,
    required this.debtorId,
    required this.debtorName,
    required this.amount,
    required this.currency,
    this.note = '',
    required this.createdAt,
  });

  PaymentRequestData copyWith({
    String? requestId,
    String? payerId,
    String? debtorId,
    String? debtorName,
    double? amount,
    String? currency,
    String? note,
    DateTime? createdAt,
  }) {
    return PaymentRequestData(
      requestId: requestId ?? this.requestId,
      payerId: payerId ?? this.payerId,
      debtorId: debtorId ?? this.debtorId,
      debtorName: debtorName ?? this.debtorName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequestData &&
        other.requestId == requestId &&
        other.payerId == payerId &&
        other.debtorId == debtorId &&
        other.debtorName == debtorName &&
        other.amount == amount &&
        other.currency == currency &&
        other.note == note &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        requestId,
        payerId,
        debtorId,
        debtorName,
        amount,
        currency,
        note,
        createdAt,
      );

  @override
  String toString() => 'PaymentRequestData(requestId: $requestId, '
      'payerId: $payerId, debtorId: $debtorId, amount: $amount, '
      'currency: $currency, note: $note, createdAt: $createdAt)';
}

class BillSplitService {
  BillSplitService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const double _percentageEpsilon = 1e-9;

  BillSplitCalculation splitEqually(
    double total,
    List<SplitParticipant> participants, {
    String currency = 'RON',
  }) {
    _validateTotal(total);
    _validateParticipants(participants);

    final int totalCents = _toCents(total);
    final int count = participants.length;
    final int base = totalCents ~/ count;
    final int remainder = totalCents % count;
    final List<int> cents = List<int>.generate(
      count,
      (int index) => base + (index < remainder ? 1 : 0),
      growable: false,
    );

    return _buildCalculation(
      totalCents,
      participants,
      cents,
      SplitMethod.equally,
      currency,
    );
  }

  BillSplitCalculation splitCustomAmounts(
    double total,
    List<SplitParticipant> participants, {
    String currency = 'RON',
  }) {
    _validateTotal(total);
    _validateParticipants(participants);

    final int totalCents = _toCents(total);
    final List<int> cents = <int>[];
    for (final SplitParticipant participant in participants) {
      final double? custom = participant.customAmount;
      if (custom == null) {
        throw ArgumentError(
          'Participant ${participant.id} is missing a custom amount.',
        );
      }
      if (!custom.isFinite || custom <= 0) {
        throw ArgumentError.value(
          custom,
          'customAmount',
          'Custom amount for ${participant.id} must be greater than zero.',
        );
      }
      final int value = _toCents(custom);
      if (value <= 0) {
        throw ArgumentError.value(
          custom,
          'customAmount',
          'Custom amount for ${participant.id} must be at least 0.01.',
        );
      }
      cents.add(value);
    }

    final int sumCents =
        cents.fold<int>(0, (int sum, int value) => sum + value);
    if (sumCents != totalCents) {
      throw ArgumentError(
        'Custom amounts do not match the total: expected '
        '${_formatCents(totalCents)} but got ${_formatCents(sumCents)}.',
      );
    }

    return _buildCalculation(
      totalCents,
      participants,
      cents,
      SplitMethod.customAmounts,
      currency,
    );
  }

  BillSplitCalculation splitByPercentages(
    double total,
    List<SplitParticipant> participants, {
    String currency = 'RON',
  }) {
    _validateTotal(total);
    _validateParticipants(participants);

    final int totalCents = _toCents(total);
    double percentageSum = 0.0;
    for (final SplitParticipant participant in participants) {
      final double? percentage = participant.percentage;
      if (percentage == null) {
        throw ArgumentError(
          'Participant ${participant.id} is missing a percentage.',
        );
      }
      if (!percentage.isFinite || percentage <= 0) {
        throw ArgumentError.value(
          percentage,
          'percentage',
          'Percentage for ${participant.id} must be greater than zero.',
        );
      }
      percentageSum += percentage;
    }

    if ((percentageSum - 100.0).abs() > _percentageEpsilon) {
      throw ArgumentError(
        'Percentages must sum to exactly 100.0 but summed to $percentageSum.',
      );
    }

    final List<double> exacts = participants
        .map((SplitParticipant participant) =>
            totalCents * participant.percentage! / 100.0)
        .toList(growable: false);
    final List<int> cents = exacts
        .map((double value) => value.floor())
        .toList(growable: true);

    int remaining =
        totalCents - cents.fold<int>(0, (int sum, int value) => sum + value);

    final List<int> order = List<int>.generate(
      participants.length,
      (int index) => index,
      growable: false,
    );
    order.sort((int a, int b) {
      final double remainderA = exacts[a] - exacts[a].floorToDouble();
      final double remainderB = exacts[b] - exacts[b].floorToDouble();
      final int byRemainder = remainderB.compareTo(remainderA);
      if (byRemainder != 0) return byRemainder;
      return a.compareTo(b);
    });

    int cursor = 0;
    while (remaining > 0) {
      cents[order[cursor % order.length]] += 1;
      remaining -= 1;
      cursor += 1;
    }

    return _buildCalculation(
      totalCents,
      participants,
      cents,
      SplitMethod.percentages,
      currency,
    );
  }

  List<PaymentRequestData> generatePaymentRequests(
    BillSplitCalculation calculation, {
    required String payerId,
    String? note,
  }) {
    if (payerId.isEmpty) {
      throw ArgumentError.value(
        payerId,
        'payerId',
        'Payer id must not be empty.',
      );
    }
    if (calculation.shares.isEmpty) {
      throw ArgumentError('Calculation must contain at least one share.');
    }

    final DateTime createdAt = _now();
    final String description = note ?? '';
    final List<PaymentRequestData> requests = <PaymentRequestData>[];
    for (final SplitShare share in calculation.shares) {
      if (share.participantId == payerId) continue;
      requests.add(
        PaymentRequestData(
          requestId: _requestId(calculation, share, payerId),
          payerId: payerId,
          debtorId: share.participantId,
          debtorName: share.participantName,
          amount: share.cents / 100,
          currency: calculation.currency,
          note: description,
          createdAt: createdAt,
        ),
      );
    }
    return requests;
  }

  BillSplitCalculation _buildCalculation(
    int totalCents,
    List<SplitParticipant> participants,
    List<int> cents,
    SplitMethod method,
    String currency,
  ) {
    final List<SplitShare> shares = List<SplitShare>.generate(
      participants.length,
      (int index) {
        final int value = cents[index];
        return SplitShare(
          participantId: participants[index].id,
          participantName: participants[index].name,
          amount: value / 100,
          cents: value,
          percentage: totalCents == 0
              ? 0.0
              : _roundTo(value * 100.0 / totalCents, 6),
        );
      },
      growable: false,
    );

    return BillSplitCalculation(
      totalAmount: totalCents / 100,
      currency: currency,
      method: method,
      shares: shares,
    );
  }

  String _requestId(
    BillSplitCalculation calculation,
    SplitShare share,
    String payerId,
  ) {
    final String input = '${calculation.method.name}'
        '|${calculation.totalCents}'
        '|${calculation.currency}'
        '|$payerId'
        '|${share.participantId}'
        '|${share.cents}';
    return _fnv1a32Hex(input);
  }

  void _validateTotal(double total) {
    if (!total.isFinite || total <= 0) {
      throw ArgumentError.value(
        total,
        'total',
        'Total amount must be greater than zero.',
      );
    }
  }

  void _validateParticipants(List<SplitParticipant> participants) {
    if (participants.isEmpty) {
      throw ArgumentError.value(
        participants,
        'participants',
        'At least one participant is required.',
      );
    }
    final Set<String> ids = <String>{};
    for (final SplitParticipant participant in participants) {
      if (participant.id.isEmpty) {
        throw ArgumentError('Participant id must not be empty.');
      }
      if (!ids.add(participant.id)) {
        throw ArgumentError(
          'Duplicate participant id: ${participant.id}.',
        );
      }
      if (participant.name.isEmpty) {
        throw ArgumentError(
          'Participant name for ${participant.id} must not be empty.',
        );
      }
    }
  }

  int _toCents(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'amount',
        'Amount must be a finite number.',
      );
    }
    return (value * 100).round();
  }

  static double _roundTo(double value, int decimals) {
    final double factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  static String _formatCents(int cents) => (cents / 100).toStringAsFixed(2);
}

String _fnv1a32Hex(String input) {
  int hash = 0x811c9dc5;
  for (final int unit in input.codeUnits) {
    hash ^= unit & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
