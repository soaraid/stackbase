#!/usr/bin/env bash
# bootstrap awal server: cek docker, buat network + folder data, salin .env.example -> .env (aman dijalankan berulang)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_ROOT="${DATA_ROOT:-/srv/data}"

say() { printf '\n==> %s\n' "$1"; }

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

say "Siapkan network Docker..."
docker network create proxy-network >/dev/null 2>&1 \
  && echo "OK: proxy-network dibuat" \
  || echo "OK: proxy-network sudah ada"

docker network create shared-db-network >/dev/null 2>&1 \
  && echo "OK: shared-db-network dibuat" \
  || echo "OK: shared-db-network sudah ada"

say "Buat folder data di ${DATA_ROOT}..."
mkdir -p "${DATA_ROOT}/mysql" "${DATA_ROOT}/backup/mysql"
echo "OK: ${DATA_ROOT}/mysql , ${DATA_ROOT}/backup/mysql"

say "Siapkan file .env per service..."
env_found=0
while IFS= read -r example; do
  target="${example%.example}"
  if [[ -f "$target" ]]; then
    echo "SKIP (sudah ada): ${target#${ROOT_DIR}/}"
  else
    cp "$example" "$target"
    echo "OK (dibuat): ${target#${ROOT_DIR}/}  <- isi password-nya secara manual"
  fi
  env_found=1
done < <(find "$ROOT_DIR" -name '.env.example' -not -path '*/node_modules/*')

if [[ $env_found -eq 0 ]]; then
  echo "INFO: belum ada .env.example di repo ini"
fi

say "Bootstrap selesai!"
cat <<'EOF'

Langkah selanjutnya:
  1. Isi semua file .env yang baru dibuat (password, dll).
  2. Jalankan service satu per satu:
       docker compose -f database/mysql/docker-compose.yml up -d
       docker compose -f nginx/docker-compose.yml up -d
  3. Setup domain + SSL: ikuti README bagian "Menambah Website Baru".
EOF
