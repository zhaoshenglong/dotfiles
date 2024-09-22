import os
from os import path
from pathlib import Path

HOME = path.expanduser("~")
ROOT = Path(__file__).parent.parent

XDG_CONFIG_DIR = f"{HOME}/.config"
XDG_DATA_DIR = f"{HOME}/.local/share"
XDG_STATE_DIR = f"{HOME}/.local/state"

# NeoVim
NeoVimConfigPath = path.join(XDG_CONFIG_DIR, "nvim")
NeoVimDataPath = path.join(XDG_DATA_DIR, "nvim")
NeoVimStatePath = path.join(XDG_STATE_DIR, "nvim")
NeoVimFiles = path.join(ROOT, "nvim")
