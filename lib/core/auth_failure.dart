/// Everything that can go wrong while signing up, signing in or choosing a
/// username, with the text the user should read.
///
/// Repositories convert Supabase errors into this type, so widgets never see
/// Supabase exceptions and every failure has a friendly Turkish message.
enum AuthFailure implements Exception {
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
  unknown('Beklenmeyen bir hata oluştu. Lütfen tekrar dene.');

  const AuthFailure(this.message);

  final String message;

  /// The message for any error that reaches the UI. Errors that were not
  /// translated by a repository fall back to [unknown] instead of leaking
  /// technical text to the user.
  static String messageFor(Object error) =>
      error is AuthFailure ? error.message : unknown.message;
}
