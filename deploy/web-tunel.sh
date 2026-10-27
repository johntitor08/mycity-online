#!/bin/bash
# MyCity Online tarayıcı sürümü için Cloudflare "quick tunnel" (hesapsız, ücretsiz).
# Bu bilgisayardaki sunucunun WebSocket portunu (7778) bir https/wss adresine açar.
# Adres her başlatmada değişir; yeni adres GitHub'daki johntitor08/mycity-online deposunun
# "sunucu" dalındaki adres.json dosyasına yazılır, tarayıcı sürümü "Resmi Sunucuya Katıl"da oradan okur.
#
# Gerekenler: ~/.local/bin/cloudflared ve oturum açılmış gh (GitHub CLI).
# Kurulum: deploy/web-tunel-kur.sh (servis olarak kurar ve başlatır).
export LC_ALL=C          # Türkçe yerel ayarda [a-z] aralığı "i" harfini kapsamıyor; adres yakalanamıyordu
LOG="$HOME/.local/state/mycity-tunel.log"
REPO="repos/johntitor08/mycity-online"
mkdir -p "$(dirname "$LOG")"

yayinla() {
	local wss="${1/https:/wss:}"
	local body sha deneme
	body=$(printf '{"wss": "%s", "guncelleme": %d}\n' "$wss" "$(date +%s)" | base64 -w0)
	# açılışta ağ ya da anahtarlık (gh token'ı) henüz hazır olmayabilir: 30 sn arayla 40 kez dene (~20 dk)
	for deneme in $(seq 1 40); do
		sha=$(timeout 30 gh api "$REPO/contents/adres.json?ref=sunucu" --jq .sha 2>>"$LOG")
		if [ -n "$sha" ] && timeout 30 gh api -X PUT "$REPO/contents/adres.json" -f message="Sunucu adresi: $wss" \
				-f content="$body" -f branch=sunucu -f sha="$sha" >/dev/null 2>>"$LOG"; then
			echo "$(date -Is) adres yayınlandı: $wss" >> "$LOG"
			return
		fi
		echo "$(date -Is) UYARI: adres yayınlanamadı ($deneme. deneme), 30 sn sonra yeniden" >> "$LOG"
		sleep 30
	done
}

echo "$(date -Is) tünel başlıyor" >> "$LOG"
"$HOME/.local/bin/cloudflared" tunnel --no-autoupdate --protocol http2 --url http://127.0.0.1:7778 2>&1 |
while IFS= read -r line; do
	echo "$line" >> "$LOG"
	if [[ $line =~ (https://[a-z0-9-]+\.trycloudflare\.com) ]] && [[ "${BASH_REMATCH[1]}" != "$last" ]]; then
		last="${BASH_REMATCH[1]}"
		yayinla "$last" &
	fi
done
