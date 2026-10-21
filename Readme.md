# 🍹 Es Cekek (3D Simulator Jualan Es Plastik Khas Indonesia)

![Status](https://img.shields.io/badge/Status-MVP%20Playable%20%2B%204%20builds%20(Win%2FLin%2FMac%2FAndroid)-green?style=for-the-badge)
![Engine](https://img.shields.io/badge/Engine-Godot-4.x-blue?style=for-the-badge&logo=godotengine)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux%20%7C%20Android-green?style=for-the-badge)

**Es Cekek** adalah game simulasi 3D bertema kuliner jalanan khas Indonesia. Pemain berperan sebagai pedagang es kantong plastik (es rendengan/es cekek) yang berkeliling menjajakan es sachet di berbagai lokasi ikonik seperti Pasar, Sekolah, dan Pemukiman Warga.

> ✅ **Status Proyek: MVP v1 — GAMEPLAY LENGKAP, BISA DIMAINKAN, SUDAH DI-BUILD.**
> Seluruh core loop sudah jadi dan **teruji otomatis 246/246 asersi hijau** + game berhasil boot tanpa error.
> **Build sudah tersedia untuk 4 platform**: Windows `.exe`, Linux, macOS `.zip`, dan Android `.apk`.
> Yang belum ada hanya polesan visual/voice akhir dan QA APK di HP asli.
> Cara memainkan: buka `project.godot` di Godot 4.7.2 lalu tekan **F5**. Detail lengkap di bawah.

---

## 📸 Overview & Gameplay

Di game ini, kualitas es yang kamu sajikan ditentukan oleh ketepatan racikan, peralatan toko yang dipakai, dan kepuasan pelanggan. **Tanpa minigame rumit**, fokus penuh pada simulasi meracik, strategi harga, dan kepuasan pembeli!

### 🔄 Siklus Utama Jualan (Core Loop)
1. **Pilih Lokasi & Buka Stand:** Berkeliling di area **Pasar**, **Sekolah**, atau **Rumah**.
2. **Terima Pesanan:** Dengarkan teriakan pesanan dari pelanggan yang datang.
3. **Racik Es Cekek:**
   - 📦 Pilih sachet yang sesuai (Tejus, Marimas, Jasjus, Frenta).
   - 💧 Tuang sachet & tambahkan air.
   - 🥄 Aduk racikan hingga larut sempurna.
   - 🧊 Tambahkan es batu sesuai porsi.
   - 🥤 Pasang sedotan & ikat kantong plastik!
4. **Atur Harga & Sajikan:** Tentukan harga jual ideal agar pelanggan tidak protes (*"Mahal amat!"*) dan beri pelayanan cepat sebelum pelanggan kesal.
5. **Manajemen Ekonomi & Toko:** Bayar sewa tempat harian, rekap keuntungan, lalu upgrade peralatan jualan seperti dispenser air, mixer otomatis, hingga cooler es batu yang lebih besar.

---

## ✨ Fitur Utama

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
- **Automated Testing:** Suite pengujian otomatis berbasis headless scene dengan **246 asersi** (semua hijau).
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
Tekan **F5** (atau tombol ▶ Play) di editor. Scene utama = `res://src/Main.tscn`.

### Kontrol

| Aksi | Desktop | Sentuh (Android) |
|---|---|---|
| Jalan | `W A S D` / panah | Virtual joystick kiri-bawah |
| Interaksi (buka stand / prep panel) | `E` atau `Space` | Tombol **INTERAKSI** |
| Tuang sachet / air / aduk / es / sedotan | `E` atau tombol panel prep | Tombol panel prep (kanan) |
| Sajikan | `E` / tombol **SAJIKAN** | Tombol **SAJIKAN** |
| Ber Traveling antar lokasi | Panel lokasi / `T` | Panel lokasi |
| Atur harga | Slider harga (desktop) / tombol `−` `+` | Tombol `−` `+` (Rp 500 per langkah) |

### Menjalankan Automated Smoke Tests (headless — tanpa jendela)
Seluruh pengujian berjalan **headless** (tidak memunculkan window):

```cmd
scripts\run_tests.cmd         # Unit & integration test (246 asersi)
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
1. Aktifkan **Developer options → USB debugging** di HP.
2. Sambungkan HP via USB (atau `adb connect <ip:port>` untuk Wi-Fi).
3. Cek perangkat terdeteksi: `adb devices`
4. Install: `adb install -r build\android\EsCekek.apk`
5. Luncurkan: `adb shell monkey -p com.escekek.game 1`

> APK sudah signed (debug key), package `com.escekek.game`, minSdk 24 (Android 7.0),
> targetSdk 36, dukungan `arm64-v8a` + `armeabi-v7a` + `x86_64`.

---

## 🗺️ Roadmap / Progress Pengembangan

- [x] **Phase 1: Core Mechanics** (Player Movement, Interaksi Stand, Sistem Racik)
- [x] **Phase 2: Game Loop & Economy** (Sistem Pelanggan, Evaluasi Racikan, Siklus Hari, Sewa Lokasi)
- [x] **Phase 3: Shop & Upgrades** (Toko Equipment, Upgrade Cooler & Mixer, Katalog Brand)
- [x] **Phase 4: Dynamic Lighting & Visual Feedback** (Siklus Siang/Malam 3D, Visual Tas Es 3D, Bubble Keluhan 3D)
- [x] **Phase 5: Audio** (Procedural SFX Tuang/Aduk/Es/Kasir + Music Loop ambient)
- [x] **Phase 6: Export & Build** (4 preset + export template + build Windows/Linux/macOS/Android; `.exe` & `.apk` terverifikasi)
- [x] **Phase 6.5: Art 3D** (asset Kenney CC0: karakter, 3 lokasi, perabot warung)
- [ ] **Phase 7: Polish & Release** (voice keluhan, VFX, warna lokasi, QA APK di perangkat asli)

### ⚠️ Yang belum selesai (jujur)
| Item | Status |
|---|---|
| APK belum diinstall & diuji di HP asli (Task 11 QA) | APK sudah jadi (`build/android/EsCekek.apk`) — tinggal pasang HP + `adb install` |
| Voice keluhan pelanggan | Belum ada (bubble teks 3D + bunyi `complain` sudah ada) |
| VFX (siram/aduk/es beradu) | Belum ada |
| Warna lokasi berbeda | Partially (tint matahari per lokasi sudah ada) |
| `assets/` (art CC0) | ✅ Selesai — 197 mesh Kenney CC0 (karakter, lokasi, propsi stand) |
| Visual belum pernah dinilai mata di editor | GPU PC ini jatuh ke renderer Compatibility/OpenGL — perlu eyeball di editor |

---

## 📜 Lisensi & Kredit

- **Kode & Aset Game:** Hak cipta dilindungi undang-undang / MIT License (dapat disesuaikan).
- **Dibuat oleh:** Tim Pengembang *Es Cekek*.

---
*Dibuat dengan ❤️ dan es sachet dingin segar dari Indonesia!*
