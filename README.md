# UKS Digital

Sistem informasi Unit Kesehatan Sekolah (UKS): pemeriksaan siswa, pemberian obat, stok, alat kesehatan, dan alur penjemputan siswa sakit. Data yang disimpan adalah data kesehatan anak, jadi **keamanan adalah syarat utama**, bukan tambahan.

- Frontend: HTML, CSS, dan JavaScript biasa (tanpa framework, tanpa library pihak ketiga), folder `public/`
- Backend: Supabase (PostgreSQL, Auth, Row Level Security), folder `supabase/`
- Hosting: Vercel (folder `public/` disajikan sebagai situs statis)

## Struktur folder

```
public/                 situs yang tayang (index.html, app.js, style.css, _headers)
supabase/schema.sql     skema database lengkap (tabel, aturan akses, fungsi)
supabase/migrations/    taruh perubahan skema berikutnya di sini
supabase/tests/         uji keamanan SQL (uji_keamanan.sql)
tests/smoke.js          uji asap tampilan (jsdom)
vercel.json             pengaturan Vercel + header keamanan
```

Hanya isi `public/` yang bisa diunduh pengunjung. File lain tidak ikut tayang.

## Peran

| Peran | Nama di aplikasi | Bisa apa |
|---|---|---|
| `admin` | Penanggung Jawab UKS | Semua: kelola akun, obat, alat, lihat semua data |
| `petugas_uks` | Administrasi UKS | Input pemeriksaan, beri obat, verifikasi jemput, ubah status alat |
| `wali_kelas` | Wali Kelas | Lihat siswa di kelasnya sendiri, konfirmasi penjemputan |

Alur penjemputan: petugas input pemeriksaan, wali kelas konfirmasi, petugas verifikasi fisik penjemput.

## Menjalankan sendiri

1. Buat project Supabase baru (kosong).
2. Buka SQL Editor, tempel isi `supabase/schema.sql`, lalu Run.
3. Di `public/app.js`, baris pertama, ganti `U` (URL project) dan `K` (kunci **publishable**, bukan `service_role`) dengan milik project Anda. Ubah juga alamat Supabase di `connect-src` pada `vercel.json` dan `public/_headers`.
4. Di Supabase, menu Authentication, atur:
   - password minimum 12 karakter
   - konfirmasi email tetap aktif
   - matikan pendaftaran publik jika semua staf akan dibuat manual
5. Buka situs, daftar dengan email Anda, lalu jadikan diri Anda admin lewat SQL Editor (satu kali saja):

```sql
insert into public.profiles (id, full_name, role)
select id, 'Nama Anda', 'admin' from auth.users where email = 'email@anda.com';
update auth.users set email_confirmed_at = now() where email = 'email@anda.com';
```

Setelah itu semua akun lain disetujui dari menu **Akun** di aplikasi.

Uji lokal: `cd public && python3 -m http.server 8000`, lalu buka http://localhost:8000.

## Deploy ke Vercel

Import repo ini di Vercel, biarkan pengaturan bawaan. `vercel.json` sudah mengarahkan ke folder `public/` dan memasang header keamanan. Tidak ada build.

## Pengujian

```
npm install
npm test
```

`npm test` memeriksa bahwa semua menu tampil dan teks berbahaya di data tidak dijalankan. Untuk database, jalankan `supabase/tests/uji_keamanan.sql` di project **dev**. Semua baris hasil harus "ditolak" atau "0 baris terlihat".

## Aturan keamanan (jangan dilanggar)

**Database**
- Semua perubahan data lewat fungsi (RPC) `security definer` yang mengecek peran di baris pertama. Jangan membuka `insert/update/delete` langsung ke tabel untuk non-admin.
- Pendaftaran akun **tidak boleh** membuat profil atau memberi peran otomatis, dan peran tidak boleh diambil dari data yang dikirim pendaftar. Peran hanya diberi Admin lewat `approve_user()`.
- Tabel baru: aktifkan RLS, jalankan `revoke all on public.<tabel> from anon, authenticated`, lalu beri `grant` seperlunya dan tulis policy.
- Fungsi baru: wajib `set search_path`, cek peran di awal, lalu `revoke execute ... from public, anon` dan `grant execute ... to authenticated`. Mencabut dari `public` saja tidak cukup.
- Log pemberian obat tidak boleh dihapus (ada trigger). Koreksi lewat alur pengajuan dan persetujuan.
- Sebelum rilis: jalankan Security Advisor Supabase dan `uji_keamanan.sql`. Peringatan "security definer function executable" untuk fungsi RPC memang disengaja karena tiap fungsi mengecek peran sendiri.

**Frontend**
- Jangan pakai `innerHTML`. Tampilkan data lewat helper `h()` atau `textContent`.
- Jangan tambah skrip, font, atau gambar dari domain luar. CSP hanya mengizinkan `'self'` dan Supabase. Jika benar-benar perlu, ubah CSP dengan sadar dan catat alasannya.
- Jangan simpan token di `localStorage`. Saat ini hanya refresh token di `sessionStorage`, dan sesi otomatis keluar setelah 15 menit tidak aktif.

**Umum**
- Jangan pernah commit kunci `service_role`, password database, atau file `.env`.
- Jangan pakai data siswa asli untuk pengembangan. Pakai data contoh.
- Repo sebaiknya Private. Beri akses hanya ke orang yang mengerjakan.

## Yang sudah ada di database tapi belum ada tampilannya

- Koreksi log obat: `request_medicine_correction`, `approve_medicine_correction`, `reject_medicine_correction`
- Umpan aktivitas (`activity_log`) per peran
- Pengelolaan kelas (`classes`) dan data siswa lengkap (NISN, golongan darah, alergi)

## Belum dikerjakan

- Mode offline / PWA (kolom `offline_synced` sudah disiapkan)
- Notifikasi
- Aturan panjang password dan batas percobaan login perlu diatur di dashboard Supabase, bukan lewat kode
