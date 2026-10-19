# stackbase

Template infrastruktur server: **nginx (reverse proxy) + MySQL**, jalan di Docker Compose. General — bisa dipakai server apa pun.

| Service | Fungsi |
|---|---|
| nginx | Reverse proxy + SSL — pintu masuk semua domain |
| mysql | Database (port hanya di localhost) |

## Setup Server Baru

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # logout-login dulu setelah ini

# 2. Clone repo
git clone <URL-REPO> ~/stackbase && cd ~/stackbase

# 3. Bootstrap — buat network, folder data, certbot, salin .env.example
./bootstrap.sh

# 4. Isi password database
nano database/mysql/.env        # MYSQL_ROOT_PASSWORD wajib diisi

# 5. Jalankan service
docker compose -f database/mysql/docker-compose.yml up -d
docker compose -f nginx/docker-compose.yml up -d
docker ps                       # dua-duanya harus status Up

# 6. Cron auto-renew SSL (opsional, disarankan)
./scripts/setup-cron.sh
```

## Menambah Website

Contoh: app `myapp` jalan di port `3000`, domain `app.example.com`.

1. DNS — A record: `app.example.com → IP-publik-server`

2. Compose aplikasi ikut network nginx:

   ```yaml
   services:
     myapp:
       image: ghcr.io/user/myapp:latest
       container_name: myapp
       networks:
         - proxy-network

   networks:
     proxy-network:
       external: true
   ```

3. Config site — dari folder `nginx/`:

   ```bash
   cp src/conf.d/sites/00-CONTOH.conf.example src/conf.d/sites/app.example.com.conf
   # Ganti NAMADOMAIN → app.example.com
   # Ganti NAMA-CONTAINER-APP:PORT → myapp:3000
   ```

4. Sertifikat + aktifkan:

   ```bash
   sudo certbot certonly --standalone -d app.example.com
   # catatan: --standalone butuh port 80 — stop nginx dulu jika bentrok, start lagi setelahnya
   docker compose restart nginx
   ```

Anatomi config + glossary nginx: [nginx/src/sites-README.md](nginx/src/sites-README.md).

## Deploy Aplikasi (GHCR)

```bash
# Sekali saja — butuh GitHub PAT dengan izin read:packages
echo "<PAT>" | docker login ghcr.io -u <username> --password-stdin

# Tiap versi baru
docker pull ghcr.io/user/myapp:latest
docker compose -f /path/ke/myapp/docker-compose.yml up -d
```

## Backup & Restore

```bash
# Backup manual — hasil: /srv/data/backup/mysql/YYYY-MM-DD_all.sql.gz, simpan 14 hari
./scripts/backup.sh

# Restore satu database
gunzip < /srv/data/backup/mysql/2026-10-19_all.sql.gz \
  | docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" nama_db'
```

## Troubleshooting

| Cek | Command |
|---|---|
| Container mati? | `docker ps -a` |
| Log nginx / app | `docker logs nginx --tail 50` |
| Config nginx valid? | `docker exec nginx nginx -t` |
| Disk penuh? | `df -h` · `du -sh /srv/data/*` |

## Aturan

- Config **hanya lewat repo** — tidak ada config di luar git; edit di repo, `git pull` di server.
- `.env` tidak pernah di-commit. Data hidup di `/srv/data`.
- MySQL hanya localhost. Akses dari luar = SSH tunnel / Tailscale — **jangan pernah buka port publik**.
- Selalu `docker exec nginx nginx -t` sebelum restart nginx.
- Service baru = folder baru + `docker-compose.yml` sendiri, join `proxy-network` (web) atau `shared-db-network` (butuh DB).

## Struktur

```
stackbase/
├── bootstrap.sh               setup awal server (sekali jalan)
├── scripts/
│   ├── backup.sh              backup database manual
│   └── setup-cron.sh          pasang cron auto-renew SSL
├── database/mysql/            service database
└── nginx/                     reverse proxy
    └── src/conf.d/sites/      satu .conf per domain (kerja harian di sini)
```
