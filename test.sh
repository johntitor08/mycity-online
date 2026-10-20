#!/bin/sh
# Otomatik testler:
#  1) ev sahibi modu (+ ticaret için ikinci oyuncu olarak yardımcı istemci)
#  2) adanmış sunucu + istemci (gerçek ağ üzerinden, şifre testleri dahil)
D="$(dirname "$(readlink -f "$0")")"
G="flatpak run org.godotengine.Godot --headless --path $D"
trap 'pkill -f "^/app/bin/godot-bin.*test_srv[.]json"; pkill -f "^/app/bin/godot-bin.*test-yardimci"' EXIT
$G -- --test-yardimci > /dev/null 2>&1 &
$G -- --test-host | grep -E "OK|HATA|SONUÇ|poker\]|atlandı" || exit 1
# Test sunucusu ayrı portta çalışır; açık bir oyun sunucusuyla çakışmaz.
$G -- --sunucu --port=7795 --kayit=user://test_srv.json > /dev/null 2>&1 &
sleep 3
$G -- --test-istemci --port=7795 | grep -E "HATA|SONUÇ"
