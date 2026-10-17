#!/bin/sh
# Projeyi Godot düzenleyicisinde açar.
exec flatpak run org.godotengine.Godot --path "$(dirname "$(readlink -f "$0")")" -e
