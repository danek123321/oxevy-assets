#!/bin/bash
#
# Instalator KDE Plasma dla Void Linux
# Stylizowany na oryginalny void-installer (dialog/ncurses)
#

set -e

BACKTITLE="Void Linux KDE Plasma Installer"
TMPFILE=$(mktemp)

# Sprzątanie po wyjściu
cleanup() {
    rm -f "$TMPFILE"
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

# --- Funkcja pomocnicza: pasek postępu podczas komendy ---
run_with_gauge() {
    local MSG="$1"
    shift
    (
        "$@" > "$TMPFILE" 2>&1 &
        PID=$!
        PCT=0
        while kill -0 $PID 2>/dev/null; do
            PCT=$(( (PCT + 5) % 100 ))
            echo $PCT
            echo "XXX"
            echo "$MSG"
            echo "XXX"
            sleep 0.3
        done
        wait $PID
        echo 100
    ) | dialog --backtitle "$BACKTITLE" --title " Proszę czekać " --gauge "$MSG" 10 70 0
}

# --- Ekran powitalny ---
dialog --backtitle "$BACKTITLE" \
    --title " Witamy " \
    --msgbox "\nTen kreator zainstaluje środowisko graficzne KDE Plasma na Twoim systemie Void Linux.\n\nUżyj strzałek i TAB do nawigacji, ENTER aby zatwierdzić." 12 65

# --- Aktualizacja bazy pakietów ---
run_with_gauge "Aktualizacja bazy danych pakietów (xbps-install -Sy)..." xbps-install -Sy

PACKAGES="plasma-desktop sddm dbus elogind frameworkintegration konsole dolphin mesa-dri xorg-fonts virtualbox-ose-guest virtualbox-ose-guest-dkms"

# --- Wybór serwera wyświetlania ---
DISPLAY_CHOICE=$(dialog --backtitle "$BACKTITLE" \
    --title " Serwer wyświetlania grafiki " \
    --menu "\nWybierz serwer graficzny, który chcesz zainstalować:" 14 65 2 \
    "1" "Wayland (nowoczesny, wymaga dobrej akceleracji 3D)" \
    "2" "X11 / Xorg (tradycyjny, stabilny w maszynach wirtualnych)" \
    3>&1 1>&2 2>&3)

if [ -z "$DISPLAY_CHOICE" ]; then
    dialog --backtitle "$BACKTITLE" --title " Przerwano " --msgbox "\nInstalacja została anulowana przez użytkownika." 8 50
    clear
    exit 1
fi

if [ "$DISPLAY_CHOICE" == "1" ]; then
    PACKAGES="$PACKAGES xorg-minimal qt6-wayland xwayland"
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
    dialog --backtitle "$BACKTITLE" --title " Przerwano " --msgbox "\nInstalacja została anulowana przez użytkownika." 8 50
    clear
    exit 1
fi

# --- Instalacja pakietów ---
run_with_gauge "Instalowanie pakietów przez XBPS, proszę czekać..." xbps-install -y $PACKAGES

if [ $? -ne 0 ]; then
    dialog --backtitle "$BACKTITLE" --title " Błąd " --msgbox "\nBłąd podczas instalacji pakietów.\nSprawdź połączenie internetowe i spróbuj ponownie." 10 60
    clear
    exit 1
fi

# --- Konfiguracja usług runit ---
run_with_gauge "Konfiguracja usług systemowych (dbus, elogind, sddm)..." bash -c '
    ln -sf /etc/sv/dbus /var/service/
    ln -sf /etc/sv/elogind /var/service/
    ln -sf /etc/sv/vboxservice /var/service/
    ln -sf /etc/sv/sddm /var/service/
'

# --- Ekran końcowy ---
SESSION_INFO="Plasma (X11)"
[ "$DISPLAY_CHOICE" == "1" ] && SESSION_INFO="Plasma (Wayland)"

dialog --backtitle "$BACKTITLE" \
    --title " Instalacja zakończona " \
    --msgbox "\nKDE Plasma zostało pomyślnie zainstalowane!\n\nUsługi dbus, elogind, vboxservice i sddm zostały włączone.\n\nNa ekranie logowania SDDM pamiętaj, aby wybrać sesję:\n'$SESSION_INFO'\n\nSystem zostanie teraz zrestartowany." 16 65

clear
fastfetch 2>/dev/null || true
echo "Restart za 5 sekund..."
sleep 5
reboot
