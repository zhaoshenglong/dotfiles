import logging
import os
import shutil
import time
from dataclasses import dataclass
from os import path
from pathlib import Path
from typing import Iterable

logger = logging.getLogger("DotFiles")


@dataclass
class FileState:
    neovim: Iterable[str]
    tmux: Iterable[str]
    bash: Iterable[str]

    def __init__(self) -> None:
        pass

    @classmethod
    def open(cls, mode="r"):
        pass

    def __enter__(self):
        pass

    def __exit__(self, exc_type, exc_value, traceback):
        return False


def copy(src: os.PathLike, dst: os.PathLike, recursive=False, exclusive=True):
    logger.debug(
        f"Copying {src} to {dst}, recursive={recursive}, exclusive={exclusive}"
    )
    return shutil.copytree(src, dst, dirs_exist_ok=not exclusive)


def move(src: os.PathLike, dst: os.PathLike):
    logger.debug(f"Moving {src} to {dst}")
    shutil.move(src, dst)


def remove(dst: os.PathLike, recursive=False):
    logger.debug(f"Removing file {dst}, recursive={recursive}")
    if not recursive:
        os.remove(dst)
    else:
        shutil.rmtree(dst)


def backup(target_path: os.PathLike) -> Path | None:
    parent_path = Path(target_path).parent
    last_component = Path(target_path).name
    backup_path = Path(path.join(parent_path, f"{last_component}.bak.{time.time()}"))
    logger.debug(f"Backing up {target_path} to {backup_path}")
    try:
        move(target_path, backup_path)
        return backup_path
    except FileNotFoundError:
        return None


def restore():
    pass
