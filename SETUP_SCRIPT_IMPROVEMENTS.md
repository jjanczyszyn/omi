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

### 5. GCloud SDK Auto-Update ✅
The script now ensures gcloud SDK is up-to-date to avoid Python deprecation warnings.

**Problem:**
```
WARNING: Python 3.9 will be deprecated on January 27th, 2026
```

**Solution:**
- Check for gcloud updates when SDK is already installed
- Automatically upgrade via Homebrew if available
- Provide manual update instructions if not using Homebrew

**Code Added:**
```bash
if command_exists gcloud; then
    # Check if gcloud needs updating
    log_info "Checking for gcloud updates..."
    if brew list google-cloud-sdk &>/dev/null; then
        log_info "Updating gcloud via Homebrew..."
        brew upgrade google-cloud-sdk || log_warning "gcloud already up to date"
    else
        log_warning "gcloud not installed via Homebrew - update manually if needed"
        log_info "To update: gcloud components update"
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
- **Before:** Outdated SDK with Python 3.9 deprecation warnings
- **After:** Auto-updates via Homebrew to use latest version

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
- ✅ GCloud SDK auto-update (fixes Python 3.9 deprecation warnings)
- ✅ numba build error fixed (pre-built wheels + llvm fallback)
- ✅ All 13 steps tracked
- ✅ Command-line options (--status, --reset, --help)
- ✅ Clear user feedback and error messages

You can safely run the setup script knowing it will:
1. Not waste time re-running completed steps
2. Automatically install Python 3.12 if you have Python 3.13+
3. Skip re-prompting for environment variables you've already entered
4. Keep gcloud SDK updated to avoid deprecation warnings
5. Handle the numba installation correctly with binary wheels
6. Resume exactly where it left off if interrupted
