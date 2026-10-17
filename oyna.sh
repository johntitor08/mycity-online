#!/bin/sh
# Oyunu açar (menüden "Sunucu Kur ve Oyna" ya da "Sunucuya Katıl").
exec flatpak run org.godotengine.Godot --path "$(dirname "$(readlink -f "$0")")" "$@"
