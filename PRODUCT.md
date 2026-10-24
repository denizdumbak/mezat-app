# PRODUCT

Ürün kararları. Her UI işinden önce DESIGN.md ile birlikte okunur. Teknik kurallar
(teklif sunucuda geçerli olur, RLS, anti-sniping) CLAUDE.md'dedir ve önceliklidir.

## Ne

Canlı yayında mezat: satıcı yayın açar, ürünü kamerada gösterir; izleyiciler canlı teklif
verir, süre bitince en yüksek teklif kazanır. Flutter, dikey, tek elle kullanım, Türkçe.

## Gezinme

Alt menüde 4 sekme. Varsayılan Material FAB iskeleti yok.

| Sekme | İçerik |
| --- | --- |
| Keşfet `/` | Üstte küçük logo ve avatar; ürün adı ve satıcıda arayan arama alanı; kategori çipleri (Tümü, Kamera, Saat, Koleksiyon, Forma, Antika, Müzik); "Şimdi canlı" 2 sütunlu ızgara, izleyici sayısına göre (6'dan fazlaysa "Tümü"); "Yaklaşan" yatay sıra, daha küçük kartlar |
| Sat `/sell` | Satıcı alanı: mezat oluştur, planlanmış mezatlarım |
| Tekliflerim `/bids` | Teklif verdiğin mezatlar ve durumları (Önde, Geçildin, Kazandın, Kaybettin; ikon + yazı). Şimdilik boş durum: veri M3 7. adımda |
| Profil `/profile` | Kullanıcı adı, harcama limiti, çıkış |

Ayrı bir "Canlı" sekmesi yok: canlı mezatlar Keşfet'in ilk bölümü. Canlı oda
`/auctions/:id/live`.

## Canlı oda

Tam ekran dikey video (yayın yokken yer tutucu). Üstte yayıncı ve izleyici sayısı, solda dar
teklif akışı, altta teklif paneli:

- güncel fiyat (40 sp) ve geri sayım,
- kural satırı: "Artış ₺X · Son 30 sn'de teklif +30 sn uzatır" (değerler sabitlerden gelir,
  sunucu kuralıyla aynı),
- artış çipleri ve büyük birincil buton "+₺X teklif ver".

Canlı sohbet MVP kapsamı dışında (CLAUDE.md); solda sohbet yerine teklif akışı var.

## Teklif etkileşimi: artış çipleri

- Çipler satıcının belirlediği artışlardır; varsayılan +₺10, +₺50, +₺100.
- En küçük çip seçili gelir. Birincil buton seçili artışı güncel fiyata ekleyip teklif verir.
- Her teklifi bir kişi verir; maksimum (ön) teklif ve otomatik teklif yok. Süre bittiğinde en
  yüksek teklif kazanır. Her teklif en az güncel fiyat + minimum artış olduğu için eşit teklif
  verilemez (karar ve gerekçe: NOTES.md).

## Güvenlik katmanı (uygulamadan kaldırılmaz; harcama limitini kullanıcı kendisi kapatabilir)

- **Yüksek tutar onayı:** tek teklif ya da bugünkü toplam taahhüt eşiği (varsayılan ₺1.000,
  config'den değişir) aşarsa ikinci onay adımı çıkar.
- **Harcama limiti:** Profil'de; "son X süre içinde en fazla ₺Y" (kayan pencere). Süre hazır
  seçeneklerden (6 saat, 1 gün, 1 hafta, 1 ay) ya da serbest (sayı + saat/gün/hafta, 1 saat ile
  365 gün arası) seçilir. Varsayılan açık, son 1 günde ₺2.000. Kullanıcı istediği zaman
  değiştirir, "Sayacı sıfırla" ile pencereyi şimdiden başlatır ya da limiti kapatır: bir kural
  değil, kendi harcamasını kontrol etmek için kullandığı bir araç. Teklif limiti aşacaksa buton
  devre dışı kalır ve nedeni yazılır ("Limitine ulaştın. Son 1 günde en fazla ₺2.000.").
- Limite sayılan toplam: kullanıcının şu an önde olduğu mezatlar ve seçtiği sürede (son
  sıfırlamadan önce olmamak üzere) kazandığı mezatlar. Aynı mezatta yeni teklif eskisinin
  yerine geçer. Sıfırlama önde olunan mezatları silmez; onlar sürüyor.

## "Satıldı" anı

Süre bitince damga animasyonu, ardından kazanan adı ve haptik. Kazanan sensen `success`
rengiyle "Kazandın".

## Eklenmeyecekler

Gizemli kutu / "break" mekaniği, sahte aciliyet (uydurma izleyici sayısı, sahte "son 1 ürün"),
rastgele ödül, gradyan, kart içinde kart, emoji ikon.
