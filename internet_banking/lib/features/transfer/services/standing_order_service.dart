enum Frequency { weekly, biWeekly, monthly, quarterly, annually }

enum StandingOrderStatus { active, paused, completed, cancelled }

class StandingOrder {
  final String id;
  final String sourceAccountId;
  final String destinationIban;
  final String beneficiaryName;
  final double amount;
  final String currency;
  final Frequency frequency;
  final DateTime startDate;
  final DateTime nextExecutionDate;
  final DateTime? endDate;
  final StandingOrderStatus status;
  final String? description;

  const StandingOrder({
    required this.id,
    required this.sourceAccountId,
    required this.destinationIban,
    required this.beneficiaryName,
    required this.amount,
    this.currency = 'RON',
    required this.frequency,
    required this.startDate,
    required this.nextExecutionDate,
    this.endDate,
    this.status = StandingOrderStatus.active,
    this.description,
  });

  StandingOrder copyWith({
    String? id,
    String? sourceAccountId,
    String? destinationIban,
    String? beneficiaryName,
    double? amount,
    String? currency,
    Frequency? frequency,
    DateTime? startDate,
    DateTime? nextExecutionDate,
    DateTime? endDate,
    StandingOrderStatus? status,
    String? description,
  }) {
    return StandingOrder(
      id: id ?? this.id,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationIban: destinationIban ?? this.destinationIban,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StandingOrder &&
        other.id == id &&
        other.sourceAccountId == sourceAccountId &&
        other.destinationIban == destinationIban &&
        other.beneficiaryName == beneficiaryName &&
        other.amount == amount &&
        other.currency == currency &&
        other.frequency == frequency &&
        other.startDate == startDate &&
        other.nextExecutionDate == nextExecutionDate &&
        other.endDate == endDate &&
        other.status == status &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(
        id,
        sourceAccountId,
        destinationIban,
        beneficiaryName,
        amount,
        currency,
        frequency,
        startDate,
        nextExecutionDate,
        endDate,
        status,
        description,
      );

  @override
  String toString() => 'StandingOrder(id: $id, amount: $amount, '
      'frequency: $frequency, nextExecutionDate: $nextExecutionDate, '
      'status: $status)';
}

class StandingOrderService {
  final DateTime Function() _now;

  StandingOrderService({DateTime Function()? now})
      : _now = now ?? (() => DateTime.now());

  static double _round2(double value) => (value * 100).round() / 100;

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  DateTime _construct(
    DateTime reference,
    int year,
    int month,
    int day,
  ) {
    if (reference.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        reference.hour,
        reference.minute,
        reference.second,
        reference.millisecond,
        reference.microsecond,
      );
    }
    return DateTime(
      year,
      month,
      day,
      reference.hour,
      reference.minute,
      reference.second,
      reference.millisecond,
      reference.microsecond,
    );
  }

  DateTime _addMonthsClamped(DateTime current, int monthsToAdd, int anchorDay) {
    int targetMonth = current.month + monthsToAdd;
    int targetYear = current.year + (targetMonth - 1) ~/ 12;
    targetMonth = ((targetMonth - 1) % 12) + 1;
    final int lastDay = _daysInMonth(targetYear, targetMonth);
    final int day = anchorDay > lastDay ? lastDay : anchorDay;
    return _construct(current, targetYear, targetMonth, day);
  }

  DateTime calculateNextExecutionDate(
    DateTime current,
    Frequency frequency, {
    int? anchorDay,
  }) {
    final int anchor = anchorDay ?? current.day;
    if (anchorDay != null && (anchorDay < 1 || anchorDay > 31)) {
      throw ArgumentError.value(
        anchorDay,
        'anchorDay',
        'anchorDay must be between 1 and 31.',
      );
    }

    switch (frequency) {
      case Frequency.weekly:
        final DateTime base =
            DateTime(current.year, current.month, current.day + 7);
        return _construct(current, base.year, base.month, base.day);
      case Frequency.biWeekly:
        final DateTime base =
            DateTime(current.year, current.month, current.day + 14);
        return _construct(current, base.year, base.month, base.day);
      case Frequency.monthly:
        return _addMonthsClamped(current, 1, anchor);
      case Frequency.quarterly:
        return _addMonthsClamped(current, 3, anchor);
      case Frequency.annually:
        return _addMonthsClamped(current, 12, anchor);
    }
  }

  bool isValidRoIban(String iban) {
    final String cleaned = iban.replaceAll(' ', '').toUpperCase();
    if (cleaned.length != 24) return false;
    if (!RegExp(r'^RO[0-9]{2}[A-Z0-9]{20}$').hasMatch(cleaned)) return false;

    final String rearranged = cleaned.substring(4) + cleaned.substring(0, 4);
    int remainder = 0;
    for (int i = 0; i < rearranged.length; i++) {
      final int codeUnit = rearranged.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        remainder = (remainder * 10 + (codeUnit - 48)) % 97;
      } else if (codeUnit >= 65 && codeUnit <= 90) {
        remainder = (remainder * 100 + (codeUnit - 55)) % 97;
      } else {
        return false;
      }
    }
    return remainder == 1;
  }

  StandingOrder create({
    required String id,
    required String sourceAccountId,
    required String destinationIban,
    required String beneficiaryName,
    required double amount,
    String currency = 'RON',
    required Frequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty.');
    }
    if (sourceAccountId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceAccountId,
        'sourceAccountId',
        'sourceAccountId must not be empty.',
      );
    }
    if (beneficiaryName.trim().isEmpty) {
      throw ArgumentError.value(
        beneficiaryName,
        'beneficiaryName',
        'beneficiaryName must not be empty.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'amount must be a finite value greater than zero.',
      );
    }
    if (currency.trim().isEmpty) {
      throw ArgumentError.value(
        currency,
        'currency',
        'currency must not be empty.',
      );
    }
    if (!isValidRoIban(destinationIban)) {
      throw ArgumentError.value(
        destinationIban,
        'destinationIban',
        'destinationIban must be a valid RO IBAN.',
      );
    }
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'endDate must not be before startDate.',
      );
    }

    return StandingOrder(
      id: id,
      sourceAccountId: sourceAccountId,
      destinationIban: destinationIban.replaceAll(' ', '').toUpperCase(),
      beneficiaryName: beneficiaryName,
      amount: _round2(amount),
      currency: currency,
      frequency: frequency,
      startDate: startDate,
      nextExecutionDate: startDate,
      endDate: endDate,
      status: StandingOrderStatus.active,
      description: description,
    );
  }

  StandingOrder pause(StandingOrder order) {
    if (order.status != StandingOrderStatus.active) {
      throw StateError(
        'Only active standing orders can be paused. Current status: '
        '${order.status.name}.',
      );
    }
    return order.copyWith(status: StandingOrderStatus.paused);
  }

  StandingOrder resume(StandingOrder order, {DateTime? from}) {
    if (order.status != StandingOrderStatus.paused) {
      throw StateError(
        'Only paused standing orders can be resumed. Current status: '
        '${order.status.name}.',
      );
    }

    final DateTime base = from ?? _now();
    final int anchor = order.startDate.day;
    DateTime next = order.nextExecutionDate;
    int guard = 0;
    while (next.isBefore(base)) {
      next = calculateNextExecutionDate(
        next,
        order.frequency,
        anchorDay: anchor,
      );
      guard++;
      if (guard > 100000) {
        throw StateError(
          'Unable to recompute a future execution date for order ${order.id}.',
        );
      }
    }

    return order.copyWith(
      status: StandingOrderStatus.active,
      nextExecutionDate: next,
    );
  }

  StandingOrder cancel(StandingOrder order) {
    if (order.status == StandingOrderStatus.completed ||
        order.status == StandingOrderStatus.cancelled) {
      throw StateError(
        'Standing order ${order.id} is already ${order.status.name} and '
        'cannot be cancelled.',
      );
    }
    return order.copyWith(status: StandingOrderStatus.cancelled);
  }

  StandingOrder complete(StandingOrder order, {DateTime? asOf}) {
    if (order.status == StandingOrderStatus.completed ||
        order.status == StandingOrderStatus.cancelled) {
      throw StateError(
        'Standing order ${order.id} is already ${order.status.name}.',
      );
    }
    final DateTime? endDate = order.endDate;
    if (endDate == null) {
      throw StateError(
        'Standing order ${order.id} has no endDate and cannot be completed.',
      );
    }
    final DateTime reference = asOf ?? _now();
    if (reference.isBefore(endDate)) {
      throw StateError(
        'Standing order ${order.id} endDate has not been reached yet.',
      );
    }
    return order.copyWith(status: StandingOrderStatus.completed);
  }

  int projectedAnnualExecutionCount(Frequency frequency) {
    switch (frequency) {
      case Frequency.weekly:
        return 52;
      case Frequency.biWeekly:
        return 26;
      case Frequency.monthly:
        return 12;
      case Frequency.quarterly:
        return 4;
      case Frequency.annually:
        return 1;
    }
  }

  double projectedAnnualExecutionSum(StandingOrder order) =>
      _round2(order.amount * projectedAnnualExecutionCount(order.frequency));
}
