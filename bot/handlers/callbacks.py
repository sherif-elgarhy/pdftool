import logging
from pathlib import Path

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InputFile
from telegram.ext import ContextTypes

from utils.pdf_ops import pdf_info, preview_first_page, merge_pdfs
from utils.session import get_user_dir

logger = logging.getLogger(__name__)


async def callback_router(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.callback_query
    await query.answer()

    try:
        action, file_id = query.data.split(":", 1)
    except ValueError:
        await query.edit_message_text("❌ Invalid action.")
        return

    user_id = query.from_user.id
    files: dict = context.user_data.get("files", {})

    # merge_finish doesn't need a specific file
    if action != "merge_finish" and file_id not in files:
        await query.edit_message_text("❌ File not found. Please send the PDF again.")
        return

    path = Path(files[file_id]) if file_id in files else None

    # ── Info ──────────────────────────────────────────────
    if action == "info":
        text = pdf_info(path)
        await query.edit_message_text(f"```\n{text}\n```", parse_mode="Markdown")

    # ── Preview ───────────────────────────────────────────
    elif action == "prev":
        folder = get_user_dir(user_id)
        img = preview_first_page(path, folder)
        if img:
            with open(img, "rb") as f:
                await query.message.reply_photo(f)
            await query.edit_message_text("🖼 Preview — page 1.")
        else:
            await query.edit_message_text("❌ Could not generate preview.")

    # ── Decrypt / Encrypt — ask for password ─────────────
    elif action in ("dec", "enc"):
        mode = "decrypt" if action == "dec" else "encrypt"
        context.user_data["pending"] = {"mode": mode, "file_id": file_id}
        verb = "decrypt" if action == "dec" else "encrypt"
        await query.edit_message_text(
            f"🔑 Send the password to *{verb}* this file.",
            parse_mode="Markdown",
        )

    # ── Merge start ───────────────────────────────────────
    elif action == "merge_start":
        context.user_data["merge_mode"] = True
        context.user_data["merge_list"] = [file_id]   # ← lives in user_data, not global
        await query.edit_message_text(
            "📎 *Merge Mode*\n"
            "Send more PDFs one by one, then tap *Finish Merge*.",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("✔ Finish Merge", callback_data="merge_finish:OK")]
            ]),
        )

    # ── Merge finish ──────────────────────────────────────
    elif action == "merge_finish":
        file_ids: list = context.user_data.get("merge_list", [])
        context.user_data["merge_mode"] = False
        context.user_data["merge_list"] = []

        if len(file_ids) < 2:
            await query.edit_message_text("❌ Need at least 2 PDFs to merge.")
            return

        paths = [Path(files[fid]) for fid in file_ids if fid in files]
        folder = get_user_dir(user_id)
        out = merge_pdfs(paths, folder)

        if out:
            with open(out, "rb") as f:
                await query.message.reply_document(f, filename="merged.pdf")
            await query.edit_message_text(f"✅ Merged {len(paths)} PDFs.")
        else:
            await query.edit_message_text("❌ Merge failed.")

    # ── Split — ask for page range ────────────────────────
    elif action == "split":
        context.user_data["split"] = file_id
        await query.edit_message_text(
            "✂️ *Split PDF*\n\n"
            "Send the page range to extract:\n"
            "• `1-3` → pages 1 to 3\n"
            "• `5` → page 5 only\n"
            "• `1,3,7` → pages 1, 3 and 7\n"
            "• `2-4,6,9` → mixed ranges",
            parse_mode="Markdown",
        )

    else:
        await query.edit_message_text("❌ Unknown action.")
        logger.warning("Unknown callback action: %s from user %s", action, user_id)
