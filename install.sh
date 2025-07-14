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
        git pull origin main
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
}

# Set Fish as default shell
setup_fish_shell() {
    if command_exists fish; then
        local fish_path
        fish_path=$(which fish)
        
        if [[ "$SHELL" != "$fish_path" ]]; then
            log_info "Setting Fish as default shell..."
            
            # Add fish to shells if not present
            if ! grep -q "$fish_path" /etc/shells; then
                echo "$fish_path" | sudo tee -a /etc/shells
            fi
            
            # Change default shell
            chsh -s "$fish_path"
            log_success "Fish shell set as default"
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
    mkdir -p "$INSTALL_DIR/bin"
    
    cat > "$cli_script" << 'EOF'
#!/bin/bash
# CLI Agent Hook command line interface

INSTALL_DIR="$HOME/.cli-agent-hook"
DOTFILES_DIR="$INSTALL_DIR"

case "$1" in
    "install")
        "$INSTALL_DIR/install.sh"
        ;;
    "update")
        cd "$INSTALL_DIR" && git pull origin main
        "$INSTALL_DIR/install.sh"
        ;;
    "backup")
        backup_dir="$HOME/.cli-agent-hook-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        echo "Creating backup in $backup_dir"
        # Add backup logic here
        ;;
    "restore")
        echo "Restore functionality coming soon..."
        ;;
    *)
        echo "Usage: cli-agent-hook {install|update|backup|restore}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$cli_script"
    
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