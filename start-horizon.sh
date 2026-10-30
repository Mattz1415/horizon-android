#!/data/data/com.termux/files/usr/bin/bash
set -e

cat << "EOF"
======================================================
  🎮  HORIZON MINECRAFT FOR ANDROID (Termux-X11)  🎮
======================================================
  Architecture: ARM64 (aarch64)
  GPU Driver:   Turnip Mesa (Adreno 619 Hardware Vulkan)
  Window:       1280x720 / Termux:X11 Display :0
======================================================
EOF

# 0. Bersihkan proses Horizon lama agar tidak terjadi duplikasi frame / stuttering
pkill -9 -f "horizon-client" 2>/dev/null || true

# 1. Pastikan direktori X11 socket siap
mkdir -p "$PREFIX/tmp/.X11-unix"

# 2. Jalankan Termux-X11 server jika belum aktif
if ! pgrep -f "termux-x11 :0" > /dev/null; then
    echo "[*] Memulai X11 display server (:0)..."
    termux-x11 :0 -ac &
    sleep 2
else
    echo "[*] X11 display server (:0) aktif."
fi

# 3. Jalankan PulseAudio untuk audio
if ! pgrep -f "pulseaudio" > /dev/null; then
    echo "[*] Memulai PulseAudio audio server..."
    pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-anonymous=1 auth-ip-acl=127.0.0.1" 2>/dev/null || true
fi

# 4. Inisialisasi background & Window Manager agar layar Termux-X11 TIDAK KOSONG
echo "[*] Menyiapkan environment grafis X11 & Openbox..."
proot-distro login --bind /data/data/com.termux/files/usr/tmp/.X11-unix:/tmp/.X11-unix ubuntu -- bash -c '
    export DISPLAY=:0
    xsetroot -solid "#101018" 2>/dev/null || true
    if ! pgrep -f "openbox" > /dev/null; then
        openbox --replace &
    fi
' 2>/dev/null || true

# 5. Buka aplikasi Termux:X11 ke layar depan Android
echo "[*] Membuka jendela Termux:X11 di layar Android..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true

# 6. Tampilkan panduan waktu loading
echo ""
echo "======================================================"
echo " [!] Hardware GPU: Qualcomm Adreno 619 (Turnip Vulkan)"
echo " [!] Horizon sedang memuat aset Minecraft..."
echo " [!] Jendela game akan muncul di aplikasi Termux:X11!"
echo "======================================================"
echo ""

# 7. Jalankan Horizon dengan Hardware GPU Vulkan (Turnip Adreno 619)
cd /data/data/com.termux/files/home/horizon
exec proot-distro login --bind /data/data/com.termux/files/usr/tmp/.X11-unix:/tmp/.X11-unix ubuntu -- bash -c '
    export DISPLAY=:0
    export PULSE_SERVER=127.0.0.1
    export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
    # Mailbox (Triple Buffering) atau Fifo (VSync) mengatasi tearing & black stutter dari atas
    export MESA_VK_WSI_PRESENT_MODE=${MESA_VK_WSI_PRESENT_MODE:-mailbox}
    export TU_DEBUG=noconform
    export vblank_mode=0
    cd /data/data/com.termux/files/home/horizon
    exec ./target/fast/horizon-client --resources .local/horizon-client/26.3 "$@"
' -- "$@"
