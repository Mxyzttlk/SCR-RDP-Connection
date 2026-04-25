@echo off
setlocal enabledelayedexpansion
Title Conectare Securizata Cloudflare RDP
color 0A

:: ========================================================
:: CURATARE PROCESE ZOMBIE RAMASE DE LA RULARI ANTERIOARE
:: Daca userul a inchis CMD fara sa ajunga la CLEANUP
:: (ex: close button X, pana de curent, browser inchis la
:: autentificarea Cloudflare), cloudflared ramane rezident
:: si ocupa portul. Il omoram acum ca sa incepem curat.
:: ========================================================
taskkill /f /im cloudflared.exe >nul 2>&1

:: ========================================================
:: VERIFICARE FISIERE NECESARE
:: ========================================================
if not exist "%~dp0cloudflared.exe" (
    color 0C
    echo.
    echo [EROARE] cloudflared.exe nu a fost gasit!
    echo Te rugam sa il plasezi in acelasi folder cu scriptul.
    echo.
    pause
    exit
)
if not exist "%~dp0wolcmd.exe" (
    color 0C
    echo.
    echo [EROARE] wolcmd.exe nu a fost gasit!
    echo Te rugam sa il plasezi in acelasi folder cu scriptul.
    echo.
    pause
    exit
)
if not exist "%~dp0config.ini" (
    color 0C
    echo.
    echo [EROARE] config.ini nu a fost gasit!
    echo Te rugam sa il plasezi in acelasi folder cu scriptul.
    echo.
    pause
    exit
)

:: ========================================================
:: SETARI REGISTRY - SUPRIMA AVERTISMENTE RDP
:: Range 127.0.0.1 - 127.0.0.20 acoperit
:: ========================================================
reg add "HKCU\Software\Microsoft\Terminal Server Client" /v "AuthenticationLevelOverride" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Terminal Server Client" /v "RDGClientTransport" /t REG_DWORD /d 1 /f >nul 2>&1

for /l %%i in (1,1,20) do (
    reg add "HKCU\Software\Microsoft\Terminal Server Client\LocalDevices" /v "127.0.0.%%i" /t REG_DWORD /d 255 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Terminal Server Client\Servers\127.0.0.%%i" /v "CertHash" /t REG_BINARY /d 00 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Terminal Server Client\Servers\127.0.0.%%i" /v "UsernameHint" /t REG_SZ /d "" /f >nul 2>&1
)

:: ========================================================
:: SETARI REGISTRY - RESURSE BIFATE AUTOMAT
:: ========================================================
reg add "HKCU\Software\Microsoft\Terminal Server Client\Default" /v "RedirectClipboard" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Terminal Server Client\Default" /v "RedirectPrinters" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Terminal Server Client\Default" /v "RedirectSmartCards" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Terminal Server Client\Default" /v "RedirectWebAuthn" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Terminal Server Client\Default" /v "RedirectDrives" /t REG_DWORD /d 1 /f >nul 2>&1

:: ========================================================
:: CITIRE CALCULATOARE DIN CONFIG.INI
:: ========================================================
cls
echo ========================================================
echo   SELECTATI CALCULATORUL
echo ========================================================
echo.

set "INDEX=0"
for /f "tokens=1,2 delims==" %%a in ('findstr "NUME" "%~dp0config.ini"') do (
    set /a INDEX+=1
    set "NUME_!INDEX!=%%b"
    echo   [!INDEX!] %%b
)

set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr "HOSTNAME" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "HOSTNAME_!CNT!=%%b"
)
set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr "PORT_LOCAL" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "PORT_!CNT!=%%b"
)
set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr "IP_LOCAL" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "IP_!CNT!=%%b"
)
set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr "MAC" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "MAC_!CNT!=%%b"
)
set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr /B "USER=" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "USER_!CNT!=%%b"
)
set "CNT=0"
for /f "tokens=1,2 delims==" %%a in ('findstr /B "PASS=" "%~dp0config.ini"') do (
    set /a CNT+=1
    set "PASS_!CNT!=%%b"
)

echo.
choice /c 123456789 /n /m "Alegeti optiunea (1-%INDEX%): "
set "SELECTIE=%errorlevel%"

if %SELECTIE% GTR %INDEX% (
    echo Optiune invalida.
    timeout /t 2 >nul
    exit
)

set "HOSTNAME=!HOSTNAME_%SELECTIE%!"
set "PORT_LOCAL=!PORT_%SELECTIE%!"
set "IP_LOCAL=!IP_%SELECTIE%!"
set "MAC=!MAC_%SELECTIE%!"
set "NUME=!NUME_%SELECTIE%!"
set "USER=!USER_%SELECTIE%!"
set "PASS=!PASS_%SELECTIE%!"

cls
echo ========================================================
echo   CONECTARE LA: %NUME%
echo ========================================================
echo.

:: ========================================================
:: VERIFICARE DACA CALCULATORUL ESTE DEJA PORNIT
:: ========================================================
echo 1. Se verifica daca calculatorul este activ...
ping -n 2 %HOSTNAME% >nul 2>&1

if %errorlevel%==0 (
    echo    Calculatorul este pornit, se continua...
    goto CONNECT_TUNNEL
)

:: ========================================================
:: WAKE ON LAN
:: ========================================================
echo    Calculatorul nu raspunde, se trimite semnal de trezire...
"%~dp0wolcmd.exe" %MAC%
echo.
echo    Semnal trimis. Asteptam 60 secunde...
timeout /t 60 /nobreak
echo.

:: ========================================================
:: PORNIRE TUNEL
:: ========================================================
:CONNECT_TUNNEL
echo 2. Se porneste tunelul securizat...
start /B "" "%~dp0cloudflared.exe" access tcp --hostname %HOSTNAME% --url %IP_LOCAL%:%PORT_LOCAL%
echo    Va rugam sa va autentificati in browser...
timeout /t 5 >nul

:: ========================================================
:: VERIFICARE SESIUNE ACTIVA
:: ========================================================
set "SESIUNE_ACTIVA=0"
for /f "skip=1 tokens=2" %%i in ('query session /server:%IP_LOCAL%:%PORT_LOCAL% 2^>nul') do (
    set "SESIUNE_ACTIVA=1"
)

if "%SESIUNE_ACTIVA%"=="1" (
    cls
    echo ========================================================
    echo   ATENTIE
    echo ========================================================
    echo.
    echo   In momentul de fata un utilizator este conectat
    echo   remote la acest calculator.
    echo.
    echo   In momentul conectarii acest utilizator va fi
    echo   deconectat automat.
    echo.
    echo   Doriti sa continuati?
    echo.
    echo   [1] Da - Conectare
    echo   [2] Nu - Iesire
    echo.
    choice /c 12 /n /m "Alegeti optiunea (1 sau 2): "
    if errorlevel 2 goto CANCEL
)

:: ========================================================
:: LANSARE RDP
:: ========================================================
:CONNECT
cls
echo ========================================================
echo   CONECTARE LA: %NUME%
echo ========================================================
echo.
echo 3. Se lanseaza Remote Desktop...
echo.

:: ========================================================
:: CACHE CREDENTIALE TEMPORAR (DACA PASS E SETAT IN CONFIG)
:: cmdkey adauga in Credential Manager pentru TERMSRV/IP,
:: mstsc le foloseste automat. La CLEANUP sunt sterse.
:: Daca PASS e gol, scriptul nu cache-uieste nimic - mstsc
:: foloseste ce e deja in Credential Manager sau cere parola.
:: ========================================================
set "CRED_CACHED=0"
if not "%PASS%"=="" if not "%USER%"=="" (
    cmdkey /generic:TERMSRV/%IP_LOCAL% /user:%USER% /pass:%PASS% >nul 2>&1
    set "CRED_CACHED=1"
)

:: Lansare directa prin parametru - fara fisier RDP
:: Evita fereastra de avertisment de securitate
mstsc /v:%IP_LOCAL%:%PORT_LOCAL%
goto CLEANUP

:: ========================================================
:: ANULARE
:: ========================================================
:CANCEL
echo.
echo Conexiune anulata.
timeout /t 2 >nul

:: ========================================================
:: CURATENIE
:: ========================================================
:CLEANUP
echo.
:: Stergere credentiale cache-uite temporar (daca au fost adaugate)
if "%CRED_CACHED%"=="1" (
    cmdkey /delete:TERMSRV/%IP_LOCAL% >nul 2>&1
)
echo Se opreste tunelul securizat...
taskkill /f /im cloudflared.exe >nul 2>&1
echo Deconectat cu succes.
timeout /t 2 >nul
exit
