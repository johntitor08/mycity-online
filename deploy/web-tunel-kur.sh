#!/bin/bash
# Tarayıcı sürümü tünelini kullanıcı servisi olarak kurar ve başlatır (oturum açıkken hep çalışır,
# çökerse yeniden başlar). Kaldırmak için: systemctl --user disable --now mycity-web-tunel
set -euo pipefail
cd "$(dirname "$0")"
install -Dm755 web-tunel.sh "$HOME/.local/bin/mycity-web-tunel.sh"
install -Dm644 mycity-web-tunel.service "$HOME/.config/systemd/user/mycity-web-tunel.service"
systemctl --user daemon-reload
systemctl --user enable --now mycity-web-tunel.service
sleep 25
systemctl --user is-active mycity-web-tunel
grep -E "adres yayınlandı|UYARI" "$HOME/.local/state/mycity-tunel.log" | tail -2
