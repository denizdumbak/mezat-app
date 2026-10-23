import 'app_failure.dart';

/// Everything that can go wrong while creating, starting or bidding on an
/// auction, with the text the user should read.
enum AuctionFailure implements AppFailure {
  invalidStartTime(
    'Başlangıç zamanı şimdi ile 30 gün sonrası arasında olmalı.',
  ),
  invalidInput('Bilgilerden biri geçersiz. Formu kontrol edip tekrar dene.'),
  notAllowed('Bu işlem için yetkin yok.'),
  notSeller('Bu mezatı yalnızca satıcısı başlatabilir.'),
  notScheduled('Bu mezat zaten başlamış ya da bitmiş.'),
  notFound('Mezat bulunamadı.'),
  bidTooLow('Teklifin geçildi. Güncel fiyata göre tekrar dene.'),
  auctionNotLive('Bu mezat şu an teklif almıyor.'),
  sellerCannotBid('Kendi mezatına teklif veremezsin.'),
  biddingNotOpen('Teklif verme henüz açık değil.'),
  imageTooLarge('Fotoğraf en fazla 5 MB olabilir.'),
  unsupportedImage('Yalnızca JPEG, PNG veya WebP fotoğraf yükleyebilirsin.'),
  network('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.'),
  unknown(unknownFailureMessage);

  const AuctionFailure(this.message);

  @override
  final String message;
}
