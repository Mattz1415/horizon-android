# 🌌 Horizon Minecraft on Android (ARM64)

<p align="center">
  <img src="https://raw.githubusercontent.com/horizon-rust/horizon/main/art/logo.png" alt="Horizon Logo" width="180" />
</p>

<p align="center">
  <strong>Native Rust implementation of Minecraft running on Android (ARM64) via Termux-X11 and Vulkan acceleration.</strong>
</p>

<p align="center">
  <a href="#-quick-start"><img src="https://img.shields.io/badge/Platform-Android%20ARM64-brightgreen.svg" alt="Platform" /></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/Language-Rust%202024-orange.svg" alt="Rust" /></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/Renderer-Vulkan%20%2F%20WGPU-blue.svg" alt="Vulkan" /></a>
  <a href="https://github.com/Mattz1415/horizon-android/actions"><img src="https://github.com/Mattz1415/horizon-android/actions/workflows/build-arm64.yml/badge.svg" alt="CI Status" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL%20v3.0-blue.svg" alt="License" /></a>
</p>

---

## ⚡ Overview

[Horizon](https://playhorizon.dev) is an ambitious, high-performance clean-room Minecraft client written entirely in **Rust** using **Vulkan** via `wgpu`.

This repository provides the complete port, build system, automated Minecraft asset extractors, audio bridges, and launcher scripts to run Horizon directly on **Android** devices (Snapdragon, Dimensity, Exynos) using **Termux** and **Termux-X11**.

---

## 🚀 Quick Start

### 1. Requirements
* Android 9+ with ARM64 (`aarch64`) architecture.
* [Termux](https://github.com/termux/termux-app/releases) installed.
* [Termux-X11 APK](https://github.com/termux/termux-x11/releases) installed.
* At least 8 GB free storage.

### 2. Automatic One-Line Installation
Buka Termux dan jalankan perintah berikut:

```bash
git clone https://github.com/Mattz1415/horizon-android.git
cd horizon-android
bash scripts/setup-horizon.sh
```

Script ini akan secara otomatis:
1. Mengonfigurasi environment Linux (Ubuntu PRoot).
2. Memasang toolchain Rust ARM64 terbaru (`rustup`).
3. Memasang dependensi grafis Vulkan, X11, Openbox, dan PulseAudio.
4. Mengunduh Minecraft 26.3 JARs beserta 114 runtime libraries.
5. Menjalankan `horizon-prepare` untuk memproses block states, bioma, dan aset.
6. Mengompilasi `horizon-client` dengan optimasi performa tinggi (`--profile fast`).

### 3. Launching the Game
Setelah instalasi selesai, jalankan game dengan:

```bash
./start-horizon.sh
```

Aplikasi **Termux:X11** akan otomatis terbuka dan menampilkan Horizon Minecraft!

---

## 🛠️ Fixing the "Blank / Empty Screen" ("Layar Kosong") Issue

Jika saat membuka Termux-X11 layarnya tampak hitam/kosong:

1. **Waktu Loading CPU (15–25 detik):**
   Pada peluncuran awal, Horizon memuat 35.700+ block states dan 1.650+ item. Pada CPU (llvmpipe), proses ini memakan waktu sekitar 15–25 detik. Layar akan mulai merender title screen segera setelah aset selesai dimuat.
2. **Dependensi X11 (`libxkbcommon-x11.so`):**
   Pastikan paket `libxkbcommon-x11-0` dan `xkb-data` terpasang (sudah otomatis disertakan di script setup).
3. **Pengaturan Termux-X11 yang Direkomendasikan:**
   Buka pengaturan Termux-X11 (Preferences):
   * **Display resolution mode:** `scaled` (1280x720 direkomendasikan untuk performa maksimal).
   * **Resizing mode:** `Fit to display`.
   * **Screen orientation:** `Sensor landscape`.
   * **Touchscreen input mode:** `Trackpad` atau `Touchscreen`.
   * **Show additional keyboard:** `Disabled` (agar layar penuh).

---

## 🔊 Audio Configuration

Horizon menggunakan ALSA/PulseAudio. Script peluncur `start-horizon.sh` otomatis menyalakan server TCP PulseAudio Termux:

```bash
pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-anonymous=1 auth-ip-acl=127.0.0.1"
```

Konfigurasi ALSA PRoot di `/etc/asound.conf`:
```ini
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
```
Audio terhubung pada format default `44100 Hz, 2 channels, f32`.

---

## 🏗️ Technical Architecture & Porting to Standalone APK

Ingin mengintegrasikan Horizon langsung ke dalam Android APK seperti **MattzLauncher** atau **PojavLauncher** tanpa Termux?

Baca panduan arsitektur lengkap di:
👉 [ARCHITECTURE_AND_APK_PORT.md](docs/ARCHITECTURE_AND_APK_PORT.md)

### Ringkasan Pendekatan Native APK:
* Mengompilasi `crates/client` sebagai `cdylib` (`.so`) menggunakan `cargo-ndk`.
* Mengganti backend X11 Winit dengan `android-activity` (`GameActivity`).
* Meneruskan `ANativeWindow` Android ke `wgpu::Instance::create_surface_from_android`.
* Memetakan sentuhan layar virtual joystick ke input event Winit.

---

## 📂 Repository Structure

```text
horizon-android/
├── .github/
│   └── workflows/
│       └── build-arm64.yml       # Automated GitHub Actions ARM64 build
├── docs/
│   └── ARCHITECTURE_AND_APK_PORT.md # Standalone Android APK porting guide
├── scripts/
│   ├── download_mc_assets.py    # Multithreaded Mojang 26.3 downloader
│   ├── setup-horizon.sh         # All-in-one installation script
│   └── asound.conf              # ALSA PulseAudio bridge configuration
├── start-horizon.sh             # Production launcher script with window manager
├── LICENSE                      # GPL v3.0 License
└── README.md                    # Project documentation
```

---

## 📜 License & Credits

* **Horizon:** Developed by the Horizon Rust team ([horizon-rust/horizon](https://github.com/horizon-rust/horizon)) under GPL v3.0.
* **Minecraft Assets:** Property of Mojang Studios / Microsoft.
* **Android Port & Tooling:** Maintained by [Mattz1415](https://github.com/Mattz1415).
