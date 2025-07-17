# Claude Hooks Management System

## Overview

The CLI Agent Hook project includes a comprehensive hook management system for integrating with Claude AI assistant. This system provides automated code validation, notifications, and pre/post processing capabilities.

## System Components

### 1. Main CLI Tool (`bin/cli-agent-hook`)
Primary interface for managing the entire system including hooks.

```bash
# Hook management commands
cli-agent-hook hook-status       # Check hook system status
cli-agent-hook hook-disable      # Temporarily disable all hooks
cli-agent-hook hook-enable       # Re-enable hooks from backup
cli-agent-hook hook-reset        # Reset to default configuration
cli-agent-hook hook-remove       # Completely remove hooks with backup
cli-agent-hook hook-troubleshoot # Run comprehensive diagnostics
```

### 2. Emergency Recovery Script (`fix_claude_hooks.sh`)
Standalone tool for critical situations when the main CLI is non-functional.

```bash
# Emergency recovery commands
./fix_claude_hooks.sh check      # Check current system status
./fix_claude_hooks.sh disable    # Immediate disable for problematic hooks
./fix_claude_hooks.sh reset      # Reset to minimal working configuration
./fix_claude_hooks.sh remove     # Complete removal with backup
./fix_claude_hooks.sh install    # Fresh installation from repository
```

## Hook Types and Functions

### PreToolUse Hooks
- **Purpose**: Execute before command/tool usage
- **Scripts**: `log_pre_tool_use.py`, `use_bun.py`
- **Function**: Logging, environment setup, tool validation

### PostToolUse Hooks
- **Purpose**: Execute after file editing operations
- **Scripts**: `ts_lint.py`
- **Function**: Code validation, linting, syntax checking

### Notification Hooks
- **Purpose**: Provide user feedback on task completion
- **Scripts**: `macos_notification.py`, `play_audio.py`
- **Function**: System notifications, audio alerts

## Configuration Management

### Settings File (`~/.claude/settings.json`)
Main configuration controlling hook behavior:

```json
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
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/log_pre_tool_use.py"
          },
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/use_bun.py"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/ts_lint.py"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/play_audio.py"
          },
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/macos_notification.py"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Hooks Not Executing
```bash
# Check system status
cli-agent-hook hook-status

# Run full diagnostics
cli-agent-hook hook-troubleshoot

# Verify permissions
chmod +x ~/.claude/hooks/*.py
```

#### 2. Python Environment Issues
```bash
# Check Python installation
python3 --version
which python3

# Test hook scripts individually
python3 ~/.claude/hooks/macos_notification.py
```

#### 3. JSON Configuration Errors
```bash
# Validate JSON syntax
python3 -m json.tool ~/.claude/settings.json

# Reset to defaults
cli-agent-hook hook-reset
```

#### 4. Permission Problems
```bash
# Fix directory permissions
chmod 755 ~/.claude
chmod 644 ~/.claude/settings.json
chmod +x ~/.claude/hooks/*.py
```

### Emergency Procedures

#### When Hooks Cause System Issues
1. **Immediate Disable**: `./fix_claude_hooks.sh disable`
2. **Check Status**: `./fix_claude_hooks.sh check`
3. **Reset if Needed**: `./fix_claude_hooks.sh reset`
4. **Complete Removal**: `./fix_claude_hooks.sh remove` (if problems persist)

#### Recovery Scenarios
- **Infinite Loop**: Use emergency disable
- **JSON Corruption**: Use reset function
- **Claude Unresponsive**: Complete removal and fresh install
- **Python Errors**: Check environment and reinstall

## Advanced Usage

### Creating Custom Hooks

1. **Create Script**: Place in `~/.claude/hooks/`
2. **Make Executable**: `chmod +x your_hook.py`
3. **Update Configuration**: Add to `settings.json`
4. **Test**: Use troubleshoot command

### Hook Script Template
```python
#!/usr/bin/env python3
import sys
import json

def main():
    try:
        # Read input from Claude
        input_data = json.load(sys.stdin)
        
        # Process the input
        tool_name = input_data.get("tool_name")
        
        # Your custom logic here
        print(f"Processing {tool_name}")
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### Configuration Matchers
- **Exact Match**: `"Bash"`, `"Edit"`, `"Write"`
- **Pattern Match**: `"Write|Edit"`, `".*Tool.*"`
- **All Tools**: `""` (empty string)

## Backup and Recovery

### Automatic Backups
- All operations create timestamped backups
- Backups stored with `.backup.YYYYMMDD_HHMMSS` suffix
- Emergency removal creates `.removed.YYYYMMDD_HHMMSS` backup

### Manual Backup
```bash
# Create full backup
cp -r ~/.claude ~/.claude.manual.backup.$(date +%Y%m%d_%H%M%S)

# Backup just settings
cp ~/.claude/settings.json ~/.claude/settings.json.manual.backup.$(date +%Y%m%d_%H%M%S)
```

### Restore Procedures
```bash
# List available backups
ls -la ~/.claude*.backup.*

# Restore from specific backup
cp ~/.claude.backup.YYYYMMDD_HHMMSS ~/.claude

# Or use enable function for settings only
cli-agent-hook hook-enable
```

## Security Considerations

### Default Protections
- Environment files blocked (`.env`, secrets)
- Certificate files protected (`.pem`, `.key`, `.crt`)
- Credentials directories denied access

### Best Practices
- Regular backup of working configurations
- Test hooks in safe environment first
- Monitor error logs for issues
- Keep Python environment updated

## Monitoring and Logging

### Error Logging
- ESLint errors: `~/.claude/eslint_errors.json`
- System logs: Check with `hook-troubleshoot`

### Status Monitoring
```bash
# Quick status check
cli-agent-hook hook-status

# Detailed diagnostics
cli-agent-hook hook-troubleshoot

# Emergency status
./fix_claude_hooks.sh check
```

## Performance Optimization

### Hook Efficiency
- Keep scripts lightweight
- Avoid long-running operations
- Use appropriate matchers to limit execution
- Cache expensive operations when possible

### System Impact
- Hooks run synchronously with Claude operations
- Failed hooks may interrupt workflow
- Use timeouts for external operations
- Monitor resource usage

This comprehensive system ensures reliable AI-assisted development with robust error handling and recovery capabilities. 