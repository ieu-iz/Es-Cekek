# 🍹 Es Cekek (3D Simulator Jualan Es Plastik Khas Indonesia)

![Status](https://img.shields.io/badge/Status-MVP%20Playable%20%2B%204%20builds%20(Win%2FLin%2FMac%2FAndroid)-green?style=for-the-badge)
![Engine](https://img.shields.io/badge/Engine-Godot-4.x-blue?style=for-the-badge&logo=godotengine)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux%20%7C%20Android-green?style=for-the-badge)

**Es Cekek** adalah game simulasi 3D bertema kuliner jalanan khas Indonesia. Pemain berperan sebagai pedagang es kantong plastik (es rendengan/es cekek) yang berkeliling menjajakan es sachet di berbagai lokasi ikonik seperti Pasar, Sekolah, dan Pemukiman Warga.

> ✅ **Status Proyek: MVP v1 — GAMEPLAY LENGKAP, BISA DIMAINKAN, SUDAH DI-BUILD.**
> Seluruh core loop sudah jadi dan **teruji otomatis 346/346 asersi hijau** + game berhasil boot tanpa error.
> **Build sudah tersedia untuk 4 platform**: Windows `.exe`, Linux, macOS `.zip`, dan Android `.apk`.
> Yang belum ada hanya polesan visual/voice akhir dan QA APK di HP asli.
> Cara memainkan: buka `project.godot` di Godot 4.7.2 lalu tekan **F5**. Detail lengkap di bawah.

---

## 📸 Overview & Gameplay

Di game ini, kualitas es yang kamu sajikan ditentukan oleh ketepatan racikan, peralatan toko yang dipakai, dan kepuasan pelanggan. **Tanpa minigame rumit**, fokus penuh pada simulasi meracik, strategi harga, dan kepuasan pembeli!

### 🔄 Siklus Utama Jualan (Core Loop)
1. **Pilih Lokasi & Buka Stand:** Berkeliling di area **Pasar**, **Sekolah**, atau **Rumah**.
2. **Terima Pesanan:** Dengarkan teriakan pesanan dari pelanggan yang datang.
3. **Racik Es Cekek — first-person dengan dua tangan:** berdiri di depan meja → view berubah jadi
   **first-person**, tangan kiri & kanan tampil di layar. **Tidak ada tombol menu** — semua
   langkah dilakukan dengan **drag objek 3D** di meja:
   - ✂️ Tangan kiri pegang **sachet** (Tejus/Marimas/Jasjus/Frenta), tangan kanan pegang **gunting**
     → **potong sachet** (brand ikut terpotong & otomatis dipilih).
   - 🛍️ Tangan yang bebas mengambil **plastik** → serbub sachet **dimasukkan ke plastik**.
   - 💧 **Jerigen air** → tuang air ke plastik.
   - 🥄 **Sendok** → aduk sampai larut.
   - 🧊 **Serok** ke **cooler es** → serok terisi → masukkan es ke plastik.
   - 🥤 **Sedotan** → pasang di plastik.
   - ⚠️ Urutan itu **wajib** — langkah salah urutan menurunkan kualitas racikan.
   - 🤚 Objek yang dekat dengan **tangan kanan** diambil tangan kanan, dekat tangan kiri → tangan
     kiri. `Q` menukar isi kedua tangan.
4. **Reaksi Pelanggan:** kalau esnya **belum siap**, pelanggan **komplain** persis apa yang kurang
   (*"Kurang: Belum ada es!, Belum dikasih air!, …"*). Kalau **sudah siap**, pelanggan
   **mengambil tasnya sendiri** — tinggal atur harga lalu sajikan.
5. **Atur Harga & Sajikan:** Tentukan harga jual ideal agar pelanggan tidak protes (*"Mahal amat!"*) dan beri pelayanan cepat sebelum pelanggan kesal.
6. **Manajemen Ekonomi & Toko:** Bayar sewa tempat harian, rekap keuntungan, lalu upgrade peralatan jualan seperti dispenser air, mixer otomatis, hingga cooler es batu yang lebih besar.

---

## ✨ Fitur Utama

- 🧤 **Racik First-Person dengan Dua Tangan:** view berubah jadi first-person saat di meja; objek
  sungguhan (4 sachet, gunting, tumpukan plastik, jerigen air, cooler es + serok, sendok, sedotan)
  diambil & digeser dengan mouse. Panel tombol racik yang lama **dihapus total** — digantikan HUD
  minimal (harga + status pesanan + tombol *Serahkan*).
- 📱 **Kontrol Layar Sentuh yang Lengkap:** mouse dan multi-jari berbagi satu mesin state pointer —
  1 jari di objek = ambil, 1/2 jari di area kosong = melihat, geser jari = objek ikut bergerak,
  plus tombol layar **Tukar Tangan** & **Putar Badan** untuk yang tidak punya keyboard.
- 🏢 **3 Lokasi Unik:** Pasar (ramai, sewa tinggi), Sekolah (sedang), dan Rumah (santai, sewa murah).
- 🍹 **4 Merek Sachet Khas:** Mulai dari sachet hemat Rp 1.000 hingga sachet premium Rp 5.000.
- 🛠️ **Sistem Equipment & Upgrade Toko:** Meja jualan, gantungan sachet, dispenser air, es cooler kecil/besar, dan mixer.
- 🌅 **Siklus Hari & Pencahayaan Dinamis:** Perubahan waktu dari fajar, siang terik, senja, hingga malam yang memengaruhi pencahayaan dan langit secara real-time.
- 😠 **Sistem Ekspresi & Keluhan Pembeli:** Pembeli memiliki level kekesalan (annoyance rate), balon ucapan keluhan 3D, serta reaksi fisik jika terlalu lama menunggu atau kemahalan.
- 🎨 **Visual 3D Racikan Real-Time:** Minuman di meja memperlihatkan warna cairan sachet, tingkat kepudaran berdasarkan kualitas/porsi es, serta sedotan secara visual.
- 🔊 **Audio Prosedural (tanpa aset eksternal):** semua bunyi (tuang, aduk, es, kasir, keluhan) disintesis saat runtime sebagai PCM 16-bit, ditambah musik ambient loop.
- 🧊 **Dunia 3D Bertenaga Aset CC0 (Kenney):** 197 mesh low-poly — karakter, gedung toko, rumah & pohon, aspal jalan, perabot warung (meja, kursi, bangku, kasir), sampai makanan & minuman. Semuanya **CC0** dengan gaya yang konsisten.

---

## 🛠️ Spesifikasi Teknis & Framework

- **Engine:** Godot Engine 4.7.2 (GDScript)
- **Renderer:** Mobile (Vulkan/D3D12) di desktop, otomatis turun ke **Compatibility (OpenGL 3.3)** bila GPU tidak mendukung; Android dipaksa `gl_compatibility` (GLES3) agar HP tua tetap bisa jalan.
- **Target Platform:** Windows, macOS, Linux, Android (APK) — preset export di `export_presets.cfg`, **build ke-4 platform sudah dibuat** (`build/`).
- **Automated Testing:** Suite pengujian otomatis berbasis headless scene dengan **346 asersi** (semua hijau).
- **Aset 3D:** **197 mesh CC0 (Kenney)** di `assets/kenney/` — karakter (mini-characters), gedung/toko,
  rumah & pohon, jalan, perabot warung, dan makanan. Gaya low-poly yang konsisten.
  Unduh & subset dilakukan oleh `scripts/prepare_kenney_assets.ps1`.
- **Aset Audio:** **0 aset eksternal** — seluruh bunyi disintesis runtime sebagai PCM 16-bit.

---

## 🚀 Cara Menjalankan untuk Pengembang (Developer Setup)

### Prasyarat
- [Godot Engine 4.x](https://godotengine.org/download) (diuji dengan Godot 4.7.2 stable)

### Steps 1 — Import Project
1. Clone repositori:
   ```bash
   git clone https://github.com/ieu-iz/es-cekek.git
   cd es-cekek
   ```
2. Buka Godot Engine Dashboard → **Import** → pilih berkas `project.godot`.
3. Tunggu proses import selesai (membuat folder `.godot/`).

### Cara MAIN (paling cepat)

**Opsi A — klik ganda `run.bat` (tanpa perlu build sama sekali):**

```cmd
run.bat            :: main game langsung dari source code
run.bat --editor   :: buka Godot Editor
run.bat --test     :: smoke test + boot check (headless)
run.bat --build    :: export 4 platform sekaligus (Windows/Linux/macOS/Android)
run.bat --headless :: game tanpa jendela
```

`run.bat` mencari binary Godot sendiri di `%LOCALAPPDATA%\Godot\`. Kalau Godot ada di tempat
lain, set env var dulu: `set GODOT=C:\path\to\Godot.exe`.

**Opsi B — dari editor:** tekan **F5** (atau tombol ▶ Play). Scene utama = `res://src/Main.tscn`.

### Kontrol

| Aksi | Desktop | Sentuh (Android) |
|---|---|---|
| Jalan | `W A S D` / panah | Virtual joystick kiri-bawah |
| Interaksi (buka stand → mode racik) | `E` atau `F` | Tombol **INTERAKSI** |
| Lihat sekeliling (mode racik) | Gerak mouse — pitch ±35°, yaw ±60° | Geser **1 jari di area kosong** atau **2 jari** |
| Ambil objek | Klik-kiri **tahan** di objek | **1 jari di objek** |
| Tangan yang dipakai | Otomatis **tangan terdekat**; `Q` = tukar tangan | Otomatis tangan terdekat; tombol layar **Tukar Tangan** |
| Geser objek | Tahan klik-kiri lalu gerakkan | Seret 1 jari (objek ikut, pandangan diam) |
| Letakkan objek | Lepas klik (jatuh di meja) / klik-kanan | Lepas jari |
| Putar badan 180° | `R` | Tombol layar **Putar Badan** |
| Sajikan (tas sudah jadi) | Tombol **Serahkan** di HUD racik | Tombol **Serahkan** di HUD racik |
| Keluar dari mode racik | `Esc` / tombol **Keluar** | Tombol **Keluar** |
| Ber Traveling antar lokasi | Panel lokasi / `Tab` | Panel lokasi |
| Atur harga | Slider harga (desktop) / tombol `−` `+` | Tombol `−` `+` (Rp 500 per langkah) |

### Menjalankan Automated Smoke Tests (headless — tanpa jendela)
Seluruh pengujian berjalan **headless** (tidak memunculkan window):

```cmd
scripts\run_tests.cmd         # Unit & integration test (346 asersi)
scripts\run_tests.cmd --boot  # Tes jalan + boot game headless selama 120 frame
```

> ⚠️ Jangan pernah menjalankan `godot --script ...` untuk test — mode itu-register autoload setelah kompilasi class global sehingga `Identifier not found: Catalog`. Suite **harus** dijalankan sebagai scene `res://tests/runtime_test.tscn`.

### Cara Export (build yang bisa dikirim / dimainkan)
Preset tersedia di `export_presets.cfg`: **Windows Desktop**, **Linux**, **macOS**, **Android**.

1. **Pasang export template** (sekali saja, ±1,28 GB):
   Godot Editor → **Editor** → **Manage Export Templates** → download versi **4.7.2.stable**.
   Tanpa ini, export gagal dengan pesan `No export template found at the expected path`.
2. (Android saja) Pasang **Android SDK + JDK**, set *Android SDK Path* + *Java SDK Path* di
   **Editor Settings**, dan pastikan debug keystore tersedia.
3. **Project → Export…** → pilih preset → **Export Project** / **Export All**.

Output (sudah pernah dibuat & diuji):

| Platform | File | Ukuran |
|---|---|---|
| Windows | `build/windows/EsCekek.exe` (+ `EsCekek.pck`) | 109,1 MB + 3,4 MB |
| Linux | `build/linux/EsCekek.x86_64` (+ `EsCekek.pck`) | 73,5 MB + 3,4 MB |
| macOS | `build/macos/EsCekek.zip` (universal) | 62,9 MB |
| Android | `build/android/EsCekek.apk` | 89,8 MB (signed) |

> Folder `build/` di-ignore Git → jalankan ulang export bila ingin build sendiri.

Atau lewat CLI (headless):
```cmd
godot --headless --path . --export-release "Windows Desktop" build\windows\EsCekek.exe
godot --headless --path . --export-release "Linux"         build\linux\EsCekek.x86_64
godot --headless --path . --export-release "macOS"         build\macos\EsCekek.zip
godot --headless --path . --export-debug   "Android"       build\android\EsCekek.apk
```

> ⚠️ **Android harus `--export-debug`.** `--export-release` mencari *release keystore* yang tidak
> ada di preset → export gagal dengan `Could not find release keystore, unable to export.`
> (APK sempat tertulis tapi **tidak signed**). `--export-debug` memakai debug keystore dari
> *Editor Settings* → APK signed + `.idsig` tergenerate, dan tetap bisa di-*sideload*.

#### 📱 Install APK di HP (Android)

**⭐ Cara paling gampang — TANPA adb:**

1. Di PC, salin `build\android\EsCekek.apk` ke HP:
   - **Kabel USB** → di HP pilih mode **"File Transfer / MTP"** (bukan "Charge only"),
     lalu copy file `EsCekek.apk` ke folder **Download** di HP.
   - Atau kirim via **Google Drive / WhatsApp / Telegram / Email** (link Google Drive paling
     aman untuk file 90 MB; WhatsApp kadang gagal untuk file >100 MB).
2. Di HP buka **Files / My Files → Download → `EsCekek.apk`** → ketuk file-nya.
3. Android akan minta izin: **Settings → Apps → Special app access → Install unknown apps**
   → pilih aplikasi yang kamu pakai untuk membuka file (Files / Chrome / WhatsApp) → **Allow**.
   (Android 8+; di bawah itu, cukup centang "Unknown sources" di Security.)
4. Ketuk **Install** → tunggu → selesai. Aplikasi **"Es Cekek"** muncul di drawer.
5. Kalau diminta, izinkan install dari sumber itu sekali saja. APK ini **signed** (debug key)
   jadi tidak akan ditolak sebagai "app tidak terverifikasi".

> **Catatan:** file `.idsig` (`EsCekek.apk.idsig`, 718 KB) **tidak perlu** dikirim ke HP —
> itu hanya metadata untuk Play Store, bukan bagian dari aplikasi.

**Alternatif — lewat adb (kalau HP sudah USB debugging):**

1. Aktifkan **Developer options → USB debugging** di HP.
2. Sambungkan HP via USB (atau `adb connect <ip:port>` untuk Wi-Fi).
3. Cek perangkat terdeteksi: `adb devices`
4. Install: `adb install -r build\android\EsCekek.apk`
5. Luncurkan: `adb shell monkey -p com.escekek.game 1`

> `adb` di PC ini ada di `C:\Users\WIN10\AppData\Local\Android\Sdk\platform-tools\adb.exe`
> (belum ada di PATH). Pakai full path kalau `adb` tidak ketemu.

> APK sudah signed (debug key), package `com.escekek.game`, minSdk 24 (Android 7.0),
> targetSdk 36, dukungan `arm64-v8a` + `armeabi-v7a` + `x86_64`.
> Kalau di HP sudah ada versi Es Cekek dari signature berbeda → **uninstall dulu** lalu install ulang.

---

## 🗺️ Roadmap / Progress Pengembangan

- [x] **Phase 1: Core Mechanics** (Player Movement, Interaksi Stand, Sistem Racik)
- [x] **Phase 2: Game Loop & Economy** (Sistem Pelanggan, Evaluasi Racikan, Siklus Hari, Sewa Lokasi)
- [x] **Phase 3: Shop & Upgrades** (Toko Equipment, Upgrade Cooler & Mixer, Katalog Brand)
- [x] **Phase 4: Dynamic Lighting & Visual Feedback** (Siklus Siang/Malam 3D, Visual Tas Es 3D, Bubble Keluhan 3D)
- [x] **Phase 5: Audio** (Procedural SFX Tuang/Aduk/Es/Kasir + Music Loop ambient)
- [x] **Phase 6: Export & Build** (4 preset + export template + build Windows/Linux/macOS/Android; `.exe` & `.apk` terverifikasi)
- [x] **Phase 6.5: Art 3D** (asset Kenney CC0: karakter, 3 lokasi, perabot warung)
- [x] **Phase 6.6: First-Person Hands** (panel prep lama dibongkar total; racik manual dengan
      drag objek 3D & dua tangan; pelanggan komplain kalau belum siap, ambil sendiri kalau siap)
- [x] **Phase 6.7: Kontrol Layar Sentuh** (mouse + multi-jari berbagi satu mesin state pointer;
      1 jari di objek = ambil, 1/2 jari di area kosong = lihat; tombol layar **Tukar Tangan** &
      **Putar Badan**; 346 asersi hijau)
- [ ] **Phase 7: Polish & Release** (voice keluhan, VFX, warna lokasi, QA APK di perangkat asli)

### ⚠️ Yang belum selesai (jujur)
| Item | Status |
|---|---|
| APK belum diinstall & diuji di HP asli (Task 11 QA) | APK sudah jadi (`build/android/EsCekek.apk`, 89,8 MB, **signed**) — tinggal salin ke HP + install dari file manager (tanpa adb) |
| Voice keluhan pelanggan | Belum ada (bubble teks 3D + bunyi `complain` sudah ada) |
| VFX (siram/aduk/es beradu) | Belum ada |
| Warna lokasi berbeda | Partially (tint matahari per lokasi sudah ada) |
| `assets/` (art CC0) | ✅ Selesai — 197 mesh Kenney CC0 (karakter, lokasi, propsi stand) |
| Visual belum pernah dinilai mata di editor | GPU PC ini jatuh ke renderer Compatibility/OpenGL — perlu eyeball di editor |
| Kontrol sentuh untuk mode racik first-person | ✅ **Selesai (Task 16)** — mouse + multi-jari satu mesin state pointer, takeover mouse-tiruan ↔ jari, tombol layar **Tukar Tangan**/**Putar Badan**, 346 asersi hijau. Yang tersisa: **feel-nya** dinilai manual di HP (lihat `todo.md` → "✍️ TUGAS MANUAL") |
| Build di `build/` | ⚠️ Build terakhir masih versi **Task 15** — Task 16 belum di-ekspor ulang. Jalankan `run.bat --build` sebelum mengirim APK ke HP |

---

## 📜 Lisensi & Kredit

- **Kode & Aset Game:** Hak cipta dilindungi undang-undang / MIT License (dapat disesuaikan).
- **Dibuat oleh:** Tim Pengembang *Es Cekek*.

---
*Dibuat dengan ❤️ dan es sachet dingin segar dari Indonesia!*
