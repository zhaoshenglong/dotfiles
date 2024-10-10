from os import path
from pathlib import Path

HOME = path.expanduser("~")
ROOT = Path(__file__).parent.parent

XDG_CONFIG_DIR = Path(path.join(HOME, ".config"))
XDG_DATA_DIR = Path(path.join(HOME, ".local/share"))
XDG_STATE_DIR = Path(path.join(HOME, ".local/state"))

# NeoVim
NeoVimConfigPath = Path(path.join(XDG_CONFIG_DIR, "nvim"))
NeoVimDataPath = Path(path.join(XDG_DATA_DIR, "nvim"))
NeoVimStatePath = Path(path.join(XDG_STATE_DIR, "nvim"))
NeoVimFiles = Path(path.join(ROOT, "nvim"))


# Tmux
TmuxConfigPath = Path(path.join(XDG_CONFIG_DIR, "tmux"))
TmuxFiles = Path(path.join(ROOT, "tmux"))

# Bash
BashScriptPath = Path(path.join(HOME, ".bashrc"))
BashFiles = Path(path.join(ROOT, "bash", "bashrc"))
BlercFiles = Path(path.join(ROOT, "bash", "blerc"))
StarshipPath = Path(path.join(XDG_CONFIG_DIR, "starship.toml"))
BlercPath = Path(path.join(XDG_DATA_DIR, "blesh", "blerc"))
StarshipFiles = Path(path.join(ROOT, "bash", "starship.toml"))
