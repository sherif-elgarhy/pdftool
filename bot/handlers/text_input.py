import logging
from pathlib import Path

from telegram import Update
from telegram.ext import ContextTypes

from utils.pdf_ops import decrypt_pdf, encrypt_pdf, split_pdf
from utils.session import get_user_dir

logger = logging.getLogger(__name__)


async def text_router(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    text = update.message.text.strip()
    user_id = update.effective_user.id
    files: dict = context.user_data.get("files", {})

    # ── Password for decrypt / encrypt ───────────────────
    pending: dict | None = context.user_data.get("pending")
    if pending:
        file_id = pending["file_id"]
        mode = pending["mode"]
        context.user_data["pending"] = None  # clear state before any await

        if file_id not in files:
            await update.message.reply_text("❌ File not found. Please send the PDF again.")
            return

        file_path = Path(files[file_id])
        folder = get_user_dir(user_id)

        await update.message.reply_text("⏳ Processing…")

        if mode == "decrypt":
            out = decrypt_pdf(file_path, text, folder)
            if out:
                with open(out, "rb") as f:
                    await update.message.reply_document(f, filename=out.name)
            else:
                await update.message.reply_text(
                    "❌ Decryption failed. Wrong password or corrupted file."
                )
        else:  # encrypt
            out = encrypt_pdf(file_path, text, folder)
            if out:
                with open(out, "rb") as f:
                    await update.message.reply_document(f, filename=out.name)
            else:
                await update.message.reply_text("❌ Encryption failed.")

        logger.info("User %s ran %s on file_id %s", user_id, mode, file_id)
        return

    # ── Page range for split ──────────────────────────────
    split_id: str | None = context.user_data.get("split")
    if split_id:
        context.user_data["split"] = None

        if split_id not in files:
            await update.message.reply_text("❌ File not found. Please send the PDF again.")
            return

        file_path = Path(files[split_id])
        folder = get_user_dir(user_id)

        await update.message.reply_text("⏳ Splitting…")

        out = split_pdf(file_path, text, folder)
        if out:
            with open(out, "rb") as f:
                await update.message.reply_document(f, filename=out.name)
        else:
            await update.message.reply_text(
                "❌ Split failed. Check your page range format (e.g. `1-3,5`).",
                parse_mode="Markdown",
            )

        logger.info("User %s split file_id %s with range '%s'", user_id, split_id, text)
        return

    # ── No active state ───────────────────────────────────
    await update.message.reply_text("📄 Send a PDF file to get started.")
