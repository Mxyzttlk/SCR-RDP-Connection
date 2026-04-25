#!/bin/bash

# Mutam working directory in folderul scriptului (esential pentru double-click)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="$SCRIPT_DIR/config.ini"
CLOUDFLARED="$SCRIPT_DIR/cloudflared"

# ========================================================
# CURATARE PROCESE ZOMBIE RAMASE DE LA RULARI ANTERIOARE
# Daca userul a inchis Terminal-ul brusc (Cmd+Q, Force Quit)
# sau browser-ul in timpul autentificarii Cloudflare, cloud-
# flared poate ramane rezident si sa ocupe portul. Il omoram
# acum ca sa incepem curat.
# ========================================================
pkill -f "cloudflared access" >/dev/null 2>&1

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
        # Adaugam Homebrew in PATH pentru sesiunea curenta
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
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
        echo "   cloudflared descarcat."
    else
        echo "   cloudflared deja prezent."
    fi

    # Asigurare permisiuni si eliminare quarantine (si pentru cloudflared
    # transferat din Windows care nu pastreaza bitul de executie)
    chmod +x "$CLOUDFLARED" 2>/dev/null
    xattr -d com.apple.quarantine "$CLOUDFLARED" 2>/dev/null

    # Verificare Microsoft Remote Desktop / Windows App
    echo ""
    echo "4. Verificare Microsoft Remote Desktop / Windows App..."

    check_msrd() {
        if [ -d "/Applications/Microsoft Remote Desktop.app" ]; then return 0; fi
        if [ -d "/Applications/Windows App.app" ]; then return 0; fi
        if mdfind "kMDItemCFBundleIdentifier == 'com.microsoft.rdc.macos'" 2>/dev/null | grep -q .; then return 0; fi
        if mdfind "kMDItemCFBundleIdentifier == 'com.microsoft.rdc.osx.beta'" 2>/dev/null | grep -q .; then return 0; fi
        return 1
    }

    if check_msrd; then
        echo "   Microsoft Remote Desktop / Windows App deja instalat."
    else
        echo "   Nu este instalat, se incearca instalare automata din App Store..."

        # Instalare mas (Mac App Store CLI) daca lipseste
        if ! command -v mas &>/dev/null; then
            echo "   Se instaleaza mas (Mac App Store CLI)..."
            brew install mas
        fi

        # Incercare instalare automata (ID 1295203466 = Windows App / Microsoft Remote Desktop)
        echo "   Se descarca Windows App din App Store..."
        if mas install 1295203466 2>/dev/null; then
            echo "   Windows App instalat cu succes."
        else
            # Fallback: App Store manual
            echo ""
            echo "========================================================"
            echo "  INSTALARE MANUALA NECESARA"
            echo "========================================================"
            echo ""
            echo "  Instalarea automata a esuat (probabil nu esti"
            echo "  logat in App Store cu Apple ID)."
            echo ""
            echo "  Se deschide App Store - apasa butonul \"Get\" /"
            echo "  \"Install\" pentru Windows App."
            echo ""
            echo "  Scriptul asteapta pana detecteaza instalarea."
            echo "========================================================"
            echo ""
            sleep 2
            open "macappstore://apps.apple.com/app/id1295203466"

            echo "   Asteptare instalare Windows App..."
            TIMEOUT=600
            ELAPSED=0
            while ! check_msrd; do
                sleep 5
                ELAPSED=$((ELAPSED + 5))
                if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
                    echo ""
                    echo "   Timeout - instalarea nu a fost detectata in 10 minute."
                    echo "   Te rugam sa relansezi scriptul dupa instalare."
                    read -p "Apasa Enter pentru a iesi..."
                    exit 0
                fi
            done
            echo "   Windows App detectat - instalare completa."
        fi
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

# Asigurare permisiuni si eliminare quarantine la fiecare rulare
# (protejeaza in cazul in care bitul de executie s-a pierdut dupa
# transferuri/copy din Windows sau Finder a re-aplicat quarantine)
if [ ! -x "$CLOUDFLARED" ]; then
    chmod +x "$CLOUDFLARED" 2>/dev/null
fi
xattr -d com.apple.quarantine "$CLOUDFLARED" 2>/dev/null

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
declare -a USER_LIST
declare -a PASS_LIST

while IFS= read -r line || [ -n "$line" ]; do
    # Curatare CR de la finaluri de linii Windows
    line="${line%$'\r'}"
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
    elif [[ "$line" =~ ^USER=(.+)$ ]]; then
        USER_LIST[$INDEX]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^PASS=(.+)$ ]]; then
        PASS_LIST[$INDEX]="${BASH_REMATCH[1]}"
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
USER_RDP="${USER_LIST[$SELECTIE]}"
PASS_RDP="${PASS_LIST[$SELECTIE]}"

clear
echo "========================================================"
echo "  CONECTARE LA: $NUME"
echo "========================================================"
echo ""

# ========================================================
# VERIFICARE DACA CALCULATORUL ESTE DEJA PORNIT
# ========================================================
echo "1. Se verifica daca calculatorul este activ..."
if ping -c 2 -W 1000 "$HOSTNAME" &>/dev/null; then
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
echo "   Va rugam sa va autentificati in browser daca e necesar..."
sleep 5

# Cleanup garantat la iesire (Ctrl+C, exit, etc.)
cleanup() {
    echo ""
    echo "Se opreste tunelul securizat..."
    kill "$CLOUDFLARED_PID" 2>/dev/null
    # Stergere fisier RDP temporar daca exista
    [ -n "$RDP_FILE" ] && [ -f "$RDP_FILE" ] && rm -f "$RDP_FILE"
    echo "Deconectat cu succes."
    sleep 2
}
trap cleanup EXIT

# ========================================================
# GENERARE FISIER RDP TEMPORAR
# Include username (daca e in config) pentru a sari peste
# ecranul de selectare user cand exista mai multi useri
# ========================================================
RDP_FILE="$(mktemp -t scr_rdp).rdp"
{
    echo "full address:s:127.0.0.1:$PORT_LOCAL"
    if [ -n "$USER_RDP" ]; then
        echo "username:s:$USER_RDP"
    fi
    echo "prompt for credentials on client:i:0"
    echo "authentication level:i:0"
    echo "redirectclipboard:i:1"
    echo "redirectprinters:i:1"
} > "$RDP_FILE"

# ========================================================
# LANSARE RDP
# ========================================================
clear
echo "========================================================"
echo "  CONECTARE LA: $NUME"
echo "========================================================"
echo ""
echo "3. Se lanseaza Remote Desktop..."
echo ""

# Deschide fisierul RDP cu aplicatia asociata (Microsoft Remote Desktop / Windows App)
open "$RDP_FILE"

# ========================================================
# AUTO-TASTARE PAROLA IN DIALOGUL DE CREDENTIALE
# Daca PASS este setat in config, lansam in background un
# AppleScript care asteapta dialogul "Enter Your Credentials"
# si tastarea automata parola + Return.
#
# NECESAR: permisiune Accessibility pentru Terminal
# (System Settings > Privacy & Security > Accessibility >
#  toggle pe Terminal). La prima rulare macOS va cere asta.
# ========================================================
if [ -n "$PASS_RDP" ]; then
    DEBUG_LOG="/tmp/scr_rdp_debug.log"
    echo "[$(date '+%H:%M:%S.%N')] Auto-fill pornit" > "$DEBUG_LOG"
    (
        osascript 2>>"$DEBUG_LOG" <<APPLESCRIPT_END >>"$DEBUG_LOG"
on run
    set targetPass to "$PASS_RDP"
    set timeWaited to 0
    set maxWait to 90

    tell application "System Events"
        repeat while not (exists process "Windows App") and timeWaited < 30
            delay 0.2
            set timeWaited to timeWaited + 0.2
        end repeat
        if not (exists process "Windows App") then
            log "Process Windows App nu apare in 30s"
            return
        end if
        log "Process Windows App detectat la " & timeWaited & "s"

        tell process "Windows App"
            repeat while timeWaited < maxWait
                delay 0.2
                set timeWaited to timeWaited + 0.2
                try
                    if exists (button "Continue" of sheet 1 of window 1) then
                        -- Verificare suplimentara: dialogul real are
                        -- minimum 2 text fields (username + parola).
                        -- Filtreaza false positives.
                        set fieldCount to 0
                        try
                            set fieldCount to count of text fields of sheet 1 of window 1
                        end try

                        if fieldCount >= 2 then
                            log "Dialog real detectat la " & timeWaited & "s (text fields: " & fieldCount & ")"
                            set frontmost to true
                            delay 0.2
                            set value of text field 2 of sheet 1 of window 1 to targetPass
                            delay 0.2
                            click button "Continue" of sheet 1 of window 1
                            log "Auto-fill complet la " & timeWaited & "s"
                            return
                        else
                            log "Fals pozitiv la " & timeWaited & "s (text fields: " & fieldCount & ") - continui polling"
                        end if
                    end if
                end try
            end repeat
        end tell
    end tell
    log "Timeout dupa " & maxWait & "s"
end run
APPLESCRIPT_END
    ) &
fi

# ========================================================
# ASTEPTARE STABILIRE CONEXIUNE RDP
# ========================================================
echo "   Astept stabilirea conexiunii..."
TIMEOUT_CONNECT=60
ELAPSED=0
while ! lsof -nP -iTCP:"$PORT_LOCAL" -sTCP:ESTABLISHED >/dev/null 2>&1; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    if [ "$ELAPSED" -ge "$TIMEOUT_CONNECT" ]; then
        echo "   Conexiunea nu s-a stabilit in $TIMEOUT_CONNECT secunde."
        echo "   Scriptul se inchide."
        exit 1
    fi
done

echo "   Conectat la $NUME."
echo "   Scriptul se va inchide automat la deconectare."
echo ""

# ========================================================
# MONITORIZARE SESIUNE ACTIVA
# Se iese cand nu mai exista conexiuni ESTABLISHED pe port
# ========================================================
while lsof -nP -iTCP:"$PORT_LOCAL" -sTCP:ESTABLISHED >/dev/null 2>&1; do
    sleep 2
done

echo "   Sesiunea RDP s-a incheiat."

# ========================================================
# AUTO-INCHIDERE FEREASTRA TERMINAL (dupa cleanup)
# ========================================================
# Planificam inchiderea ferestrei Terminal dupa ce scriptul iese
# (trap-ul EXIT ruleaza inainte, deci tunelul se opreste corect)
(
    sleep 3
    osascript -e 'tell application "Terminal" to close (every window whose name contains "conectare.command")' >/dev/null 2>&1
) &

exit 0
