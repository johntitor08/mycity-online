#!/bin/sh
# playit ajanı takılırsa yeniden başlat:
#  - son 3 satırın hepsi "register" zaman aşımıysa VE son satır 90 sn'den yeniyse
#    (takılı ajan bu hatayı yarım saniyede bir yazar; sağlıklı ajan log yazmaz, eski satırlar kalır), ya da
#  - son satır ağ hatasıyla "failed to send ping" ise (ağ değişince ajan kendini toparlayamıyor), ya da
#  - son satırlar "Network unreachable" ise (uykudan uyanınca ajan eski ağda takılı kalıyor).
LOG="$HOME/.local/state/playit/playit.log"
[ -f "$LOG" ] || exit 0
last=$(tail -n 1 "$LOG" | sed 's/\x1b\[[0-9;]*m//g')
ts=$(echo "$last" | cut -c1-19)
age=$(( $(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null || echo 0) ))
stuck=""
if [ "$(tail -n 3 "$LOG" | grep -c 'timeout waiting for register response')" -eq 3 ] && [ "$age" -lt 90 ]; then
	stuck="register zaman aşımı"
elif echo "$last" | grep -q 'failed to send ping'; then
	stuck="ağ hatası (ping)"
elif [ "$(tail -n 4 "$LOG" | grep -c 'Network unreachable')" -ge 3 ] && [ "$age" -lt 90 ]; then
	stuck="ağ ulaşılamaz (uykudan sonra)"
fi
if [ -n "$stuck" ]; then
	systemctl --user restart playit.service
	echo "$(date '+%F %T') playit takılmıştı ($stuck), yeniden başlatıldı" >> "$HOME/.local/state/playit/bekci.log"
fi
