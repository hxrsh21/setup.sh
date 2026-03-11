#!/bin/bash
# BrainHack Robot — Updated Setup for RPi 4B 2GB
# Matches brainhack.py Complete Edition
# Run: chmod +x setup.sh && bash setup.sh

set -e
C='\033[0;36m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; W='\033[0m'; B='\033[1m'

echo -e "${C}${B}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║      BrainHack Robot — RPi 4B 2GB Setup                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${W}"

# ── Step 1: System packages ───────────────────────────────
echo -e "${C}[1/7] System packages...${W}"
sudo apt update -q
sudo apt install -y \
    python3-pip portaudio19-dev \
    espeak espeak-ng \
    ffmpeg unzip wget curl \
    libsndfile1 libasound2-dev \
    python3-opencv \
    python3-rpi.gpio
echo -e "${G}✓ Done${W}"

# ── Step 2: Python packages ───────────────────────────────
echo -e "${C}[2/7] Python packages...${W}"
pip3 install \
    vosk \
    pyaudio \
    sounddevice \
    numpy \
    requests \
    RPi.GPIO \
    opencv-python \
    --break-system-packages
echo -e "${G}✓ Done${W}"

# ── Step 3: Vosk model ────────────────────────────────────
echo -e "${C}[3/7] Vosk speech model (~50MB)...${W}"
if [ ! -d "model" ]; then
    wget -q --show-progress \
        https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip \
        -O vosk-model.zip
    unzip -q vosk-model.zip
    mv vosk-model-small-en-us-0.15 model
    rm vosk-model.zip
    echo -e "${G}✓ Vosk model ready${W}"
else
    echo -e "${G}✓ Already exists${W}"
fi

# ── Step 4: ALSA audio config ─────────────────────────────
echo -e "${C}[4/7] Configuring audio (mic=hw:3,0 speaker=hw:0,0)...${W}"
sudo tee /etc/asound.conf > /dev/null << 'ASOUND'
pcm.!default {
    type asym
    playback.pcm {
        type plug
        slave.pcm "hw:0,0"
    }
    capture.pcm {
        type plug
        slave.pcm "hw:3,0"
    }
}
ctl.!default {
    type hw
    card 0
}
ASOUND
amixer -c 0 set Headphone 100% unmute 2>/dev/null || true
amixer -c 0 set PCM 100% unmute 2>/dev/null || true
sudo alsactl store 2>/dev/null || true
echo -e "${G}✓ Audio configured${W}"

# ── Step 5: Swap memory (critical for 2GB RPi!) ───────────
echo -e "${C}[5/7] Setting up 2GB swap memory...${W}"
sudo dphys-swapfile swapoff 2>/dev/null || true
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
echo -e "${G}✓ Swap ready${W}"
free -h | grep Swap

# ── Step 6: Ollama + model ────────────────────────────────
echo -e "${C}[6/7] Installing Ollama + qwen2.5:1.5b...${W}"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
else
    echo -e "${G}✓ Ollama already installed${W}"
fi

echo -e "${Y}Starting Ollama and pulling model (~900MB)...${W}"
ollama serve &>/dev/null &
sleep 8
ollama pull qwen2.5:1.5b
echo -e "${G}✓ Ollama + qwen2.5:1.5b ready${W}"

# ── Step 7: Performance optimizations ────────────────────
echo -e "${C}[7/7] Optimizing RPi performance...${W}"

# Disable unused services to free RAM
sudo systemctl disable bluetooth hciuart triggerhappy avahi-daemon 2>/dev/null || true
sudo systemctl stop bluetooth hciuart triggerhappy avahi-daemon 2>/dev/null || true

# Give more RAM to CPU
if ! grep -q "gpu_mem=64" /boot/firmware/config.txt 2>/dev/null; then
    echo "gpu_mem=64" | sudo tee -a /boot/firmware/config.txt
fi

# Auto-start on boot
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo tee /etc/systemd/system/brainhack.service > /dev/null << SERVICE
[Unit]
Description=BrainHack Robot
After=network.target sound.target

[Service]
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/python3 ${SCRIPT_DIR}/brainhack.py
WorkingDirectory=${SCRIPT_DIR}
User=${USER}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable brainhack
echo -e "${G}✓ Optimizations done${W}"

# ── Done! ─────────────────────────────────────────────────
echo ""
echo -e "${G}${B}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                 Setup Complete! ✓                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║                                                          ║"
echo "║  1. Fill in hackathon details:                           ║"
echo "║     nano brainhack.py                                    ║"
echo "║     Edit the HACKATHON_INFO section                      ║"
echo "║                                                          ║"
echo "║  2. Hardware connections:                                ║"
echo "║     PIR sensor  → GPIO 17 (Pin 11)                      ║"
echo "║     Camera      → CSI port or USB                       ║"
echo "║     USB Mic     → any USB port                          ║"
echo "║     Speaker     → 3.5mm jack                            ║"
echo "║                                                          ║"
echo "║  3. Test run:                                            ║"
echo "║     python3 brainhack.py                                 ║"
echo "║                                                          ║"
echo "║  4. Start service (auto-runs on boot):                   ║"
echo "║     sudo systemctl start brainhack                       ║"
echo "║                                                          ║"
echo "║  5. View logs:                                           ║"
echo "║     sudo journalctl -u brainhack -f                      ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${W}"
