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

- Runs on `apt` and `pacman` based distributions, resolving package names per
  distribution — including the Debian 13 / Ubuntu 24.04 `t64` library variants
  and the `7zip` package where `p7zip-full` is no longer available
- Preflight checks — architecture, package manager, free disk space and whether
  the access port is already taken — before anything is installed
- `--check` and `--dry-run` to inspect a machine and the full plan without
  touching it, and `--uninstall` to revert the service and `/etc/hosts` changes
- Downloads and extracts Acunetix automatically, with optional SHA256
  verification before anything is executed
- Updates `/etc/hosts` to block telemetry and tracking endpoints (IPv4 + IPv6)
  in a delimited, idempotent block that can be removed again with a single flag
- Places license files with the correct permissions and immutable attributes
- Cleans up installation artifacts on exit, keeping `install.log` when the run
  failed
- Single-point version configuration (`BUILD` / `VERSION_SHORT` variables)
- Colored, readable terminal output

## Requirements

- `x86_64` with systemd
- Root privileges (`sudo`)
- A supported package manager — `apt-get` or `pacman`
- An active internet connection

Everything else (`wget`, `curl`, a 7-Zip CLI, the runtime libraries) is
installed by the script.

## Distribution support

| Distribution | Package manager | Status |
|---|---|---|
| Debian 12 / 13 | `apt` | Supported |
| Ubuntu 22.04 / 24.04 | `apt` | Supported |
| Kali Rolling | `apt` | Supported |
| Arch / Manjaro / EndeavourOS | `pacman` | Script adapted, upstream payload is not — see below |
| Anything else | — | Unsupported, the script stops at the preflight |

Package names are resolved per distribution, with the alternatives that recent
releases introduced handled automatically:

- Debian 13 dropped `p7zip-full` in favour of `7zip`; the script accepts either,
  and looks for `7zz`, `7za` or `7z` at extraction time
- Debian 13 / Ubuntu 24.04 renamed several libraries with a `t64` suffix
  (`libcups2t64`, `libasound2t64`, …); each `apt` package is retried with that
  suffix before being reported as failed
- On Arch the equivalents are used instead — `alsa-lib`, `mesa`, `atk`,
  `at-spi2-core`, `libcups`, and so on

### Arch caveat

The parts this repository owns — platform detection, dependency resolution,
`/etc/hosts`, download and verification — are adapted for Arch and behave the
same there as on Debian.

What is **not** adapted is the upstream payload. The archive published by
Pwn3rzs is packaged for Debian-based systems, and neither this project nor its
maintainer controls it. Once `install.sh` hands over to that installer, Arch is
on its own: the service account, the install paths and the systemd unit are all
created by upstream code written against a Debian layout, and things like
Debian's `adduser` simply do not exist on Arch.

So on Arch, expect the dependency and configuration stages to work and the
upstream installer stage to need manual intervention. Adapting that part is up
to you — this project will not do it for you. The script prints the same warning
before it starts.

Run the preflight before committing to a machine:

```bash
sudo ./install.sh --check
```

This prints the detected distribution, architecture, package manager and the
exact package list that would be installed, without changing anything.

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
| `-c`, `--check` | Report distribution, architecture, package manager and package list, then exit |
| `-n`, `--dry-run` | Print every step that would run, without changing anything |
| `-r`, `--restore-hosts` | Remove the script's block from `/etc/hosts` and exit |
| `-u`, `--uninstall` | Stop/disable the service and revert `/etc/hosts`, then exit |

To target a different Acunetix build, edit the `BUILD` and `VERSION_SHORT`
variables at the top of `install.sh`; every path is derived from them.

### Verifying the download

The archive is fetched from a third-party host and its contents are executed as
root, so `install.sh` will happily warn you that it has no way to tell whether
what it downloaded is what you expected. Compute the digest once from a copy you
trust and pin it:

```bash
sha256sum Acunetix-v25.1.250204093-Linux-Pwn3rzs-CyberArsenal.7z
```

Then set `ARCHIVE_SHA256` at the top of `install.sh`. On a mismatch the archive
is deleted and the run aborts before anything is extracted.

### The `/etc/hosts` block

All entries are written between two markers:

```
# >>> acunetix-installer (ByCh4n) >>>
...
# <<< acunetix-installer (ByCh4n) <<<
```

The block is rewritten from scratch on every run, so repeated executions never
duplicate entries, and `sudo ./install.sh --restore-hosts` removes it cleanly.
An untouched copy of the original file is kept at `/etc/hosts.original`.

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
