#!/usr/bin/env bash
# pasang cron auto-renew SSL ke crontab root (opsional, cukup sekali; aman dijalankan berulang)

set -euo pipefail

CRON_ENTRY='0 3,15 * * * certbot renew --quiet --deploy-hook "docker exec nginx nginx -s reload"'

if ! command -v certbot >/dev/null 2>&1; then
  echo "ERROR: certbot belum terpasang. Jalankan bootstrap.sh dulu." >&2
  exit 1
fi

if sudo crontab -l 2>/dev/null | grep -q 'certbot renew'; then
  echo "OK: cron renew SSL sudah terpasang"
else
  (sudo crontab -l 2>/dev/null; echo "$CRON_ENTRY") | sudo crontab -
  echo "OK: cron renew SSL dipasang (2x sehari, nginx otomatis reload)"
fi
