from pathlib import Path
from config import SESSION_DIR


def get_user_dir(uid: int) -> Path:
    folder = Path(SESSION_DIR) / str(uid)
    folder.mkdir(parents=True, exist_ok=True)
    return folder
