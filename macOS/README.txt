========================================================
  SCR RDP Connection - Ghid Instalare macOS
========================================================

Scriptul automatizeaza majoritatea pasilor, dar exista
cateva actiuni care necesita interventia utilizatorului
din motive de securitate macOS.


--------------------------------------------------------
 CONTINUT FOLDER
--------------------------------------------------------

  conectare.command  -> scriptul principal
  config.ini         -> configuratia calculatoarelor
  cloudflared        -> (optional) se descarca automat
  README.txt         -> acest fisier


--------------------------------------------------------
 PASII DE INSTALARE (o singura data)
--------------------------------------------------------

PASUL 1 - Copiere folder pe Mac
--------------------------------

  Copiaza intreg folderul "macOS" oriunde pe Mac
  (ex: Desktop, Documents, Applications).


PASUL 2 - Prima lansare (Gatekeeper)
-------------------------------------

  La PRIMUL double-click pe conectare.command, macOS
  POSIBIL sa blocheze executia cu unul din mesajele:

    "conectare.command cannot be opened because it is
     from an unidentified developer"
  sau
    "Apple nu a putut verifica daca nu contine malware"

  Acest mesaj nu apare la toata lumea - depinde de
  setarile Gatekeeper si de metoda de transfer a
  folderului. Daca nu apare, sari peste acest pas.

  SOLUTIA RAPIDA (daca apare o singura data):
    1. Click DREAPTA pe conectare.command
    2. Selecteaza "Open" din meniu
    3. In dialog apare acum butonul "Open" - apasa-l

  SOLUTIA PERMANENTA (daca avertizarea reapare de
  fiecare data, chiar si pentru cloudflared):

    Deschide Terminal si ruleaza - o SINGURA DATA -
    pe folderul intreg (inlocuieste CALEA/CATRE/FOLDER
    cu calea reala):

      xattr -dr com.apple.quarantine "CALEA/CATRE/FOLDER"
      chmod +x "CALEA/CATRE/FOLDER/conectare.command"
      chmod +x "CALEA/CATRE/FOLDER/cloudflared"

    Tip rapid pentru cale: dupa ce scrii xattr -dr
    com.apple.quarantine , trage folderul direct in
    Terminal si calea se completeaza automat.

    Dupa aceste 3 comenzi, double-click va functiona
    normal de acum incolo.


PASUL 3 - Setup automat (intra in joc scriptul)
------------------------------------------------

  La prima rulare scriptul face automat:

    a) Instaleaza Homebrew
       -> va cere parola de Mac (sudo)
       -> se tasteaza orb, nu apar caractere, apoi Enter

    b) Instaleaza wakeonlan (pentru Wake-on-LAN)
       -> nu cere nimic

    c) Descarca cloudflared in folder
       -> nu cere nimic

    d) Instaleaza mas (Mac App Store CLI)
       -> nu cere nimic

    e) Instaleaza Windows App din App Store
       -> AUTOMAT daca esti deja logat in App Store
       -> MANUAL daca nu esti logat: scriptul deschide
          App Store la pagina app-ului; apesi "Get" /
          "Install"; scriptul astepta activ pana detec-
          teaza instalarea si continua singur.


PASUL 4 - Prima conectare RDP (permisiuni macOS)
-------------------------------------------------

  La prima incercare de conectare, macOS poate afisa:

    "Windows App would like to find and connect to
     devices on your local network"

  Apasa ALLOW. Dialog-ul apare o singura data, apoi
  permisiunea e memorata permanent.


--------------------------------------------------------
 UTILIZARE ZILNICA (dupa ce setup-ul e complet)
--------------------------------------------------------

  1. Double-click pe conectare.command
  2. Alegi PC-ul din meniu (1, 2, 3...)
  3. Introduci parola contului remote cand cere Windows App
  4. Te conectezi - scriptul se ocupa de tunel si WOL

  Nota: username-ul e completat automat din config.ini.
  Tot ce trebuie sa introduci la conectare e parola.


--------------------------------------------------------
 RESETARE SETUP (daca ceva merge prost)
--------------------------------------------------------

  Sterge fisierul ascuns .setup_done din folder:

    rm ~/cale/catre/folder/.setup_done

  La urmatoarea rulare scriptul va relua tot setup-ul.


--------------------------------------------------------
 REZOLVARE PROBLEME FRECVENTE
--------------------------------------------------------

  "Operation not permitted" / "Permission denied" la rulare
    -> In cazuri rare bitul executable se pierde la transfer.
       Deschide Terminal in folder si ruleaza:
         chmod +x conectare.command cloudflared

  "Unable to connect" / Error 0x204 in Windows App
    -> Tunelul cloudflared nu e gata inca
    -> Asteapta 10 secunde si relanseaza din Windows App
    -> Verifica ca PC-ul server e pornit si are NLA activ

  Scriptul se deschide in TextEdit in loc de Terminal
    -> Fisierul s-a redenumit in .sh pe parcurs
    -> Asigura-te ca extensia este .command

  "brew: command not found" in mijlocul setup-ului
    -> Inchide Terminal si relanseaza scriptul

========================================================
