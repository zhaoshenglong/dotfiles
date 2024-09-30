#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
from enum import StrEnum
from typing import Iterable

from rich.logging import RichHandler

from dotfiles import file, var

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    handlers=[RichHandler()],
)
logger = logging.getLogger("DotFiles")


class Target(StrEnum):
    NeoVim = "neovim"
    Tmux = "tmux"
    Bash = "bash"


def install(
    targets: None | Iterable[str] | Iterable[Target] | str | Target,
    do_backup: bool = True,
):
    if not targets:
        logger.info("No targets specified, do nothing")
        return
    if isinstance(targets, Iterable) and not isinstance(targets, str):
        for target in targets:
            install(target, do_backup=do_backup)
        return
    match Target(targets):
        case Target.NeoVim:
            install_neovim(do_backup=do_backup)
        case Target.Tmux:
            install_tmux(do_backup=do_backup)
        case Target.Bash:
            install_bash(do_backup=do_backup)


def back_neovim():
    file.backup(var.NeoVimConfigPath)
    file.backup(var.NeoVimDataPath)
    file.backup(var.NeoVimStatePath)


def install_neovim(do_backup: bool = True):
    if do_backup:
        back_neovim()
    logger.info(f"Copying files from {var.NeoVimFiles} to {var.NeoVimConfigPath}")
    file.copy(var.NeoVimFiles, var.NeoVimConfigPath, recursive=True, exclusive=False)
    logger.info(f"Installing Neovim completed!")


def install_tmux(do_backup: bool = True):
    raise NotImplementedError("installing tmux is not implemented")


def install_bash(do_backup: bool = True):
    raise NotImplementedError("installing bash is not implemented")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--targets",
        "-t",
        choices=list(Target),
        action="extend",
        nargs="+",
        type=Target,
        help=(
            f"The targets to install, separated with space. "
            f"Valid values are {[e.value for e in Target]}, "
            f"E.g. --targets tmux neovim [...]"
        ),
    )
    parser.add_argument(
        "--backup",
        action="store_true",
        help=(
            "Whether to do backup during installation, "
            "if set to False, the script will not do back up when installing, "
            "else, the script will move the original files somewhere"
        ),
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help=(
            "If this flag is set, the logging level will be set to DEBUG. "
            "The default logging level is INFO"
        ),
    )

    args = parser.parse_args()
    if args.verbose:
        logger.setLevel(logging.DEBUG)

    install(args.targets, do_backup=args.backup)


if __name__ == "__main__":
    main()
