import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel
{
  const factory UserModel({
    required int id,
    required String phone,
    String? email,
    String? firstName,
    String? lastName,
    @Default(false) bool approved,
    @Default(false) bool acceptedTerms,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
