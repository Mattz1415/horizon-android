# 🌌 Horizon Launcher for Android (Rust Edition)

<p align="center">
  <img src="https://raw.githubusercontent.com/horizon-rust/horizon/main/art/logo.png" alt="Horizon Logo" width="180" />
</p>

<p align="center">
  <strong>Next-Gen Standalone Android Minecraft Launcher for the Rust Horizon Engine with Pure Dark OLED Glassmorphism and On-Screen Touch Controls.</strong>
</p>

<p align="center">
  <a href="#-apk-highlights"><img src="https://img.shields.io/badge/Platform-Android%20APK-brightgreen.svg" alt="Platform" /></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/Engine-Rust%202024%20(Horizon)-orange.svg" alt="Rust" /></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/Renderer-Vulkan%20%2F%20WGPU-blue.svg" alt="Vulkan" /></a>
  <a href="https://github.com/Mattz1415/horizon-android/actions"><img src="https://github.com/Mattz1415/horizon-android/actions/workflows/build-apk.yml/badge.svg" alt="Build APK Status" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL%20v3.0-blue.svg" alt="License" /></a>
</p>

---

## 🌟 The "PojavLauncher for Rust": Horizon Launcher

**Horizon Launcher** adalah aplikasi APK Android mandiri (standalone) yang dirancang khusus untuk menjalankan Minecraft versi **Rust** ([Horizon](https://playhorizon.dev)). 

Sama seperti **PojavLauncher** dan **ZalithLauncher** yang membawa Minecraft Java ke Android, Horizon Launcher membawa **Horizon Rust Engine** ke Android dengan tampilan antarmuka modern, tombol kontrol sentuh virtual di layar, dan akselerasi grafis Vulkan langsung ke layar HP Anda tanpa perlu membuka terminal Termux atau Linux X11 manual!

---

## ⚡ Pojav / Zalith vs. Horizon Launcher

| Fitur | PojavLauncher / ZalithLauncher | Horizon Launcher (Rust) |
| :--- | :--- | :--- |
| **Engine Core** | Java Edition (Mojang jar + JVM) | **Clean-Room Rust Engine** ([Horizon](https://playhorizon.dev)) |
| **Runtime Overhead** | Butuh OpenJDK (200MB+ heap overhead) | **0% JVM Overhead!** Native ARM64 binary |
| **Graphics API** | OpenGL via GL4ES / Zink / VirGL | **Pure Native Vulkan** via `wgpu` |
| **Memory Footprint** | 2.5 GB – 4.5 GB RAM | **Ringan (~600 MB – 1.2 GB RAM)** |
| **Frame Pacing** | Sering micro-stutter akibat Garbage Collector Java | **Smooth 60–120 FPS** (Tanpa GC pauses) |
| **Kontrol Touch** | Virtual buttons overlay (D-pad, Attack, Place) | **Integrated Virtual Touchpad & D-Pad** |

---

## 🎮 Fitur Utama APK

* 🌌 **Pure Dark OLED Theme (`#000000`) & Glassmorphism:**
  Desain kartu akrilik frosted glass elegan dengan aksen warna Electric Cyan (`#00F0FF`) khas MattzLauncher.
* 🕹️ **Virtual On-Screen Touch Controller:**
  * **D-Pad Gerak:** Maju (W), Kiri (A), Mundur (S), Kanan (D), dan Sneak (Shift).
  * **Tombol Aksi Cepat:** Primary Attack/Mine (L-Click), Secondary Place/Use (R-Click), dan Jump (Space).
  * **Utility Bar:** Inventory (E), F3 Debug Screen, Chat (T), dan Menu Pause (ESC).
  * **Touchpad Kamera:** Sentuh dan seret di area layar mana pun untuk menggerakkan sudut pandang kamera (First-Person Look).
  * **Haptic Feedback:** Getaran mikro taktil saat menekan tombol sentuh virtual.
* 🚀 **Vulkan Native SurfaceView:**
  Merender langsung ke `ANativeWindow` Android melalui C++ JNI bridge tanpa lapisan X11 desktop.
* 🤖 **Automated CI/CD:**
  Workflow GitHub Actions siap merakit file `.apk` secara otomatis pada setiap rilis.

---

## 🛠️ Cara Mengunduh & Memasang APK

1. Buka tab **[Actions](https://github.com/Mattz1415/horizon-android/actions)** di repository ini.
2. Klik workflow terbaru **Build Horizon Launcher APK**.
3. Di bagian **Artifacts**, unduh `HorizonLauncher-v1.0.0-debug-apk`.
4. Install file `.apk` tersebut di HP Android Anda.
5. Buka **Horizon Launcher** dari Home Screen Android Anda dan tekan tombol **PLAY HORIZON**!

---

## 🏗️ Struktur Proyek Android

```text
horizon-android/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml          # Launcher & Game Fullscreen Activity
│   │   ├── cpp/                         # Native C++ Vulkan Surface & Input Bridge
│   │   │   ├── CMakeLists.txt
│   │   │   └── horizon_bridge.cpp       # ANativeWindow & Input event forwarder
│   │   ├── java/dev/playhorizon/launcher/
│   │   │   ├── MainActivity.kt          # Glassmorphism Launcher UI & Settings
│   │   │   ├── GameActivity.kt          # SurfaceView & Virtual Touch Controller
│   │   │   └── core/
│   │   │       ├── HorizonNativeBridge.kt # JNI Bridge
│   │   │       └── AssetManagerService.kt # Asset unpacker
│   │   └── res/                         # OLED Dark layouts, drawables, & themes
│   └── build.gradle.kts
├── .github/workflows/
│   ├── build-apk.yml                    # Automated Android APK compilation CI
│   └── build-arm64.yml                  # Native Rust ARM64 binary build CI
├── scripts/                             # Termux / PRoot fallback development scripts
├── start-horizon.sh                     # Termux-X11 runner script
├── build.gradle.kts
├── settings.gradle.kts
└── README.md
```

---

## 📜 Lisensi & Penghargaan

* **Horizon:** Dikembangkan oleh tim Horizon Rust ([horizon-rust/horizon](https://github.com/horizon-rust/horizon)) di bawah lisensi GPL v3.0.
* **Horizon Launcher Android:** Dibuat dan dikembangkan oleh [Mattz1415](https://github.com/Mattz1415).
