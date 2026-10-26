#!/bin/bash
# VPS'te root olarak çalışır (deploy/kur.sh çağırır). Tekrar çalıştırmak güvenlidir: güncelleme de budur.
set -euo pipefail
PORT="${PORT:-7777}"
SRC=/tmp/mycity

id mycity &>/dev/null || useradd --system --home-dir /var/lib/mycity --create-home --shell /usr/sbin/nologin mycity
install -d -o mycity -g mycity -m 750 /var/lib/mycity
install -d -m 755 /opt/mycity

# Çalışıyorsa düzgünce durdur (kayıt yazılsın), sonra yeni sürümü koy
if systemctl is-active --quiet mycity; then systemctl stop mycity; fi
install -m 755 "$SRC/MyCityOnline.x86_64" /opt/mycity/MyCityOnline.x86_64
install -m 644 "$SRC/mycity.service" /etc/systemd/system/mycity.service
sed -i "s/--port=[0-9]*/--port=$PORT/" /etc/systemd/system/mycity.service
install -m 755 "$SRC/yedekle.sh" /usr/local/bin/mycity-yedekle
# taşınan kayıt (sadece VPS'te henüz kayıt yoksa)
KAYIT_DIR="/var/lib/mycity/.local/share/godot/app_userdata/MyCity Online"
if [ -f "$SRC/mycity_kayit.json" ] && [ ! -f "$KAYIT_DIR/mycity_kayit.json" ]; then
	install -d -o mycity -g mycity -m 750 "$KAYIT_DIR"
	install -o mycity -g mycity -m 640 "$SRC/mycity_kayit.json" "$KAYIT_DIR/mycity_kayit.json"
	echo "kayıt taşındı"
fi
echo "17 4 * * * root /usr/local/bin/mycity-yedekle" > /etc/cron.d/mycity-yedek

WS_PORT=$((PORT + 1))
DOMAIN="${DOMAIN:-}"

# Güvenlik duvarı: oyun UDP portu, tarayıcı oyuncuları için WebSocket (TCP), alan adı varsa 80/443 (SSH'a dokunma)
ac() {  # ac PORT PROTO
	if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
		ufw allow "$1/$2" >/dev/null
	elif command -v iptables >/dev/null; then
		# Oracle Cloud gibi varsayılan olarak her şeyi reddeden iptables kuralları için
		iptables -C INPUT -p "$2" --dport "$1" -j ACCEPT 2>/dev/null || iptables -I INPUT -p "$2" --dport "$1" -j ACCEPT
	fi
}
ac "$PORT" udp
ac "$WS_PORT" tcp
if [ -n "$DOMAIN" ]; then ac 80 tcp; ac 443 tcp; fi
if command -v netfilter-persistent >/dev/null; then netfilter-persistent save >/dev/null 2>&1 || true; fi

# Web sürümü ve alan adı: Caddy hem oyunu (https://alanadı/) sunar hem de wss://alanadı/oyun'u sunucuya aktarır.
# Sertifikayı (Let's Encrypt) kendisi alır ve yeniler.
if [ -d "$SRC/web" ]; then
	rm -rf /opt/mycity/web
	cp -r "$SRC/web" /opt/mycity/web
	chmod -R a+rX /opt/mycity/web
fi
if [ -n "$DOMAIN" ]; then
	if ! command -v caddy >/dev/null; then
		apt-get update -qq && apt-get install -y -qq caddy
	fi
	cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
	encode gzip
	@oyun path /oyun
	reverse_proxy @oyun 127.0.0.1:$WS_PORT
	root * /opt/mycity/web
	file_server
}
EOF
	systemctl enable caddy >/dev/null 2>&1 || true
	systemctl reload caddy || systemctl restart caddy
fi

systemctl daemon-reload
systemctl enable --now mycity
sleep 3
systemctl is-active mycity
journalctl -u mycity -n 5 --no-pager -o cat
rm -rf "$SRC"
