import logging
import subprocess
from pathlib import Path
from uuid import uuid4

from config import PREVIEW_DPI
from utils.file_ops import safe_output_path

logger = logging.getLogger(__name__)

TG_MAX_CHARS = 4000  # Telegram message limit is 4096, leave headroom


def run_cmd(cmd: list[str]) -> tuple[bool, str]:
    """Run a subprocess command. Returns (success, output).
    Logs stderr on failure so errors are visible in bot logs.
    """
    try:
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode != 0:
            logger.warning("Command failed: %s\nSTDERR: %s", " ".join(cmd), p.stderr.strip())
        return p.returncode == 0, p.stdout + p.stderr
    except Exception as e:
        logger.error("Command exception: %s — %s", " ".join(cmd), e)
        return False, str(e)


def pdf_info(path: Path) -> str:
    _, check  = run_cmd(["qpdf", "--check", str(path)])
    _, enc    = run_cmd(["qpdf", "--show-encryption", str(path)])
    _, linear = run_cmd(["qpdf", "--check-linearization", str(path)])

    result = (
        "── QPDF Check ──\n" + (check or "N/A") +
        "\n── Encryption ──\n" + (enc or "N/A") +
        "\n── Linearization ──\n" + (linear or "N/A")
    )
    # Guard against Telegram's message length limit
    if len(result) > TG_MAX_CHARS:
        result = result[:TG_MAX_CHARS] + "\n… (truncated)"
    return result


def decrypt_pdf(path: Path, pwd: str, folder: Path) -> Path | None:
    out = safe_output_path(folder, path.stem + "_dec", ".pdf")
    ok, _ = run_cmd(["qpdf", f"--password={pwd}", "--decrypt", str(path), str(out)])
    return out if ok else None


def encrypt_pdf(path: Path, pwd: str, folder: Path) -> Path | None:
    out = safe_output_path(folder, path.stem + "_enc", ".pdf")
    ok, _ = run_cmd(["qpdf", "--encrypt", pwd, pwd, "256", "--", str(path), str(out)])
    return out if ok else None


def merge_pdfs(paths: list[Path], folder: Path) -> Path | None:
    out = safe_output_path(folder, "merged_" + uuid4().hex, ".pdf")
    ok, _ = run_cmd(["qpdf", "--empty", "--pages", *map(str, paths), "--", str(out)])
    return out if ok else None


def split_pdf(path: Path, ranges: str, folder: Path) -> Path | None:
    out = safe_output_path(folder, path.stem + "_split", ".pdf")
    ok, _ = run_cmd(["qpdf", str(path), "--pages", str(path), ranges, "--", str(out)])
    return out if ok else None


def preview_first_page(path: Path, folder: Path) -> Path | None:
    prefix = folder / f"preview_{uuid4().hex}"
    ok, _ = run_cmd([
        "pdftoppm", "-png", "-r", str(PREVIEW_DPI),
        "-f", "1", "-l", "1",
        str(path), str(prefix),
    ])
    out = Path(str(prefix) + "-1.png")
    return out if out.exists() else None
