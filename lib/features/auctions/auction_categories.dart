/// Categories for the chips on Keşfet.
///
/// Auctions have no category in the database yet, so one is guessed from the
/// title with keywords. Good enough for the demo catalogue and for filtering;
/// a real category column (picked by the seller) can replace it later.
enum AuctionCategory {
  kamera('Kamera', [
    'kamera',
    'fotoğraf',
    'lens',
    'canon',
    'nikon',
    'helios',
    'zenit',
    'polaroid',
    'objektif',
  ]),
  saat('Saat', ['saat', 'seiko', 'casio', 'rolex', 'omega', 'kronometre']),
  koleksiyon('Koleksiyon', [
    'koleksiyon',
    'panini',
    'albüm',
    'kart',
    'çıkartma',
    'pul',
    'madalyon',
    'figür',
  ]),
  forma('Forma', ['forma', 'fenerbahçe', 'galatasaray', 'beşiktaş', 'trabzon']),
  antika('Antika', [
    'antika',
    'daktilo',
    'gümüş',
    'telkari',
    'pirinç',
    'bakır',
    'osmanlı',
    'kilim',
  ]),
  muzik('Müzik', [
    'plak',
    'kaset',
    'walkman',
    'gramofon',
    'pikap',
    '45’lik',
    "45'lik",
    'müzik',
  ]);

  const AuctionCategory(this.label, this.keywords);

  final String label;

  /// Lowercase, Turkish spelling.
  final List<String> keywords;

  /// Whether [title] mentions one of the keywords.
  bool matches(String title) {
    final text = turkishLower(title);
    return keywords.any(text.contains);
  }
}

/// Lowercase with Turkish dotted and dotless i: "İ" becomes "i" and "I"
/// becomes "ı", which Dart's `toLowerCase` gets wrong.
String turkishLower(String text) =>
    text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
