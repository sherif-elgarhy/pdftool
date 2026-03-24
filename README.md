# 📄 pdftool

A terminal PDF toolbox for people who just want to handle their PDFs — no ads, no uploads, no accounts.
Works on **Termux (Android)**, Linux, and macOS.

---

## Why this exists

Every PDF tool online either costs money, drowns you in ads, or uploads your file to a server.
Bank statements, payslips, and official reports shouldn't be sent to a random website just to remove a password.
This script runs entirely on your device using `qpdf` — nothing leaves your phone.

---

## Features

| | |
|---|---|
| 🔓 Decrypt PDF | Remove password from a protected file |
| 🔐 Encrypt PDF | Add AES-256 password protection |
| 🔄 Batch decrypt | Unlock multiple PDFs at once |
| 🔄 Batch encrypt | Lock multiple PDFs at once |
| 📎 Merge PDFs | Combine multiple PDFs into one |
| ✂️ Split PDF | Extract a page range into a new file |
| 🧾 PDF Info | Show encryption status, structure, linearization |
| 👁️ View in terminal | Render pages with `chafa` or read text with `pdftotext` |

---

## Install

### Termux (Android) — recommended

```bash
# 1. Allow storage access (first time only)
termux-setup-storage

# 2. Download the script
curl -sL https://raw.githubusercontent.com/sherif-elgarhy/pdftool/main/pdftool.sh -o ~/pdftool.sh
chmod +x ~/pdftool.sh

# 3. Run it — dependencies will be offered automatically
~/pdftool.sh
```

> **Optional:** Install `chafa` for visual page rendering in terminal:
> ```bash
> pkg install chafa
> ```

---

### Linux (Debian/Ubuntu)

```bash
curl -sL https://raw.githubusercontent.com/sherif-elgarhy/pdftool/main/pdftool.sh -o ~/pdftool.sh
chmod +x ~/pdftool.sh
~/pdftool.sh
# Script will offer: sudo apt install qpdf nnn
```

---

### macOS

```bash
curl -sL https://raw.githubusercontent.com/sherif-elgarhy/pdftool/main/pdftool.sh -o ~/pdftool.sh
chmod +x ~/pdftool.sh
~/pdftool.sh
# Script will offer: brew install qpdf nnn
```

---

## Usage

### Interactive menu (recommended)
```bash
./pdftool.sh
```
Launches a menu. Use `nnn` file picker to select PDFs — arrow keys to navigate, Space to select, Q to quit.

### Command line (quick use)
```bash
# Decrypt a PDF
./pdftool.sh -d /path/to/file.pdf

# Decrypt with password inline
./pdftool.sh -d -p mypassword /path/to/file.pdf

# Encrypt a PDF
./pdftool.sh -e /path/to/file.pdf
```

---

## Dependencies

| Tool | Purpose | Required |
|------|---------|----------|
| [`qpdf`](https://qpdf.sourceforge.io/) | All PDF operations | ✅ Yes |
| [`nnn`](https://github.com/jarun/nnn) | File picker in terminal | ✅ Yes |
| [`chafa`](https://hpjansson.org/chafa/) | Visual page preview | Optional |
| `pdftotext` (poppler) | Text view fallback | Optional |

> The script detects your platform on first run and will prompt you to install anything missing.

---

## Output files

The script never overwrites your original. Output files are named automatically:

| Operation | Output name |
|-----------|------------|
| Decrypt | `filename_decrypted.pdf` |
| Encrypt | `filename_locked.pdf` |
| Split | `filename_split.pdf` |
| Merge | `merged.pdf` (you choose the name) |

If a file already exists, it appends `_1`, `_2`, etc.

---

## Roadmap

- [x] Bash CLI tool
- [x] Termux support with auto-install
- [x] Linux & macOS auto-install
- [x] Telegram bot version
- [ ] Android app (Flutter)

---

## License

MIT — free to use, share, and modify.

