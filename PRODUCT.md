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
| Keşfet | Canlı mezatlar (ayrı şerit) ve yaklaşanlar: büyük fotoğraf, fiyat, başlama zamanı |
| Canlı | Şu an yayında olan mezatların listesi; dokununca canlı oda |
| Yayın aç | Satıcı alanı: mezat oluştur, planlanmış mezatlarım |
| Profil | Kullanıcı adı, günlük harcama limiti, çıkış |

## Canlı oda

Tam ekran dikey video (yayın yokken yer tutucu). Üstte yayıncı ve izleyici sayısı, solda dar
teklif akışı, altta teklif paneli:

- güncel fiyat (40 sp) ve geri sayım,
- kural satırı: "Artış ₺X · Son 30 sn'de teklif +30 sn uzatır" (değerler sabitlerden gelir,
  sunucu kuralıyla aynı),
- artış çipleri, büyük birincil buton "+₺X teklif ver", "Maksimum teklif" metin butonu.

Canlı sohbet MVP kapsamı dışında (CLAUDE.md); solda sohbet yerine teklif akışı var.

## Teklif etkileşimi: artış çipleri

- Çipler satıcının belirlediği artışlardır; varsayılan +₺10, +₺50, +₺100.
- En küçük çip seçili gelir. Birincil buton seçili artışı güncel fiyata ekleyip teklif verir.
- "Maksimum teklif" (ön teklif): kullanıcı bir üst sınır belirler; geçildikçe sistem en küçük
  artışla onun adına teklif verir, sınıra kadar.

## Güvenlik katmanı (kaldırılmaz, kısaltılmaz)

- **Yüksek tutar onayı:** tek teklif ya da bugünkü toplam taahhüt eşiği (varsayılan ₺1.000,
  config'den değişir) aşarsa ikinci onay adımı çıkar.
- **Günlük harcama limiti:** Profil'de; varsayılan ₺2.000, kullanıcı değiştirir. Teklif limiti
  aşacaksa buton devre dışı kalır ve nedeni yazılır ("Günlük limitine ulaştın").
- "Bugünkü toplam taahhüt": kullanıcının bugün önde olduğu ya da kazandığı mezatlardaki
  teklifleri toplamı. Aynı mezatta yeni teklif eskisinin yerine geçer.

## "Satıldı" anı

Süre bitince damga animasyonu, ardından kazanan adı ve haptik. Kazanan sensen `success`
rengiyle "Kazandın".

## Eklenmeyecekler

Gizemli kutu / "break" mekaniği, sahte aciliyet (uydurma izleyici sayısı, sahte "son 1 ürün"),
rastgele ödül, gradyan, kart içinde kart, emoji ikon.
