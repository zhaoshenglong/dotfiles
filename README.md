# Dotfiles

A collection of my dotfiles.
They present here due to version control.

## Installation
The install script relies on Python-3.11's features. (I will make it compatible with Python-3.9 on next release, but not for now)

**Install Python-3.11**
```sh
conda create python311 python=3.11.2
conda activate python311
```

**Install dotfiles**
```sh
python3 install.py -t nvim -v
```
To see more options
```sh
python3 install.py -h
```

## Testing
No test scripts provided for now


## Packaging
Considering make it a python package, so that I can install packages via `dotfiles install/uninstall ...`
