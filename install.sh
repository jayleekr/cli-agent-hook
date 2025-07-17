#!/bin/bash

# CLI Agent Hook Installer
# Bootstrapper for AI-assisted development environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/jayleekr/cli-agent-hook.git"
INSTALL_DIR="$HOME/.cli-agent-hook"
DOTFILES_DIR="$INSTALL_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create backup of existing file/directory
backup_existing() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup_name="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing $target to $backup_name"
        mv "$target" "$backup_name"
    elif [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    fi
}

# Create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    
    if [[ ! -e "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # Backup existing file/directory
    backup_existing "$target"
    
    # Create symlink
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Install Homebrew if on macOS and not installed
install_homebrew() {
    if [[ "$OSTYPE" == "darwin"* ]] && ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

# Install essential packages
install_packages() {
    log_info "Installing essential packages..."
    
    if [[ "$OSTYPE" == "darwin"* ]] && command_exists brew; then
        # macOS packages
        local packages=(
            "fish"
            "neovim"
            "tmux"
            "starship"
            "zoxide"
            "git"
            "curl"
            "wget"
            "jq"
            "ripgrep"
            "fd"
            "bat"
            "fzf"
        )
        
        local tap_packages=(
            "nikitabobko/tap/aerospace"
            "felixkratz/formulae/sketchybar"
        )
        
        for package in "${packages[@]}"; do
            if ! brew list "$package" >/dev/null 2>&1; then
                log_info "Installing $package..."
                brew install "$package"
            else
                log_info "$package is already installed"
            fi
        done
        
        # Tap for aerospace and sketchybar
        if ! brew tap | grep -q "nikitabobko/tap"; then
            log_info "Adding aerospace tap..."
            brew tap nikitabobko/tap
        fi
        
        if ! brew tap | grep -q "felixkratz/formulae"; then
            log_info "Adding sketchybar tap..."
            brew tap felixkratz/formulae
        fi
        
        # Install tap packages
        for package in "${tap_packages[@]}"; do
            local package_name
            package_name=$(basename "$package")
            if ! brew list "$package_name" >/dev/null 2>&1; then
                log_info "Installing $package_name..."
                brew install "$package"
            else
                log_info "$package_name is already installed"
            fi
        done
        
    elif command_exists apt-get; then
        # Ubuntu/Debian packages
        sudo apt-get update
        sudo apt-get install -y fish neovim tmux git curl wget jq ripgrep fd-find bat fzf
        
    elif command_exists pacman; then
        # Arch Linux packages
        sudo pacman -S --needed fish neovim tmux git curl wget jq ripgrep fd bat fzf
        
    else
        log_warning "Package manager not detected. Please install packages manually."
    fi
}

# Clone or update repository
setup_repository() {
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        # Stash any local changes before pulling
        git stash push -m "Auto-stash before update" 2>/dev/null || true
        git pull origin main || {
            log_warning "Git pull failed, continuing with existing installation"
            # Try to pop stash if it exists
            git stash pop 2>/dev/null || true
        }
        # Restore stashed changes
        git stash pop 2>/dev/null || true
    else
        log_info "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
}

# Setup dotfiles symlinks
setup_dotfiles() {
    log_info "Setting up dotfiles..."
    
    # Fish shell configuration
    create_symlink "$DOTFILES_DIR/config/fish" "$HOME/.config/fish"
    
    # Neovim configuration
    create_symlink "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
    
    # Tmux configuration
    create_symlink "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"
    
    # macOS specific configurations
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Aerospace window manager
        create_symlink "$DOTFILES_DIR/aerospace.toml" "$HOME/.aerospace.toml"
        create_symlink "$DOTFILES_DIR/config/aerospace" "$HOME/.config/aerospace"
        
        # SketchyBar
        create_symlink "$DOTFILES_DIR/config/sketchybar" "$HOME/.config/sketchybar"
        
        # Karabiner Elements
        create_symlink "$DOTFILES_DIR/config/karabiner" "$HOME/.config/karabiner"
    fi
    
    # Claude CLI hooks and settings
    if [[ -d "$DOTFILES_DIR/.claude" ]]; then
        create_symlink "$DOTFILES_DIR/.claude" "$HOME/.claude"
        
        # Make Python hook scripts executable
        find "$HOME/.claude/hooks" -name "*.py" -exec chmod +x {} \;
        
        # Copy audio files if they exist
        if [[ -d "$DOTFILES_DIR/.claude/audio" ]]; then
            mkdir -p "$HOME/.claude/audio"
            cp -r "$DOTFILES_DIR/.claude/audio/"* "$HOME/.claude/audio/" 2>/dev/null || true
            log_info "Audio files copied for hook notifications"
        fi
        
        # Install uv if not present (Python package manager for hooks)
        if ! command_exists uv; then
            log_info "Installing uv (Python package manager)..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
        
        # Set up Python environment for hooks
        if command_exists uv; then
            log_info "Setting up Python environment for Claude hooks..."
            cd "$HOME/.claude/hooks"
            uv python install 3.11 2>/dev/null || true
            uv venv --python 3.11 2>/dev/null || true
            uv pip install requests 2>/dev/null || true
        fi
        
        log_success "Claude CLI hooks and settings installed"
    fi
}

# Set Fish as default shell
setup_fish_shell() {
    if command_exists fish; then
        local fish_path
        fish_path=$(which fish)
        
        if [[ "$SHELL" != "$fish_path" ]]; then
            log_info "Setting Fish as default shell..."
            
            # Check if running in SSH session (remote environment)
            if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
                log_info "SSH session detected - using alternative Fish setup method..."
                
                # Backup existing .bashrc
                if [[ -f ~/.bashrc ]]; then
                    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
                    log_info "Created backup of ~/.bashrc"
                fi
                
                # Add Fish auto-start to .bashrc (only for interactive sessions)
                if ! grep -q "CLI Agent Hook: Auto-start Fish shell" ~/.bashrc 2>/dev/null; then
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
                    log_success "Added Fish auto-start to ~/.bashrc (SSH-friendly method)"
                    log_info "Fish will start automatically in new SSH sessions"
                else
                    log_info "Fish auto-start already configured in ~/.bashrc"
                fi
            else
                # Local environment - try traditional chsh method
                # Add fish to shells if not present
                if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
                    echo "$fish_path" | sudo tee -a /etc/shells
                fi
                
                # Change default shell
                if chsh -s "$fish_path" 2>/dev/null; then
                    log_success "Fish shell set as default"
                else
                    log_warning "Failed to set Fish as default shell with chsh"
                    log_info "You can manually set Fish as default or run 'fish' to start it"
                fi
            fi
        else
            log_info "Fish is already the default shell"
        fi
    fi
}

# Install Fish plugins
setup_fish_plugins() {
    if command_exists fish; then
        log_info "Installing Fish plugins..."
        fish -c "
            # Install fisher if not installed
            if not functions -q fisher
                curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
                fisher install jorgebucaran/fisher
            end
            
            # Install plugins from fish_plugins file
            if test -f ~/.config/fish/fish_plugins
                fisher update
            end
        "
    fi
}

# Post-installation setup
post_install() {
    log_info "Running post-installation setup..."
    
    # Make scripts executable
    find "$DOTFILES_DIR" -name "*.sh" -exec chmod +x {} \;
    
    # Source Fish configuration
    if command_exists fish && [[ -f "$HOME/.config/fish/config.fish" ]]; then
        fish -c "source ~/.config/fish/config.fish"
    fi
    
    # macOS specific post-install
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Start services
        brew services start aerospace 2>/dev/null || true
        brew services start sketchybar 2>/dev/null || true
    fi
}

# Create CLI command
create_cli_command() {
    local cli_script="$INSTALL_DIR/bin/cli-agent-hook"
    
    # Make sure the existing cli-agent-hook script is executable
    if [[ -f "$cli_script" ]]; then
        chmod +x "$cli_script"
        log_success "CLI script already exists and made executable"
    else
        log_warning "CLI script not found, this may indicate an incomplete installation"
        return 1
    fi
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$INSTALL_DIR/bin"; then
        if [[ -f "$HOME/.config/fish/config.fish" ]]; then
            echo "fish_add_path \"$INSTALL_DIR/bin\"" >> "$HOME/.config/fish/config.fish"
        fi
    fi
    
    log_success "CLI command installed: cli-agent-hook"
}

# Main installation function
main() {
    log_info "Starting CLI Agent Hook installation..."
    
    # Check prerequisites
    if ! command_exists git; then
        log_error "Git is required but not installed"
        exit 1
    fi
    
    # Run installation steps
    install_homebrew
    install_packages
    setup_repository
    setup_dotfiles
    setup_fish_shell
    setup_fish_plugins
    create_cli_command
    post_install
    
    log_success "Installation completed successfully!"
    log_info "Please restart your terminal or run: exec fish"
    log_info "Use 'cli-agent-hook' command for management"
}

# Run main function
main "$@"