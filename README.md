<img width="1280" height="400" alt="2" src="https://github.com/user-attachments/assets/ef9cdbc9-41a9-4a85-8608-977972527692" />

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

<img width="1024" height="541" alt="image" src="https://github.com/user-attachments/assets/db5ed141-1228-472c-89fc-c309479cb66c" />


## 🚀 Kurulum

Aşağıdaki komutları sırayla çalıştırarak kurulumu başlatabilirsiniz:

```bash
git clone https://github.com/ByCh4n/acunetix-installer.git
cd acunetix-installer
chmod +777 install.sh
sudo ./install.sh
```
<img width="1604" height="614" alt="image" src="https://github.com/user-attachments/assets/d283d304-27dc-4837-90dd-46c27fae8ca0" />

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
