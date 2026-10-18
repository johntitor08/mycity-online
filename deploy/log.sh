#!/bin/bash
# Sunucu loglarını canlı izle. Kullanım: ./deploy/log.sh root@SUNUCU_IP
ssh -i "${MYCITY_SSH_KEY:-$HOME/.ssh/mycity_vps}" "${1:?Kullanım: ./deploy/log.sh root@SUNUCU_IP}" "sudo journalctl -u mycity -f -o cat"
