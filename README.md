# Horizon Android (Rust Edition)

Port native Android untuk [Horizon](https://playhorizon.dev), engine Minecraft Java 26.3 berbasis Rust & Vulkan.

## Fitur

- **Engine:** Rust native (`wgpu` Vulkan), tanpa JVM overhead.
- **Kontrol Layar:** Virtual Joystick & D-Pad (Attack, Place, Jump, Sneak).
- **Audio:** AAudio / CPAL stereo output.
- **Launcher:** Liquid Glass UI, dual downloader (CDN otomatis & import .zip offline).
- **Proteksi Media:** File aset otomatis disembunyikan dari galeri HP (`.nomedia`).
- **Background Pinning:** Service wakelock agar download dan game tidak ditutup paksa Android.

## Download & Pasang

1. Unduh APK dari [Releases](https://github.com/Mattz1415/horizon-android/releases/latest).
2. Pasang di HP Android (Android 9+).
3. Buka aplikasi, masuk tab **Downloader**:
   - **Otomatis:** Klik **UNDUH OTOMATIS (CDN)**.
   - **Manual:** Unduh `horizon-resources-26.3.zip` via browser, lalu klik **IMPORT FILE .ZIP (SAF)**.
4. Klik **PLAY 26.3**.

## Rekomendasi Pengaturan (Snapdragon 695 / Realme 10 Pro 5G)

- **RAM:** 2560 MB
- **Threads:** 4
- **Backend:** Vulkan
- **Render Distance:** 8–10 chunks

## Lisensi

GPL-3.0 / MIT upstream. Aset Minecraft milik Mojang / Microsoft.
