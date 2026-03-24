from telegram import Update
from telegram.ext import ContextTypes


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "📄 *PDF Toolbox Bot*\n"
        "Send me any PDF to get started.\n\n"
        "I can decrypt, encrypt, merge, split, preview, and inspect PDFs — "
        "all on your device, nothing uploaded anywhere.",
        parse_mode="Markdown",
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "🛠 *PDF Toolbox — Commands*\n\n"
        "Just send a PDF and choose what to do:\n"
        "• 🔓 *Decrypt* — remove password\n"
        "• 🔐 *Encrypt* — add AES-256 password\n"
        "• 📎 *Merge* — combine multiple PDFs\n"
        "• ✂️ *Split* — extract page range\n"
        "• 🔍 *Info* — show encryption and structure\n"
        "• 🖼 *Preview* — see page 1 as image\n\n"
        "For merge: tap Merge on the first PDF, then send the rest, then tap Finish.",
        parse_mode="Markdown",
    )
