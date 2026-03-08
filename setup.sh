#!/bin/bash
# BrainHack Robot — One-click setup for Raspberry Pi 4B 2GB
# Usage: chmod +x setup.sh && bash setup.sh

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║   BrainHack Robot — RPi 4B Setup        ║"
echo "║   Ollama + Piper TTS + Vosk STT          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: System packages ───────────────────────────────────────────────────
echo -e "${CYAN}[1/5] Installing system packages...${NC}"
sudo apt update -q
sudo apt install -y \
    python3-pip portaudio19-dev \
    espeak espeak-ng \
    ffmpeg unzip wget curl \
    libsndfile1 libasound2-dev
echo -e "${GREEN}✓ System packages done${NC}"

# ── Step 2: Python packages ───────────────────────────────────────────────────
echo -e "${CYAN}[2/5] Installing Python packages...${NC}"
pip3 install \
    vosk \
    pyaudio \
    sounddevice \
    numpy \
    requests \
    piper-tts \
    --break-system-packages
echo -e "${GREEN}✓ Python packages done${NC}"

# ── Step 3: Vosk speech model ─────────────────────────────────────────────────
echo -e "${CYAN}[3/5] Downloading Vosk speech model (~50MB)...${NC}"
if [ ! -d "model" ]; then
    wget -q --show-progress \
        https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip \
        -O vosk-model.zip
    unzip -q vosk-model.zip
    mv vosk-model-small-en-us-0.15 model
    rm vosk-model.zip
    echo -e "${GREEN}✓ Vosk model downloaded${NC}"
else
    echo -e "${GREEN}✓ Vosk model already exists${NC}"
fi

# ── Step 4: Piper TTS voice ───────────────────────────────────────────────────
echo -e "${CYAN}[4/5] Downloading Piper human voice (~60MB)...${NC}"
mkdir -p voices
VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium"

if [ ! -f "voices/en_US-amy-medium.onnx" ]; then
    wget -q --show-progress \
        "${VOICE_URL}/en_US-amy-medium.onnx" \
        -O voices/en_US-amy-medium.onnx
    wget -q \
        "${VOICE_URL}/en_US-amy-medium.onnx.json" \
        -O voices/en_US-amy-medium.onnx.json
    echo -e "${GREEN}✓ Piper voice downloaded${NC}"
else
    echo -e "${GREEN}✓ Piper voice already exists${NC}"
fi

# ── Step 5: Ollama ────────────────────────────────────────────────────────────
echo -e "${CYAN}[5/5] Installing Ollama...${NC}"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    echo -e "${GREEN}✓ Ollama installed${NC}"
else
    echo -e "${GREEN}✓ Ollama already installed${NC}"
fi

# Start Ollama and pull tinyllama
echo -e "${YELLOW}Starting Ollama and downloading tinyllama model (~600MB)...${NC}"
ollama serve &>/dev/null &
OLLAMA_PID=$!
sleep 5
ollama pull tinyllama
echo -e "${GREEN}✓ tinyllama model ready${NC}"

# ── Auto-start service ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo -e "${CYAN}Setting up auto-start on boot...${NC}"

sudo bash -c "cat > /etc/systemd/system/brainhack.service << EOF
[Unit]
Description=BrainHack Robot Voice Assistant
After=network.target sound.target ollama.service

[Service]
ExecStartPre=/bin/sleep 8
ExecStart=/usr/bin/python3 ${SCRIPT_DIR}/brainhack.py
WorkingDirectory=${SCRIPT_DIR}
User=${USER}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable brainhack
echo -e "${GREEN}✓ Auto-start enabled${NC}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║              Setup Complete!  ✓                     ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  NEXT — Edit brainhack.py and fill in your event:   ║"
echo "║    nano brainhack.py                                 ║"
echo "║    → Find HACKATHON_INFO and add your real details   ║"
echo "║                                                      ║"
echo "║  TEST manually first:                                ║"
echo "║    python3 brainhack.py                              ║"
echo "║                                                      ║"
echo "║  START as a service (auto-runs on boot):             ║"
echo "║    sudo systemctl start brainhack                    ║"
echo "║                                                      ║"
echo "║  CHECK logs:                                         ║"
echo "║    sudo journalctl -u brainhack -f                   ║"
echo "║                                                      ║"
echo "║  STOP:                                               ║"
echo "║    sudo systemctl stop brainhack                     ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
