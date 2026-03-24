import logging
import time
from pathlib import Path

from config import CLEANUP_HOURS, SESSION_DIR

logger = logging.getLogger(__name__)


def cleanup_old_sessions(context=None) -> None:
    """Delete session folders older than CLEANUP_HOURS.
    Accepts an optional context argument so it can be used
    directly as a telegram job_queue callback.
    """
    base = Path(SESSION_DIR)
    if not base.exists():
        return

    now = time.time()
    expire_sec = CLEANUP_HOURS * 3600
    removed = 0

    for folder in base.iterdir():
        if not folder.is_dir():
            continue
        if now - folder.stat().st_mtime > expire_sec:
            for f in folder.glob("*"):
                try:
                    f.unlink()
                except Exception as e:
                    logger.warning("Could not delete %s: %s", f, e)
            try:
                folder.rmdir()
                removed += 1
            except Exception as e:
                logger.warning("Could not remove folder %s: %s", folder, e)

    if removed:
        logger.info("Cleanup: removed %d expired session(s).", removed)
