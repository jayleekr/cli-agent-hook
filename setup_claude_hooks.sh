#!/bin/bash

# Setup Claude hooks symlink
DOTFILES_DIR="/Users/jaylee/CodeWorkspace/cli-agent-hook"

# Remove existing .claude directory if it exists
if [[ -L "$HOME/.claude" ]]; then
    rm "$HOME/.claude"
elif [[ -d "$HOME/.claude" ]]; then
    mv "$HOME/.claude" "$HOME/.claude.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create symlink
ln -sf "$DOTFILES_DIR/.claude" "$HOME/.claude"

# Make scripts executable
chmod +x "$HOME/.claude/hooks"/*.py

# Install uv if not present
if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi

echo "Claude hooks setup complete!"
echo "Hook files location: $HOME/.claude"
echo "Python scripts should now be executable via: uv run ~/.claude/hooks/<script>.py"