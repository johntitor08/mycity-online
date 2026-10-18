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
echo "17 4 * * * root /usr/local/bin/mycity-yedekle" > /etc/cron.d/mycity-yedek

# Güvenlik duvarı: UDP portunu aç (SSH'a dokunma)
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
	ufw allow "$PORT/udp"
elif command -v iptables >/dev/null; then
	# Oracle Cloud gibi varsayılan olarak her şeyi reddeden iptables kuralları için
	iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT
	if command -v netfilter-persistent >/dev/null; then netfilter-persistent save >/dev/null 2>&1 || true; fi
fi

systemctl daemon-reload
systemctl enable --now mycity
sleep 3
systemctl is-active mycity
journalctl -u mycity -n 5 --no-pager -o cat
rm -rf "$SRC"
