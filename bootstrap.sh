#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — persiapan awal server (cukup dijalankan SEKALI)
# ============================================================
# Apa yang dilakukan:
#   1. Cek Docker & Docker Compose sudah terpasang
#   2. Buat network Docker bersama (proxy-network, shared-db-network)
#   3. Buat folder data di /srv/data
#   4. Salin .env.example -> .env untuk tiap service yang belum punya
#
# Cara pakai (dari root repo):
#   ./bootstrap.sh
#
# Aman dijalankan berulang — tidak ada yang ditimpa.
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_ROOT="${DATA_ROOT:-/srv/data}"

say() { printf '\n==> %s\n' "$1"; }

# --- 1. Cek dependensi --------------------------------------
say "Cek Docker..."
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker belum terpasang."
  echo "Cara install: lihat README bagian 'Setup Server Baru'."
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose plugin belum terpasang."
  echo "Cara install: https://docs.docker.com/compose/install/linux/"
  exit 1
fi
echo "OK: $(docker --version)"

# --- 2. Network Docker bersama -------------------------------
# Network ini "ruang pertemuan" antar container:
#   proxy-network       -> nginx <=> semua app yang punya website
#   shared-db-network   => mysql <=> semua app yang butuh database
say "Siapkan network Docker..."
docker network create proxy-network >/dev/null 2>&1 \
  && echo "OK: proxy-network dibuat" \
  || echo "OK: proxy-network sudah ada"

docker network create shared-db-network >/dev/null 2>&1 \
  && echo "OK: shared-db-network dibuat" \
  || echo "OK: shared-db-network sudah ada"

# --- 3. Folder data ------------------------------------------
# Semua data (database, backup) hidup di sini, di luar repo,
# supaya update repo tidak pernah menyentuh data.
say "Buat folder data di ${DATA_ROOT}..."
mkdir -p "${DATA_ROOT}/mysql" "${DATA_ROOT}/backup/mysql"
echo "OK: ${DATA_ROOT}/mysql , ${DATA_ROOT}/backup/mysql"

# --- 4. File .env per service --------------------------------
# .env berisi password dll. Template (.env.example) ada di git,
# file aslinya (.env) tidak — dibuat sekali di tiap server.
say "Siapkan file .env per service..."
env_found=0
while IFS= read -r example; do
  target="${example%.example}"
  if [[ -f "$target" ]]; then
    echo "SKIP (sudah ada): ${target#${ROOT_DIR}/}"
  else
    cp "$example" "$target"
    echo "OK (dibuat): ${target#${ROOT_DIR}/}  <- ISI password-nya secara manual"
  fi
  env_found=1
done < <(find "$ROOT_DIR" -name '.env.example' -not -path '*/node_modules/*')

if [[ $env_found -eq 0 ]]; then
  echo "INFO: belum ada .env.example di repo ini"
fi

# --- Selesai -------------------------------------------------
say "Bootstrap selesai!"
cat <<'EOF'

Langkah selanjutnya:
  1. Isi semua file .env yang baru dibuat (password, dll).
  2. Jalankan service satu per satu:
       docker compose -f database/mysql/docker-compose.yml up -d
       docker compose -f nginx/docker-compose.yml up -d
  3. Setup domain + SSL: ikuti README bagian "Menambah Website Baru".
EOF
