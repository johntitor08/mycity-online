#!/bin/sh
# Ekransız (adanmış) sunucu. Kullanım: ./sunucu.sh [port]   (varsayılan 7777)
exec flatpak run org.godotengine.Godot --headless --path "$(dirname "$(readlink -f "$0")")" -- --sunucu --port="${1:-7777}"
