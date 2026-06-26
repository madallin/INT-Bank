class CardModel
{
  final int id;
  final int accountId;
  final String cardNumber;
  final String cardHolder;
  final String expiryDate;
  final String cvv;
  final String cardType;
  final double spendingLimit;
  final bool isBlocked;
  final String status;
  final String? pin;

  CardModel({
    required this.id,
    required this.accountId,
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
    required this.cvv,
    required this.cardType,
    this.spendingLimit = 0,
    this.isBlocked = false,
    this.status = 'active',
    this.pin,
  });

  factory CardModel.fromJson(Map<String, dynamic> json)
  {
    return CardModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      accountId: json['accountId'] is int
          ? json['accountId']
          : int.parse(json['accountId'].toString()),
      cardNumber: json['cardNumber'] ?? '',
      cardHolder: json['cardHolder'] ?? '',
      expiryDate: json['expiryDate'] ?? '',
      cvv: json['cvv'] ?? '',
      cardType: json['cardType'] ?? 'debit',
      spendingLimit: (json['spendingLimit'] as num?)?.toDouble() ?? 0,
      isBlocked: json['isBlocked'] ?? false,
      status: json['status'] ?? 'active',
      pin: json['pin'],
    );
  }

  CardModel copyWith({
    int? id,
    int? accountId,
    String? cardNumber,
    String? cardHolder,
    String? expiryDate,
    String? cvv,
    String? cardType,
    double? spendingLimit,
    bool? isBlocked,
    String? status,
    String? pin,
    String? fullNumber,
    String? expiry,
  })
  {
    return CardModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      cardNumber: fullNumber ?? cardNumber ?? this.cardNumber,
      cardHolder: cardHolder ?? this.cardHolder,
      expiryDate: expiry ?? expiryDate ?? this.expiryDate,
      cvv: cvv ?? this.cvv,
      cardType: cardType ?? this.cardType,
      spendingLimit: spendingLimit ?? this.spendingLimit,
      isBlocked: isBlocked ?? this.isBlocked,
      status: status ?? this.status,
      pin: pin ?? this.pin,
    );
  }

  Map<String, dynamic> toJson()
  {
    return {
      'id': id,
      'accountId': accountId,
      'cardNumber': cardNumber,
      'cardHolder': cardHolder,
      'expiryDate': expiryDate,
      'cvv': cvv,
      'cardType': cardType,
      'spendingLimit': spendingLimit,
      'isBlocked': isBlocked,
      'status': status,
      'pin': pin,
    };
  }

  String get fullNumber => cardNumber;

  String get last4
  {
    if(cardNumber.length >= 4)
    {
      return cardNumber.substring(cardNumber.length - 4);
    }
    return cardNumber;
  }

  String get expiry => expiryDate;

  String get detinator => cardHolder;

  String get maskedCardNumber
  {
    if(cardNumber.length >= 8)
    {
      return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
    }
    return cardNumber;
  }

  String get maskedCVV => '***';
}
