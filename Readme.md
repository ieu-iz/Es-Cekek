# 🍹 Es Cekek (3D Simulator Jualan Es Plastik Khas Indonesia)

![Status](https://img.shields.io/badge/Status-In%20Development-orange?style=for-the-badge)
![Engine](https://img.shields.io/badge/Godot-4.x-blue?style=for-the-badge&logo=godotengine)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux%20%7C%20Android-green?style=for-the-badge)

**Es Cekek** adalah game simulasi 3D bertema kuliner jalanan khas Indonesia. Pemain berperan sebagai pedagang es kantong plastik (es rendengan/es cekek) yang berkeliling menjajakan es sachet di berbagai lokasi ikonik seperti Pasar, Sekolah, dan Pemukiman Warga.

> 🚧 **Status Proyek:** **Masih Dalam Pengembangan (In Development)**  
> Fitur gameplay utama (core loop) dan sistem ekonomi sudah berjalan. Saat ini sedang dalam tahap polesan audio (procedural SFX), efek visual, dan persiapan build export (APK Android & Desktop).

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

---

## 🛠️ Spesifikasi Teknis & Framework

- **Engine:** Godot Engine 4.x (GDScript)
- **Renderer:** Mobile / Compatibility (Dioptimalkan untuk Android & Low-End PC)
- **Target Platform:** Windows, macOS, Linux, Android (APK)
- **Automated Testing:** Suite pengujian otomatis berbasis headless scene dengan 170+ asersi test passing.

---

## 🚀 Cara Menjalankan untuk Pengembang (Developer Setup)

### Prasyarat
- [Godot Engine 4.x](https://godotengine.org/download) (diuji menggunakan Godot 4.7.2+)

### Langkah Jalankan Project
1. **Clone Repositori:**
   ```bash
   git clone https://github.com/username/es-cekek.git
   cd es-cekek
   ```
2. **Buka di Godot:**
   - Buka Godot Engine Dashboard.
   - Klik **Import**, pilih berkas `project.godot` di dalam direktori proyek.
   - Tekan **F5** (atau klik Play) untuk menjalankan dari scene utama (`res://src/Main.tscn`).

### Menjalankan Automated Smoke Tests
Proyek ini dilengkapi dengan skrip pengujian otomatis (Headless Runtime Test):
- **Windows Batch Runner:**
  ```cmd
  scripts\run_tests.cmd         # Menjalankan unit & integration test
  scripts\run_tests.cmd --boot  # Tes jalan + boot game headless selama 120 frame
  ```

---

## 🗺️ Roadmap / Progress Pengembangan

- [x] **Phase 1: Core Mechanics** (Player Movement, Interaksi Stand, Sistem Racik)
- [x] **Phase 2: Game Loop & Economy** (Sistem Pelanggan, Evaluasi Racikan, Siklus Hari, Sewa Lokasi)
- [x] **Phase 3: Shop & Upgrades** (Toko Equipment, Upgrade Cooler & Mixer, Katalog Brand)
- [x] **Phase 4: Dynamic Lighting & Visual Feedback** (Siklus Siang/Malam 3D, Visual Tas Es 3D, Bubble Keluhan 3D)
- [ ] **Phase 5: Audio & Polish** 🔄 *(In Progress)* (Procedural SFX Tuang/Aduk/Es/Kasir & Music Loop)
- [ ] **Phase 6: Build & Distribution** (Export Preset Windows/Linux/Mac & APK Android)

---

## 📜 Lisensi & Kredit

- **Kode & Aset Game:** Hak cipta dilindungi undang-undang / MIT License (dapat disesuaikan).
- **Dibuat oleh:** Tim Pengembang *Es Cekek*.

---
*Dibuat dengan ❤️ dan es sachet dingin segar dari Indonesia!*