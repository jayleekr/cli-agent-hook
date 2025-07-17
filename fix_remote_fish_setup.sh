#!/bin/bash

echo "=== Remote Fish Shell Setup Fix ==="
echo "This script fixes Fish shell setup issues in remote SSH environments"

# Check if running in SSH session
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    echo "[INFO] SSH session detected - applying remote-friendly configuration"
    REMOTE_SESSION=true
else
    echo "[INFO] Local session detected"
    REMOTE_SESSION=false
fi

# Backup existing .bashrc
if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
    echo "[INFO] Created backup: ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Check if Fish is available
FISH_PATH=$(which fish)
if [ -z "$FISH_PATH" ]; then
    echo "[ERROR] Fish shell not found. Please install fish first."
    exit 1
fi

echo "[INFO] Fish shell found at: $FISH_PATH"

# Add Fish auto-start to .bashrc (only for interactive sessions)
cat >> ~/.bashrc << 'EOF'

# CLI Agent Hook: Auto-start Fish shell in interactive sessions
if [[ $- == *i* ]] && [[ -x "$(command -v fish)" ]] && [[ "$TERM" != "dumb" ]]; then
    # Check if we're not already in fish and not in tmux
    if [[ "$(basename "$SHELL")" != "fish" ]] && [[ -z "$TMUX" ]]; then
        echo "Starting Fish shell..."
        exec fish
    fi
fi
EOF

echo "[SUCCESS] Added Fish auto-start to ~/.bashrc"

# Verify Fish configuration
if [ -d ~/.config/fish ]; then
    echo "[INFO] Fish configuration found at ~/.config/fish"
    
    # Test Fish configuration
    if fish -c "echo 'Fish configuration test: OK'" 2>/dev/null; then
        echo "[SUCCESS] Fish configuration is valid"
    else
        echo "[WARNING] Fish configuration may have issues"
    fi
else
    echo "[WARNING] Fish configuration directory not found"
fi

# CLI Agent Hook integration
if [ -f ~/.cli-agent-hook/bin/cli-agent-hook ]; then
    echo "[INFO] CLI Agent Hook found"
    
    # Make sure it's executable
    chmod +x ~/.cli-agent-hook/bin/cli-agent-hook
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q ~/.cli-agent-hook/bin; then
        echo 'export PATH="$HOME/.cli-agent-hook/bin:$PATH"' >> ~/.bashrc
        echo "[SUCCESS] Added CLI Agent Hook to PATH"
    fi
else
    echo "[WARNING] CLI Agent Hook binary not found"
fi

echo ""
echo "=== Setup Complete ==="
echo "To apply changes:"
echo "1. Close and reopen your SSH session, OR"
echo "2. Run: source ~/.bashrc"
echo "3. Fish shell will start automatically in new interactive sessions"
echo ""
echo "Manual Fish start: just type 'fish' and press Enter"
echo "To disable auto-start, edit ~/.bashrc and remove the Fish auto-start section" 