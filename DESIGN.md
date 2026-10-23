# DESIGN

Mezat'ın tasarım dili. Her UI işinden önce okunur. Değerlerin tek kaynağı kodda
`lib/app/design_tokens.dart`; tema `lib/app/theme.dart` içinde bu belirteçlerden kurulur.
Widget içinde sabit hex, `Colors.*` veya sihirli sayı yazılmaz.

## Kimlik

Gece, sahne ışığı, altın. Lacivert zemin canlı yayının videosunu öne çıkarır; altın tek vurgu
rengidir ve neredeyse yalnızca birincil eylemde (teklif ver) görünür. Düzen Whatnot benzeri
canlı satış desenidir, ama renk, logo ve ikon dili bizimdir.

- **Yalnızca koyu tema.** Açık tema yok.
- Gradyan yok, kart içinde kart yok, emoji ikon yok, varsayılan mor/indigo
  (`ColorScheme.fromSeed`) yok. Gölge yerine 1 dp çizgi.

## Renk

| Belirteç (DESIGN) | Kod (`AppColors`) | Değer | Kullanım | Kontrast |
| --- | --- | --- | --- | --- |
| stage | `stage` | #0C1424 | Zemin | — |
| stageRaised | `stageRaised` | #152036 | Sheet, panel, alan | — |
| onStage | `onStage` | #EEF1F7 | Metin, ikon | 15:1 zeminde |
| onStageMuted | `onStageMuted` | #A7B1C6 | İkincil metin | 8.5:1 zeminde, 7.5:1 yüzeyde |
| altın | `gold` | #D9A93A | Vurgu, birincil buton dolgusu | — |
| altın üstü metin | `onGold` | #0C1424 | Altın üstündeki yazı | 8.5:1 |
| zaman | `urgent` | #FF6B5B | Son saniyeler, hata, limit uyarısı | 6.6:1 zeminde, 5.8:1 yüzeyde |
| onay | `success` | #4CC38A | Kazandın, başarı | 8.3:1 zeminde |
| çizgi | `line` | onStage %14 | 1 dp ayırıcı ve kenar | — |

Kontrast oranları `test/app/theme_test.dart` ile doğrulanır.

## Yazı

- **Fraunces** (600/700): başlıklar, "SATILDI" damgası.
- **Manrope** (400–800): gövde, buton, etiket, fiyat.
- Fiyat ve sayaçta `FontFeature.tabularFigures()`: rakamlar eşit genişlikte, değişirken
  zıplamaz. Canlı odada güncel fiyat 40 sp.
- Fontlar `assets/fonts` içinde gömülü (SIL OFL). Türkçe karakter testi:
  `ÇĞİIÖŞÜ çğıiöşü ₺` hem font dosyasında (`test/app/fonts_test.dart`) hem widget testinde.

## Biçim ve ölçü

- Köşe yarıçapı yalnızca iki değer: **8 dp** (alan, çip, buton) ve **16 dp** (sheet, kart, panel).
- Boşluk ölçeği: 4, 8, 12, 16, 24, 32. Yatay ekran kenarı 16 dp.
- Dokunma hedefi en az 48 dp; teklif butonu en az 56 dp yüksek.

## Hareket

Seviye "orta": yalnızca anlam taşıyan hareket. Fiyat değişimi, geri sayım, süre uzatma, teklif
akışı satırı, ekran geçişleri. Dekoratif, sürekli dönen animasyon yok.

| Süre | ms | Nerede |
| --- | --- | --- |
| press | 120 | Basma geri bildirimi |
| entry | 180 | Satır, sayfa, sheet girişi |
| price | 220 | Fiyat rakamlarının kayması |
| extend | 240 | "+30 sn" uzatma çipi |
| sold | 700 | "Satıldı" damgası (tek sefer) |

- Girişte ease-out, çıkışta ease-in.
- Sistem "hareketi azalt" açıksa (`MediaQuery.disableAnimations`) hareket kapanır, yalnızca
  opaklık değişir. Kontrol: `motionAllowed(context)`.
- "Satıldı": ~700 ms damga (hafif büyüyüp oturur, küçük bir sarsılma), sonra kazanan adı,
  güçlü haptik. Bir kez oynar.

## Bileşenler (`lib/core/widgets`)

- **Birincil buton:** altın dolgu, 8 dp, en az 48 dp (teklif butonu 56 dp). Ekranda tek
  birincil eylem.
- **Artış çipi:** seçilebilir, 8 dp, seçiliyken altın dolgu.
- **Fiyat göstergesi:** değişen rakamlar dikey kayar.
- **Geri sayım:** son 10 saniyede `urgent` rengi; süre uzayınca "+30 sn" çipi belirir.
- **Teklif akışı satırı:** kullanıcı adı + tutar, girişte kayarak belirir.
- **Durumlar:** yükleniyor (özel gösterge), boş, hata ve bağlantı koptu.
- Varsayılan `CircularProgressIndicator`, `SnackBar` ve `Card` görünümü kullanılmaz; özel
  sürümleri var (`AppLoader`, `showAppMessage`, `AppPanel`).

## Metin

Kısa ve somut Türkçe: "Teklif ver", "Satıldı", "Limitine ulaştın". Jenerik dolgu metni
("Harika bir deneyim!") yok. Hata mesajı ne olduğunu ve ne yapılacağını söyler.

## Anti-slop kontrolü (her ekranda)

1. Tek birincil eylem var mı?
2. Gradyan, kart içinde kart, gölge yığını kaldı mı?
3. Jenerik veya uzun metin var mı?
4. Sabit renk/sayı widget'a sızmış mı?
5. Uzun kullanıcı adı, 6 haneli tutar, boş liste ve bağlantı kopması test edildi mi?
