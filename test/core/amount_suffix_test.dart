import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/amount_suffix.dart';
import 'package:mezat_app/core/money.dart';

Money tl(int lira) => Money.kurus(lira * 100);

void main() {
  test('ablative follows the last word read aloud', () {
    expect(withAblative(tl(2000)), "₺2.000'den"); // bin
    expect(withAblative(tl(2160)), "₺2.160'tan"); // altmış: hard ş
    expect(withAblative(tl(3)), "₺3'ten"); // üç: hard ç
    expect(withAblative(tl(6)), "₺6'dan"); // altı
    expect(withAblative(tl(500)), "₺500'den"); // yüz
    expect(withAblative(tl(40)), "₺40'tan"); // kırk: hard k
    expect(withAblative(tl(1000000)), "₺1.000.000'dan"); // milyon
  });

  test('dative adds a buffer y after a vowel', () {
    expect(withDative(tl(2160)), "₺2.160'a");
    expect(withDative(tl(2000)), "₺2.000'e");
    expect(withDative(tl(6)), "₺6'ya");
    expect(withDative(tl(2)), "₺2'ye");
    expect(withDative(tl(90)), "₺90'a"); // doksan
    expect(withDative(tl(10)), "₺10'a"); // on
  });

  test('with kuruş, the kuruş are read last', () {
    expect(withDative(const Money.kurus(125050)), "₺1.250,50'ye"); // elli
    expect(withAblative(const Money.kurus(125005)), "₺1.250,05'ten"); // beş
  });
}
