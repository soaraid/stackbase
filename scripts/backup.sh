#!/usr/bin/env bash
# ============================================================
# backup.sh — backup semua database MySQL ke satu file .sql.gz
# ============================================================
# Dijalankan otomatis oleh cron (setup-nya di README bagian
# "Setup Backup Otomatis"). Bisa juga dijalankan manual:
#   ./scripts/backup.sh
#
# Hasil backup: /srv/data/backup/mysql/YYYY-MM-DD_all.sql.gz
# Backup lebih tua dari 14 hari dihapus otomatis.
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_ROOT="${DATA_ROOT:-/srv/data}"
BACKUP_DIR="${BACKUP_DIR:-${DATA_ROOT}/backup/mysql}"
RETAIN_DAYS="${RETAIN_DAYS:-14}"
ENV_FILE="${ROOT_DIR}/database/mysql/.env"

# --- Ambil password dari .env service mysql ------------------
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  echo "ERROR: MYSQL_ROOT_PASSWORD kosong. Pastikan ${ENV_FILE} sudah diisi." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# --- Backup ---------------------------------------------------
# Perintah mysqldump dijalankan DI DALAM container mysql, jadi
# password tidak pernah lewat shell host. --single-transaction
# membuat backup konsisten tanpa menghentikan database.
STAMP="$(date +%F)"
OUT="${BACKUP_DIR}/${STAMP}_all.sql.gz"

echo "==> Backup semua database ke ${OUT}"
docker exec mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction' \
  | gzip > "$OUT"

# --- Validasi hasil -------------------------------------------
if ! gzip -t "$OUT" 2>/dev/null; then
  echo "ERROR: file backup tidak valid (gzip rusak)! Segera cek disk/log." >&2
  exit 1
fi

SIZE=$(du -h "$OUT" | cut -f1)
echo "OK: backup valid (${SIZE})"

# --- Rotasi: hapus backup lama ---------------------------------
echo "==> Hapus backup lebih tua dari ${RETAIN_DAYS} hari..."
find "$BACKUP_DIR" -name '*_all.sql.gz' -type f -mtime "+${RETAIN_DAYS}" -delete
echo "==> Selesai."
