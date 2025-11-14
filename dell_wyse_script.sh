#!/bin/bash

set -e
trap 'echo "❌ Wystąpił błąd w linii $LINENO. Skrypt przerwany."; exit 1' ERR

echo '*************** STARTUP SCRIPT STARTED ***************'
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"

# 🔹 Wyłączenie trybów uśpienia
echo '▶️ Wyłączanie trybów uśpienia...'
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 🔹 Ustawienie czasu i strefy
echo '▶️ Ustawianie strefy czasowej i synchronizacji czasu...'
sudo timedatectl set-timezone Europe/Warsaw
sudo timedatectl set-ntp true

# 🔹 Aktualizacja systemu
echo '▶️ Aktualizacja systemu...'
sudo apt update -y || { echo '❌ Błąd podczas aktualizacji listy pakietów.'; exit 1; }
sudo apt upgrade -y || { echo '❌ Błąd podczas aktualizacji systemu.'; exit 1; }

# 🔹 Instalacja podstawowych pakietów
echo '▶️ Instalacja podstawowego oprogramowania...'
sudo apt install -y \
    samba zip unzip ntp udevil \
    gvfs-backends smbclient \
    curl wget net-tools iputils-ping \
    htop iotop ncdu \
    fail2ban ufw \
    avahi-daemon nfs-common \
    nano git || { echo '❌ Błąd podczas instalacji pakietów.'; exit 1; }

# 🔹 Instalacja środowiska graficznego i xRDP
echo '▶️ Instalacja środowiska XFCE4 i xRDP...'
sudo apt install -y xfce4 xfce4-goodies xrdp || { echo '❌ Błąd podczas instalacji XFCE4/xRDP.'; exit 1; }
sudo apt install -y lightdm || { echo '❌ Błąd podczas instalacji lightdm.'; exit 1; }
sudo dpkg-reconfigure lightdm
sudo bash -c 'echo "[Seat:*]\nuser-session=xfce" > /etc/lightdm/lightdm.conf'
sudo sed -i 's|^test -x /etc/X11/Xsession && exec /etc/X11/Xsession|startxfce4|g' /etc/xrdp/startwm.sh
echo xfce4-session > ~/.xsession
chmod +x ~/.xsession
sudo systemctl enable xrdp || { echo '❌ Błąd podczas aktywacji xrdp.'; exit 1; }
sudo systemctl restart xrdp || { echo '❌ Błąd podczas restartu xrdp.'; exit 1; }

# 🔹 Konfiguracja SSH
echo '▶️ Konfiguracja SSH (zmiana portu, blokada roota)...'
sudo sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh || { echo '❌ Błąd podczas restartu SSH.'; exit 1; }

# 🔹 Konfiguracja firewalla UFW
echo '▶️ Konfiguracja firewalla (UFW)...'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp         # SSH (nowy port)
sudo ufw allow 3389/tcp         # xRDP
sudo ufw allow 80,443/tcp       # HTTP/HTTPS (dla Portainera itd.)
sudo ufw allow 8123/tcp         # Home Assistant
sudo ufw allow 8581/tcp         # Homebridge UI
sudo ufw allow 8080/tcp         # NetAlertX
sudo ufw allow 8000/tcp         # Speedtest Tracker
sudo ufw allow 8086/tcp        # InfluxDB 
sudo ufw enable || { echo '❌ Błąd podczas aktywacji UFW.'; exit 1; }

# 🔹 Instalacja Docker + Compose
echo '▶️ Instalacja Dockera...'
curl -fsSL https://get.docker.com -o get-docker.sh || { echo '❌ Błąd podczas pobierania Dockera.'; exit 1; }
sudo sh get-docker.sh || { echo '❌ Błąd podczas instalacji Dockera.'; exit 1; }
sudo usermod -aG docker $USER || { echo '❌ Błąd podczas dodawania użytkownika do grupy docker.'; exit 1; }

echo '▶️ Instalacja Docker Compose...'
sudo apt install -y docker-compose || { echo '❌ Błąd podczas instalacji Docker Compose.'; exit 1; }

# 🔹 Uruchomienie Portainera (z volume)
echo '▶️ Tworzenie volume i uruchamianie Portainera...'
docker volume create portainer_data || { echo '❌ Błąd podczas tworzenia volume Portainera.'; exit 1; }
docker run -d -p 9000:9000 -p 9443:9443 \
  --name portainer \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce || { echo '❌ Błąd podczas uruchamiania Portainera.'; exit 1; }

# 🔹 Domyślna przeglądarka dla XFCE
sudo apt install -y chromium-browser || { echo '❌ Błąd podczas instalacji Chromium.'; exit 1; }
echo '▶️ Ustawianie Chromium jako domyślnej przeglądarki...'
sudo update-alternatives --config x-www-browser || { echo '❌ Błąd podczas ustawiania domyślnej przeglądarki.'; exit 1; }

# 🔹 Czyszczenie systemu
echo '▶️ Czyszczenie nieużywanych pakietów...'
sudo apt autoremove -y || { echo '❌ Błąd podczas autoremove.'; exit 1; }
sudo apt autoclean -y || { echo '❌ Błąd podczas autoclean.'; exit 1; }

# 🔹 Sprawdzenie dostępnych interfejsów sieciowych
echo '▶️ Dostępne interfejsy sieciowe:'
ip -o link show | awk -F': ' '{print $2}'
read -p "Podaj nazwę interfejsu sieciowego do konfiguracji (np. enp1s0): " NET_IF
read -p "Podaj adres IP (np. 192.168.1.100/24): " IP_ADDR
read -p "Podaj bramę (np. 192.168.1.1): " GW_ADDR
read -p "Podaj serwery DNS oddzielone przecinkami (np. 1.1.1.1,8.8.8.8): " DNS_ADDR

# 🔹 Konfiguracja statycznego IP
cat <<EOF | sudo tee /etc/netplan/01-static.yaml > /dev/null
network:
  version: 2
  ethernets:
    $NET_IF:
      dhcp4: no
      addresses: [$IP_ADDR]
      gateway4: $GW_ADDR
      nameservers:
        addresses: [${DNS_ADDR}]
EOF

sudo netplan apply || { echo '❌ Błąd podczas stosowania konfiguracji sieci (netplan apply).'; exit 1; }

# 🔹 Restart systemu
echo "✅ Skrypt zakończony. Restart systemu... End time: $(date '+%Y-%m-%d %H:%M:%S')"
sleep 3
sudo reboot