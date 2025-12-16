# Setup Script Improvements

## Changes Made

### 1. Progress Tracking System ✅
The script now saves its progress and can resume from where it left off if interrupted.

**Features:**
- State file: `~/.omi-setup-state.json` tracks completed steps
- Automatic resume on restart
- Each step is marked complete after successful execution
- Skip completed steps automatically

**Command-line Options:**
```bash
# Run normally (resumes if interrupted)
./omi_setup_mac.sh

# Check current progress
./omi_setup_mac.sh --status

# Start over from scratch
./omi_setup_mac.sh --reset

# Show help
./omi_setup_mac.sh --help
```

### 2. Fixed numba Build Error ✅
The script now properly handles the numba dependency installation issue.

**Problem:**
```
ERROR: Failed to build 'numba' when getting requirements to build wheel
```

**Solution:**
- Pre-install numpy and llvmlite before other dependencies
- Use `--only-binary` flag to prefer pre-built wheels
- Automatically install llvm on macOS if needed for source builds
- Upgrade pip, setuptools, and wheel before installation

**Code Added:**
```python
# Pre-installing numpy and llvmlite to avoid build errors
pip install --only-binary :all: numpy || pip install numpy
pip install --only-binary :all: llvmlite || {
    # On macOS, ensure llvm is available
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install llvm
        export LLVM_CONFIG="$(brew --prefix llvm)/bin/llvm-config"
    fi
    pip install llvmlite
}
```

### 3. Fixed Python 3.13 Compatibility Issue ✅
The script now handles Python 3.13+ which is incompatible with numba.

**Problem:**
```
RuntimeError: Cannot install on Python version 3.13.3; only versions >=3.9,<3.13 are supported.
```

**Solution:**
- Detect if Python 3.13+ is installed
- Automatically install Python 3.12 via Homebrew if needed
- Use `python3.12` command explicitly for venv creation
- Pin numpy to `<2.0` for compatibility

**Code Added:**
```bash
# Check if Python 3.13+ (incompatible with numba)
if [[ $major -eq 3 && $minor -ge 13 ]]; then
    log_error "Python 3.13+ detected, but numba requires Python 3.9-3.12"
    log_warning "Need to install Python 3.12 for compatibility"

    if command_exists python3.12; then
        PYTHON_CMD="python3.12"
    else
        brew install python@3.12
        PYTHON_CMD="python3.12"
    fi
fi
```

### 4. Smart Environment Variable Handling ✅
The script no longer re-prompts for environment variables that already exist.

**Problem:**
- Script kept asking for keys that were already entered
- No way to skip re-entering existing configuration

**Solution:**
- Check if environment variables already exist in .env
- Show masked preview of existing values
- Only prompt to update if user confirms (defaults to "n")

**Code Added:**
```bash
# Check if env var exists
env_var_exists() {
    local key="$1"
    local env_file="$2"
    local value=$(grep "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2-)
    [[ -n "$value" ]]
}

# Show masked value
get_masked_value() {
    local key="$1"
    local env_file="$2"
    local value=$(grep "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2-)
    if [[ ${#value} -gt 8 ]]; then
        echo "${value:0:4}...${value: -4}"
    fi
}

# Only prompt if key doesn't exist
if env_var_exists "OPENAI_API_KEY" "$ENV_FILE"; then
    local masked=$(get_masked_value "OPENAI_API_KEY" "$ENV_FILE")
    log_success "OPENAI_API_KEY already set ($masked)"
    if confirm "Update OPENAI_API_KEY?" "n"; then
        # ... update logic
    fi
fi
```

### 5. GCloud SDK Python Configuration ✅
The script now configures gcloud to use Python 3.12, avoiding both deprecation warnings and virtualenv errors.

**Problems:**
```
WARNING: Python 3.9 will be deprecated on January 27th, 2026
ERROR: (gcloud.config.virtualenv.create) /opt/homebrew/opt/python@3.13/libexec/bin/python3: command not found
```

**Solution:**
- Set `CLOUDSDK_PYTHON=python3.12` environment variable for all gcloud commands
- Check for gcloud updates when SDK is already installed
- Automatically upgrade via Homebrew if available
- Handle upgrade failures gracefully with reinstall fallback
- Provide manual update instructions if not using Homebrew

**Code Added:**
```bash
# Configure gcloud to use Python 3.12
if command_exists python3.12; then
    export CLOUDSDK_PYTHON="python3.12"
    log_info "Configured gcloud to use Python 3.12"
fi

if command_exists gcloud; then
    # Check if gcloud needs updating
    log_info "Checking for gcloud updates..."
    if brew list google-cloud-sdk &>/dev/null || brew list gcloud-cli &>/dev/null; then
        log_info "Updating gcloud via Homebrew..."
        # Try to upgrade, but don't fail if it errors due to Python issues
        if ! brew upgrade google-cloud-sdk 2>/dev/null && ! brew upgrade gcloud-cli 2>/dev/null; then
            log_warning "gcloud upgrade encountered issues, trying reinstall..."
            # Uninstall and reinstall to fix Python virtualenv issues
            brew uninstall --ignore-dependencies google-cloud-sdk 2>/dev/null || true
            brew uninstall --ignore-dependencies gcloud-cli 2>/dev/null || true
            brew install --cask google-cloud-sdk
        fi
    fi
fi
```

### 6. Progress Tracking for All Steps

All 13 setup steps now have progress tracking:
1. ✅ Install Homebrew
2. ✅ Install Python (with 3.12 auto-install for numba)
3. ✅ Install System Dependencies
4. ✅ Validate Repository
5. ✅ Configure Environment File
6. ✅ Collect Environment Variables (with smart skipping)
7. ✅ Setup Python Virtual Environment (with numba fix)
8. ✅ Configure Ngrok
9. ✅ Install Google Cloud SDK (with auto-update)
10. ✅ Configure GCP Project
11. ✅ Enable GCP APIs
12. ✅ Configure Firestore Indexes
13. ✅ Final Instructions

## Benefits

### Interruption Recovery
- **Before:** Had to start over if script was interrupted
- **After:** Automatically resumes from last completed step

### Better UX
- Shows progress count when resuming
- Clear skip messages for completed steps
- Can check status without running setup

### Reliability
- Avoids re-running expensive operations (GCP auth, dependency installation)
- Safe to run multiple times
- No duplicate installations

### Python Compatibility
- **Before:** Build failures with Python 3.13+, numba incompatibility
- **After:** Auto-detects version, installs Python 3.12 when needed, uses pre-built wheels

### Environment Variables
- **Before:** Re-prompted for all keys every time
- **After:** Checks existing values, shows masked previews, only updates on confirmation

### GCloud SDK
- **Before:** Python 3.9 deprecation warnings, Python 3.13 virtualenv errors
- **After:** Configured to use Python 3.12, auto-updates via Homebrew, handles upgrade failures

## Usage Examples

### First Time Setup
```bash
./omi_setup_mac.sh
# Completes steps 1-7, then gets interrupted
```

### Resume After Interruption
```bash
./omi_setup_mac.sh
# Output: "📋 Resuming setup - 7 steps already completed"
# Skips steps 1-7, continues from step 8
```

### Check Progress
```bash
./omi_setup_mac.sh --status
# Shows:
#   ✓ install_homebrew
#   ✓ install_python
#   ✓ install_system_dependencies
#   ...
```

### Start Over
```bash
./omi_setup_mac.sh --reset
# Deletes ~/.omi-setup-state.json
# Next run starts from step 1
```

## Technical Details

### State File Format
```json
{
  "completed_steps": [
    "install_homebrew",
    "install_python",
    "install_system_dependencies",
    "validate_repository"
  ]
}
```

### Function Pattern
Each function follows this pattern:
```bash
function_name() {
    local step_name="function_name"
    
    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step X: ... (already completed)"
        # Restore any exported variables
        return 0
    fi
    
    # ... existing function code ...
    
    mark_step_completed "$step_name"
}
```

## Summary of All Improvements

The setup script is now production-ready with:
- ✅ Progress tracking and resume capability
- ✅ Python 3.13 compatibility (auto-installs Python 3.12 for numba)
- ✅ Smart environment variable handling (skips existing keys)
- ✅ GCloud SDK Python configuration (uses Python 3.12, fixes virtualenv errors)
- ✅ GCloud SDK auto-update with reinstall fallback
- ✅ numba build error fixed (pre-built wheels + llvm fallback)
- ✅ All 13 steps tracked
- ✅ Command-line options (--status, --reset, --help)
- ✅ Clear user feedback and error messages

You can safely run the setup script knowing it will:
1. Not waste time re-running completed steps
2. Automatically install Python 3.12 if you have Python 3.13+
3. Configure gcloud to use Python 3.12 (avoiding both 3.9 deprecation and 3.13 errors)
4. Skip re-prompting for environment variables you've already entered
5. Keep gcloud SDK updated, with automatic reinstall if upgrade fails
6. Handle the numba installation correctly with binary wheels
7. Resume exactly where it left off if interrupted
