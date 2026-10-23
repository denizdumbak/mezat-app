# Mezat App — CLAUDE.md

Canlı yayınlı mezat (açık artırma) uygulaması. Satıcı canlı yayın açar, ürünü kamerada gösterir; izleyiciler canlı teklif verir, en yüksek teklif sahibi süre bitince kazanır.

Bu repo bir portföy projesidir: kod okunabilir, test edilmiş ve README'si eksiksiz olmalı. Geliştirici (Deniz) projeyi öğrenerek ilerliyor: teknik bir terim ilk kez geçtiğinde bir cümleyle açıkla, önemli kararların "neden"ini anlat.

İletişim dili: Türkçe. Kod, commit mesajları, dosya/değişken adları: İngilizce.

## Stack

- **Mobil:** Flutter (stable kanal), Dart. State management: Riverpod. Routing: go_router.
- **Backend:** Supabase — Auth, Postgres, Realtime, Storage, Edge Functions (Deno/TypeScript).
- **Canlı video:** LiveKit (LiveKit Cloud ücretsiz katman), Flutter tarafında `livekit_client`.
- **Test:** `flutter test` (unit + widget), Postgres fonksiyonları için SQL testleri (pgTAP veya `supabase test db`).

## Klasör yapısı

```
lib/
  app/              # app, router, theme
  features/
    auth/
    auctions/       # liste, detay, oluşturma
    live_room/      # yayın + teklif ekranı
  core/             # supabase client, env, ortak widget'lar, hata tipleri
  data/             # repository'ler (Supabase erişimi burada, UI'da değil)
supabase/
  migrations/       # tüm şema, RLS ve fonksiyonlar dosya olarak
  functions/
    livekit-token/  # Edge Function: LiveKit erişim token'ı üretir
  tests/
test/
.env.example
README.md
NOTES.md            # kararlar ve teknik borç
```

Katmanlar: UI (widget) → controller/provider → repository → Supabase. Widget içinde doğrudan Supabase sorgusu yazılmaz.

## Veri modeli (ilk taslak)

- `profiles` — id (auth.users ile aynı), username (benzersiz), avatar_url, created_at
- `auctions` — id, seller_id, title, description, image_url, start_price, min_increment, status (`scheduled` | `live` | `ended` | `cancelled`), starts_at, ends_at, current_price, current_winner_id, created_at
- `bids` — id, auction_id, bidder_id, amount, created_at

Para değerleri `numeric(12,2)`, para birimi TRY. Float kullanılmaz.

## Kritik kurallar (pazarlık yok)

1. **Teklif yalnızca sunucuda geçerli olur.** Client `bids` tablosuna doğrudan INSERT yapamaz. Teklif `place_bid(auction_id, amount)` Postgres fonksiyonu (RPC) ile verilir. Fonksiyon:
   - kullanıcıyı `auth.uid()`'den alır (parametreden değil),
   - mezat satırını `SELECT ... FOR UPDATE` ile kilitler (aynı anda gelen iki teklif yarışmasın),
   - kontroller: mezat `live` mı, süre dolmamış mı, teklif veren satıcı değil mi, `amount >= current_price + min_increment` mi,
   - geçerliyse `bids`'e yazar, `auctions.current_price` ve `current_winner_id`'yi günceller,
   - **anti-sniping:** son 30 saniyede gelen teklif `ends_at`'ı 30 saniye uzatır (son saniye teklifiyle kazanmayı engeller),
   - hatada anlamlı bir hata kodu döner (`AUCTION_NOT_LIVE`, `BID_TOO_LOW`, `SELLER_CANNOT_BID` …).
2. **RLS her tabloda açık.** (RLS = Row Level Security: Postgres'in satır bazında "bu kullanıcı bu satırı okuyabilir/yazabilir mi" kuralı; Supabase'de client veritabanına doğrudan bağlandığı için tek savunma hattı budur.)
   - `profiles`: herkes okur, kişi yalnızca kendi satırını günceller.
   - `auctions`: herkes okur; yalnızca satıcı kendi mezatını oluşturur; `current_price`, `current_winner_id`, `status` client'tan güncellenemez.
   - `bids`: herkes okur; INSERT/UPDATE/DELETE client'a kapalı (yalnızca `place_bid` yazar, `security definer`).
3. **Mezat bitişi sunucuda.** Süresi dolan `live` mezatları `ended` yapan `finalize_ended_auctions()` fonksiyonu pg_cron ile dakikada bir çalışır. Client'taki geri sayım yalnızca görüntüdür.
4. **LiveKit gizli anahtarı uygulamaya girmez.** Token `livekit-token` Edge Function'ında üretilir: kullanıcıyı Supabase JWT'sinden doğrular; mezatın satıcısıysa yayınlama (publish) izni, değilse yalnızca izleme (subscribe) izni verir. `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` yalnızca Supabase secrets'ta durur.
5. **Gizli bilgiler:** `.env` git'e girmez; repoda `.env.example` var. Flutter'a yalnızca Supabase URL, anon key ve LiveKit sunucu URL'i gider (bunlar herkese açık değerlerdir).
6. Supabase'de şema değişikliği yalnızca `supabase/migrations/` altında migration dosyasıyla yapılır; dashboard'dan elle değişiklik yok.

## MVP kapsamı ve sıra

Her milestone çalışır, test edilmiş ve commit'lenmiş biter. Bir sonrakine geçmeden önce kullanıcıya özet ver ve onay al.

- [x] **M0 — Kurulum:** Flutter projesi, klasör yapısı, Riverpod/go_router, Supabase CLI ve local Supabase, `.env.example`, README iskeleti, GitHub Actions (`flutter analyze` + `flutter test`).
- [x] **M1 — Auth + profil:** e-posta + şifre ile kayıt/giriş (Supabase Auth), kullanıcı adı seçme, çıkış. Hata mesajları kullanıcı dostu. Bu akış özellikle sağlam ve test edilmiş olsun: "kayıt oldum ama giriş yapamıyorum" en sık şikâyetlerden biridir.
- [ ] **M2 — Mezat oluşturma ve listeleme:** satıcı başlık, açıklama, fotoğraf (Storage), başlangıç fiyatı, minimum artış, süre girer. Ana ekranda canlı ve yaklaşan mezatlar.
- [ ] **M3 — Canlı teklif (videosuz):** mezat odası ekranı; güncel fiyat, son teklifler listesi, geri sayım, "teklif ver" (hızlı artış butonları: +min, +2×min). Realtime ile tüm izleyicilerde anlık güncellenir. `place_bid` için SQL testleri: düşük teklif, satıcı teklifi, bitmiş mezat, eşzamanlı teklifler, anti-sniping uzaması.
- [ ] **M4 — Canlı video:** `livekit-token` Edge Function; satıcı kamerasını yayınlar, izleyiciler M3 ekranının üstünde videoyu izler. Yetki testi: izleyici token'ı ile yayın yapılamıyor.
- [ ] **M5 — Bitiş ve sonuç:** pg_cron ile otomatik bitiş, kazanan ekranı, satıcının "mezatlarım", alıcının "kazandıklarım" listesi.
- [ ] **M6 — Vitrin:** README'de ekran görüntüleri / GIF, mimari diyagramı, kurulum adımları, bilinen eksikler; uygulama ikonu ve tutarlı tema.

**Kapsam dışı (MVP sonrası):** ödeme, kargo, canlı sohbet, moderasyon/raporlama, bildirimler, iOS yayını.

## Çalışma kuralları

- **Oturum başında `STATUS.md`'yi oku** (projenin güncel durumu ve sıradaki adımlar); oturum sonunda güncelle. Kararların gerekçeleri `NOTES.md`'de.
- Önce plan (5–10 madde), sonra kod. Tek seferde tek milestone/özellik.
- Her adımdan sonra `flutter analyze` ve `flutter test` çalıştır; kırmızı test varken "bitti" deme. Test etmediğin şeye "çalışıyor" deme.
- Güvenlik içeren her özellikte saldırgan testi: token'sız istek, başkasının kaynağı, client'tan `current_price`/`status` güncelleme denemesi, anon key ile `bids`'e doğrudan yazma.
- **Git akışı (GitHub Flow):** `main` her zaman çalışır ve korumalıdır; doğrudan commit/push yok. Her iş kısa ömürlü bir branch'te yapılır (`feat/m2-auction-list`, `fix/…`, `docs/…`, `chore/…`, `test/…`), GitHub'da PR açılır, CI yeşilse "Squash and merge" ile `main`'e alınır ve branch silinir. Bir milestone birden fazla PR olabilir.
- **Commit'leri Claude atmaz.** Her adım sonunda commit mesajını ve çalıştırılacak git komutlarını (PowerShell'e yapıştırılabilir) verir; commit ve push'u Deniz yapar.
- Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). Force push, veri silme, production'a deploy öncesi onay al.
- Kararları ve teknik borcu `NOTES.md`'ye yaz.
- Yeni bağımlılık eklemeden önce gerçekten gerekli mi düşün; pubspec sürümleri sabit.

## Komutlar

- Çalıştırma: `flutter run --dart-define-from-file=.env` (önce `cp .env.example .env`)
- Analiz: `flutter analyze`
- Test: `flutter test`
- Local Supabase (Docker açık olmalı): `npx supabase start` / `npx supabase stop`
- Yeni migration uygulama: `npx supabase migration up`; şemayı sıfırdan kurma: `npx supabase db reset`
- SQL testleri: `npx supabase test db`
- Repository'leri gerçek local Supabase'e karşı test etme: `flutter test test_supabase --dart-define-from-file=.env` (`flutter test` bunları çalıştırmaz)
- Uçtan uca UI testi (gerçek uygulama + local Supabase): `flutter test integration_test -d windows --dart-define-from-file=.env`
- VS Code'da Run/F5 `.env`'i otomatik geçirir (`.vscode/settings.json` → `dart.flutterRunAdditionalArgs`). Masaüstünde denemek için `windows/` lokal olarak üretilir ve git'e girmez.
- Edge Function deploy: M4'te eklenecek.
