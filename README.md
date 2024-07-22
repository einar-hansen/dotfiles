# macOS Development Environment Setup

## Introduction

This repository contains my personal dotfiles and scripts for setting up a macOS development environment. It automates the process of installing necessary tools, configuring the shell, and setting up common development applications. Feel free to explore, learn, and adapt these dotfiles for your own use.

## Contents

- `.aliases`: Custom shell aliases for various tools and commands
- `.zshrc`: Zsh configuration file
- `Brewfile`: List of applications and tools to be installed via Homebrew
- `install.sh`: Main installation script
- `phpstorm.sh`: Script to open PhpStorm from the command line

## Setting up your Mac

Follow these steps to set up your development environment:

1. Ensure your macOS is up-to-date
2. Clone this repository to your home directory:
   ```zsh
   git clone https://github.com/einar-hansen/dotfiles.git ~/.dotfiles
   ```
3. Run the installation script:
   ```zsh
   cd ~/.dotfiles
   ./install.sh
   ```
4. Restart your computer to finalize the process

The installation script will:
- Install Homebrew (if not already installed)
- Install all dependencies listed in the Brewfile
- Install global Composer packages
- Create a `Sites` directory in your home folder
- Set up symlinks for configuration files

## Features

### Aliases

The `.aliases` file includes shortcuts for:
- Git operations
- Docker Compose commands
- Terraform commands
- PHP and JS development
- Directory navigation
- Hashing operations
- And more...

### Zsh Configuration

The `.zshrc` file sets up:
- Oh My Zsh with the "robbyrussell" theme
- Custom plugin loading (git)
- Path exports
- Additional aliases and functions

### Installed Software

The `Brewfile` includes:
- Command-line tools: git, ffmpeg, fzf, jq, etc.
- Applications: GitHub, PhpStorm, Slack, TablePlus, VLC, etc.
- Fonts: Lato, Roboto, Source Code Pro, etc.
- Mac App Store apps: Keynote, The Unarchiver

## Customization

Feel free to modify any of the configuration files to suit your needs:

- Add new aliases to `.aliases`
- Customize Zsh settings in `.zshrc`
- Add or remove software in the `Brewfile`

## PhpStorm

The `phpstorm.sh` script allows you to open PhpStorm from the command line. You may need to add it to your PATH or create a symlink in a directory that's already in your PATH.

## Contributing

If you have suggestions for improvements or bug fixes, please open an issue or submit a pull request.

## License

This project is open-source and available under the [MIT License](LICENSE).

## Acknowledgements

This project was inspired by [Dries Vints](https://github.com/driesvints/dotfiles) dotfiles projects and the macOS development community.