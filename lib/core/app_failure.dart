/// A failure that carries the text the user should read.
///
/// Repositories convert Supabase errors into one of these ([AuthFailure],
/// [AuctionFailure]), so widgets never see Supabase exceptions.
abstract interface class AppFailure implements Exception {
  String get message;
}

const unknownFailureMessage =
    'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';

/// The message for any error that reaches the UI. Errors that were not
/// translated by a repository get a generic text instead of leaking technical
/// details to the user.
String failureMessage(Object error) =>
    error is AppFailure ? error.message : unknownFailureMessage;
