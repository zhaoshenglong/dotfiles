import logging
from abc import ABC, abstractmethod
from enum import StrEnum

from dotfiles import file, var

logger = logging.getLogger("TargetManager")


class Target(StrEnum):
    NeoVim = "neovim"
    Tmux = "tmux"
    Bash = "bash"


class TargetManager(ABC):
    @classmethod
    def create(cls, tt: Target) -> "TargetManager":
        match tt:
            case Target.NeoVim:
                return NeovimManager()
            case Target.Tmux:
                return TmuxManager()
            case Target.Bash:
                return BashManager()
            case _:
                raise ValueError(f"Unknown target {tt}")

    @abstractmethod
    def backup(self):
        raise NotImplementedError("backup is not implemented")

    @abstractmethod
    def cleanup(self):
        raise NotImplementedError("cleanup is not implemented")

    @abstractmethod
    def restore(self):
        raise NotImplementedError("restore is not implemented")

    @abstractmethod
    def install(self):
        raise NotImplementedError("install is not implemented")


class NeovimManager(TargetManager):
    def __init__(self) -> None:
        super().__init__()

    def backup(self):
        file.backup(var.NeoVimConfigPath)
        file.backup(var.NeoVimDataPath)
        file.backup(var.NeoVimStatePath)

    def cleanup(self):
        file.remove(var.NeoVimConfigPath, recursive=True)
        file.remove(var.NeoVimDataPath, recursive=True)
        file.remove(var.NeoVimStatePath, recursive=True)

    def restore(self):
        pass

    def install(self):
        logger.info(f"Copying files from {var.NeoVimFiles} to {var.NeoVimConfigPath}")
        file.copy(
            var.NeoVimFiles, var.NeoVimConfigPath, recursive=True, exclusive=False
        )
        logger.info("Installing Neovim completed!")


class TmuxManager(TargetManager):
    def __init__(self) -> None:
        super().__init__()

    def backup(self):
        file.backup(var.TmuxConfigPath)

    def cleanup(self):
        file.remove(var.TmuxConfigPath, recursive=True)

    def restore(self):
        pass

    def install(self):
        logger.info(f"Copying files from {var.TmuxFiles} to {var.TmuxConfigPath}")
        file.copy(var.TmuxFiles, var.TmuxConfigPath, recursive=True, exclusive=False)
        logger.info("Installing Tmux completed!")


class BashManager(TargetManager):
    def __init__(self) -> None:
        super().__init__()

    def backup(self):
        file.backup(var.BashScriptPath)
        file.backup(var.StarshipPath)

    def cleanup(self):
        file.remove(var.BashScriptPath)
        file.remove(var.StarshipPath)

    def restore(self):
        pass

    def install(self):
        logger.info(f"Copying files from {var.BashFiles} to {var.BashScriptPath}")
        file.copy(var.BashFiles, var.BashScriptPath)
        file.copy(var.StarshipFiles, var.StarshipPath)
        logger.info("Installing Bash completed!")
