Oto zaktualizowana wersja skryptu. Dodałem logikę, która po wybraniu i zainstalowaniu środowiska **Hyprland** pyta użytkownika, czy chce pobrać i zastosować konfigurację (dots) z repozytorium `caelestia-dots/shell`. 

Jeśli użytkownik się zgodzi, skrypt automatycznie zainstaluje `git` (jeśli go brakuje), sklonuje repozytorium i spróbuje uruchomić dołączony do niego skrypt instalacyjny jako docelowy użytkownik (twórca repozytorium zazwyczaj udostępnia automatyczny skrypt `setup.sh` lub `install.sh`).

```bash
#!/bin/bash
#
# Uniwersalny instalator Środowisk Graficznych (Void / Arch / Debian-Ubuntu / Fedora)
# Wsparcie: KDE Plasma, GNOME, XFCE, LXQt, MATE, Cinnamon, Hyprland
# Stylizowany na archinstall (dialog/ncurses)
# Obsluga jezykow: polski / english
#

# ============================================================
#  KONFIGURACJA SAMO-AKTUALIZACJI / SELF-UPDATE CONFIG
# ============================================================
SCRIPT_VERSION="4.2.0"
SCRIPT_URL="https://raw.githubusercontent.com/TWOJ-USER/TWOJE-REPO/main/desktop-installer.sh"
SCRIPT_PATH="$(readlink -f "$0")"

TMPFILE=$(mktemp)
EXITCODE_FILE=$(mktemp)
LANG_CHOICE="pl"

cleanup() {
    rm -f "$TMPFILE" "$EXITCODE_FILE"
}
trap cleanup EXIT

# ============================================================
#  FUNKCJA TLUMACZEN
# ============================================================
t() {
    if [ "$LANG_CHOICE" == "en" ]; then
        printf '%s' "$2"
    else
        printf '%s' "$1"
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "Blad/Error: uruchom przez sudo / run with sudo"
    exit 1
fi

# ============================================================
#  WYKRYWANIE DYSTRYBUCJI
# ============================================================
DISTRO_FAMILY="unknown"
INIT_SYSTEM="unknown"
DISTRO_NAME="unknown"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="${PRETTY_NAME:-$ID}"
        case "$ID" in
            void) DISTRO_FAMILY="void"; INIT_SYSTEM="runit" ;;
            arch|archlinux|endeavouros|manjaro|artix) DISTRO_FAMILY="arch"; INIT_SYSTEM="systemd" ;;
            debian|ubuntu|linuxmint|pop|raspbian|zorin) DISTRO_FAMILY="debian"; INIT_SYSTEM="systemd" ;;
            fedora|rhel|centos|rocky|almalinux) DISTRO_FAMILY="fedora"; INIT_SYSTEM="systemd" ;;
            *)
                case "$ID_LIKE" in
                    *arch*) DISTRO_FAMILY="arch"; INIT_SYSTEM="systemd" ;;
                    *debian*) DISTRO_FAMILY="debian"; INIT_SYSTEM="systemd" ;;
                    *fedora*|*rhel*) DISTRO_FAMILY="fedora"; INIT_SYSTEM="systemd" ;;
                esac ;;
        esac
    fi
}
detect_distro

# ============================================================
#  ABSTRAKCJA NAZW PAKIETOW
# ============================================================
pkgname() {
    local key="$1"
    case "$DISTRO_FAMILY" in
        void)
            case "$key" in
                kde) echo "kde-plasma kde-baseapps" ;; gnome) echo "gnome" ;; xfce) echo "xfce4 xfce4-goodies" ;;
                lxqt) echo "lxqt" ;; mate) echo "mate" ;; cinnamon) echo "cinnamon" ;;
                hyprland) echo "hyprland kitty waybar wofi" ;;
                sddm) echo "sddm" ;; gdm) echo "gdm" ;; lightdm) echo "lightdm lightdm-gtk3-greeter" ;;
                dbus) echo "dbus" ;; elogind) echo "elogind" ;; mesa) echo "mesa-dri" ;;
                xorgfonts) echo "xorg-fonts" ;; xorgminimal) echo "xorg-minimal" ;; xorgfull) echo "xorg" ;;
                vbox) echo "virtualbox-ose-guest virtualbox-ose-guest-dkms" ;;
                qtwayland) echo "qt6-wayland" ;; xwayland) echo "xorg-server-xwayland" ;;
                firefox) echo "firefox" ;; chromium) echo "chromium" ;; tor) echo "torbrowser-launcher" ;;
                vlc) echo "vlc" ;; mpv) echo "mpv" ;; gimp) echo "gimp" ;; blender) echo "blender" ;;
                obs) echo "obs" ;; kdenlive) echo "kdenlive" ;; audacity) echo "audacity" ;;
                libreoffice) echo "libreoffice" ;; telegram) echo "telegram-desktop" ;; discord) echo "discord" ;;
                thunderbird) echo "thunderbird" ;;
                git) echo "git" ;; fish) echo "fish-shell" ;; fastfetch) echo "fastfetch" ;; htop) echo "htop" ;;
                neovim) echo "neovim" ;; docker) echo "docker" ;; python3) echo "python3" ;;
                btop) echo "btop" ;; tmux) echo "tmux" ;; ranger) echo "ranger" ;; flatpak) echo "flatpak" ;;
                build_tools) echo "base-devel" ;;
                steam) echo "steam" ;; lutris) echo "lutris" ;; wine) echo "wine" ;; gamemode) echo "gamemode" ;;
            esac ;;
        arch)
            case "$key" in
                kde) echo "plasma-desktop plasma-workspace" ;; gnome) echo "gnome gnome-tweaks" ;; xfce) echo "xfce4" ;;
                lxqt) echo "lxqt" ;; mate) echo "mate mate-extra" ;; cinnamon) echo "cinnamon" ;;
                hyprland) echo "hyprland kitty waybar wofi" ;;
                sddm) echo "sddm" ;; gdm) echo "gdm" ;; lightdm) echo "lightdm lightdm-gtk-greeter" ;;
                dbus) echo "dbus" ;; elogind) echo "" ;; mesa) echo "mesa" ;;
                xorgfonts) echo "xorg-fonts-misc" ;; xorgminimal) echo "xorg-server" ;; xorgfull) echo "xorg-server xorg-apps xorg-xinit" ;;
                vbox) echo "virtualbox-guest-utils" ;;
                qtwayland) echo "qt6-wayland" ;; xwayland) echo "xorg-xwayland" ;;
                firefox) echo "firefox" ;; chromium) echo "chromium" ;; tor) echo "torbrowser-launcher" ;;
                vlc) echo "vlc" ;; mpv) echo "mpv" ;; gimp) echo "gimp" ;; blender) echo "blender" ;;
                obs) echo "obs-studio" ;; kdenlive) echo "kdenlive" ;; audacity) echo "audacity" ;;
                libreoffice) echo "libreoffice-fresh" ;; telegram) echo "telegram-desktop" ;; discord) echo "discord" ;;
                thunderbird) echo "thunderbird" ;;
                git) echo "git" ;; fish) echo "fish" ;; fastfetch) echo "fastfetch" ;; htop) echo "htop" ;;
                neovim) echo "neovim" ;; docker) echo "docker" ;; python3) echo "python" ;;
                btop) echo "btop" ;; tmux) echo "tmux" ;; ranger) echo "ranger" ;; flatpak) echo "flatpak" ;;
                build_tools) echo "base-devel" ;;
                steam) echo "steam" ;; lutris) echo "lutris" ;; wine) echo "wine" ;; gamemode) echo "gamemode" ;;
            esac ;;
        debian)
            case "$key" in
                kde) echo "kde-plasma-desktop" ;; gnome) echo "gnome-core" ;; xfce) echo "xfce4" ;;
                lxqt) echo "lxqt" ;; mate) echo "mate-desktop-environment" ;; cinnamon) echo "cinnamon-desktop-environment" ;;
                hyprland) echo "hyprland kitty waybar wofi" ;;
                sddm) echo "sddm" ;; gdm) echo "gdm3" ;; lightdm) echo "lightdm lightdm-gtk-greeter" ;;
                dbus) echo "dbus" ;; elogind) echo "" ;; mesa) echo "libgl1-mesa-dri" ;;
                xorgfonts) echo "xfonts-base" ;; xorgminimal) echo "xserver-xorg-core" ;; xorgfull) echo "xserver-xorg" ;;
                vbox) echo "virtualbox-guest-x11 virtualbox-guest-utils" ;;
                qtwayland) echo "qt6-wayland" ;; xwayland) echo "xwayland" ;;
                firefox) echo "firefox-esr" ;; chromium) echo "chromium" ;; tor) echo "torbrowser-launcher" ;;
                vlc) echo "vlc" ;; mpv) echo "mpv" ;; gimp) echo "gimp" ;; blender) echo "blender" ;;
                obs) echo "obs-studio" ;; kdenlive) echo "kdenlive" ;; audacity) echo "audacity" ;;
                libreoffice) echo "libreoffice" ;; telegram) echo "telegram-desktop" ;; discord) echo "discord" ;;
                thunderbird) echo "thunderbird" ;;
                git) echo "git" ;; fish) echo "fish" ;; fastfetch) echo "fastfetch" ;; htop) echo "htop" ;;
                neovim) echo "neovim" ;; docker) echo "docker.io" ;; python3) echo "python3" ;;
                btop) echo "btop" ;; tmux) echo "tmux" ;; ranger) echo "ranger" ;; flatpak) echo "flatpak" ;;
                build_tools) echo "build-essential" ;;
                steam) echo "steam" ;; lutris) echo "lutris" ;; wine) echo "wine" ;; gamemode) echo "gamemode" ;;
            esac ;;
        fedora)
            case "$key" in
                kde) echo "@kde-desktop-environment" ;; gnome) echo "@gnome-desktop-environment" ;; xfce) echo "@xfce-desktop-environment" ;;
                lxqt) echo "@lxqt-desktop-environment" ;; mate) echo "@mate-desktop-environment" ;; cinnamon) echo "@cinnamon-desktop-environment" ;;
                hyprland) echo "hyprland kitty waybar wofi" ;;
                sddm) echo "sddm" ;; gdm) echo "gdm" ;; lightdm) echo "lightdm lightdm-gtk-greeter" ;;
                dbus) echo "dbus-broker" ;; elogind) echo "" ;; mesa) echo "mesa-dri-drivers" ;;
                xorgfonts) echo "xorg-x11-fonts-base" ;; xorgminimal) echo "xorg-x11-server-Xorg" ;; xorgfull) echo "xorg-x11-server-Xorg xorg-x11-drv-libinput" ;;
                vbox) echo "virtualbox-guest-additions" ;;
                qtwayland) echo "qt6-qtwayland" ;; xwayland) echo "xorg-x11-server-Xwayland" ;;
                firefox) echo "firefox" ;; chromium) echo "chromium" ;; tor) echo "torbrowser-launcher" ;;
                vlc) echo "vlc" ;; mpv) echo "mpv" ;; gimp) echo "gimp" ;; blender) echo "blender" ;;
                obs) echo "obs-studio" ;; kdenlive) echo "kdenlive" ;; audacity) echo "audacity" ;;
                libreoffice) echo "libreoffice" ;; telegram) echo "telegram-desktop" ;; discord) echo "discord" ;;
                thunderbird) echo "thunderbird" ;;
                git) echo "git" ;; fish) echo "fish" ;; fastfetch) echo "fastfetch" ;; htop) echo "htop" ;;
                neovim) echo "neovim" ;; docker) echo "docker" ;; python3) echo "python3" ;;
                btop) echo "btop" ;; tmux) echo "tmux" ;; ranger) echo "ranger" ;; flatpak) echo "flatpak" ;;
                build_tools) echo "@development-tools" ;;
                steam) echo "steam" ;; lutris) echo "lutris" ;; wine) echo "wine" ;; gamemode) echo "gamemode" ;;
            esac ;;
    esac
}

# ============================================================
#  ABSTRAKCJA MENEDZERA PAKIETOW
# ============================================================
pkg_bootstrap() {
    case "$DISTRO_FAMILY" in
        void) command -v dialog >/dev/null 2>&1 || xbps-install -Sy dialog >/dev/null 2>&1 ;;
        arch) command -v dialog >/dev/null 2>&1 || pacman -Sy --noconfirm dialog >/dev/null 2>&1 ;;
        debian) command -v dialog >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y dialog >/dev/null 2>&1; } ;;
        fedora) command -v dialog >/dev/null 2>&1 || dnf install -y dialog >/dev/null 2>&1 ;;
    esac
}

pkg_sync() {
    case "$DISTRO_FAMILY" in
        void) xbps-install -Sy ;; arch) pacman -Sy --noconfirm ;; debian) apt-get update ;; fedora) dnf makecache ;;
    esac
}

pkg_install() {
    case "$DISTRO_FAMILY" in
        void) xbps-install -y "$@" ;; arch) pacman -S --noconfirm --needed "$@" ;;
        debian) DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;; fedora) dnf install -y "$@" ;;
    esac
}

pkg_is_installed() {
    local pkg="$1"
    case "$DISTRO_FAMILY" in
        void) xbps-query -l 2>/dev/null | grep -q " $pkg-" ;;
        arch) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        debian) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        fedora) rpm -q "$pkg" >/dev/null 2>&1 ;;
    esac
}

service_enable() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit) ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null ;;
        systemd) systemctl enable "$svc" >/dev/null 2>&1 ;;
    esac
}

service_is_enabled() {
    local svc="$1"
    case "$INIT_SYSTEM" in
        runit) [ -L "/var/service/$svc" ] ;;
        systemd) systemctl is-enabled "$svc" >/dev/null 2>&1 ;;
    esac
}

run_with_gauge() {
    local MSG="$1"; shift
    (
        "$@" > "$TMPFILE" 2>&1
        echo $? > "$EXITCODE_FILE"
    ) &
    local CMD_PID=$!

    (
        PCT=0
        while kill -0 $CMD_PID 2>/dev/null; do
            PCT=$(( (PCT + 5) % 100 ))
            echo $PCT; echo "XXX"; echo "$MSG"; echo "XXX"
            sleep 0.3
        done
        echo 100
    ) | dialog --backtitle "$BACKTITLE" --title " $(t 'Proszę czekać' 'Please wait') " --gauge "$MSG" 10 70 0

    wait $CMD_PID
    LAST_EXIT_CODE=$(cat "$EXITCODE_FILE" 2>/dev/null || echo 1)
}

show_error_log() {
    local TITLE="$1"
    dialog --backtitle "$BACKTITLE" --title "$TITLE" --textbox "$TMPFILE" 20 75
}

# ============================================================
#  START SKRYPTU
# ============================================================
pkg_bootstrap

if command -v dialog >/dev/null 2>&1; then
    LANG_SEL=$(dialog --title " Language / Język " --menu "\nSelect your language / Wybierz język:" 12 55 2 \
        "pl" "Polski" "en" "English" 3>&1 1>&2 2>&3)
    [ -n "$LANG_SEL" ] && LANG_CHOICE="$LANG_SEL"
else
    echo "Select language / Wybierz język: [pl/en]"
    read -r LANG_SEL
    [ "$LANG_SEL" == "en" ] && LANG_CHOICE="en"
fi

BACKTITLE="$(t 'Instalator Środowiska Graficznego' 'Desktop Environment Installer') v${SCRIPT_VERSION} — ${DISTRO_NAME}"

if [ "$DISTRO_FAMILY" == "unknown" ]; then
    dialog --backtitle "$BACKTITLE" --title " $(t 'Nieobsługiwany system' 'Unsupported system') " \
        --msgbox "\n$(t "Nie rozpoznano dystrybucji Linuksa.\n\nObsługiwane systemy: Void Linux, Arch Linux, Debian/Ubuntu, Fedora." "Could not detect a supported Linux distribution.\n\nSupported systems: Void Linux, Arch Linux, Debian/Ubuntu, Fedora.")" 14 65
    clear; exit 1
fi

dialog --backtitle "$BACKTITLE" --title " $(t 'Witamy' 'Welcome') " \
    --msgbox "\n$(t "Ten kreator zainstaluje środowisko graficzne na Twoim systemie." "This wizard will install a desktop environment on your system.")\n\n$(t 'Wykryty system' 'Detected system'): $DISTRO_NAME\n$(t 'Wersja skryptu' 'Script version'): $SCRIPT_VERSION\n\n$(t "Użyj strzałek i TAB do nawigacji, ENTER aby zatwierdzić." "Use arrows and TAB to navigate, ENTER to confirm.")" 14 65

run_with_gauge "$(t 'Sprawdzanie połączenia z internetem...' 'Checking internet connection...')" bash -c 'ping -c 2 -W 3 1.1.1.1 > /dev/null 2>&1'
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    dialog --backtitle "$BACKTITLE" --title " $(t 'Brak internetu' 'No internet') " \
        --yesno "\n$(t "Nie udało się połączyć z internetem." "Could not connect to the internet.")\n\n$(t "Sprawdź kartę sieciową i adres IP." "Check your network card and IP address.")\n\n$(t "Czy mimo to chcesz kontynuować?" "Continue anyway?")" 14 65
    if [ $? -ne 0 ]; then clear; echo "$(t 'Przerwano: brak internetu.' 'Aborted: no internet.')"; exit 1; fi
fi

run_with_gauge "$(t 'Synchronizacja bazy pakietów...' 'Syncing package database...')" bash -c "$(declare -f pkg_sync); pkg_sync"
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    show_error_log " $(t 'Błąd synchronizacji' 'Sync error') "
    dialog --backtitle "$BACKTITLE" --title " $(t 'Błąd' 'Error') " \
        --yesno "\n$(t "Synchronizacja bazy pakietów nie powiodła się." "Package database sync failed.")\n\n$(t "Kontynuować mimo to?" "Continue anyway?")" 12 65
    if [ $? -ne 0 ]; then clear; echo "$(t 'Przerwano.' 'Aborted.')"; exit 1; fi
fi

# ============================================================
#  WYBÓR ŚRODOWISKA
# ============================================================
DE_CHOICE=$(dialog --backtitle "$BACKTITLE" --title " $(t 'Środowisko graficzne' 'Desktop environment') " \
    --menu "\n$(t 'Wybierz środowisko graficzne do instalacji:' 'Choose desktop environment to install:')" 19 65 7 \
    "1" "KDE Plasma" \
    "2" "GNOME" \
    "3" "XFCE" \
    "4" "LXQt" \
    "5" "MATE" \
    "6" "Cinnamon" \
    "7" "Hyprland (Wayland)" \
    3>&1 1>&2 2>&3)

if [ -z "$DE_CHOICE" ]; then clear; echo "$(t 'Anulowano.' 'Cancelled.')"; exit 1; fi

DE_KEY=""; DM_KEY=""; DE_LABEL=""
case "$DE_CHOICE" in
    1) DE_KEY="kde"; DM_KEY="sddm"; DE_LABEL="KDE Plasma" ;;
    2) DE_KEY="gnome"; DM_KEY="gdm"; DE_LABEL="GNOME" ;;
    3) DE_KEY="xfce"; DM_KEY="lightdm"; DE_LABEL="XFCE" ;;
    4) DE_KEY="lxqt"; DM_KEY="sddm"; DE_LABEL="LXQt" ;;
    5) DE_KEY="mate"; DM_KEY="lightdm"; DE_LABEL="MATE" ;;
    6) DE_KEY="cinnamon"; DM_KEY="lightdm"; DE_LABEL="Cinnamon" ;;
    7) DE_KEY="hyprland"; DM_KEY="sddm"; DE_LABEL="Hyprland" ;;
esac

# ============================================================
#  BUDOWA LISTY PAKIETOW i WYBÓR APLIKACJI (HUB MENU)
# ============================================================
PACKAGES=""
add_pkg() {
    local resolved=$(pkgname "$1")
    [ -n "$resolved" ] && PACKAGES="$PACKAGES $resolved"
}

for K in mesa xorgfonts xorgminimal dbus elogind vbox; do add_pkg "$K"; done

# --- Wybor serwera wyswietlania ---
DISPLAY_LABEL="X11 (Xorg)"
if [ "$DE_KEY" == "hyprland" ]; then
    # Hyprland to czysty Wayland - nie pytamy o X11
    add_pkg "qtwayland"
    add_pkg "xwayland"
    DISPLAY_LABEL="Wayland"
elif [ "$DE_KEY" == "kde" ] || [ "$DE_KEY" == "gnome" ]; then
    DISPLAY_CHOICE=$(dialog --backtitle "$BACKTITLE" --title " $(t 'Serwer wyświetlania' 'Display server') " \
        --menu "\n$(t 'Wybierz serwer graficzny:' 'Choose your display server:')" 14 65 2 \
        "1" "$(t 'Wayland (nowoczesny)' 'Wayland (modern)')" "2" "$(t 'X11 / Xorg (tradycyjny)' 'X11 / Xorg (traditional)')" 3>&1 1>&2 2>&3)
    
    if [ -z "$DISPLAY_CHOICE" ]; then clear; echo "$(t 'Anulowano.' 'Cancelled.')"; exit 1; fi

    if [ "$DISPLAY_CHOICE" == "1" ]; then
        add_pkg "qtwayland"; add_pkg "xwayland"; DISPLAY_LABEL="Wayland"
    else
        add_pkg "xorgfull"
    fi
else
    add_pkg "xorgfull"
fi

add_pkg "$DE_KEY"
add_pkg "$DM_KEY"

# --- System stanu zaznaczonych aplikacji ---
declare -A APP_STATE

show_app_menu() {
    local title="$1"; shift
    local n="$1"; shift
    local args=()
    local keys=()
    
    while [ $# -gt 0 ]; do
        local key="$1" desc="$2"; shift 2
        local pkg=$(pkgname "$key")
        if [ -n "$pkg" ]; then
            local state="off"
            [ "${APP_STATE[$key]}" == "1" ] && state="on"
            args+=("$key" "$desc" "$state")
            keys+=("$key")
        fi
    done
    
    if [ ${#args[@]} -eq 0 ]; then
        dialog --msgbox "$(t 'Brak dostępnych pakietów w tej kategorii dla tego systemu.' 'No packages available in this category for this system.')" 8 50
        return
    fi
    
    local RESULT=$(dialog --backtitle "$BACKTITLE" --title "$title" \
        --checklist "\n$(t 'Zaznacz spacją, ENTER aby zatwierdzić.' 'Use SPACE to select, ENTER to confirm.')" 20 70 "$n" \
        "${args[@]}" 3>&1 1>&2 2>&3)
        
    for k in "${keys[@]}"; do APP_STATE[$k]="0"; done
    for CH in $RESULT; do
        CH=$(echo "$CH" | tr -d '"')
        APP_STATE[$CH]="1"
    done
}

while true; do
    SEL_COUNT=0
    for k in "${!APP_STATE[@]}"; do [ "${APP_STATE[$k]}" == "1" ] && SEL_COUNT=$((SEL_COUNT+1)); done
    
    MENU_CHOICE=$(dialog --backtitle "$BACKTITLE" --title " $(t 'Menu aplikacji' 'Applications Menu') " \
        --menu "\n$(t 'Wybierz kategorię, aby dodać aplikacje.' 'Select a category to add applications.')\n$(t 'Zaznaczono aplikacji' 'Apps selected'): $SEL_COUNT\n" 16 60 7 \
        "1" "$(t 'Przeglądarki internetowe' 'Web Browsers')" \
        "2" "$(t 'Multimedia i grafika' 'Multimedia & Graphics')" \
        "3" "$(t 'Biuro i komunikacja' 'Office & Communication')" \
        "4" "$(t 'Programowanie i narzędzia' 'Development & Tools')" \
        "5" "$(t 'Narzędzia systemowe' 'System Utilities')" \
        "6" "$(t 'Gaming' 'Gaming')" \
        "7" "$(t 'Zakończ i kontynuuj instalację' 'Confirm & Continue')" 3>&1 1>&2 2>&3)
        
    [ -z "$MENU_CHOICE" ] && MENU_CHOICE="7"

    case "$MENU_CHOICE" in
        1) show_app_menu " $(t 'Przeglądarki internetowe' 'Web Browsers') " 3 \
            firefox "Mozilla Firefox" chromium "Chromium" tor "Tor Browser" ;;
        2) show_app_menu " $(t 'Multimedia i grafika' 'Multimedia & Graphics') " 6 \
            vlc "VLC Media Player" mpv "mpv" gimp "GIMP" blender "Blender" obs "OBS Studio" kdenlive "Kdenlive" audacity "Audacity" ;;
        3) show_app_menu " $(t 'Biuro i komunikacja' 'Office & Communication') " 4 \
            libreoffice "LibreOffice" telegram "Telegram Desktop" discord "Discord" thunderbird "Thunderbird" ;;
        4) show_app_menu " $(t 'Programowanie i narzędzia' 'Development & Tools') " 6 \
            git "Git" fish "Fish Shell" neovim "Neovim" docker "Docker" python3 "Python 3" build_tools "Build tools (gcc/make)" ;;
        5) show_app_menu " $(t 'Narzędzia systemowe' 'System Utilities') " 5 \
            htop "htop" btop "btop" fastfetch "fastfetch" tmux "tmux" ranger "ranger" flatpak "Flatpak" ;;
        6) show_app_menu " $(t 'Gaming' 'Gaming') " 4 \
            steam "Steam" lutris "Lutris" wine "Wine" gamemode "Gamemode" ;;
        7) break ;;
    esac
done

# Zbieranie zaznaczonych pakietów
for k in "${!APP_STATE[@]}"; do
    if [ "${APP_STATE[$k]}" == "1" ]; then add_pkg "$k"; fi
done

PACKAGES=$(echo "$PACKAGES" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ')

# ============================================================
#  PODSUMOWANIE I INSTALACJA
# ============================================================
dialog --backtitle "$BACKTITLE" --title " $(t 'Podsumowanie' 'Summary') " \
    --yesno "\n$(t 'System' 'System'): $DISTRO_NAME\n$(t 'Środowisko' 'Environment'): $DE_LABEL\n$(t 'Serwer graficzny' 'Display server'): $DISPLAY_LABEL\n\n$(t 'Pakiety' 'Packages'):\n$PACKAGES\n\n$(t 'Kontynuować instalację?' 'Proceed with installation?')" 22 70

if [ $? -ne 0 ]; then clear; echo "$(t 'Anulowano.' 'Cancelled.')"; exit 1; fi

run_with_gauge "$(t 'Instalowanie pakietów, proszę czekać...' 'Installing packages, please wait...')" bash -c "$(declare -f pkg_install); pkg_install $PACKAGES"

if [ "$LAST_EXIT_CODE" -ne 0 ]; then
    show_error_log " $(t 'Błąd instalacji' 'Installation error') "
    dialog --backtitle "$BACKTITLE" --title " $(t 'Błąd' 'Error') " \
        --msgbox "\n$(t "Instalacja pakietów nie powiodła się (kod: $LAST_EXIT_CODE)." "Package installation failed (exit code: $LAST_EXIT_CODE).")\n\n$(t "Zobacz log powyżej." "See the log above.")" 12 65
    clear; exit 1
fi

CHECK_PKGS="$(pkgname $DE_KEY) $(pkgname $DM_KEY) $(pkgname dbus)"
MISSING=""
for PKG in $CHECK_PKGS; do
    pkg_is_installed "$PKG" || MISSING="$MISSING $PKG"
done

if [ -n "$MISSING" ]; then
    dialog --backtitle "$BACKTITLE" --title " $(t 'Błąd weryfikacji' 'Verification error') " \
        --msgbox "\n$(t "Brakuje kluczowych pakietów:" "Missing key packages:")\n$MISSING" 12 65
    clear; exit 1
fi

run_with_gauge "$(t 'Konfiguracja usług systemowych...' 'Configuring system services...')" bash -c "
    $(declare -f service_enable)
    mkdir -p /var/service 2>/dev/null
    service_enable dbus
    service_enable elogind
    service_enable $DM_KEY
    service_enable vboxservice
"

SERVICE_MISSING=""
for SVC in $DM_KEY; do
    service_is_enabled "$SVC" || SERVICE_MISSING="$SERVICE_MISSING $SVC"
done

if [ -n "$SERVICE_MISSING" ]; then
    dialog --backtitle "$BACKTITLE" --title " $(t 'Brakujące usługi' 'Missing services') " \
        --msgbox "\n$(t "Nie udało się włączyć:" "Failed to enable:")\n$SERVICE_MISSING\n\n$(t "Włącz ręcznie po restarcie." "Enable manually after reboot.")" 12 65
fi

# ============================================================
#  KONFIGURACJA HYPRLAND (CAELESTIA-DOTS)
# ============================================================
if [ "$DE_KEY" == "hyprland" ]; then
    dialog --backtitle "$BACKTITLE" --title " $(t 'Konfiguracja Hyprland' 'Hyprland Configuration') " \
        --yesno "\n$(t "Czy chcesz automatycznie pobrać i zainstalować konfigurację (dots) z repozytorium:" "Do you want to automatically download and install the configuration (dots) from the repository:")\n\ngithub.com/caelestia-dots/shell\n\n$(t "Wymaga to połączenia z internetem i zainstalowanego git." "This requires internet connection and git installed.")" 13 70

    if [ $? -eq 0 ]; then
        install_hypr_dots() {
            # Wymuszamy instalację git, jeśli nie został wybrany w menu
            if ! pkg_is_installed git; then
                pkg_install git >/dev/null 2>&1
            fi

            TARGET_USER=${SUDO_USER:-$USER}
            TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
            TMP_DOTFILES=$(mktemp -d)

            # Klonowanie repozytorium
            if git clone --depth 1 https://github.com/caelestia-dots/shell.git "$TMP_DOTFILES" 2>&1; then
                cd "$TMP_DOTFILES" || return 1
                
                # Caelestia-dots zazwyczaj posiada skrypt instalacyjny
                if [ -f "install.sh" ]; then
                    sudo -u "$TARGET_USER" bash install.sh 2>&1
                elif [ -f "setup.sh" ]; then
                    sudo -u "$TARGET_USER" bash setup.sh 2>&1
                else
                    # Awaryjne kopiowanie .config jeśli brak skryptu
                    mkdir -p "$TARGET_HOME/.config"
                    if [ -d "config" ]; then
                        sudo -u "$TARGET_USER" cp -r config/* "$TARGET_HOME/.config/" 2>&1
                    elif [ -d ".config" ]; then
                        sudo -u "$TARGET_USER" cp -r .config/* "$TARGET_HOME/.config/" 2>&1
                    fi
                fi
                cd - || return 1
                rm -rf "$TMP_DOTFILES"
                return 0
            else
                return 1
            fi
        }

        run_with_gauge "$(t 'Pobieranie i instalacja konfiguracji Hyprland...' 'Downloading and installing Hyprland configuration...')" bash -c "$(declare -f install_hypr_dots); $(declare -f pkg_is_installed); $(declare -f pkg_install); install_hypr_dots"
        
        if [ "$LAST_EXIT_CODE" -ne 0 ]; then
            show_error_log " $(t 'Błąd konfiguracji Hyprland' 'Hyprland config error') "
            dialog --backtitle "$BACKTITLE" --title " $(t 'Uwaga' 'Notice') " \
                --msgbox "\n$(t "Nie udało się w pełni zainstalować konfiguracji. Sprawdź log błędów. Możesz to zrobić ręcznie po restarcie." "Failed to fully install the configuration. Check the error log. You can do this manually after reboot.")" 12 65
        fi
    fi
fi

# ============================================================
#  EKRAN KOŃCOWY
# ============================================================
SESSION_INFO="$DE_LABEL (X11)"
[ "$DISPLAY_LABEL" == "Wayland" ] && SESSION_INFO="$DE_LABEL (Wayland)"

dialog --backtitle "$BACKTITLE" --title " $(t 'Instalacja zakończona' 'Installation complete') " \
    --msgbox "\n$(t "$DE_LABEL zostało zainstalowane!" "$DE_LABEL has been installed!")\n\n$(t "Na ekranie logowania wybierz sesję" "On the login screen, choose session"): '$SESSION_INFO'\n\n$(t "System zostanie teraz zrestartowany." "The system will now reboot.")" 14 65

clear
fastfetch 2>/dev/null || true
echo "$(t 'Restart za 5 sekund...' 'Rebooting in 5 seconds...')"
sleep 5
reboot
```
