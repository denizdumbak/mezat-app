import 'app_failure.dart';

/// Everything that can go wrong while signing up, signing in or choosing a
/// username, with the text the user should read.
enum AuthFailure implements AppFailure {
  invalidCredentials('E-posta veya şifre hatalı.'),
  emailNotConfirmed(
    'E-posta adresin henüz doğrulanmadı. Gelen kutunu kontrol et.',
  ),
  emailAlreadyRegistered(
    'Bu e-posta ile zaten bir hesap var. Giriş yapmayı dene.',
  ),
  weakPassword('Şifre çok zayıf. En az 8 karakter kullan.'),
  invalidEmail('Geçerli bir e-posta adresi gir.'),
  usernameTaken('Bu kullanıcı adı alınmış. Başka bir tane dene.'),
  invalidUsername(
    'Kullanıcı adı 3–20 karakter olmalı; yalnızca küçük harf, rakam ve _ '
    'içerebilir.',
  ),
  tooManyRequests('Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.'),
  network('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.'),
  unknown(unknownFailureMessage);

  const AuthFailure(this.message);

  @override
  final String message;
}
