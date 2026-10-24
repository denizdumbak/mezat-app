import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/features/auctions/auction_categories.dart';

Set<AuctionCategory> _of(String title) => {
  for (final category in AuctionCategory.values)
    if (category.matches(title)) category,
};

void main() {
  test('the chips, in order', () {
    expect(AuctionCategory.values.map((c) => c.label), [
      'Kamera',
      'Saat',
      'Koleksiyon',
      'Forma',
      'Antika',
      'Müzik',
    ]);
  });

  test('every demo item lands in its category', () {
    expect(_of('Canon AE-1 Program, 50mm f/1.8 lens'), {
      AuctionCategory.kamera,
    });
    expect(_of('Helios 44-2 58mm lens, M42 bağlantı'), {
      AuctionCategory.kamera,
    });
    expect(_of('Seiko 5 otomatik saat, 1970’ler'), {AuctionCategory.saat});
    expect(_of('1998 Panini Dünya Kupası albümü, tam set'), {
      AuctionCategory.koleksiyon,
    });
    expect(_of('1990’lar futbolcu kartları, 200 adet'), {
      AuctionCategory.koleksiyon,
    });
    expect(_of('Fenerbahçe 1996 iç saha forması, imzalı'), {
      AuctionCategory.forma,
    });
    expect(_of('Sony Walkman WM-F10, kasetli, çalışır'), {
      AuctionCategory.muzik,
    });
    expect(_of('1970’ler Türk pop 45’lik plak seti, 12 adet'), {
      AuctionCategory.muzik,
    });
    expect(_of('Olivetti Lettera 32 daktilo, Türkçe klavye'), {
      AuctionCategory.antika,
    });
    // Two at once is fine: it shows under both chips.
    expect(_of('Antika kurmalı kol saati, 1950’ler, gümüş kasa'), {
      AuctionCategory.saat,
      AuctionCategory.antika,
    });
  });

  test('an unknown item is only under Tümü', () {
    expect(_of('Çay bardağı seti'), isEmpty);
  });

  test('Turkish casing: İ and I', () {
    expect(turkishLower('İSTANBUL'), 'istanbul');
    expect(turkishLower('IŞIK'), 'ışık');
    expect(AuctionCategory.forma.matches('FENERBAHÇE FORMASI'), isTrue);
  });
}
