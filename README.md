# Acunetix Installer Script

Bu script, Acunetix v25.1 sürümünü otomatik olarak indirip kurar, gerekli yapılandırmaları yapar ve kurulum sonrası geçici dosyaları temizler.

## 🛠 Özellikler

- Bağımlılıkların kurulumu
- /etc/hosts güncellemesi
- Acunetix indirip kurma
- Lisans dosyalarının yerleştirilmesi
- Geçici dosyaların otomatik temizliği

## 🚀 Kurulum

```bash
git clone https://github.com/kullanici_adi/acunetix-installer.git
cd acunetix-installer
chmod +x install.sh
sudo ./install.sh
