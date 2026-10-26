import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

class AuthService {
  AuthService._();

  static bool get isConfigured => SupabaseConfig.isConfigured;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<AuthResponse> createAccount({
    required String name,
    required String email,
    required String contactNumber,
    required String address,
    required String password,
  }) => _client.auth.signUp(
    email: email.trim(),
    password: password,
    data: {
      'full_name': name.trim(),
      'contact_number': contactNumber.trim(),
      'address': address.trim(),
    },
  );

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  static Future<Map<String, dynamic>> loadMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to view your profile.');
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return row ??
        {
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? '',
          'contact_number': user.userMetadata?['contact_number'] ?? '',
          'address': user.userMetadata?['address'] ?? '',
        };
  }

  static Future<void> updateMyProfile({
    required String name,
    required String contactNumber,
    required String address,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to update your profile.');
    final updated = await _client
        .from('profiles')
        .update({
          'full_name': name.trim(),
          'contact_number': contactNumber.trim(),
          'address': address.trim(),
        })
        .eq('id', user.id)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw const AuthException(
        'Your profile could not be found. Please sign in again.',
      );
    }
  }

  static Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());
}
