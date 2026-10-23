import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auth_failure.dart';
import 'package:mezat_app/features/auth/validators.dart';

void main() {
  group('normalizeEmail', () {
    test('trims spaces and lowercases', () {
      expect(normalizeEmail('  Deniz@Example.COM \n'), 'deniz@example.com');
    });
  });

  group('validateEmail', () {
    test('accepts a normal address, also with surrounding spaces', () {
      expect(validateEmail('deniz@example.com'), isNull);
      expect(validateEmail(' deniz@example.com '), isNull);
    });

    test('asks for an address when empty', () {
      expect(validateEmail(''), 'E-posta adresini gir.');
      expect(validateEmail('   '), 'E-posta adresini gir.');
      expect(validateEmail(null), 'E-posta adresini gir.');
    });

    test('rejects malformed addresses', () {
      for (final email in ['deniz', 'deniz@', '@example.com', 'a b@c.com']) {
        expect(
          validateEmail(email),
          AuthFailure.invalidEmail.message,
          reason: email,
        );
      }
    });
  });

  group('passwords', () {
    test('sign-in only requires a value', () {
      expect(validateSignInPassword(''), 'Şifreni gir.');
      expect(validateSignInPassword('x'), isNull);
    });

    test('new password needs $minPasswordLength characters', () {
      expect(validateNewPassword(''), 'Bir şifre belirle.');
      expect(validateNewPassword('1234567'), isNotNull);
      expect(validateNewPassword('12345678'), isNull);
    });

    test('spaces count and are not trimmed', () {
      expect(validateNewPassword('  abcdef'), isNull);
    });
  });

  group('validateUsername', () {
    test('accepts what the database accepts after normalizing', () {
      expect(validateUsername('deniz_01'), isNull);
      expect(validateUsername('  Deniz  '), isNull);
      expect(validateUsername('abc'), isNull);
      expect(validateUsername('a' * 20), isNull);
    });

    test('rejects what the database check constraint rejects', () {
      for (final username in ['ab', 'a' * 21, 'has space', 'şeker', 'a-b']) {
        expect(
          validateUsername(username),
          AuthFailure.invalidUsername.message,
          reason: username,
        );
      }
    });

    test('asks for a username when empty', () {
      expect(validateUsername(''), 'Bir kullanıcı adı seç.');
    });
  });
}
