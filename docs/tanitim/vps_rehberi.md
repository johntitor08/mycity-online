# 7/24 sunucu ve tarayıcı sürümü — adım adım

Bilgisayarın kapalıyken (ya da uykudayken) de oyun açık kalsın ve oyun tarayıcıdan oynanabilsin diye.
Hesap açma ve ödeme kısmını **sen** yaparsın; gerisini (kurulum, güncelleme) tek komutla Claude yapar.

## 1) Sunucu (VPS) al — biri yeter

**A) Oracle Cloud — ücretsiz (Always Free)**
1. https://www.oracle.com/cloud/free/ → "Start for free" → hesap aç (kart doğrulaması ister ama ücret almaz).
2. Compute → Instances → **Create instance**
   - Image: **Ubuntu 24.04** (Canonical)
   - Shape: **VM.Standard.E2.1.Micro** (Always Free, x86) — *Ampere (ARM) seçme*, oyun x86_64 için derleniyor.
   - "Add SSH keys" → **Paste public key** → aşağıdaki anahtarı yapıştır.
3. Oluşunca **Public IP**'yi not et. Kullanıcı adı: `ubuntu`.
4. Ağ izinleri: Instance → Subnet → **Security List** → Add Ingress Rules:
   - UDP **7777** (masaüstü oyuncular), TCP **7778** (tarayıcı), TCP **80** ve **443** (web sayfası ve sertifika)
   - Source CIDR: `0.0.0.0/0`

**B) Hetzner — ~4 €/ay, kurulumu daha kolay**
1. https://www.hetzner.com/cloud → hesap aç → yeni proje → **Add Server**
   - Location: Falkenstein ya da Helsinki, Image: **Ubuntu 24.04**, Type: **CX22** (x86)
   - SSH keys → **Add SSH key** → aşağıdaki anahtarı yapıştır.
2. IP'yi not et. Kullanıcı adı: `root`. (Hetzner'de varsayılan güvenlik duvarı yok, ek ayar gerekmez.)

**Yapıştırılacak SSH anahtarı** (bu bilgisayarda `~/.ssh/mycity_vps.pub`):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIClJXJHY2lxVZe9yoYSahADuknNpmi1vJfdQbjHua7eA mycity-vps
```

## 2) Ücretsiz alan adı (tarayıcı sürümü için gerekli)

Tarayıcılar güvenli bağlantı (https/wss) ister; bunun için bir alan adı gerekir.
1. https://www.duckdns.org → GitHub/Google ile giriş.
2. Bir ad seç (ör. `mycityonline`) → **current ip** kutusuna VPS'in IP'sini yaz → **update ip**.
3. Adresin: `mycityonline.duckdns.org`

## 3) Claude'a şunu söyle
"VPS hazır: IP `…`, kullanıcı `ubuntu` (ya da `root`), alan adı `….duckdns.org`"

Claude şunu çalıştırır:
```
./deploy/kur.sh ubuntu@IP 7777 mycityonline.duckdns.org --kayit
```
Bu komut: oyunu ve tarayıcı sürümünü derler, VPS'e kurar, çökünce/yeniden başlayınca kendiliğinden açılan
servisi kurar, gece yedek alır, Caddy ile **https://mycityonline.duckdns.org** adresinde tarayıcı sürümünü
yayınlar ve sertifikayı alır. Sonra oyundaki "Resmi Sunucuya Katıl" adresi VPS'e çevrilir ve yeni sürüm yayınlanır.

## Sonuç
- Masaüstü: itch.io'dan indir → **Resmi Sunucuya Katıl**
- Tarayıcı: **https://mycityonline.duckdns.org** (ya da itch.io sayfasında "Tarayıcıda oyna")
- Bilgisayarın kapalı olsa bile sunucu açık kalır. Mevcut oyuncu kaydı da VPS'e taşınır.
