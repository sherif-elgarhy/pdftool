#!/usr/bin/env python3
"""
PDF Toolbox Bot — entry point.
All logic lives in handlers/ and utils/.
"""

import logging

from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters,
)

from config import TELEGRAM_TOKEN, CLEANUP_HOURS
from handlers.commands import start, help_cmd
from handlers.pdf_upload import handle_pdf
from handlers.callbacks import callback_router
from handlers.text_input import text_router
from utils.cleanup import cleanup_old_sessions

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger("pdfbot")


def main() -> None:
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()

    # ── Commands ──────────────────────────────────────────
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help",  help_cmd))

    # ── PDF upload ────────────────────────────────────────
    app.add_handler(MessageHandler(filters.Document.PDF, handle_pdf))

    # ── Inline keyboard callbacks ─────────────────────────
    app.add_handler(CallbackQueryHandler(callback_router))

    # ── Text messages (passwords, page ranges) ────────────
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, text_router))

    # ── Scheduled cleanup (every hour) ───────────────────
    # Runs immediately on startup, then repeats every CLEANUP_HOURS
    job_queue = app.job_queue
    job_queue.run_once(cleanup_old_sessions, when=0)
    job_queue.run_repeating(
        cleanup_old_sessions,
        interval=CLEANUP_HOURS * 3600,
        first=CLEANUP_HOURS * 3600,
    )

    logger.info("PDF Toolbox Bot is running…")
    app.run_polling()


if __name__ == "__main__":
    main()
