// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CardModelImpl _$$CardModelImplFromJson(Map<String, dynamic> json) =>
    _$CardModelImpl(
      id: (json['id'] as num).toInt(),
      accountId: (json['accountId'] as num).toInt(),
      cardNumber: json['cardNumber'] as String,
      cardHolder: json['cardHolder'] as String,
      expiryDate: json['expiryDate'] as String,
      cvv: json['cvv'] as String,
      cardType: json['cardType'] as String,
      spendingLimit: (json['spendingLimit'] as num?)?.toDouble() ?? 0,
      isBlocked: json['isBlocked'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      pin: json['pin'] as String?,
    );

Map<String, dynamic> _$$CardModelImplToJson(_$CardModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'accountId': instance.accountId,
      'cardNumber': instance.cardNumber,
      'cardHolder': instance.cardHolder,
      'expiryDate': instance.expiryDate,
      'cvv': instance.cvv,
      'cardType': instance.cardType,
      'spendingLimit': instance.spendingLimit,
      'isBlocked': instance.isBlocked,
      'status': instance.status,
      'pin': instance.pin,
    };
