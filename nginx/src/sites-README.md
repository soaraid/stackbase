# Cara Membaca Config Site (folder `sites/`)

Folder ini isinya **satu file `.conf` per domain**. Contoh:
`app.example.com.conf`, `dashboard.example.com.conf`.

Kalau bingung istilahnya, baca bagian [Glossary](#glossary) di bawah.
Yang mau langsung praktik, ikuti README utama bagian
**"Menambah Website Baru"**.

---

## Anatomi satu file site

```
server {
    listen 443 ssl;              <- dengarkan di port HTTPS
    server_name app.example.com;  <- domain mana yang masuk ke blok ini

    ssl_certificate ...;         <- kunci + sertifikat SSL (dari certbot)

    location / {                 <- semua path ("/", "/api", dll)
        proxy_pass http://app-ku:3000;   <- teruskan ke container app
    }
}
```

Alurnya:

```
Browser ketik app.example.com
   -> DNS mengarah ke IP server
   -> masuk nginx port 443
   -> nginx cocokkan "server_name"
   -> proxy_pass ke container app lewat proxy-network
```

## Kapan perlu mengubah apa

| Mau apa | Ubah apa |
|---|---|
| Tambah website baru | buat file `.conf` baru dari `00-CONTOH.conf.example` |
| Naikkan batas upload file | `client_max_body_size 50M` di file site itu |
| App pakai port lain | bagian `set $app NAMA-CONTAINER:PORT` |
| Cek config ada typo atau tidak | `docker exec nginx nginx -t` |
| Terapkan perubahan config | `docker compose restart nginx` (di folder `nginx/`) |

## Aturan main

- **Satu domain = satu file `.conf`.** Namanya samakan dengan domain
  (contoh: `app.example.com.conf`) biar gampang dicari.
- **Jangan edit config langsung di server** tanpa commit — repo ini
  adalah satu-satunya sumber kebenaran config.
- Setelah edit, **selalu cek dulu**: `docker exec nginx nginx -t`.
  Kalau "syntax is ok" baru restart. Kalau salah, nginx tidak jalan.

---

## Glossary

**Reverse proxy**
"Pramubakti" yang duduk di depan semua app. Semua pengunjung datang
ke dia, lalu dia mengantar ke app yang tepat di belakang. Manfaatnya:
app tidak perlu terbuka ke internet, SSL cukup dipasang di satu tempat.

**server_name**
Nama domain yang dilayani oleh blok `server { }` itu. Nginx membaca
domain yang diminta browser, lalu memilih blok yang cocok.

**listen**
Port yang didengarkan: `80` = HTTP, `443` = HTTPS.

**proxy_pass**
Perintah "teruskan permintaan ini ke alamat X". Alamatnya nama
container + port internal (bukan IP, bukan port publik).

**location**
Bagian URL mana yang diatur. `location /` = semua URL. Bisa dibuat
khusus, mis. `location /api/` untuk aturan berbeda.

**client_max_body_size**
Batas ukuran data yang boleh dikirim pengunjung (upload file, form
besar). Default nginx hanya 1 MB — makanya di template diset 50M.

**Sertifikat SSL** (`/etc/letsencrypt/...`)
File yang membuat koneksi jadi `https://` (terenkripsi, ada gembok di
browser). Dibuat oleh certbot di host, gratis dari Let's Encrypt,
otomatis diperbarui oleh cron (lihat README).

**resolver 127.0.0.11**
Alamat DNS internal Docker. Karena `proxy_pass` memakai nama container
(bukan IP), nginx butuh DNS ini untuk mencarinya. Ada trik
`set $app ...` di template supaya pencarian ini diulang berkala.

**WebSocket** (`Upgrade` / `Connection "upgrade"`)
Teknologi untuk koneksi dua arah (chat, notifikasi live). Header di
template membuatnya otomatis jalan; app biasa tidak terpengaruh.
