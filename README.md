# CLI Agent Hook

A bootstrapper for CLI-based agentic code development environments. Automatically sets up development tools, configurations, and hooks for optimal AI-assisted coding workflows.

## Features

- **Dotfiles Management**: Automated symlink creation and configuration deployment
- **Development Environment Setup**: Fish shell, Neovim, Tmux, and productivity tools
- **AI Integration**: Pre-configured settings for Claude and other AI development tools
- **Extensible Architecture**: Plugin-based system for custom configurations

## Quick Start

```bash
# Clone and install
git clone https://github.com/jayleekr/cli-agent-hook.git
cd cli-agent-hook
./install.sh

# Or run directly
curl -fsSL https://raw.githubusercontent.com/jayleekr/cli-agent-hook/main/install.sh | bash
```

## What Gets Installed

- **Shell Environment**: Fish shell with developer-friendly aliases and functions
- **Editor**: Neovim with NvChad configuration and AI plugins
- **Terminal**: Tmux with optimized keybindings and workflow
- **Window Management**: Aerospace tiling window manager (macOS)
- **Status Bar**: SketchyBar with system monitoring (macOS)
- **Git Workflow**: Pre-configured git aliases and hooks

## Configuration

The bootstrapper automatically creates symlinks from your dotfiles to their expected locations:

```
~/.config/fish/       -> config/fish/
~/.config/nvim/       -> config/nvim/
~/.config/sketchybar/ -> config/sketchybar/
~/.tmux.conf          -> tmux.conf
~/.aerospace.toml     -> aerospace.toml
```

## Usage

```bash
# Install all configurations
cli-agent-hook install

# Install specific components
cli-agent-hook install --fish --nvim --tmux

# Update existing configurations
cli-agent-hook update

# Backup current configurations
cli-agent-hook backup

# Restore from backup
cli-agent-hook restore
```