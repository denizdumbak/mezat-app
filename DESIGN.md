# DESIGN

Mezat'ın tasarım dili. Her UI işinden önce okunur. Değerlerin tek kaynağı kodda
`lib/app/design_tokens.dart`; iki tema `lib/app/theme.dart` içinde bu belirteçlerden kurulur.
Widget içinde sabit hex, `Colors.*`, `AppColors.*` veya sihirli sayı yazılmaz.

## Kimlik

Canlı mezat atmosferi: enerjik, hızlı, net. **Ürün görseli ve fiyat her ekranda en güçlü
öğedir; arayüzün geri kalanı sessizdir.** Beyaz zemin, siyah metin, tek bir aksiyon rengi
(amber) ve yalnızca "canlı" anlamında kırmızı. Düzen Whatnot benzeri canlı satış desenidir,
ama renk, logo ve ikon dili bizimdir.

- **İki tema.** `browseTheme` (açık) uygulamanın varsayılanıdır: sekmeler, giriş/kayıt,
  açılış, form ve hata ekranları. `liveTheme` (koyu) yalnızca canlı odadır
  (`/auctions/:id/live`, `router.dart` bu rotayı `Theme(data: liveTheme)` ile sarar; odadan
  açılan alt paneller de bu temayı alır).
- Büyük alana renk yok. Gradyan yok (tek istisna: canlı kartında görselin alt kenarındaki koyu
  geçiş, beyaz kalan süre her fotoğrafta okunsun diye), kart içinde kart yok, emoji ikon yok,
  `fromSeed` yok.
- Kartlarda çerçeve yok; ayrım boşlukla ve görselle yapılır. Gölge yalnızca alt panellerde.

## Renk

Widget'lar rengi temadan okur: `Theme.of(context).colorScheme` (zemin, metin, ikincil metin,
çizgi, aksiyon, hata) ve `context.palette` (`AppPalette` ThemeExtension: canlı, başarı, uyarı,
panel, koyu örtü, pasif, fotoğraf üstü hap). Böylece aynı widget iki temada da doğru görünür.
`test/app/theme_test.dart`, `lib/core` ve `lib/features` içinde `AppColors.` geçmediğini
denetler.

### Açık (browse)

| Rol | Kod | Değer | Kontrast |
| --- | --- | --- | --- |
| Zemin | `surface` | #FFFFFF | |
| İkincil yüzey (panel, alan, çip) | `surfaceAlt` | #F4F4F5 | |
| Çizgi | `line` | #E4E4E7 | |
| Metin | `text` | #0A0A0B | 19.8:1 zeminde |
| İkincil metin | `textMuted` | #52525B | 7.7:1 zeminde, 7.0:1 ikincil yüzeyde |
| Pasif (yalnızca disabled) | `disabled` | #A1A1AA | okunacak metin için değil |
| Hata metni | `error` | #DC2626 | 4.8:1 zeminde |

### Koyu (canlı oda)

| Rol | Kod | Değer | Kontrast |
| --- | --- | --- | --- |
| Zemin | `liveSurface` | #0A0A0B | |
| Panel (video üstü) | `scrim` | siyah %60 + 20 blur | |
| Metin | `liveText` | #FFFFFF | 19.8:1 zeminde |
| İkincil metin | `liveTextMuted` | #A1A1AA | 7.7:1 zeminde |
| Çizgi | `liveLine` | beyaz %12 | |
| Hata metni | `errorOnDark` | #F87171 | 7.2:1 zeminde |
| Koyu örtü ("Satıldı", "Süre doldu") | `scrimStrong` | siyah %92 | |

### Her iki tema

| Rol | Kod | Değer | Nerede | Kontrast |
| --- | --- | --- | --- | --- |
| Aksiyon | `accent` | #FFB020 | **Yalnızca** teklif düğmesi, birincil CTA, seçili sekme | |
| Aksiyon üstü metin | `onAccent` | #0A0A0B | Amber üstündeki yazı | 10.8:1 |
| Canlı | `live` | #EF4444 | **Yalnızca** `LiveBadge`/`LiveDot` ve sayacın son 30 sn'si | beyaz yazı 3.8:1 |
| Başarı | `success` | #16A34A | "Kazandın", "SATILDI" damgası, onay mesajı | 6.3:1 koyu örtüde |
| Uyarı | `warning` | #F59E0B | Bekleme durumları (bağlantı geri geliyor) | |

- Amber metin linki olmaz; linkler metin renginde, altı çizili. Odak çerçevesi, seçili çip,
  seçili segment ve switch metin rengindedir.
- Bekleme durumları hata rengini kullanmaz ("Bağlantı bekleniyor" uyarı rengidir).
- "CANLI" rozeti kırmızı hap üstünde beyaz w800 yazıdır: 3.8:1, büyük/kalın metin ve ikon
  eşiğini (3:1) geçer, küçük metin eşiğinin (4.5:1) altındadır. Kısa, büyük harf, tek kelime
  olduğu için bilinçli tercih.
- Seçili sekme: ikonun arkasında amber hap, ikon amber üstü metin renginde, etiket metin
  renginde kalın (beyaz üstünde amber yazı okunmaz).

## Yazı

Tek aile: **Manrope** (400–800), `assets/fonts` içinde gömülü (SIL OFL). Türkçe karakter
testi `ÇĞİIÖŞÜ çğıiöşü ₺` hem font dosyasında (`test/app/fonts_test.dart`) hem widget testinde.

| Ölçek | Boyut / satır | Ağırlık | Material rolü | Nerede |
| --- | --- | --- | --- | --- |
| priceDisplay | 40/44 | 800, tabular | `AppTextStyles.priceDisplay` | **Yalnızca** canlı oda fiyatı |
| title | 22/28 | 700 | display*, headline*, titleLarge | Sayfa ve panel başlıkları |
| headline | 17/22 | 700 | titleMedium, titleSmall, labelLarge | Bölüm başı, satır başlığı, buton metni |
| body | 15/22 | 400 | bodyLarge, bodyMedium | Metin, uzun açıklamalar dahil |
| label | 13/18 | 600 | labelMedium | Çip, segment, küçük kontrol |
| caption | 12/16 | 500 | bodySmall, labelSmall | Yalnızca kısa yardımcı metin |

- 12'nin altı yok.
- Sayfa başlıkları title boyutunda; büyük alan içeriğe kalır.
- Fiyat ve sayaç her yerde tabular ve w800: listelerde `AppTextStyles.price` (17/22), sayaç
  `AppTextStyles.timer` (22/28). Rakamlar eşit genişlikte, değişirken zıplamaz.
- "SATILDI" damgası `AppTextStyles.stamp`: 40, w800, harf aralığı 2, başarı yeşili.

## Biçim ve ölçü

| Yarıçap | Değer | Nerede |
| --- | --- | --- |
| `image` | 12 | Fotoğraflar, form alanları |
| `card` | 16 | Kartlar, paneller |
| `sheet` | 24 | Alt panelin üst köşeleri |
| `pill` | 999 | Çip, hap düğme (birincil ve teklif butonu dahil), rozet |

- Boşluk ölçeği: 4, 8, 12, 16, 24, 32, 48. Yatay ekran kenarı 16.
- Dokunma hedefi en az 48; teklif butonu 56.

## Hareket

Seviye "orta": yalnızca anlam taşıyan hareket. Fiyat değişimi, geri sayım, süre uzatma, teklif
akışı satırı, ekran geçişleri. Dekoratif, sürekli dönen animasyon yok.

| Süre | ms | Nerede |
| --- | --- | --- |
| press | 120 | Basma geri bildirimi, seçili sekme hapı |
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

- **Birincil buton:** amber dolgu, hap, en az 48 (teklif butonu 56). Ekranda tek birincil
  eylem; **amber dolgu yalnızca onda**. Devre dışıyken panel rengi dolgu, pasif yazı, nedeni
  altında yazılı.
- **Artış çipi:** hap, panel zemini, 1 dp çizgi; seçiliyken 2 dp metin rengi çerçeve. Amber
  değil: hemen altındaki teklif butonuyla yarışmasın.
- **Panel (`AppPanel`, `BlurredPanel`):** ikincil yüzey, 16, çerçevesiz. Canlı odada siyah
  %60 + blur, video üstünde okunur.
- **Mezat kartı (`AuctionCard`, `lib/features/auctions/widgets`):** listelerdeki tek kart.
  `live`: 3:4 görsel, sol üstte "CANLI · 236", altta geçiş üstünde kalan süre; altında satıcı
  (avatar + ad, caption), ürün adı (en fazla 2 satır), güncel teklif. `upcoming`: geniş görsel,
  üstünde "Bugün 21:00" ve "Hatırlat" düğmesi; altında satıcı, ad, açılış fiyatı. `ended`:
  soluk (%60), "Satıldı ₺X". `row`: kare küçük görsel + ayrıntılar + sağda isteğe bağlı eylem
  (Canlı listesi, Yayın aç'taki planlanmış mezatlar).
- **Ürün görseli (`AuctionPhoto`):** ağ adresi ya da `assets/` yolu. Görsel yoksa ya da
  yüklenmezse ikincil yüzey üstünde ürün adının baş harfi; büyük gri resim ikonu yok.
- **Fiyat etiketi (`PriceLabel`):** listelerdeki her tutar. Türkçe ayraçlar (₺1.250,50), ₺
  işareti rakamlardan biraz küçük (0,8), tabular w800; isteğe bağlı önek ("Açılış", "Satıldı").
- **Fiyat göstergesi:** değişen rakamlar dikey kayar.
- **Geri sayım:** son 30 saniyede (anti-sniping penceresi, `antiSnipingWindow` sabitinden)
  canlı kırmızı; süre uzayınca "+30 sn" çipi belirir.
- **Teklif akışı satırı:** bulanık hap üstünde kullanıcı adı + tutar, girişte kayarak belirir.
  Kendi teklifin "Sen", tam renk ve kalın.
- **Durumlar:** yükleniyor (üç nokta, ikincil metin rengi), boş, hata ve bağlantı koptu (uyarı
  rengi).
- Varsayılan `CircularProgressIndicator`, `SnackBar` ve `Card` görünümü kullanılmaz; özel
  sürümleri var (`AppLoader`, `showAppMessage`, `AppPanel`).

## Metin

Kısa ve somut Türkçe: "Teklif ver", "Satıldı", "Limitine ulaştın". Jenerik dolgu metni
("Harika bir deneyim!") yok. Hata mesajı ne olduğunu ve ne yapılacağını söyler. Arayüz
metinlerinde uzun tire (—) kullanılmaz.

## Anti-slop kontrolü (her ekranda)

1. Ürün görseli ve fiyat ekranın en güçlü öğesi mi?
2. Tek birincil eylem var mı; amber yalnızca orada (ve seçili sekmede) mi?
3. Kırmızı yalnızca "canlı" anlamında mı?
4. Gradyan, kart içinde kart, çerçeveli kart, gölge yığını kaldı mı?
5. Jenerik veya uzun metin var mı?
6. Sabit renk/sayı widget'a sızmış mı?
7. Uzun kullanıcı adı, 6 haneli tutar, boş liste ve bağlantı kopması test edildi mi?
