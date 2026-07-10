#!/bin/bash

# Kolory dla lepszej czytelności w terminalu
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}   Skrypt instalacyjny KDE Plasma dla Void Linux    ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Sprawdzenie, czy użytkownik ma uprawnienia sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Błąd: Uruchom ten skrypt używając sudo! (sudo bash skrypt.sh)${NC}"
    exit 1
fi

# 1. Aktualizacja bazy danych pakietów
echo -e "\n${YELLOW}[1/4] Aktualizacja bazy danych pakietów...${NC}"
xbps-install -Sy

# Podstawowa lista pakietów (KDE Plasma, SDDM, D-Bus, Elogind, sterowniki 3D dla VM)
PACKAGES="plasma-desktop sddm dbus elogind frameworkintegration konsole dolphin mesa-dri xorg-fonts virtualbox-ose-guest virtualbox-ose-guest-dkms"

# 2. Wybór serwera grafiki (X11 vs Wayland)
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${YELLOW}[2/4] Wybór serwera wyświetlania grafiki:${NC}"
echo -e "1) Wayland (Nowoczesny, wymaga dobrej akceleracji 3D w VM)"
echo -e "2) X11 (Xorg - Tradycyjny, najbardziej stabilny na Maszynach Wirtualnych)"
read -p "Wybierz opcję (1 lub 2): " DISPLAY_CHOICE

if [ "$DISPLAY_CHOICE" == "1" ]; then
    echo -e "${GREEN}Wybrano: Wayland${NC}"
    PACKAGES="$PACKAGES xorg-minimal qt6-wayland xwayland"
else
    echo -e "${GREEN}Wybrano: X11 (Xorg)${NC}"
    PACKAGES="$PACKAGES xorg plasma-x11"
fi

# 3. Pytanie o dodatkowe narzędzia
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${YELLOW}[3/4] Opcjonalne pakiety:${NC}"

# Czy instalować Firefoxa?
read -p "Czy chcesz zainstalować przeglądarkę Firefox? (t/n): " INSTALL_FF
if [[ "$INSTALL_FF" =~ ^[Tt]$ ]]; then
    PACKAGES="$PACKAGES firefox"
    echo -e "${GREEN}- Dodano Firefox do listy instalacji.${NC}"
fi

# Czy instalować podstawowe toolsy?
read -p "Czy chcesz zainstalować podstawowe narzędzia (git, curl, fish, fastfetch)? (t/n): " INSTALL_TOOLS
if [[ "$INSTALL_TOOLS" =~ ^[Tt]$ ]]; then
    PACKAGES="$PACKAGES git curl fish fastfetch"
    echo -e "${GREEN}- Dodano narzędzia (git, curl, fish, fastfetch) do listy instalacji.${NC}"
fi

# 4. Instalacja pakietów przez XBPS
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${YELLOW}[4/4] Rozpoczynanie instalacji wybranych pakietów...${NC}"
echo -e "Instalowane pakiety: $PACKAGES\n"

xbps-install -y $PACKAGES

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}Instalacja pakietów zakończona sukcesem!${NC}"
else
    echo -e "\n${RED}Błąd podczas instalacji pakietów. Sprawdź połączenie internetowe.${NC}"
    exit 1
fi

# 5. Konfiguracja usług (Setup autostartu przez runit)
echo -e "\n${YELLOW}Konfiguracja usług systemowych w /var/service/...${NC}"

# Tworzenie bezpiecznych dowiązań symbolicznych (-f nadpisuje istniejące)
ln -sf /etc/sv/dbus /var/service/
ln -sf /etc/sv/elogind /var/service/
ln -sf /etc/sv/vboxservice /var/service/
ln -sf /etc/sv/sddm /var/service/

echo -e "${GREEN}Usługi (dbus, elogind, vboxservice, sddm) zostały pomyślnie włączone!${NC}"

# 6. Informacja końcowa i restart
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}Konfiguracja zakończona! System za chwilę się zrestartuje.${NC}"
if [ "$DISPLAY_CHOICE" == "1" ]; then
    echo -e "${YELLOW}PAMIĘTAJ: Na ekranie logowania SDDM wybierz sesję 'Plasma (Wayland)'.${NC}"
else
    echo -e "${YELLOW}PAMIĘTAJ: Na ekranie logowania SDDM wybierz sesję 'Plasma (X11)'.${NC}"
fi
echo -e "${BLUE}====================================================${NC}"

sleep 5
reboot
