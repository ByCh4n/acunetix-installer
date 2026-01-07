#!/bin/bash
# Acunetix Kurulum ve Yapılandırma Scripti - v2.0
# ByCh4n | Cyber Security Expert

# Hata oluştuğunda durma opsiyonu (İsteğe bağlı, şu an kapalı)
# set -e

# Renk Tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper Fonksiyonlar
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Root Kontrolü
if [ "$(id -u)" -ne 0 ]; then
    error "Bu script root yetkileriyle çalıştırılmalıdır! (sudo su)"
fi

# Banner
clear
cat << "EOF"
  ___  _  _  ____  _  _  ___  _____  _  _  ____ 
 / __)( \/ )( ___)( \( )/ __)(  _  )( \( )( ___)
( (__  \  /  )__)  )  (( (_-. )(_)(  )  (  )__) 
 \___)  \/  (____)(_)\_)\___/(_____)(_)\_)(____)

      Acunetix Auto Installer & Patcher
      ByCh4n | Cyber Security Expert
------------------------------------------------
EOF

# 1. Bağımlılıkların Kurulumu
install_dependencies() {
    info "Sistem güncelleniyor ve bağımlılıklar kuruluyor..."
    
    # apt işlemleri sırasında kullanıcı etkileşimini kapatmak için
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update -qq >/dev/null 2>&1
    DEPENDENCIES=(p7zip-full libxcomposite1 libcups2 libasound2 libatk1.0-0 libgbm1 libxfixes3 libcairo2 libxrandr2 libxkbcommon0 libatk-bridge2.0-0 libxdamage1 libatspi2.0-0 wget curl systemd)
    
    apt-get install -y "${DEPENDENCIES[@]}" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        success "Bağımlılıklar kuruldu."
    else
        error "Bağımlılıklar kurulurken hata oluştu. İnternet bağlantınızı kontrol edin."
    fi
}

# 2. Hosts Dosyası Güncellemesi (Akıllı Ekleme)
add_host_entry() {
    local ip=$1
    local domain=$2
    if ! grep -q "$domain" /etc/hosts; then
        echo "$ip  $domain" >> /etc/hosts
        echo -e "   ${GREEN}+${NC} Eklendi: $domain"
    else
        echo -e "   ${YELLOW}*${NC} Mevcut: $domain"
    fi
}

update_hosts() {
    info "/etc/hosts dosyası yapılandırılıyor..."
    
    # Yedek al (Eğer yedek yoksa)
    if [ ! -f /etc/hosts.original ]; then
        cp /etc/hosts /etc/hosts.original
        success "Orijinal hosts dosyası yedeklendi (/etc/hosts.original)"
    fi

    echo -e "\n# Acunetix Engellemeleri (ByCh4n Script)" >> /etc/hosts
    
    # Domain listesi
    DOMAINS=(
        "erp.acunetix.com"
        "discovery-service.invicti.com"
        "cdn.pendo.io"
        "bxss.me"
        "jwtsigner.invicti.com"
        "sca.acunetix.com"
        "telemetry.invicti.com"
    )

    # IPv4 Ekleme
    for domain in "${DOMAINS[@]}"; do
        if [[ "$domain" == "telemetry.invicti.com" ]]; then
             add_host_entry "192.178.49.174" "$domain"
        else
             add_host_entry "127.0.0.1" "$domain"
        fi
    done

    # IPv6 Ekleme
    for domain in "${DOMAINS[@]}"; do
        if [[ "$domain" == "telemetry.invicti.com" ]]; then
             add_host_entry "2607:f8b0:402a:80a::200e" "$domain"
        else
             add_host_entry "::1" "$domain"
        fi
    done
    
    success "Hosts dosyası güncellendi."
}

# 3. İndirme ve Kurulum
install_acunetix() {
    local FILE_NAME="Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z"
    local URL="https://pwn3rzs.co/scanner_web/acunetix/$FILE_NAME"
    local INSTALLER="acunetix_25.1.250204093_x64.sh"

    info "Acunetix indiriliyor..."
    if [ ! -f "$FILE_NAME" ]; then
        wget -q --show-progress "$URL"
    else
        warning "Dosya zaten mevcut, indirme atlanıyor."
    fi

    if [ ! -f "$FILE_NAME" ]; then
        error "İndirme başarısız! Link kırık veya internet yok."
    fi

    info "Arşiv çıkarılıyor..."
    7za e -y "$FILE_NAME" -p'Pwn3rzs' >/dev/null 2>&1
    
    if [ ! -f "$INSTALLER" ]; then
        error "Arşivden çıkarma başarısız oldu. Şifre yanlış olabilir veya dosya bozuk."
    fi

    info "Kurulum başlatılıyor... (Lütfen ekrandaki yönergeleri izleyin)"
    chmod +x "$INSTALLER"
    
    # Not: Otomatik kurulum için genellikle bayraklar kullanılır ama scriptin yapısına göre manuel bıraktım.
    ./"$INSTALLER"
}

# 4. Yapılandırma ve Crack
configure_acunetix() {
    info "Lisanslama işlemi başlatılıyor..."

    # Servisi durdur
    systemctl stop acunetix 2>/dev/null

    # Hedef dizinler
    local SCANNER_DIR="/home/acunetix/.acunetix/v_250204093/scanner"
    local LICENSE_DIR="/home/acunetix/.acunetix/data/license"

    # Dosya varlığı kontrolü
    if [ ! -d "$SCANNER_DIR" ]; then
        error "Acunetix kurulum dizini bulunamadı! Kurulumun doğru yapıldığından emin olun."
    fi

    info "Binary dosyası değiştiriliyor..."
    if [ -f "wvsc" ]; then
        cp -f wvsc "$SCANNER_DIR/wvsc"
        chown acunetix:acunetix "$SCANNER_DIR/wvsc"
        chmod +x "$SCANNER_DIR/wvsc"
    else
        error "'wvsc' dosyası bulunamadı! Crack dosyaları eksik."
    fi

    info "Lisans dosyaları kopyalanıyor..."
    
    # Önceki kilitleri kaldır (Eğer varsa)
    chattr -i "$LICENSE_DIR/license_info.json" 2>/dev/null
    chattr -i "$LICENSE_DIR/wa_data.dat" 2>/dev/null
    
    # Eski lisansları temizle
    rm -f "$LICENSE_DIR"/* 2>/dev/null

    if [ -f "license_info.json" ] && [ -f "wa_data.dat" ]; then
        cp license_info.json "$LICENSE_DIR/"
        cp wa_data.dat "$LICENSE_DIR/"
        
        # İzinleri ayarla
        chown acunetix:acunetix "$LICENSE_DIR/license_info.json"
        chown acunetix:acunetix "$LICENSE_DIR/wa_data.dat"
        chmod 444 "$LICENSE_DIR/license_info.json"
        chmod 444 "$LICENSE_DIR/wa_data.dat"
        
        # Dosyaları kilitle (Silinmemesi için)
        chattr +i "$LICENSE_DIR/license_info.json"
        chattr +i "$LICENSE_DIR/wa_data.dat"
        
        success "Lisans dosyaları yerleştirildi ve kilitlendi."
    else
        error "Lisans dosyaları (json/dat) bulunamadı!"
    fi

    info "Acunetix servisi başlatılıyor..."
    systemctl start acunetix

    # Servis durumunu bekle ve kontrol et
    sleep 5
    if systemctl is-active --quiet acunetix; then
        success "Acunetix servisi AKTİF ve çalışıyor."
    else
        error "Acunetix servisi başlatılamadı! 'systemctl status acunetix' komutuyla logları kontrol edin."
    fi
}

# 5. Temizlik
cleanup() {
    info "Geçici dosyalar temizleniyor..."
    
    local FILES=(
        "Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z"
        "acunetix_25.1.250204093_x64.sh"
        "install.log"
        "license_info.json"
        "wa_data.dat"
        "wvsc"
        "README.txt"
    )

    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo -e "   ${GREEN}-${NC} Silindi: $file"
        fi
    done
    success "Temizlik tamamlandı."
}

# Ana Akış
main() {
    install_dependencies
    update_hosts
    install_acunetix
    configure_acunetix
    cleanup
    
    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}   KURULUM BAŞARIYLA TAMAMLANDI!   ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo -e "Tarayıcıdan erişim: ${YELLOW}https://localhost:3443${NC}"
    echo -e "veya sunucu IP adresiniz ile bağlanabilirsiniz."
    echo ""
}

main "$@"
