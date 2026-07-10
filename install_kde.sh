#!/bin/bash
#
# Instalator KDE Plasma dla Void Linux
# Stylizowany na oryginalny void-installer (dialog/ncurses)
#

BACKTITLE="Void Linux KDE Plasma Installer"
TMPFILE=$(mktemp)
EXITCODE_FILE=$(mktemp)

# Sprzątanie po wyjściu
cleanup() {
    rm -f "$TMPFILE" "$EXITCODE_FILE"
}
trap cleanup EXIT

# Sprawdzenie uprawnień roota
if [ "$EUID" -ne 0 ]; then
    echo "Błąd: Uruchom ten skrypt używając sudo! (sudo bash kde-installer.sh)"
    exit 1
fi

# Upewnij się, że dialog jest zainstalowany (potrzebny do interfejsu)
if ! command -v dialog >/dev/null 2>&1; then
    xbps-install -Sy dialog >/dev/null 2>&1
fi

# --- Funkcja pomocnicza: pasek postępu podczas komendy, z realnym kodem wyjścia ---
# Po wywołaniu, prawdziwy kod wyjścia komendy jest w $LAST_EXIT_CODE
run_with_gauge() {
    local MSG="$1"
    shift
    (
        "$@" > "$TMPFILE" 2>&1
        echo $? > "$EXITCODE_FILE"
    ) &
    local CMD_PID=$!

    (
        PCT=0
        while kill -0 $CMD_PID 2>/dev/null; do
            PCT=$(( (PCT + 5) % 100 ))
            echo $PCT
            echo "XXX"
            echo "$MSG"
            echo "XXX"
            sleep 0.3
        done
        echo 100
    ) | dialog --backtitle "$BACKTITLE" --title " Proszę czekać " --gauge "$MSG" 10 70 0

    wait $CMD_PID
    LAST_EXIT_CODE=$(cat "$EXITCODE_FILE" 2>/dev/null || echo 1)
}

# Pokazuje treść ostatniego logu komendy w oknie dialog
show_error_log() {
    local TITLE="$1"
    dialog --backtitle "$BACKTITLE" --title "$TITLE" --textbox "$TMPFILE" 20 75
}

# --- Ekran powitalny ---
dialog --backtitle "$BACKTITLE" \
    --title " Witamy " \
    --msgbox "\nTen kreator zainstaluje środowisko graficzne KDE Plasma na Twoim systemie Void Linux.\n\nUżyj strzałek i TAB do nawigacji, ENTER aby zatwierdzić." 12 65

# --- Sprawdzenie połączenia z internetem PRZED czymkolwiek innym ---
run_with_gauge "Sprawdzanie połączenia z internetem..." bash -c '
    ping -c 2 -W 3 repo-default.voidlinux.org > /dev/null 2>&1
'
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    dialog --backtitle "$BACKTITLE" --title " Brak internetu " \
        --yesno "\nNie udało się połączyć z repozytorium Void Linux (repo-default.voidlinux.org).\n\nSprawdź:\n- czy karta sieciowa jest podłączona\n- czy usługa dhcpcd działa (sudo sv status dhcpcd)\n- czy masz przydzielony adres IP (ip addr)\n\nCzy mimo to chcesz spróbować kontynuować instalację?" 16 70
    if [ $? -ne 0 ]; then
        clear
        echo "Instalacja przerwana: brak połączenia z internetem."
        exit 1
    fi
fi

# --- Aktualizacja bazy pakietów ---
run_with_gauge "Aktualizacja bazy danych pakietów (xbps-install -Sy)..." xbps-install -Sy
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    show_error_log " Błąd aktualizacji bazy pakietów "
    dialog --backtitle "$BACKTITLE" --title " Błąd " \
        --yesno "\nAktualizacja bazy pakietów nie powiodła się.\n\nCzy mimo to chcesz kontynuować (może się nie udać)?" 12 65
    if [ $? -ne 0 ]; then
        clear
        echo "Instalacja przerwana: błąd aktualizacji bazy pakietów."
        exit 1
    fi
fi

PACKAGES="plasma-desktop sddm dbus elogind frameworkintegration konsole dolphin mesa-dri xorg-fonts virtualbox-ose-guest virtualbox-ose-guest-dkms"

# --- Wybór serwera wyświetlania ---
DISPLAY_CHOICE=$(dialog --backtitle "$BACKTITLE" \
    --title " Serwer wyświetlania grafiki " \
    --menu "\nWybierz serwer graficzny, który chcesz zainstalować:" 14 65 2 \
    "1" "Wayland (nowoczesny, wymaga dobrej akceleracji 3D)" \
    "2" "X11 / Xorg (tradycyjny, stabilny w maszynach wirtualnych)" \
    3>&1 1>&2 2>&3)

if [ -z "$DISPLAY_CHOICE" ]; then
    clear
    echo "Instalacja anulowana przez użytkownika."
    exit 1
fi

if [ "$DISPLAY_CHOICE" == "1" ]; then
    PACKAGES="$PACKAGES xorg-minimal qt6-wayland xorg-server-xwayland"
    DISPLAY_LABEL="Wayland"
else
    PACKAGES="$PACKAGES xorg plasma-x11"
    DISPLAY_LABEL="X11 (Xorg)"
fi

# --- Wybór pakietów opcjonalnych (checklista jak w void-installer) ---
EXTRA_CHOICES=$(dialog --backtitle "$BACKTITLE" \
    --title " Pakiety opcjonalne " \
    --checklist "\nZaznacz spacją pakiety, które chcesz zainstalować:" 14 65 2 \
    "firefox" "Przeglądarka internetowa Firefox" off \
    "tools" "Podstawowe narzędzia (git, curl, fish, fastfetch)" off \
    3>&1 1>&2 2>&3)

for CHOICE in $EXTRA_CHOICES; do
    CHOICE=$(echo "$CHOICE" | tr -d '"')
    case "$CHOICE" in
        firefox) PACKAGES="$PACKAGES firefox" ;;
        tools) PACKAGES="$PACKAGES git curl fish fastfetch" ;;
    esac
done

# --- Podsumowanie / potwierdzenie ---
dialog --backtitle "$BACKTITLE" \
    --title " Podsumowanie instalacji " \
    --yesno "\nSerwer graficzny: $DISPLAY_LABEL\n\nPakiety do zainstalowania:\n$PACKAGES\n\nCzy chcesz kontynuować instalację?" 16 70

if [ $? -ne 0 ]; then
    clear
    echo "Instalacja anulowana przez użytkownika."
    exit 1
fi

# --- Instalacja pakietów ---
run_with_gauge "Instalowanie pakietów przez XBPS, proszę czekać (to może potrwać kilka minut)..." xbps-install -y $PACKAGES

if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    show_error_log " Błąd instalacji pakietów "
    dialog --backtitle "$BACKTITLE" --title " Błąd " \
        --msgbox "\nInstalacja pakietów NIE powiodła się (kod wyjścia: $LAST_EXIT_CODE).\n\nSprawdź powyższy log błędu. Najczęstsze przyczyny:\n- brak/słabe połączenie internetowe\n- zbyt mało miejsca na dysku\n- błąd sygnatury/repo (spróbuj: xbps-install -Sy)\n\nInstalacja przerwana." 16 70
    clear
    echo "Instalacja przerwana: błąd instalacji pakietów. Zobacz log powyżej."
    exit 1
fi

# Weryfikacja, że kluczowe pakiety faktycznie się zainstalowały
MISSING=""
for PKG in plasma-desktop sddm dbus elogind; do
    xbps-query -l 2>/dev/null | grep -q " $PKG-" || MISSING="$MISSING $PKG"
done

if [ -n "$MISSING" ]; then
    dialog --backtitle "$BACKTITLE" --title " Błąd weryfikacji " \
        --msgbox "\nInstalacja zgłosiła sukces, ale brakuje kluczowych pakietów:\n$MISSING\n\nSpróbuj zainstalować je ręcznie:\nsudo xbps-install -Sy$MISSING" 14 65
    clear
    echo "Instalacja przerwana: brakuje pakietów:$MISSING"
    exit 1
fi

# --- Konfiguracja usług runit ---
run_with_gauge "Konfiguracja usług systemowych (dbus, elogind, sddm)..." bash -c '
    ln -sf /etc/sv/dbus /var/service/ &&
    ln -sf /etc/sv/elogind /var/service/ &&
    ln -sf /etc/sv/vboxservice /var/service/ 2>/dev/null
    ln -sf /etc/sv/sddm /var/service/
'

if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    show_error_log " Błąd konfiguracji usług "
    dialog --backtitle "$BACKTITLE" --title " Uwaga " \
        --msgbox "\nWystąpił problem przy włączaniu usług.\nSprawdź ręcznie: ls -la /var/service/" 10 60
fi

# Weryfikacja że symlinki faktycznie powstały
SERVICE_MISSING=""
for SVC in dbus elogind sddm; do
    [ -L "/var/service/$SVC" ] || SERVICE_MISSING="$SERVICE_MISSING $SVC"
done

if [ -n "$SERVICE_MISSING" ]; then
    dialog --backtitle "$BACKTITLE" --title " Brakujące usługi " \
        --msgbox "\nNastępujące usługi NIE zostały poprawnie włączone:\n$SERVICE_MISSING\n\nWłącz je ręcznie po restarcie:\nsudo ln -sf /etc/sv/<usługa> /var/service/" 14 65
fi

# --- Ekran końcowy ---
SESSION_INFO="Plasma (X11)"
[ "$DISPLAY_CHOICE" == "1" ] && SESSION_INFO="Plasma (Wayland)"

dialog --backtitle "$BACKTITLE" \
    --title " Instalacja zakończona " \
    --msgbox "\nKDE Plasma zostało pomyślnie zainstalowane i zweryfikowane!\n\nUsługi dbus, elogind i sddm zostały włączone.\n\nNa ekranie logowania SDDM pamiętaj, aby wybrać sesję:\n'$SESSION_INFO'\n\nSystem zostanie teraz zrestartowany." 16 65

clear
fastfetch 2>/dev/null || true
echo "Restart za 5 sekund... (Ctrl+C aby anulować)"
sleep 5
reboot
