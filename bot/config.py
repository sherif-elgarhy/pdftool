import os
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_TOKEN: str = os.environ.get("TELEGRAM_TOKEN", "")
if not TELEGRAM_TOKEN:
    raise RuntimeError("TELEGRAM_TOKEN is not set. Add it to your .env file.")

SESSION_DIR: str  = os.environ.get("SESSION_DIR", "sessions")
PREVIEW_DPI: int  = int(os.environ.get("PREVIEW_DPI", "150"))
CLEANUP_HOURS: int = int(os.environ.get("CLEANUP_HOURS", "48"))
