#!/bin/sh
# Otomatik testler: önce ev sahibi modu, sonra adanmış sunucu + istemci (gerçek ağ üzerinden).
D="$(dirname "$(readlink -f "$0")")"
G="flatpak run org.godotengine.Godot --headless --path $D"
$G -- --test-host | grep -E "OK|HATA|SONUÇ|poker\]" || exit 1
# Test sunucusu ayrı portta çalışır; açık bir oyun sunucusuyla çakışmaz ve çıkışta kapatılır.
$G -- --sunucu --port=7795 --kayit=user://test_srv.json > /dev/null 2>&1 &
trap 'pkill -f "godot-bin.*test_srv[.]json"' EXIT
sleep 3
$G -- --test-istemci --port=7795 | grep -E "HATA|SONUÇ"
