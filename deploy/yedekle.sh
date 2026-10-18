#!/bin/sh
# Günlük kayıt yedeği; 14 günden eski yedekler silinir.
SRC="/var/lib/mycity/.local/share/godot/app_userdata/MyCity Online/mycity_kayit.json"
DST=/var/lib/mycity/yedekler
mkdir -p "$DST"
[ -f "$SRC" ] && cp "$SRC" "$DST/kayit-$(date +%F).json"
find "$DST" -name 'kayit-*.json' -mtime +14 -delete
chown -R mycity:mycity "$DST"
