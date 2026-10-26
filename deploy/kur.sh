#!/bin/bash
# Sunucuyu VPS'e kurar ya da günceller (aynı komut).
# Kullanım: ./deploy/kur.sh root@SUNUCU_IP [port] [alan.adi] [--kayit]     (Oracle'da kullanıcı: ubuntu@SUNUCU_IP)
#  --kayit: ilk kurulumda bu bilgisayardaki sunucu kaydını (hesaplar, paralar, arsalar) VPS'e taşır.
#  alan.adi verilirse (ör. mycity.duckdns.org, VPS'in IP'sine yönlenmiş olmalı) tarayıcı sürümü de kurulur:
#  https://alan.adi/ adresinden oynanır, sertifika kendiliğinden alınır.
set -euo pipefail
HEDEF="${1:?Kullanım: ./deploy/kur.sh root@SUNUCU_IP [port] [alan.adi]}"
PORT="${2:-7777}"
DOMAIN="${3:-}"
D="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${MYCITY_SSH_KEY:-$HOME/.ssh/mycity_vps}"
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

echo "== Linux ve web sürümleri derleniyor"
mkdir -p "$D/build/linux" "$D/build/web"
flatpak run org.godotengine.Godot --headless --path "$D" --export-release "Linux" "$D/build/linux/MyCityOnline.x86_64" > /dev/null 2>&1
flatpak run org.godotengine.Godot --headless --path "$D" --export-release "Web" "$D/build/web/index.html" > /dev/null 2>&1 || echo "  (web şablonu yok, web sürümü atlandı)"
echo "== Dosyalar gönderiliyor: $HEDEF"
ssh "${SSH_OPTS[@]}" "$HEDEF" "rm -rf /tmp/mycity && mkdir -p /tmp/mycity"
scp "${SSH_OPTS[@]}" -q "$D/build/linux/MyCityOnline.x86_64" "$D/deploy/mycity.service" \
	"$D/deploy/yedekle.sh" "$D/deploy/sunucu-kurulum.sh" "$HEDEF:/tmp/mycity/"
if [ -f "$D/build/web/index.html" ]; then
	scp "${SSH_OPTS[@]}" -q -r "$D/build/web" "$HEDEF:/tmp/mycity/web"
fi
# --kayit: bu bilgisayardaki sunucu kaydını VPS'e taşı (sadece ilk kurulumda; VPS'te kayıt varsa dokunmaz)
if [ "${4:-}" = "--kayit" ]; then
	YEREL="$HOME/.local/share/godot/app_userdata/MyCity Online/mycity_kayit.json"
	[ -f "$YEREL" ] && scp "${SSH_OPTS[@]}" -q "$YEREL" "$HEDEF:/tmp/mycity/mycity_kayit.json" && echo "  kayıt gönderildi"
fi
echo "== Kuruluyor"
ssh "${SSH_OPTS[@]}" "$HEDEF" "sudo PORT=$PORT DOMAIN=$DOMAIN bash /tmp/mycity/sunucu-kurulum.sh"
echo "== Bitti. Masaüstü oyunculara adres: ${HEDEF#*@}  port: $PORT"
if [ -n "$DOMAIN" ]; then
	echo "   Tarayıcıdan oynamak için: https://$DOMAIN/"
fi
