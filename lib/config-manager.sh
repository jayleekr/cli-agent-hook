#!/bin/bash

# Configuration Manager for CLI Agent Hook
# Handles configuration file management, validation, and templating

set -euo pipefail

# Configuration paths
CONFIG_DIR="$HOME/.config/cli-agent-hook"
TEMPLATE_DIR="$(dirname "${BASH_SOURCE[0]}")/../templates"
BACKUP_DIR="$HOME/.cli-agent-hook-backups"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"

# Logging (reuse from install.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[CONFIG]${NC} $1"; }
log_success() { echo -e "${GREEN}[CONFIG]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[CONFIG]${NC} $1"; }
log_error() { echo -e "${RED}[CONFIG]${NC} $1"; }

# Configuration validation
validate_config() {
    local config_file="$1"
    local config_type="$2"
    
    case "$config_type" in
        "fish")
            if ! fish -n "$config_file" >/dev/null 2>&1; then
                log_error "Invalid Fish configuration syntax: $config_file"
                return 1
            fi
            ;;
        "tmux")
            if ! tmux -f "$config_file" list-keys >/dev/null 2>&1; then
                log_error "Invalid Tmux configuration: $config_file"
                return 1
            fi
            ;;
        "nvim")
            # Basic Lua syntax check
            if command -v lua >/dev/null 2>&1; then
                if ! lua -e "dofile('$config_file')" >/dev/null 2>&1; then
                    log_warning "Neovim configuration may have syntax issues: $config_file"
                fi
            fi
            ;;
    esac
    
    log_success "Configuration validated: $config_file"
}

# Template processing
process_template() {
    local template_file="$1"
    local output_file="$2"
    local -A variables=()
    
    # Read additional variables from arguments
    shift 2
    while [[ $# -gt 0 ]]; do
        local key="$1"
        local value="$2"
        variables["$key"]="$value"
        shift 2
    done
    
    # Default variables
    variables["HOME"]="${HOME}"
    variables["USER"]="${USER}"
    variables["HOSTNAME"]="$(hostname)"
    variables["OS"]="$(uname -s)"
    variables["ARCH"]="$(uname -m)"
    variables["DATE"]="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Process template
    local temp_file
    temp_file=$(mktemp)
    cp "$template_file" "$temp_file"
    
    # Replace variables
    for key in "${!variables[@]}"; do
        sed -i.bak "s|{{${key}}}|${variables[$key]}|g" "$temp_file"
    done
    
    # Move to final location
    mv "$temp_file" "$output_file"
    rm -f "${temp_file}.bak"
    
    log_success "Template processed: $template_file -> $output_file"
}

# Backup existing configuration
backup_config() {
    local source="$1"
    local name="$2"
    
    if [[ -e "$source" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="$BACKUP_DIR/${name}_${timestamp}"
        
        if [[ -d "$source" ]]; then
            cp -r "$source" "$backup_path"
        else
            cp "$source" "$backup_path"
        fi
        
        log_success "Backed up $source to $backup_path"
        echo "$backup_path" # Return backup path
    fi
}

# Restore configuration from backup
restore_config() {
    local target="$1"
    local backup_pattern="$2"
    
    # Find latest backup
    local latest_backup
    latest_backup=$(find "$BACKUP_DIR" -name "${backup_pattern}_*" | sort -r | head -n1)
    
    if [[ -n "$latest_backup" && -e "$latest_backup" ]]; then
        # Remove current config
        rm -rf "$target"
        
        # Restore from backup
        if [[ -d "$latest_backup" ]]; then
            cp -r "$latest_backup" "$target"
        else
            cp "$latest_backup" "$target"
        fi
        
        log_success "Restored $target from $latest_backup"
    else
        log_error "No backup found for pattern: $backup_pattern"
        return 1
    fi
}

# Merge configurations
merge_configs() {
    local base_config="$1"
    local user_config="$2"
    local output_config="$3"
    local config_type="$4"
    
    case "$config_type" in
        "fish")
            # For Fish, append user config to base config
            cat "$base_config" > "$output_config"
            echo "" >> "$output_config"
            echo "# User customizations" >> "$output_config"
            cat "$user_config" >> "$output_config"
            ;;
        "tmux")
            # For Tmux, similar approach
            cat "$base_config" > "$output_config"
            echo "" >> "$output_config"
            echo "# User customizations" >> "$output_config"
            cat "$user_config" >> "$output_config"
            ;;
        *)
            # Default: just copy user config over base
            cp "$user_config" "$output_config"
            ;;
    esac
    
    log_success "Merged configurations: $base_config + $user_config -> $output_config"
}

# Generate user configuration from template
generate_user_config() {
    local config_type="$1"
    local user_name="${2:-$USER}"
    local user_email="${3:-}"
    
    local template_path="$TEMPLATE_DIR/${config_type}.template"
    local output_path="$CONFIG_DIR/${config_type}_user.conf"
    
    if [[ ! -f "$template_path" ]]; then
        log_error "Template not found: $template_path"
        return 1
    fi
    
    process_template "$template_path" "$output_path" \
        "USER_NAME" "$user_name" \
        "USER_EMAIL" "$user_email"
}

# Main configuration management function
manage_config() {
    local action="$1"
    local config_type="${2:-}"
    
    case "$action" in
        "validate")
            if [[ -z "$config_type" ]]; then
                log_error "Config type required for validation"
                return 1
            fi
            local config_file="$3"
            validate_config "$config_file" "$config_type"
            ;;
        "backup")
            if [[ -z "$config_type" ]]; then
                log_error "Config type required for backup"
                return 1
            fi
            local source_path="$3"
            backup_config "$source_path" "$config_type"
            ;;
        "restore")
            if [[ -z "$config_type" ]]; then
                log_error "Config type required for restore"
                return 1
            fi
            local target_path="$3"
            restore_config "$target_path" "$config_type"
            ;;
        "generate")
            if [[ -z "$config_type" ]]; then
                log_error "Config type required for generation"
                return 1
            fi
            generate_user_config "$config_type" "${3:-}" "${4:-}"
            ;;
        *)
            log_error "Unknown action: $action"
            log_info "Usage: manage_config {validate|backup|restore|generate} [config_type] [args...]"
            return 1
            ;;
    esac
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    manage_config "$@"
fi