#!/bin/bash
# Acunetix Kurulum ve Yapılandırma Scripti
# ByCh4n | Cyber Security Expert
# https://github.com/ByCh4n/acunetix-installer

# Renkli çıktı fonksiyonları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[+]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[-]${NC} $1" >&2
}

# Root kontrolü
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Bu script root olarak çalıştırılmalıdır!"
        exit 1
    fi
}

# Bağımlılık kurulumu
install_dependencies() {
    info "Gerekli bağımlılıklar kuruluyor..."
    apt update >/dev/null 2>&1
    apt install -y sudo p7zip-full libxcomposite1 libcups2 libasound2 \
        libatk1.0-0 libgbm1 libxfixes3 libcairo2 libxrandr2 \
        libxkbcommon0 libatk-bridge2.0-0 libxdamage1 libatspi2.0-0 >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        info "Bağımlılıklar başarıyla kuruldu."
    else
        error "Bağımlılık kurulumunda hata oluştu!"
        exit 1
    fi
}

# /etc/hosts güncellemesi
update_hosts() {
    info "/etc/hosts dosyası güncelleniyor..."
    
    # Yedek alma
    cp /etc/hosts /etc/hosts.bak
    info "/etc/hosts dosyasının yedeği alındı: /etc/hosts.bak"

    # hosts dosyasına eklemeler
    echo -e "\n# Acunetix Engellemeleri" >> /etc/hosts
    echo "127.0.0.1  erp.acunetix.com" >> /etc/hosts
    echo "127.0.0.1  erp.acunetix.com." >> /etc/hosts
    echo "::1  erp.acunetix.com" >> /etc/hosts
    echo "::1  erp.acunetix.com.#127.0.0.1  discovery-service.invicti.com" >> /etc/hosts
    echo "127.0.0.1  discovery-service.invicti.com." >> /etc/hosts
    echo "::1  discovery-service.invicti.com" >> /etc/hosts
    echo "::1  discovery-service.invicti.com.#127.0.0.1  cdn.pendo.io" >> /etc/hosts
    echo "127.0.0.1  cdn.pendo.io." >> /etc/hosts
    echo "::1  cdn.pendo.io" >> /etc/hosts
    echo "::1  cdn.pendo.io.#127.0.0.1  bxss.me" >> /etc/hosts
    echo "127.0.0.1  bxss.me." >> /etc/hosts
    echo "::1  bxss.me" >> /etc/hosts
    echo "::1  bxss.me.#127.0.0.1  jwtsigner.invicti.com" >> /etc/hosts
    echo "127.0.0.1  jwtsigner.invicti.com." >> /etc/hosts
    echo "::1  jwtsigner.invicti.com" >> /etc/hosts
    echo "::1  jwtsigner.invicti.com.#127.0.0.1  sca.acunetix.com" >> /etc/hosts
    echo "127.0.0.1  sca.acunetix.com." >> /etc/hosts
    echo "::1  sca.acunetix.com" >> /etc/hosts
    echo "::1  sca.acunetix.com.#192.178.49.174  telemetry.invicti.com" >> /etc/hosts
    echo "192.178.49.174  telemetry.invicti.com." >> /etc/hosts
    echo "2607:f8b0:402a:80a::200e  telemetry.invicti.com" >> /etc/hosts
    echo "2607:f8b0:402a:80a::200e  telemetry.invicti.com." >> /etc/hosts

    info "/etc/hosts güncellemesi tamamlandı."
}

# Acunetix indirme ve kurulum
install_acunetix() {
    info "Acunetix indiriliyor..."
    wget -q https://pwn3rzs.co/scanner_web/acunetix/Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z
    
    if [ ! -f "Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z" ]; then
        error "Acunetix indirme başarısız!"
        exit 1
    fi

    info "Arşiv çıkarılıyor..."
    7za e -y Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z -p'Pwn3rzs' >/dev/null 2>&1
    
    info "Kurulum başlatılıyor..."
    chmod +x acunetix_25.1.250204093_x64.sh
    ./acunetix_25.1.250204093_x64.sh
}

# Acunetix yapılandırması
configure_acunetix() {
    info "Acunetix servisi durduruluyor..."
    sudo systemctl stop acunetix

    info "Dosyalar kopyalanıyor ve izinler ayarlanıyor..."
    sudo cp wvsc /home/acunetix/.acunetix/v_250204093/scanner/wvsc
    sudo chown acunetix:acunetix /home/acunetix/.acunetix/v_250204093/scanner/wvsc
    sudo chmod +x /home/acunetix/.acunetix/v_250204093/scanner/wvsc

    info "Lisans dosyaları ayarlanıyor..."
    sudo rm -f /home/acunetix/.acunetix/data/license/* 2>/dev/null || true
    sudo cp license_info.json /home/acunetix/.acunetix/data/license/
    sudo cp wa_data.dat /home/acunetix/.acunetix/data/license/
    sudo chown acunetix:acunetix /home/acunetix/.acunetix/data/license/license_info.json
    sudo chown acunetix:acunetix /home/acunetix/.acunetix/data/license/wa_data.dat
    sudo chmod 444 /home/acunetix/.acunetix/data/license/license_info.json
    sudo chmod 444 /home/acunetix/.acunetix/data/license/wa_data.dat
    sudo chattr +i /home/acunetix/.acunetix/data/license/license_info.json
    sudo chattr +i /home/acunetix/.acunetix/data/license/wa_data.dat

    info "Acunetix servisi başlatılıyor..."
    sudo systemctl start acunetix

    # Servis durumu kontrolü
    if systemctl is-active --quiet acunetix; then
        info "Acunetix başarıyla başlatıldı."
    else
        error "Acunetix başlatılamadı!"
        exit 1
    fi
}

cleanup() {
    info "Geçici dosyalar temizleniyor..."

    FILES_TO_DELETE=(
        "Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z"
        "acunetix_25.1.250204093_x64.sh"
        "install.log"
        "license_info.json"
        "wa_data.dat"
        "wvsc"
        "README.txt"
    )

    for file in "${FILES_TO_DELETE[@]}"; do
        [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done

    info "Temizlik tamamlandı."
}

# Ana işlem akışı
main() {
    clear
    echo -e "${GREEN}"
    echo "  ___  _  _  ____  _  _  ___  _____  _  _  ____ "
    echo " / __)( \\/ )( ___)( \\( )/ __)(  _  )( \\( )( ___)"
    echo "( (__  \\  /  )__)  )  (( (_-. )(_)(  )  (  )__) "
    echo " \\___)  \\/  (____)(_)\\_)\\___/(_____)(_)\\_)(____)"
    echo -e "${NC}"
    echo " Acunetix Kurulum Scripti"
    echo " ByCh4n | Cyber Security Expert"
    echo "----------------------------------------"
    
    check_root
    install_dependencies
    update_hosts
    install_acunetix
    configure_acunetix
	cleanup
    
    info "Kurulum başarıyla tamamlandı!"
    warning "Lütfen tarayıcınızda Acunetix arayüzüne giriş yaparak kurulumu tamamlayın."
}

main "$@"
