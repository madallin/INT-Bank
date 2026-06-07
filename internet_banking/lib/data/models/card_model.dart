// lib/data/models/card_model.dart
// Data model for bank cards

class CardModel {
  final int id;
  final String token;
  final String detinator;
  final String last4;
  final String? expiry;
  final int? accountId;
  final String? fullNumber;
  final String? cvv;

  CardModel({
    required this.id,
    required this.token,
    required this.detinator,
    required this.last4,
    this.expiry,
    this.accountId,
    this.fullNumber,
    this.cvv,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as int,
      token: json['token'] as String,
      detinator: json['detinator'] as String,
      last4: (json['last4'] as String?) ?? '****',
      expiry: json['expiry'] as String?,
      accountId: json['accountId'] as int?,
      fullNumber: json['fullNumber'] as String?,
      cvv: json['cvv'] as String?,
    );
  }

  CardModel copyWith({String? fullNumber, String? cvv, String? expiry}) {
    return CardModel(
      id: id,
      token: token,
      detinator: detinator,
      last4: last4,
      expiry: expiry ?? this.expiry,
      accountId: accountId,
      fullNumber: fullNumber,
      cvv: cvv,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'detinator': detinator,
      'last4': last4,
      'expiry': expiry,
      'accountId': accountId,
      'fullNumber': fullNumber,
      'cvv': cvv,
    };
  }
}
