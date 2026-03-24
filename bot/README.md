# 📄 PDF Toolbox Bot

A Telegram bot for PDF operations — decrypt, encrypt, merge, split, preview.  
Processing happens on your own server using `qpdf`. Files are transmitted via Telegram but never sent to any third-party PDF service.

---

## Features

| | |
|---|---|
| 🔓 Decrypt | Remove password from a protected PDF |
| 🔐 Encrypt | Add AES-256 password protection |
| 📎 Merge | Combine multiple PDFs into one |
| ✂️ Split | Extract a page range |
| 🔍 Info | Show encryption status and structure |
| 🖼 Preview | Send page 1 as an image |

---

## Setup

### 1. System dependencies
```bash
# Debian/Ubuntu
sudo apt install qpdf poppler-utils

# Termux
pkg install qpdf poppler
```

### 2. Python dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure
```bash
cp .env.example .env
# Edit .env and set your TELEGRAM_TOKEN
```

Get a token from [@BotFather](https://t.me/BotFather) on Telegram.

### 4. Run
```bash
python bot.py
```

---

## Project structure

```
pdftool_bot/
├── bot.py                  # Entry point — registers handlers, starts polling
├── config.py               # Reads settings from .env
├── .env.example            # Config template (copy to .env)
├── requirements.txt
├── handlers/
│   ├── commands.py         # /start, /help
│   ├── pdf_upload.py       # Incoming PDF handler + keyboard builder
│   ├── callbacks.py        # Inline button router
│   └── text_input.py       # Password + page range input
└── utils/
    ├── pdf_ops.py          # qpdf wrappers (decrypt, encrypt, merge, split, preview)
    ├── file_ops.py         # File save + collision-safe naming
    ├── session.py          # Per-user session folder
    └── cleanup.py          # Periodic old-session cleanup
```

---

## Notes

- Session files are stored under `sessions/<user_id>/` and cleaned up automatically after 48 hours (configurable)
- The bot token must **never** be committed to git — keep it in `.env` only
- Requires `qpdf` and `pdftoppm` (from `poppler-utils`) on the host system
