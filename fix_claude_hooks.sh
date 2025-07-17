#!/bin/bash

# Claude Hooks Emergency Recovery Script
# Standalone tool for fixing Claude hook issues

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[HOOK-FIX]${NC} $1"; }
log_success() { echo -e "${GREEN}[HOOK-FIX]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[HOOK-FIX]${NC} $1"; }
log_error() { echo -e "${RED}[HOOK-FIX]${NC} $1"; }

show_usage() {
    cat << EOF
Claude Hooks Emergency Recovery Script

Usage: $0 [command]

Commands:
    check       Check hook system status
    disable     Disable all hooks
    enable      Enable hooks from backup
    reset       Reset to minimal working configuration
    remove      Completely remove hooks
    install     Fresh install from this repository
    help        Show this help

Examples:
    $0 check     # Check current status
    $0 disable   # Disable hooks immediately
    $0 reset     # Reset to default configuration
    $0 remove    # Complete removal with backup

EOF
}

# Check current status
check_status() {
    log_info "Checking Claude Hooks status..."
    echo
    
    # Check .claude directory
    if [[ -d "$HOME/.claude" ]]; then
        if [[ -L "$HOME/.claude" ]]; then
            echo "✅ Claude directory: Symlinked to $(readlink "$HOME/.claude")"
        else
            echo "⚠️  Claude directory: Exists but not symlinked"
        fi
    else
        echo "❌ Claude directory: Not found"
        return 1
    fi
    
    # Check settings.json
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        echo "✅ Settings file: Found"
        if command -v python3 >/dev/null 2>&1; then
            if python3 -m json.tool "$HOME/.claude/settings.json" >/dev/null 2>&1; then
                echo "✅ Settings file: Valid JSON format"
            else
                echo "❌ Settings file: Invalid JSON format"
            fi
        fi
    else
        echo "❌ Settings file: Not found"
    fi
    
    # Check hook scripts
    if [[ -d "$HOME/.claude/hooks" ]]; then
        local script_count
        script_count=$(find "$HOME/.claude/hooks" -name "*.py" 2>/dev/null | wc -l)
        echo "📄 Hook scripts: ${script_count} found"
        
        # Check permissions
        local non_executable
        non_executable=$(find "$HOME/.claude/hooks" -name "*.py" ! -perm +111 2>/dev/null | wc -l)
        if [[ $non_executable -eq 0 ]]; then
            echo "✅ Execute permissions: All scripts executable"
        else
            echo "⚠️  Execute permissions: ${non_executable} scripts not executable"
        fi
    else
        echo "❌ Hook scripts directory: Not found"
    fi
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        echo "✅ Python3: $(python3 --version)"
    else
        echo "❌ Python3: Not installed"
    fi
    
    echo
}

# Disable hooks
disable_hooks() {
    log_info "Disabling Claude Hooks..."
    
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        # Create backup
        cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Replace with empty hooks configuration
        cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(**/.env*)",
      "Read(**/env*)",
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Read(**/*.crt)",
      "Read(**/*.cert)",
      "Read(**/secrets/**)",
      "Read(**/credentials/**)"
    ]
  },
  "hooks": {}
}
EOF
        log_success "Hooks disabled (backup created)"
    else
        log_warning "No settings file found to disable"
    fi
}

# Enable from backup
enable_hooks() {
    log_info "Restoring hooks from backup..."
    
    local backup_file
    backup_file=$(find "$HOME/.claude" -name "settings.json.backup.*" 2>/dev/null | sort -r | head -n1)
    
    if [[ -n "$backup_file" && -f "$backup_file" ]]; then
        cp "$backup_file" "$HOME/.claude/settings.json"
        log_success "Restored from backup: $(basename "$backup_file")"
    else
        log_error "No backup file found"
        return 1
    fi
}

# Reset to minimal configuration
reset_hooks() {
    log_info "Resetting to minimal default configuration..."
    
    # Create backup
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create default configuration
    cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(**/.env*)",
      "Read(**/env*)",
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Read(**/*.crt)",
      "Read(**/*.cert)",
      "Read(**/secrets/**)",
      "Read(**/credentials/**)"
    ]
  },
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Claude notification'"
          }
        ]
      }
    ]
  }
}
EOF
    
    # Create hooks directory
    mkdir -p "$HOME/.claude/hooks"
    
    # Create basic notification script
    cat > "$HOME/.claude/hooks/simple_notification.py" << 'EOF'
#!/usr/bin/env python3
import sys
import json

def main():
    try:
        input_data = json.load(sys.stdin)
        print(f"Claude operation completed: {input_data.get('tool_name', 'unknown')}")
    except:
        print("Claude operation completed")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$HOME/.claude/hooks/simple_notification.py"
    
    log_success "Reset to default configuration complete"
}

# Complete removal
remove_hooks() {
    log_warning "Complete Claude Hooks removal"
    read -p "Are you sure you want to remove all hooks? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -d "$HOME/.claude" ]]; then
            local backup_dir="$HOME/.claude.removed.$(date +%Y%m%d_%H%M%S)"
            mv "$HOME/.claude" "$backup_dir"
            log_success "Removed (backed up to: $backup_dir)"
        else
            log_info "Nothing to remove"
        fi
    else
        log_info "Removal cancelled"
    fi
}

# Fresh install
fresh_install() {
    log_info "Fresh Claude Hooks installation..."
    
    # Check if current directory is cli-agent-hook repository
    local current_dir="$(pwd)"
    if [[ ! -f "$current_dir/.claude/settings.json" ]]; then
        log_error "This script must be run from the cli-agent-hook repository directory"
        log_info "Usage: cd /path/to/cli-agent-hook && ./fix_claude_hooks.sh install"
        return 1
    fi
    
    # Remove existing (with backup)
    if [[ -d "$HOME/.claude" ]]; then
        local backup_dir="$HOME/.claude.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/.claude" "$backup_dir"
        log_info "Existing configuration backed up: $backup_dir"
    fi
    
    # Create new installation
    ln -sf "$current_dir/.claude" "$HOME/.claude"
    
    # Set execute permissions
    find "$HOME/.claude/hooks" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
    
    # Check UV installation
    if ! command -v uv >/dev/null 2>&1; then
        log_info "Installing UV package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    
    log_success "Fresh installation complete"
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        "check")
            check_status
            ;;
        "disable")
            disable_hooks
            ;;
        "enable")
            enable_hooks
            ;;
        "reset")
            reset_hooks
            ;;
        "remove")
            remove_hooks
            ;;
        "install")
            fresh_install
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@" 