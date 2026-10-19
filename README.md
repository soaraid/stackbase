# stackbase

Template infrastruktur server yang sederhana: **nginx (reverse proxy) + MySQL**, semuanya jalan di Docker, dengan backup otomatis dan panduan yang bisa diikuti orang baru.

Cocok untuk server kantor maupun pribadi. Tidak ada keajaiban — hanya Docker Compose, config yang dikomentari, dan dokumen ini.

---

## Daftar Isi

1. [Konsep Dasar 5 Menit](#1-konsep-dasar-5-menit) — wajib baca sekali
2. [Setup Server Baru dari Nol](#2-setup-server-baru-dari-nol)
3. [Tugas Rutin](#3-tugas-rutin) — sehari-hari, paling sering dibuka
4. [Akses Database dari Luar](#4-akses-database-dari-luar)
5. [Aturan Main](#5-aturan-main)
6. [Struktur Repo](#6-struktur-repo)

---

## 1. Konsep Dasar 5 Menit

### Apa itu container / Docker?

Container = "paket aplikasi siap jalan". Daripada install MySQL manual di
server (ribet, kotor, susah dipindah), kita jalankan MySQL sebagai container.
Mau hapus/upgrade? Hapus containernya, datanya tetap aman di folder host.

### Apa isi server ini?

Hanya ada **2 service**:

| Service | Fungsi |
|---|---|
| **nginx** | Pintu masuk semua website. Menerima `https://namadomain.com` lalu meneruskan ke aplikasi yang tepat |
| **mysql** | Database untuk semua aplikasi |

Aplikasi lain (web kantor, API, dll) ditambah belakang sebagai container
terpisah — tidak ada di repo ini. Repo ini cuma fondasinya.

### Bagaimana orang membuka website kamu?

```
1. Kamu punya domain, mis. app.kantor.com
2. Di panel domain (DNS), dibuat A record:
       app.kantor.com  ->  IP-publik-server
3. Browser pengunjung nyambung ke server port 443 (HTTPS)
4. nginx membaca nama domain yang diminta, cocokkan dengan
   config di nginx/src/conf.d/sites/
5. nginx meneruskan ke container aplikasi
```

**Konfigurasi nginx ada di repo ini** (`nginx/src/conf.d/sites/`), bukan
di dalam container. Container nginx "menempel" membaca folder itu
(mekanisme mount). Makanya alur kerjanya:

> edit file di repo -> commit -> di server `git pull` -> restart nginx

Satu sumber kebenaran: **isi repo = isi server**. Tidak ada config
tersembunyi yang cuma ada di server.

### Bagaimana aplikasi konek ke database?

Container yang ikut network `shared-db-network` bisa konek ke MySQL
cukup dengan hostname `mysql` port `3306`. Database **tidak** bisa
diakses dari internet — portnya hanya dibuka di localhost.

---

## 2. Setup Server Baru dari Nol

Ikuti berurutan. Sekali setup, tidak perlu diulang.

### Langkah 1 — Install Docker

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Install Docker (cara resmi)
curl -fsSL https://get.docker.com | sudo sh

# Pastikan docker jalan tanpa sudo (logout-login dulu setelah ini)
sudo usermod -aG docker $USER

# Cek
docker --version
docker compose version
```

### Langkah 2 — Ambil repo ini

```bash
git clone <URL-REPO-INI> ~/stackbase
cd ~/stackbase
```

### Langkah 3 — Jalankan bootstrap

```bash
./bootstrap.sh
```

Script ini: cek Docker & certbot, buat network antar container, buat
folder data di `/srv/data`, dan menyalin template `.env`.

### Langkah 4 — Isi password database

```bash
# Buka file, isi MYSQL_ROOT_PASSWORD dengan password panjang & acak
nano database/mysql/.env

# Contoh membuat password acak (copy hasilnya):
openssl rand -base64 24
```

### Langkah 5 — Nyalakan service

```bash
docker compose -f database/mysql/docker-compose.yml up -d
docker compose -f nginx/docker-compose.yml up -d

# Cek semua jalan (dua-duanya harus status "Up")
docker ps
```

### Langkah 6 — Buat sertifikat SSL domain pertama

Sertifikat SSL dibuat di **host** (bukan di Docker) dengan certbot
(sudah dipasang oleh bootstrap.sh), lalu otomatis terbaca oleh nginx
lewat mount.

```bash
# Buat sertifikat untuk domain pertama.
# (Domain harus sudah diarahkan ke IP server lewat DNS dulu!)
sudo certbot certonly --standalone -d app.kantor.com
```

> Catatan: `--standalone` butuh port 80 kosong sebentar. Kalau nginx
> sedang jalan, matikan dulu: `docker compose -f nginx/docker-compose.yml stop`,
> jalankan certbot, lalu `start` lagi. Setelah sertifikat pertama ada,
> nginx tetap jalan dan sertifikat berikutnya bisa dibuat dengan
> `--webroot` atau stop-start lagi.

### Langkah 7 — Pasang auto-renew SSL (sekali, opsional tapi disarankan)

```bash
./scripts/setup-cron.sh
```

Script ini memasang cron di server: sertifikat diperpanjang otomatis
2x sehari (hanya yang mendekati kadaluarsa) dan nginx langsung reload.
Cek kalau sudah terpasang: `sudo crontab -l`.

**Selesai.** Lanjut ke [Tugas Rutin](#3-tugas-rutin) untuk menambah website pertama.

---

## 3. Tugas Rutin

### 3.1 Menambah website baru (aplikasi sudah jalan sebagai container)

Contoh kasus: ada aplikasi bernama `inventaris` yang jalan di port `3000`.

1. **Arahkan domain** — di panel DNS, buat A record:
   `inventaris.kantor.com -> IP-publik-server`

2. **Pastikan app ikut network nginx** — di docker-compose aplikasi:

   ```yaml
   services:
     inventaris:
       image: ghcr.io/kantor/inventaris:latest
       container_name: inventaris
       networks:
         - proxy-network

   networks:
     proxy-network:
       external: true
   ```

3. **Buat config site** (dari folder `nginx/`):

   ```bash
   cp src/conf.d/sites/00-CONTOH.conf.example src/conf.d/sites/inventaris.kantor.com.conf
   nano src/conf.d/sites/inventaris.kantor.com.conf
   # Ganti: NAMADOMAIN -> inventaris.kantor.com
   #        NAMA-CONTAINER-APP:PORT -> inventaris:3000
   ```

4. **Buat sertifikat SSL** (di host), lalu apply config:

   ```bash
   sudo certbot certonly --standalone -d inventaris.kantor.com   # stop nginx dulu kalau port 80 dipakai
   docker compose restart nginx
   ```

5. **Cek di browser** — buka `https://inventaris.kantor.com`

> Detail istilah (server_name, proxy_pass, dll): baca
> [nginx/src/sites-README.md](nginx/src/sites-README.md).

### 3.2 Deploy / update aplikasi (image dari GitHub — GHCR)

Image aplikasi disimpan di GitHub Container Registry (`ghcr.io`), bukan
di server ini. Alur: build + push dari laptop/CI, lalu tarik di server.

**Sekali saja** — login GHCR di server (butuh GitHub PAT dengan izin `read:packages`):

```bash
echo "TOKEN_GITHUB_PAT" | docker login ghcr.io -u USERNAME-GITHUB --password-stdin
```

Tiap ada versi baru:

```bash
docker pull ghcr.io/kantor/inventaris:latest
docker compose -f /path/ke/app/inventaris/docker-compose.yml up -d
```

### 3.3 Troubleshooting cepat

| Gejala | Perintah | Arti |
|---|---|---|
| Website down | `docker ps -a` | ada container status `Exited`? |
| Lihat log error | `docker logs nginx --tail 50` | 50 baris terakhir log nginx |
| Lihat log app | `docker logs NAMA-APP --tail 50` | idem, untuk app |
| Config nginx salah | `docker exec nginx nginx -t` | "syntax is ok" = aman |
| Disk penuh? | `df -h` dan `du -sh /srv/data/*` | cek pemakaian |
| Semua log nginx | `docker exec nginx ls /var/log/nginx` | file log di dalam container |

Urutan panik yang benar: `docker ps` -> `docker logs` -> baru tanya orang.

### 3.4 Backup & restore manual

```bash
# Backup sekarang juga
~/stackbase/scripts/backup.sh

# Lihat isi backup (file tersimpan di /srv/data/backup/mysql/)
ls -lh /srv/data/backup/mysql/

# Restore ke database tertentu (contoh: db_kantor)
gunzip < /srv/data/backup/mysql/2026-10-19_all.sql.gz \
  | docker exec -i mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" db_kantor'
```

Saat ini backup berjalan **manual** — jalankan `scripts/backup.sh`
kapan saja perlu. Simpan 14 hari terakhir.

> Kalau nanti mau dibuat otomatis (mis. tiap jam 2 pagi), tinggal
> tambahkan baris ini ke crontab: `0 2 * * * /path/ke/stackbase/scripts/backup.sh`

> Saran: backup di server yang sama tetap bisa hilang kalau servernya
> yang mati. Kalau kantor punya storage/NAS/akun cloud lain, salin folder
> `/srv/data/backup/` ke sana secara berkala.

---

## 4. Akses Database dari Luar

Port database sengaja **tidak** dibuka ke internet. Kalau suatu saat butuh
mengakses MySQL dari laptop (mis. pakai DBeaver/TablePlus), **jangan buka
port publik** — pilih salah satu yang aman:

| Cara | Cocok untuk | Catatan |
|---|---|---|
| **SSH tunnel** (paling simpel) | 1-2 orang, sesekali | `ssh -L 3307:127.0.0.1:3306 user@server` lalu konek ke `localhost:3307` di laptop. Tidak ada yang perlu diubah di server |
| **Tailscale** | akses rutin / tim kecil | VPN pribadi gratis; database dianggap "di jaringan kantor". Dicatat di sini sebagai rencana ekspansi — belum terpasang |

Dua-duanya tidak membuka port apa pun ke internet.

---

## 5. Aturan Main

1. **Config hanya lewat repo.** Jangan pernah edit file config langsung di
   server tanpa commit. Repo = keadaan server. Kalau beda, itu bug.
2. **`.env` tidak pernah di-commit** — isinya password. Yang di-commit cuma
   `.env.example` (template kosong).
3. **Data hidup di `/srv/data`** — bukan di dalam container, bukan di repo.
   Jangan pindah-pindah tanpa update dokumentasi ini.
4. **Setiap service punya foldernya sendiri** dengan `docker-compose.yml`
   sendiri. Mau tambah service (mis. MinIO, Redis)? Buat folder baru,
   tiru pola folder yang ada, join network yang sesuai
   (`proxy-network` untuk web, `shared-db-network` untuk yang butuh database).
5. **Sebelum restart nginx setelah edit config**, jalankan dulu:
   `docker exec nginx nginx -t`. Kalau error, benerin dulu.
6. **Update dokumentasi.** Kalau ada yang berubah (service baru, port baru,
   domain baru), update README ini di commit yang sama. Dokumen basi lebih
   bahaya daripada tidak ada dokumen.

### Kartu perintah sering dipakai

| Keperluan | Perintah (dari folder yang disebut) |
|---|---|
| Nyalakan service | `docker compose -f database/mysql/docker-compose.yml up -d` |
| Restart nginx | `docker compose -f nginx/docker-compose.yml restart` |
| Cek config nginx | `docker exec nginx nginx -t` |
| Reload nginx tanpa putus koneksi | `docker exec nginx nginx -s reload` |
| Lihat semua container | `docker ps -a` |
| Log service | `docker logs NAMA-CONTAINER --tail 50 -f` |
| Backup manual | `./scripts/backup.sh` |

---

## 6. Struktur Repo

```
stackbase/
├── README.md                  <- dokumen ini
├── bootstrap.sh               <- setup awal server (sekali jalan)
├── scripts/
│   ├── backup.sh              <- backup database manual (opsional dibuat cron)
│   └── setup-cron.sh          <- pasang cron auto-renew SSL (opsional)
├── database/
│   └── mysql/                 <- service database
│       ├── docker-compose.yml
│       └── .env.example       <- template password (aslinya tidak di-commit)
└── nginx/
    ├── docker-compose.yml     <- service reverse proxy
    └── src/
        ├── nginx.conf         <- config utama (jarang diubah)
        ├── sites-README.md    <- cara baca config site + glossary
        └── conf.d/
            ├── default.conf   <- pemuat folder sites/
            └── sites/         <- SATU FILE PER DOMAIN (di sinilah kerja harian)
                └── 00-CONTOH.conf.example
```

Mau menambah service baru (MinIO, Redis, app, dll)? Tiru polanya:
folder baru + `docker-compose.yml` + `.env.example` + join network yang
sesuai. Nggak lebih dari itu.
