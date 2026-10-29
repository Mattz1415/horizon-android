#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================================="
echo "    🚀 Horizon Minecraft for Android Setup Installer 🚀   "
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HORIZON_DIR="$HOME/horizon"

# 1. Update Termux base packages
echo "[1/7] Updating Termux packages..."
pkg update -y
pkg install -y proot-distro pulseaudio x11-repo python

# 2. Setup PRoot Ubuntu container
echo "[2/7] Configuring PRoot Ubuntu container..."
if ! proot-distro list | grep -q "ubuntu.*installed"; then
    echo "[*] Installing Ubuntu PRoot container..."
    proot-distro install ubuntu
fi

# 3. Install dependencies inside Ubuntu
echo "[3/7] Installing build dependencies inside Ubuntu container..."
proot-distro login ubuntu -- bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt update && apt install -y \
        build-essential curl git pkg-config \
        libudev-dev libasound2-dev libasound2-plugins \
        libxkbcommon-x11-0 libxkbcommon-dev xkb-data \
        openjdk-25-jdk-headless python3 python3-pip \
        mesa-vulkan-drivers libvulkan1 vulkan-tools \
        openbox x11-utils x11-xserver-utils
'

# 4. Setup Audio routing inside Ubuntu
echo "[4/7] Configuring audio bridge (PulseAudio)..."
proot-distro login ubuntu -- bash -c '
cat << "EOF" > /etc/asound.conf
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF
'

# 5. Setup Rust compiler via rustup inside Ubuntu
echo "[5/7] Configuring Rust toolchain (stable-aarch64-unknown-linux-gnu)..."
proot-distro login ubuntu -- bash -c '
    if ! command -v rustc >/dev/null 2>&1; then
        echo "[*] Installing rustup..."
        curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    fi
'

# 6. Clone Horizon and prepare assets
echo "[6/7] Preparing Horizon source code and Minecraft assets..."
if [ ! -d "$HORIZON_DIR" ]; then
    git clone https://github.com/horizon-rust/horizon.git "$HORIZON_DIR"
fi

python3 "$SCRIPT_DIR/download_mc_assets.py"

echo "[*] Building horizon-prepare..."
proot-distro login ubuntu -- bash -c "
    source /root/.cargo/env
    cd $HORIZON_DIR
    cargo build --profile fast --bin horizon-prepare -j 2
"

echo "[*] Extracting Minecraft 26.3 resources..."
proot-distro login ubuntu -- bash -c "
    cd $HORIZON_DIR
    ./target/fast/horizon-prepare \
        --version 26.3 \
        --assets /root/.minecraft/assets \
        --jars /root/.minecraft/versions/26.3/client.jar /root/.minecraft/servers/26.3/server.jar \
        --libraries /root/.minecraft/libraries \
        --output .local/horizon-client/26.3
"

# 7. Compile Horizon Client
echo "[7/7] Compiling Horizon Client with high performance optimizations..."
proot-distro login ubuntu -- bash -c "
    source /root/.cargo/env
    cd $HORIZON_DIR
    cargo build --profile fast --bin horizon-client -j 2
"

echo ""
echo "=========================================================="
echo " [✓] SETUP COMPLETED SUCCESSFULLY!"
echo " Jalankan game menggunakan: ./start-horizon.sh"
echo "=========================================================="
