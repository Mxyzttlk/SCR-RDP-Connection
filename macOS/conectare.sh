#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.ini"
CLOUDFLARED="$SCRIPT_DIR/cloudflared"

# ========================================================
# SETUP AUTOMAT LA PRIMA RULARE
# ========================================================
setup_automat() {
    clear
    echo "========================================================"
    echo "  SETUP INITIAL - PRIMA RULARE"
    echo "========================================================"
    echo ""

    # Verificare Homebrew
    echo "1. Verificare Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "   Homebrew nu este instalat, se instaleaza..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo "   Homebrew instalat."
    else
        echo "   Homebrew deja instalat."
    fi

    # Verificare wakeonlan
    echo ""
    echo "2. Verificare wakeonlan..."
    if ! command -v wakeonlan &>/dev/null; then
        echo "   Se instaleaza wakeonlan..."
        brew install wakeonlan
        echo "   wakeonlan instalat."
    else
        echo "   wakeonlan deja instalat."
    fi

    # Verificare cloudflared
    echo ""
    echo "3. Verificare cloudflared..."
    if [ ! -f "$CLOUDFLARED" ]; then
        echo "   Se descarca cloudflared..."
        ARCH=$(uname -m)
        if [ "$ARCH" == "arm64" ]; then
            DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz"
            echo "   Detectat: Apple Silicon (arm64)"
        else
            DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz"
            echo "   Detectat: Intel (amd64)"
        fi
        curl -L "$DOWNLOAD_URL" -o "$SCRIPT_DIR/cloudflared.tgz"
        tar -xzf "$SCRIPT_DIR/cloudflared.tgz" -C "$SCRIPT_DIR"
        rm "$SCRIPT_DIR/cloudflared.tgz"
        chmod +x "$CLOUDFLARED"
        echo "   cloudflared instalat."
    else
        echo "   cloudflared deja prezent."
    fi

    # Verificare Microsoft Remote Desktop
    echo ""
    echo "4. Verificare Microsoft Remote Desktop..."
    if ! open -Ra "Microsoft Remote Desktop" 2>/dev/null; then
        echo ""
        echo "========================================================"
        echo "  ATENTIE"
        echo "========================================================"
        echo ""
        echo "  Microsoft Remote Desktop nu este instalat."
        echo ""
        echo "  Este necesar pentru conectarea la calculatorul"
        echo "  de la distanta."
        echo ""
        echo "  Se deschide App Store pentru instalare..."
        echo ""
        echo "  Dupa instalare te rugam sa relansezi scriptul."
        echo "========================================================"
        echo ""
        sleep 3
        open "https://apps.apple.com/app/microsoft-remote-desktop/id1295203466"
        read -p "Apasa Enter pentru a iesi..."
        exit 0
    else
        echo "   Microsoft Remote Desktop deja instalat."
    fi

    # Marcare setup complet
    touch "$SCRIPT_DIR/.setup_done"

    echo ""
    echo "========================================================"
    echo "  SETUP COMPLET! Se continua..."
    echo "========================================================"
    sleep 2
    clear
}

# Ruleaza setup doar la prima rulare
if [ ! -f "$SCRIPT_DIR/.setup_done" ]; then
    setup_automat
fi

# ========================================================
# VERIFICARE FISIERE NECESARE
# ========================================================
if [ ! -f "$CLOUDFLARED" ]; then
    echo ""
    echo "[EROARE] cloudflared nu a fost gasit!"
    echo "Te rugam sa stergi fisierul .setup_done si"
    echo "sa relansezi scriptul pentru reinstalare."
    echo ""
    read -p "Apasa Enter pentru a iesi..."
    exit 1
fi

if [ ! -f "$CONFIG" ]; then
    echo ""
    echo "[EROARE] config.ini nu a fost gasit!"
    echo "Te rugam sa il plasezi in acelasi folder cu scriptul."
    echo ""
    read -p "Apasa Enter pentru a iesi..."
    exit 1
fi

# ========================================================
# CITIRE CALCULATOARE DIN CONFIG.INI
# ========================================================
clear
echo "========================================================"
echo "  SELECTATI CALCULATORUL"
echo "========================================================"
echo ""

INDEX=0
declare -a NUME_LIST
declare -a HOSTNAME_LIST
declare -a PORT_LIST
declare -a MAC_LIST

while IFS= read -r line; do
    if [[ "$line" =~ ^NUME=(.+)$ ]]; then
        INDEX=$((INDEX + 1))
        NUME_LIST[$INDEX]="${BASH_REMATCH[1]}"
        echo "  [$INDEX] ${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^HOSTNAME=(.+)$ ]]; then
        HOSTNAME_LIST[$INDEX]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^PORT_LOCAL=(.+)$ ]]; then
        PORT_LIST[$INDEX]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^MAC=(.+)$ ]]; then
        MAC_LIST[$INDEX]="${BASH_REMATCH[1]}"
    fi
done < "$CONFIG"

echo ""
read -p "Alegeti optiunea (1-$INDEX): " SELECTIE

if ! [[ "$SELECTIE" =~ ^[0-9]+$ ]] || [ "$SELECTIE" -lt 1 ] || [ "$SELECTIE" -gt "$INDEX" ]; then
    echo ""
    echo "Optiune invalida."
    sleep 2
    exit 1
fi

HOSTNAME="${HOSTNAME_LIST[$SELECTIE]}"
PORT_LOCAL="${PORT_LIST[$SELECTIE]}"
MAC="${MAC_LIST[$SELECTIE]}"
NUME="${NUME_LIST[$SELECTIE]}"

clear
echo "========================================================"
echo "  CONECTARE LA: $NUME"
echo "========================================================"
echo ""

# ========================================================
# VERIFICARE DACA CALCULATORUL ESTE DEJA PORNIT
# ========================================================
echo "1. Se verifica daca calculatorul este activ..."
if ping -c 2 -W 1 "$HOSTNAME" &>/dev/null; then
    echo "   Calculatorul este pornit, se continua..."
else
    echo "   Calculatorul nu raspunde, se trimite semnal de trezire..."
    wakeonlan "$MAC"
    echo ""
    echo "   Semnal trimis. Asteptam 60 secunde..."
    sleep 60
    echo ""
fi

# ========================================================
# PORNIRE TUNEL
# ========================================================
echo "2. Se porneste tunelul securizat..."
"$CLOUDFLARED" access tcp --hostname "$HOSTNAME" --url "127.0.0.1:$PORT_LOCAL" &
CLOUDFLARED_PID=$!
echo "   Va rugam sa va autentificati in browser..."
sleep 5

# ========================================================
# VERIFICARE SESIUNE ACTIVA
# ========================================================
SESIUNE_ACTIVA=0
if query session /server:127.0.0.1:$PORT_LOCAL &>/dev/null 2>&1; then
    SESIUNE_ACTIVA=1
fi

if [ "$SESIUNE_ACTIVA" -eq 1 ]; then
    clear
    echo "========================================================"
    echo "  ATENTIE"
    echo "========================================================"
    echo ""
    echo "  In momentul de fata un utilizator este conectat"
    echo "  remote la acest calculator."
    echo ""
    echo "  In momentul conectarii acest utilizator va fi"
    echo "  deconectat automat."
    echo ""
    echo "  Doriti sa continuati?"
    echo ""
    echo "  [1] Da - Conectare"
    echo "  [2] Nu - Iesire"
    echo ""
    read -p "Alegeti optiunea (1 sau 2): " OPTIUNE

    if [ "$OPTIUNE" == "2" ]; then
        echo ""
        echo "Conexiune anulata."
        kill $CLOUDFLARED_PID 2>/dev/null
        sleep 2
        exit 0
    fi
fi

# ========================================================
# LANSARE RDP
# ========================================================
clear
echo "========================================================"
echo "  CONECTARE LA: $NUME"
echo "========================================================"
echo ""
echo "3. Se lanseaza Remote Desktop..."
echo "   Puteti inchide aceasta fereastra dupa conectare."
echo ""
open "rdp://full%20address=s:127.0.0.1:$PORT_LOCAL"

read -p "Apasa Enter dupa ce ai inchis fereastra RDP..."

# ========================================================
# CURATENIE
# ========================================================
echo ""
echo "Se opreste tunelul securizat..."
kill $CLOUDFLARED_PID 2>/dev/null
echo "Deconectat cu succes."
sleep 2
exit 0