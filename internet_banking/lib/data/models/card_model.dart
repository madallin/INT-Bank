import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_model.freezed.dart';
part 'card_model.g.dart';

@freezed
class CardModel with _$CardModel
{
  const factory CardModel({
    required int id,
    required int accountId,
    required String cardNumber,
    required String cardHolder,
    required String expiryDate,
    required String cvv,
    required String cardType,
    @Default(0) double spendingLimit,
    @Default(false) bool isBlocked,
    @Default('active') String status,
    String? pin,
  }) = _CardModel;

  factory CardModel.fromJson(Map<String, dynamic> json) =>
      _$CardModelFromJson(json);
}

extension CardModelGetters on CardModel
{
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
