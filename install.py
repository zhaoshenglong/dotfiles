#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
from typing import Iterable

from rich.logging import RichHandler

from dotfiles.target import Target, TargetManager

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    handlers=[RichHandler()],
)
logger = logging.getLogger("DotFiles")


def install(
    targets: None | Iterable[str] | Iterable[Target] | str | Target,
    do_backup: bool = False,
    do_restore: bool = False,
    do_cleanup: bool = False,
):
    if not targets:
        logger.info("No targets specified, do nothing")
        return
    if isinstance(targets, str) or isinstance(targets, Target):
        targets = [Target(targets)]

    for tt in targets:
        mgr = TargetManager.create(Target(tt))
        if do_backup:
            mgr.backup()
        if do_restore:
            mgr.restore()
        if do_cleanup:
            mgr.cleanup()
        mgr.install()


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
        "-b",
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
    parser.add_argument(
        "-r",
        "--restore",
        action="store_true",
        help="Restore backup files for some targets",
    )
    parser.add_argument(
        "-c",
        "--cleanup",
        action="store_true",
        help="Cleanup the currently installed packages",
    )

    args = parser.parse_args()
    if args.verbose:
        logger.setLevel(logging.DEBUG)

    install(
        args.targets,
        do_backup=args.backup,
        do_restore=args.restore,
        do_cleanup=args.cleanup,
    )


if __name__ == "__main__":
    main()
