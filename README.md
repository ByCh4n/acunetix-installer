<p align="center">
  <img width="1280" alt="acunetix-installer" src="https://github.com/user-attachments/assets/ef9cdbc9-41a9-4a85-8608-977972527692" />
</p>

<h1 align="center">Acunetix Installer</h1>

<p align="center">
  <img src="https://github.com/ByCh4n/acunetix-installer/actions/workflows/shellcheck.yml/badge.svg" alt="ShellCheck" />
  <img src="https://img.shields.io/github/license/ByCh4n/acunetix-installer" alt="License" />
  <img src="https://img.shields.io/github/stars/ByCh4n/acunetix-installer?style=social" alt="Stars" />
</p>

A fully automated Bash script that installs and configures **Acunetix v25.1** on
Linux systems. It handles dependency installation, `/etc/hosts` telemetry
blocking, licensing, and cleanup — driven entirely from a single script.

## Features

- Installs all required dependencies, with automatic fallback to the Debian 13 /
  Ubuntu 24.04 `t64` library variants
- Downloads and extracts Acunetix automatically
- Updates `/etc/hosts` to block telemetry and tracking endpoints (IPv4 + IPv6)
- Places license files with the correct permissions and immutable attributes
- Cleans up installation artifacts on exit
- Single-point version configuration (`BUILD` / `VERSION_SHORT` variables)
- Colored, readable terminal output

## Requirements

- A Debian-based distribution (Debian / Ubuntu / Kali)
- Root privileges (`sudo`)
- `wget`, `7za` (installed automatically via `p7zip-full`)
- An active internet connection

## Installation

```bash
git clone https://github.com/ByCh4n/acunetix-installer.git
cd acunetix-installer
chmod +x install.sh
sudo ./install.sh
```

Once finished, open `https://localhost:3443` in your browser.

## Usage

| Flag | Description |
|------|-------------|
| _(none)_ | Run the full installation flow |
| `-h`, `--help` | Show the help message |
| `-v`, `--version` | Show the targeted Acunetix version |

To target a different Acunetix build, edit the `BUILD` and `VERSION_SHORT`
variables at the top of `install.sh`; every path is derived from them.

## Disclaimer

This script is provided for **authorized, educational, and lab use only**. You
are responsible for complying with Acunetix's licensing terms and all applicable
laws in your jurisdiction. The author accepts no liability for misuse.

## Author

**Hüseyin Altıntaş — ByCh4n**

- GitHub: [@ByCh4n](https://github.com/ByCh4n)
- LinkedIn: [huseyinaltns](https://www.linkedin.com/in/huseyinaltns/)
- X: [@huseyinaltns](https://x.com/huseyinaltns)

## License

Licensed under the [MIT](LICENSE) license.
