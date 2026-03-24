import logging

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from utils.file_ops import save_file
from utils.session import get_user_dir

logger = logging.getLogger(__name__)


def build_main_keyboard(file_id: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🔓 Decrypt",  callback_data=f"dec:{file_id}")],
        [InlineKeyboardButton("🔐 Encrypt",  callback_data=f"enc:{file_id}")],
        [InlineKeyboardButton("📎 Merge",    callback_data=f"merge_start:{file_id}")],
        [InlineKeyboardButton("✂️ Split",    callback_data=f"split:{file_id}")],
        [InlineKeyboardButton("🔍 Info",     callback_data=f"info:{file_id}")],
        [InlineKeyboardButton("🖼 Preview",  callback_data=f"prev:{file_id}")],
    ])


async def handle_pdf(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    doc = update.message.document
    if not doc or not doc.file_name.lower().endswith(".pdf"):
        await update.message.reply_text("❌ Please send a PDF file.")
        return

    user_id = update.effective_user.id
    tg_file = await doc.get_file()
    raw = await tg_file.download_as_bytearray()

    folder = get_user_dir(user_id)
    full_path = save_file(folder, doc.file_name, bytes(raw))

    files: dict = context.user_data.setdefault("files", {})
    file_id = str(len(files) + 1)
    files[file_id] = str(full_path)

    # If user is in merge mode, just queue the file
    if context.user_data.get("merge_mode"):
        merge_list: list = context.user_data.setdefault("merge_list", [])
        merge_list.append(file_id)
        count = len(merge_list)
        await update.message.reply_text(
            f"📄 Added to merge queue ({count} file{'s' if count > 1 else ''}).",
        )
        return

    await update.message.reply_text(
        f"📁 *{doc.file_name}* saved.\nChoose an action:",
        reply_markup=build_main_keyboard(file_id),
        parse_mode="Markdown",
    )
    logger.info("User %s uploaded: %s", user_id, doc.file_name)
