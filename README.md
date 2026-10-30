# Horizon Android

Port Android untuk [Horizon](https://playhorizon.dev), client Minecraft Java 26.3 berbasis Rust dan Vulkan.

## Fitur

* Client native Rust (`wgpu`), tanpa runtime Java di HP.
* Kontrol sentuh di layar: analog joystick, tombol D-pad, aksi serang, pasang blok, lompat, dan jongkok.
* Suara game langsung lewat backend AAudio / CPAL.
* Downloader bawaan: tarik paket aset via CDN langsung di dalam aplikasi atau import file `.zip` manual dari storage.
* Proteksi galeri HP: folder aset otomatis diberi file `.nomedia` supaya file suara dan tekstur tidak terbaca di galeri foto.
* Service wakelock aktif saat download dan main agar proses tidak dimatikan Android di background.

## Pemasangan

1. Unduh APK dari halaman [Releases](https://github.com/Mattz1415/horizon-android/releases).
2. Buka aplikasi, lalu buka tab Downloader.
3. Pilih salah satu cara pasang aset:
   * **Otomatis:** Tekan tombol unduh CDN.
   * **Manual:** Unduh `horizon-resources-26.3.zip` lewat browser, lalu pilih file lewat tombol import.
4. Tekan tombol Play setelah status aset siap.

## Catatan Perangkat (Realme 10 Pro 5G / Snapdragon 695)

* RAM: 2560 MB
* Threads: 4
* Render API: Vulkan

## Lisensi

GPL-3.0 / MIT. Aset Minecraft tetap milik Mojang dan Microsoft.
