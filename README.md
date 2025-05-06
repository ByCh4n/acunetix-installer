
![logo](https://github.com/user-attachments/assets/89abd73f-f2cc-4173-b3b3-b4ff6e83a75a)

# Acunetix Kurulum Scripti

Bu script, **Acunetix v25.1** sürümünü Linux sistemlere otomatik olarak kurmak ve yapılandırmak için hazırlanmıştır. Bağımlılık kurulumundan lisans yamalamaya, `/etc/hosts` düzenlemesinden geçici dosya temizliğine kadar tüm süreci yönetir.

## 🛠 Özellikler

- Gerekli tüm bağımlılıkların kurulumu
- Acunetix arşivinin otomatik indirilmesi ve çıkarılması
- Telemetri ve izleme sunucularının `/etc/hosts` dosyası üzerinden engellenmesi
- Orijinal `wvsc` tarama dosyasının değiştirilmesi
- Lisans dosyalarının uygun izinlerle yerleştirilmesi
- Kurulum sonrası geçici dosyaların otomatik temizlenmesi
- Renkli terminal çıktıları ile kullanıcı dostu arayüz

## 🚀 Kurulum

Aşağıdaki komutları sırayla çalıştırarak kurulumu başlatabilirsiniz:

```bash
git clone https://github.com/ByCh4n/acunetix-installer.git
cd acunetix-installer
chmod +777 install.sh
sudo ./install.sh
```

--------------------------------------------------------------

# Acunetix Installer Script

A fully automated Bash script that installs and configures **Acunetix v25.1** on Linux systems. It handles dependency installation, host blocking for telemetry, license patching, and cleanup.

## 🛠 Features

- Installs all required dependencies
- Automatically downloads and extracts Acunetix
- Updates `/etc/hosts` to block telemetry and tracking
- Replaces original `wvsc` scanner binary
- Patches license files with proper permissions and attributes
- Cleans up installation artifacts after setup
- Colored terminal output for better readability

## 🚀 Installation

Clone the repository and run the script:

```bash
git clone https://github.com/ByCh4n/acunetix-installer.git
cd acunetix-installer
chmod +777 install.sh
sudo ./install.sh
```
