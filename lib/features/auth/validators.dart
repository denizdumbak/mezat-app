import '../../core/auth_failure.dart';

/// Minimum password length. Kept equal to `minimum_password_length` in
/// supabase/config.toml so the form and the server agree.
const minPasswordLength = 8;

// Mirrors the profiles_username_format check constraint in the database.
final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Emails are case-insensitive in practice, and a stray space from the
/// keyboard's autocomplete is a classic reason for "login does not work".
String normalizeEmail(String raw) => raw.trim().toLowerCase();

/// Same normalization the database applies.
String normalizeUsername(String raw) => raw.trim().toLowerCase();

String? validateEmail(String? raw) {
  final email = normalizeEmail(raw ?? '');
  if (email.isEmpty) return 'E-posta adresini gir.';
  if (!_emailPattern.hasMatch(email)) return AuthFailure.invalidEmail.message;
  return null;
}

/// Sign-in only checks presence: length rules may change after an account
/// was created, and the server is the judge of the password anyway.
String? validateSignInPassword(String? raw) =>
    (raw ?? '').isEmpty ? 'Şifreni gir.' : null;

String? validateNewPassword(String? raw) {
  final password = raw ?? '';
  if (password.isEmpty) return 'Bir şifre belirle.';
  if (password.length < minPasswordLength) {
    return 'Şifre en az $minPasswordLength karakter olmalı.';
  }
  return null;
}

String? validateUsername(String? raw) {
  final username = normalizeUsername(raw ?? '');
  if (username.isEmpty) return 'Bir kullanıcı adı seç.';
  if (!_usernamePattern.hasMatch(username)) {
    return AuthFailure.invalidUsername.message;
  }
  return null;
}
