# Horizon Minecraft on Android: Architecture & APK Porting Blueprint

This document details the exact technical architecture of **Horizon Minecraft** on Android, how it differs from **PojavLauncher** / **MattzLauncher**, and how to port it directly into a standalone Android APK.

---

## 1. Architectural Comparison: PojavLauncher vs. Horizon

| Feature | PojavLauncher / MattzLauncher | Horizon on Android |
| :--- | :--- | :--- |
| **Language** | Java (OpenJDK) + C / JNI | Pure Rust (`horizon-client`, `horizon-prepare`) |
| **Windowing System** | Custom GLFW stub redirected to Android SurfaceView | Standard X11 / Wayland via Winit (or `android-activity`) |
| **Graphics API** | OpenGL / OpenGL ES (via GL4ES / Zink / VirGL) | Vulkan via `wgpu` (llvmpipe, Turnip, or native Adreno) |
| **Audio** | OpenAL Soft routed to Android AudioTrack / Oboe | ALSA / PulseAudio (or `cpal` with AAudio/Oboe backend) |
| **Execution Model** | Standalone Android APK with embedded JRE & JVM dlsym | PRoot Linux container OR Standalone Native Activity APK |
| **Assets Format** | Standard Minecraft Client JAR + JSON assets | Processed `.local/horizon-client/<version>` packs |

---

## 2. Why PRoot Ubuntu is the Recommended Runtime Today

1. **Winit 0.30 & Android Target Requirements:**
   When compiling Rust with `target = aarch64-linux-android`, `winit` activates `android-activity`. This crate expects to run inside an Android Java VM (`NativeActivity` or `GameActivity`) with a valid JNI context (`ANativeActivity*` or `ANativeWindow*`). It fails to launch from a plain Termux CLI shell.
   In contrast, targeting `aarch64-unknown-linux-gnu` inside PRoot GNU/Linux allows Winit to use standard X11 or Wayland protocols connected to Termux-X11.

2. **System Dependencies:**
   Horizon requires:
   - `libudev` (for gamepad/hidapi support)
   - `libasound2` (for ALSA / PulseAudio audio output)
   - `libxkbcommon-x11` (for X11 keyboard layout processing)
   These libraries are fully provided in Debian/Ubuntu GNU arm64, whereas Android Bionic lacks `libudev` entirely.

---

## 3. Blueprint for Standalone Android APK Port (Native APK)

To create a native APK for Horizon (like PojavLauncher / MattzLauncher) without needing Termux or PRoot:

### Step 1: Rust Android Target (`cargo-apk` / `cargo-ndk`)
Compile `crates/client` into a shared library:
```toml
# In horizon client Cargo.toml:
[lib]
crate-type = ["cdylib"]
name = "horizon_client"
```

### Step 2: Android Native Activity
In `AndroidManifest.xml`:
```xml
<activity
    android:name="android.app.NativeActivity"
    android:exported="true"
    android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
    <meta-data
        android:name="android.app.lib_name"
        android:value="horizon_client" />
</activity>
```

### Step 3: Winit + `android-activity`
Use `android-activity = { version = "0.6", features = ["game-activity"] }`.
Provide `ANativeWindow` to `wgpu::Surface`:
```rust
let surface = unsafe { instance.create_surface_from_android(native_window) }?;
```

### Step 4: Asset Bundling
Bundle Minecraft 26.3 extracted packs (`.local/horizon-client/26.3`) into Android `assets/` or download them upon first launch inside MattzLauncher.

### Step 5: Touch Virtual Gamepad Overlay
Inject touch input into Winit's event loop (`WindowEvent::KeyboardInput` and `WindowEvent::MouseMotion`) via an Android `FrameLayout` overlay on top of the `SurfaceView`.
