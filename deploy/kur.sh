#!/bin/bash
# Sunucuyu VPS'e kurar ya da günceller (aynı komut).
# Kullanım: ./deploy/kur.sh root@SUNUCU_IP [port]     (Oracle'da kullanıcı: ubuntu@SUNUCU_IP)
set -euo pipefail
HEDEF="${1:?Kullanım: ./deploy/kur.sh root@SUNUCU_IP [port]}"
PORT="${2:-7777}"
D="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${MYCITY_SSH_KEY:-$HOME/.ssh/mycity_vps}"
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

echo "== Linux sürümü derleniyor"
mkdir -p "$D/build/linux"
flatpak run org.godotengine.Godot --headless --path "$D" --export-release "Linux" "$D/build/linux/MyCityOnline.x86_64" > /dev/null 2>&1
echo "== Dosyalar gönderiliyor: $HEDEF"
ssh "${SSH_OPTS[@]}" "$HEDEF" "mkdir -p /tmp/mycity"
scp "${SSH_OPTS[@]}" -q "$D/build/linux/MyCityOnline.x86_64" "$D/deploy/mycity.service" \
	"$D/deploy/yedekle.sh" "$D/deploy/sunucu-kurulum.sh" "$HEDEF:/tmp/mycity/"
echo "== Kuruluyor"
ssh "${SSH_OPTS[@]}" "$HEDEF" "sudo PORT=$PORT bash /tmp/mycity/sunucu-kurulum.sh"
echo "== Bitti. Oyunculara adres: ${HEDEF#*@}  port: $PORT"
