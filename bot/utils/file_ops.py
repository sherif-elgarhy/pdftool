from pathlib import Path


def save_file(folder: Path, name: str, data: bytes) -> Path:
    path = folder / name
    path.write_bytes(data)
    return path


def safe_output_path(folder: Path, base_name: str, suffix: str) -> Path:
    out = folder / f"{base_name}{suffix}"
    i = 1
    while out.exists():
        out = folder / f"{base_name}_{i}{suffix}"
        i += 1
    return out
