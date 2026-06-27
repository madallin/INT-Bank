import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_session_manager.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthState
{
  final int? userId;
  final String? phone;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.userId,
    this.phone,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    int? userId,
    String? phone,
    bool? isLoading,
    String? error,
  })
  {
    return AuthState(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState>
{
  AuthNotifier() : super(const AuthState());

  Future<void> checkSession() async
  {
    state = state.copyWith(isLoading: true);
    try
    {
      final uid = await SecureSessionManager.getUserId();
      final ph = await SecureSessionManager.getPhone();
      if(uid != null)
      {
        state = state.copyWith(userId: uid, phone: ph, isLoading: false);
      }
      else
      {
        state = state.copyWith(isLoading: false);
      }
    }
    catch(e)
    {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setUserId(int id)
  {
    state = state.copyWith(userId: id);
  }

  void setPhone(String phone)
  {
    state = state.copyWith(phone: phone);
  }

  Future<void> clearSession() async
  {
    await SecureSessionManager.clearSession();
    state = const AuthState();
  }
}
