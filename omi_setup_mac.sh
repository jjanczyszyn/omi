#!/usr/bin/env bash

################################################################################
# Omi Backend Setup Script for macOS
#
# This script automates the setup of the Omi backend for local development
# on macOS, including:
# - Google Cloud SDK and project configuration
# - Firebase and Firestore setup
# - Python environment and dependencies
# - Ngrok tunnel configuration
# - Environment variable collection
#
# Usage: ./omi_setup_mac.sh
#
# Author: Generated for Omi local development
# Date: 2025
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

################################################################################
# CONFIGURATION
################################################################################

# State file to track progress
STATE_FILE="${HOME}/.omi-setup-state.json"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize state file
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"completed_steps": []}' > "$STATE_FILE"
    fi
}

# Check if step is completed
is_step_completed() {
    local step_name="$1"
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    grep -q "\"$step_name\"" "$STATE_FILE"
}

# Mark step as completed
mark_step_completed() {
    local step_name="$1"
    if [[ ! -f "$STATE_FILE" ]]; then
        init_state
    fi

    # Read current state
    local current_state=$(cat "$STATE_FILE")

    # Add step to completed list if not already there
    if ! is_step_completed "$step_name"; then
        local new_state=$(echo "$current_state" | python3 -c "
import sys, json
state = json.load(sys.stdin)
state['completed_steps'].append('$step_name')
print(json.dumps(state, indent=2))
")
        echo "$new_state" > "$STATE_FILE"
        log_success "Progress saved: $step_name"
    fi
}

# Reset state (start over)
reset_state() {
    rm -f "$STATE_FILE"
    log_info "Progress reset - starting fresh"
}

# Show progress
show_progress() {
    if [[ -f "$STATE_FILE" ]]; then
        log_info "Completed steps:"
        cat "$STATE_FILE" | python3 -c "
import sys, json
state = json.load(sys.stdin)
for step in state.get('completed_steps', []):
    print(f'  ✓ {step}')
"
    else
        log_info "No progress saved yet"
    fi
}

# Prompt for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

# Update or add a key-value pair in .env file
update_env_var() {
    local key="$1"
    local value="$2"
    local env_file="$3"

    if grep -q "^${key}=" "$env_file"; then
        # Key exists, update it
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
        fi
    else
        # Key doesn't exist, append it
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Check if env var exists and is non-empty
env_var_exists() {
    local key="$1"
    local env_file="$2"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    local value=$(grep "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2-)
    [[ -n "$value" ]]
}

# Get masked value for display (shows first 4 and last 4 chars)
get_masked_value() {
    local key="$1"
    local env_file="$2"

    local value=$(grep "^${key}=" "$env_file" 2>/dev/null | cut -d'=' -f2-)
    if [[ ${#value} -gt 8 ]]; then
        echo "${value:0:4}...${value: -4}"
    elif [[ -n "$value" ]]; then
        echo "****"
    else
        echo ""
    fi
}

# Read secret without echoing
read_secret() {
    local prompt="$1"
    local var_name="$2"
    local secret_value

    read -s -p "$prompt" secret_value
    echo ""  # New line after secret input

    if [[ -z "$secret_value" ]]; then
        return 1
    fi

    eval "$var_name='$secret_value'"
    return 0
}

# Read value with default
read_with_default() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local value

    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
    fi

    eval "$var_name='$value'"
}

################################################################################
# MAIN SETUP FUNCTIONS
################################################################################

# Step 1: Install Homebrew if needed
install_homebrew() {
    local step_name="install_homebrew"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 1: Homebrew (already completed)"
        return 0
    fi

    log_step "Step 1: Checking Homebrew Installation"

    if command_exists brew; then
        log_success "Homebrew is already installed"
        brew --version
    else
        log_info "Homebrew is not installed. Installing now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        log_success "Homebrew installed successfully"
    fi

    mark_step_completed "$step_name"
}

# Step 2: Install Python
install_python() {
    local step_name="install_python"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 2: Python (already completed)"
        # Still export commands for use in later steps
        PYTHON_CMD="${PYTHON_CMD:-python3.12}"
        if command_exists pip3; then
            PIP_CMD="pip3"
        else
            PIP_CMD="pip"
        fi
        export PYTHON_CMD PIP_CMD
        return 0
    fi

    log_step "Step 2: Installing Python"

    # Check current Python version
    local current_python_version=""
    if command_exists python3; then
        current_python_version=$(python3 --version 2>&1 | awk '{print $2}')
        local major=$(echo "$current_python_version" | cut -d. -f1)
        local minor=$(echo "$current_python_version" | cut -d. -f2)

        log_info "Found Python $current_python_version"

        # Check if Python 3.13+ (incompatible with numba)
        if [[ $major -eq 3 && $minor -ge 13 ]]; then
            log_error "Python 3.13+ detected, but numba requires Python 3.9-3.12"
            log_warning "Need to install Python 3.12 for compatibility"

            # Check if Python 3.12 is available
            if command_exists python3.12; then
                log_success "Python 3.12 is already installed"
                PYTHON_CMD="python3.12"
            else
                log_info "Installing Python 3.12 via Homebrew..."
                brew install python@3.12
                PYTHON_CMD="python3.12"
                log_success "Python 3.12 installed successfully"
            fi
        elif [[ $major -eq 3 && $minor -ge 9 ]]; then
            log_success "Python $current_python_version is compatible"
            PYTHON_CMD="python3"
        else
            log_error "Python version too old. Need Python 3.9-3.12"
            log_info "Installing Python 3.12..."
            brew install python@3.12
            PYTHON_CMD="python3.12"
        fi
    else
        log_info "Installing Python 3.12 via Homebrew..."
        brew install python@3.12
        PYTHON_CMD="python3.12"
        log_success "Python 3.12 installed successfully"
    fi

    # Verify the chosen Python version
    log_info "Using Python: $PYTHON_CMD"
    $PYTHON_CMD --version

    # Check for pip
    if command_exists pip3; then
        log_success "pip3 is available"
        PIP_CMD="pip3"
    elif command_exists pip; then
        log_success "pip is available"
        PIP_CMD="pip"
    else
        log_error "pip is not available. Please install pip manually."
        exit 1
    fi

    export PYTHON_CMD PIP_CMD
    mark_step_completed "$step_name"
}

# Step 3: Install system dependencies
install_system_dependencies() {
    local step_name="install_system_dependencies"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 3: System Dependencies (already completed)"
        return 0
    fi

    log_step "Step 3: Installing System Dependencies"

    local deps=("git" "ffmpeg" "opus")

    for dep in "${deps[@]}"; do
        if command_exists "$dep"; then
            log_success "$dep is already installed"
        else
            log_info "Installing $dep via Homebrew..."
            brew install "$dep"
            log_success "$dep installed successfully"
        fi
    done

    mark_step_completed "$step_name"
}

# Step 4: Validate repository
validate_repository() {
    local step_name="validate_repository"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 4: Repository Validation (already completed)"
        # Still set variables for later steps
        REPO_PATH="${REPO_PATH:-$(pwd)}"
        BACKEND_PATH="$REPO_PATH/backend"
        export REPO_PATH BACKEND_PATH
        return 0
    fi

    log_step "Step 4: Validating Omi Repository"

    local repo_path
    read_with_default "Enter path to Omi repository root" "repo_path" "$(pwd)"

    if [[ ! -d "$repo_path" ]]; then
        log_error "Directory does not exist: $repo_path"
        exit 1
    fi

    if [[ ! -d "$repo_path/backend" ]]; then
        log_error "Backend directory not found in: $repo_path"
        log_error "Please ensure you have cloned the Omi repository correctly."
        exit 1
    fi

    REPO_PATH="$repo_path"
    BACKEND_PATH="$repo_path/backend"

    log_success "Repository validated: $REPO_PATH"
    cd "$BACKEND_PATH"
    log_info "Changed directory to: $BACKEND_PATH"

    mark_step_completed "$step_name"
}

# Step 5: Configure environment file
configure_env_file() {
    local step_name="configure_env_file"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 5: Environment File (already completed)"
        ENV_FILE="$BACKEND_PATH/.env"
        export ENV_FILE
        return 0
    fi

    log_step "Step 5: Configuring Environment File"

    local env_file="$BACKEND_PATH/.env"
    local env_template="$BACKEND_PATH/.env.template"

    if [[ ! -f "$env_template" ]]; then
        log_error ".env.template not found in backend directory"
        exit 1
    fi

    if [[ -f "$env_file" ]]; then
        log_warning ".env file already exists"

        if confirm "Do you want to back it up and reconfigure?" "n"; then
            local backup_file="$BACKEND_PATH/.env.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$env_file" "$backup_file"
            log_success "Backed up existing .env to: $backup_file"
            cp "$env_template" "$env_file"
            log_info "Created fresh .env from template"
        else
            log_info "Using existing .env file. Will update missing keys only."
        fi
    else
        log_info "Creating .env from template..."
        cp "$env_template" "$env_file"
        log_success ".env file created"
    fi

    ENV_FILE="$env_file"
    mark_step_completed "$step_name"
}

# Step 6: Collect environment variables
collect_env_variables() {
    local step_name="collect_env_variables"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 6: Environment Variables (already completed)"
        return 0
    fi

    log_step "Step 6: Collecting Environment Variables"

    log_warning "You will be prompted for API keys and credentials."
    log_warning "Existing values will be skipped unless you choose to update them."
    echo ""

    # OPENAI_API_KEY
    if env_var_exists "OPENAI_API_KEY" "$ENV_FILE"; then
        local masked=$(get_masked_value "OPENAI_API_KEY" "$ENV_FILE")
        log_success "OPENAI_API_KEY already set ($masked)"
        if confirm "Update OPENAI_API_KEY?" "n"; then
            local openai_key
            if read_secret "Enter new OPENAI_API_KEY: " "openai_key"; then
                update_env_var "OPENAI_API_KEY" "$openai_key" "$ENV_FILE"
                log_success "OPENAI_API_KEY updated"
            fi
        fi
    else
        local openai_key
        if read_secret "Enter OPENAI_API_KEY: " "openai_key"; then
            update_env_var "OPENAI_API_KEY" "$openai_key" "$ENV_FILE"
            log_success "OPENAI_API_KEY configured"
        else
            log_warning "OPENAI_API_KEY not provided"
        fi
    fi

    # DEEPGRAM_API_KEY
    if env_var_exists "DEEPGRAM_API_KEY" "$ENV_FILE"; then
        local masked=$(get_masked_value "DEEPGRAM_API_KEY" "$ENV_FILE")
        log_success "DEEPGRAM_API_KEY already set ($masked)"
        if confirm "Update DEEPGRAM_API_KEY?" "n"; then
            local deepgram_key
            if read_secret "Enter new DEEPGRAM_API_KEY: " "deepgram_key"; then
                update_env_var "DEEPGRAM_API_KEY" "$deepgram_key" "$ENV_FILE"
                log_success "DEEPGRAM_API_KEY updated"
            fi
        fi
    else
        local deepgram_key
        if read_secret "Enter DEEPGRAM_API_KEY: " "deepgram_key"; then
            update_env_var "DEEPGRAM_API_KEY" "$deepgram_key" "$ENV_FILE"
            log_success "DEEPGRAM_API_KEY configured"
        else
            log_warning "DEEPGRAM_API_KEY not provided"
        fi
    fi

    # Redis
    echo ""
    if env_var_exists "REDIS_DB_HOST" "$ENV_FILE" && env_var_exists "REDIS_DB_PASSWORD" "$ENV_FILE"; then
        log_success "Redis credentials already configured"
        if confirm "Update Redis credentials?" "n"; then
            log_info "Enter Redis connection details (Upstash or other):"
            read_with_default "REDIS_DB_HOST" "redis_host" ""
            read_with_default "REDIS_DB_PORT" "redis_port" "6379"
            if read_secret "REDIS_DB_PASSWORD: " "redis_password"; then
                update_env_var "REDIS_DB_HOST" "$redis_host" "$ENV_FILE"
                update_env_var "REDIS_DB_PORT" "$redis_port" "$ENV_FILE"
                update_env_var "REDIS_DB_PASSWORD" "$redis_password" "$ENV_FILE"
                log_success "Redis credentials updated"
            fi
        fi
    else
        log_info "Enter Redis connection details (Upstash or other):"
        read_with_default "REDIS_DB_HOST" "redis_host" ""
        read_with_default "REDIS_DB_PORT" "redis_port" "6379"
        if read_secret "REDIS_DB_PASSWORD: " "redis_password"; then
            update_env_var "REDIS_DB_HOST" "$redis_host" "$ENV_FILE"
            update_env_var "REDIS_DB_PORT" "$redis_port" "$ENV_FILE"
            update_env_var "REDIS_DB_PASSWORD" "$redis_password" "$ENV_FILE"
            log_success "Redis credentials configured"
        else
            log_warning "Redis credentials not fully provided"
        fi
    fi

    # ADMIN_KEY
    echo ""
    if env_var_exists "ADMIN_KEY" "$ENV_FILE"; then
        log_success "ADMIN_KEY already set"
        if confirm "Update ADMIN_KEY?" "n"; then
            local admin_key
            read_with_default "Enter ADMIN_KEY for local dev" "admin_key" "123"
            update_env_var "ADMIN_KEY" "$admin_key" "$ENV_FILE"
            log_success "ADMIN_KEY updated"
        fi
    else
        local admin_key
        read_with_default "Enter ADMIN_KEY for local dev" "admin_key" "123"
        update_env_var "ADMIN_KEY" "$admin_key" "$ENV_FILE"
        log_success "ADMIN_KEY configured"
    fi

    # Pinecone
    echo ""
    if env_var_exists "PINECONE_API_KEY" "$ENV_FILE"; then
        local masked=$(get_masked_value "PINECONE_API_KEY" "$ENV_FILE")
        log_success "PINECONE_API_KEY already set ($masked)"
        if confirm "Update Pinecone credentials?" "n"; then
            local pinecone_key
            if read_secret "Enter new PINECONE_API_KEY: " "pinecone_key"; then
                update_env_var "PINECONE_API_KEY" "$pinecone_key" "$ENV_FILE"

                local pinecone_index
                read_with_default "Enter PINECONE_INDEX_NAME" "pinecone_index" "omi"
                update_env_var "PINECONE_INDEX_NAME" "$pinecone_index" "$ENV_FILE"

                log_success "Pinecone credentials updated"
            fi
        fi
    else
        log_info "Configuring Pinecone..."
        local pinecone_key
        if read_secret "Enter PINECONE_API_KEY: " "pinecone_key"; then
            update_env_var "PINECONE_API_KEY" "$pinecone_key" "$ENV_FILE"

            local pinecone_index
            read_with_default "Enter PINECONE_INDEX_NAME" "pinecone_index" "omi"
            update_env_var "PINECONE_INDEX_NAME" "$pinecone_index" "$ENV_FILE"

            log_success "Pinecone credentials configured"
        else
            log_warning "Pinecone credentials not provided"
        fi
    fi

    echo ""
    log_success "Environment variables collection complete"
    mark_step_completed "$step_name"
}

# Step 7: Setup Python virtual environment
setup_python_venv() {
    local step_name="setup_python_venv"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 7: Python venv (already completed)"
        # Activate venv if it exists for later steps
        if [[ -d "$BACKEND_PATH/venv" ]]; then
            source "$BACKEND_PATH/venv/bin/activate"
            VENV_CREATED="yes"
            VENV_PATH="$BACKEND_PATH/venv"
        else
            VENV_CREATED="no"
        fi
        export VENV_CREATED VENV_PATH
        return 0
    fi

    log_step "Step 7: Setting Up Python Virtual Environment"

    local use_venv="y"

    if confirm "Use Python virtual environment (recommended)?" "y"; then
        use_venv="y"
    else
        use_venv="n"
    fi

    if [[ "$use_venv" == "y" ]]; then
        VENV_PATH="$BACKEND_PATH/venv"

        # Show which Python version will be used
        local python_version=$($PYTHON_CMD --version 2>&1)
        log_info "Using $python_version for virtual environment"

        if [[ -d "$VENV_PATH" ]]; then
            log_warning "Virtual environment already exists at: $VENV_PATH"

            if confirm "Recreate virtual environment?" "n"; then
                log_info "Removing existing virtual environment..."
                rm -rf "$VENV_PATH"
                log_info "Creating new virtual environment with $PYTHON_CMD..."
                "$PYTHON_CMD" -m venv "$VENV_PATH"
            else
                log_info "Using existing virtual environment"
            fi
        else
            log_info "Creating virtual environment with $PYTHON_CMD..."
            "$PYTHON_CMD" -m venv "$VENV_PATH"
            log_success "Virtual environment created"
        fi

        log_info "Activating virtual environment..."
        source "$VENV_PATH/bin/activate"

        log_info "Upgrading pip and setuptools..."
        pip install --upgrade pip setuptools wheel

        log_info "Installing Python dependencies..."
        log_warning "Note: This may take several minutes..."

        # Fix for numba build errors: comprehensive approach
        log_info "Pre-installing critical dependencies to avoid build errors..."

        # Step 1: Install numpy first (required by many packages)
        log_info "Installing numpy..."
        pip install "numpy<2.0" --only-binary :all: || pip install "numpy<2.0"

        # Step 2: Install llvmlite (required by numba)
        log_info "Installing llvmlite..."
        if ! pip install --only-binary :all: llvmlite; then
            log_warning "Binary wheel not available for llvmlite, attempting source build..."
            # On macOS, ensure llvm is available
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if ! command_exists llvm-config; then
                    log_info "Installing llvm@14 for llvmlite compilation..."
                    brew install llvm@14
                fi
                # Set LLVM paths
                export LLVM_CONFIG="$(brew --prefix llvm@14)/bin/llvm-config"
                export LDFLAGS="-L$(brew --prefix llvm@14)/lib"
                export CPPFLAGS="-I$(brew --prefix llvm@14)/include"
            fi
            pip install llvmlite
        fi

        # Step 3: Install numba explicitly
        log_info "Installing numba..."
        pip install --only-binary :all: numba || {
            log_warning "Installing numba from source (this may take a few minutes)..."
            pip install numba --no-build-isolation
        }

        # Now install the rest of the dependencies, preferring binary wheels
        log_info "Installing remaining dependencies..."
        pip install -r "$BACKEND_PATH/requirements.txt" --prefer-binary || {
            log_warning "Some packages couldn't use binary wheels, retrying without restriction..."
            pip install -r "$BACKEND_PATH/requirements.txt"
        }

        log_success "Dependencies installed in virtual environment"

        VENV_CREATED="yes"
    else
        log_info "Installing dependencies globally..."

        # Apply same fix for global installation
        log_info "Pre-installing critical dependencies to avoid build errors..."

        # Install numpy first
        log_info "Installing numpy..."
        "$PIP_CMD" install "numpy<2.0" --only-binary :all: || "$PIP_CMD" install "numpy<2.0"

        # Install llvmlite
        log_info "Installing llvmlite..."
        if ! "$PIP_CMD" install --only-binary :all: llvmlite; then
            log_warning "Binary wheel not available for llvmlite, attempting source build..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if ! command_exists llvm-config; then
                    log_info "Installing llvm@14 for llvmlite compilation..."
                    brew install llvm@14
                fi
                export LLVM_CONFIG="$(brew --prefix llvm@14)/bin/llvm-config"
                export LDFLAGS="-L$(brew --prefix llvm@14)/lib"
                export CPPFLAGS="-I$(brew --prefix llvm@14)/include"
            fi
            "$PIP_CMD" install llvmlite
        fi

        # Install numba explicitly
        log_info "Installing numba..."
        "$PIP_CMD" install --only-binary :all: numba || {
            log_warning "Installing numba from source (this may take a few minutes)..."
            "$PIP_CMD" install numba --no-build-isolation
        }

        # Install remaining dependencies
        "$PIP_CMD" install -r "$BACKEND_PATH/requirements.txt" --prefer-binary || \
            "$PIP_CMD" install -r "$BACKEND_PATH/requirements.txt"

        log_success "Dependencies installed globally"

        VENV_CREATED="no"
    fi

    mark_step_completed "$step_name"
}

# Step 8: Configure Ngrok
configure_ngrok() {
    local step_name="configure_ngrok"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 8: Ngrok (already completed)"
        return 0
    fi

    log_step "Step 8: Configuring Ngrok"

    if command_exists ngrok; then
        log_success "Ngrok is already installed"
    else
        log_info "Installing Ngrok via Homebrew..."
        brew install ngrok
        log_success "Ngrok installed successfully"
    fi

    # Configure authtoken
    local ngrok_token
    echo ""
    if read_secret "Enter your Ngrok auth token: " "ngrok_token"; then
        ngrok config add-authtoken "$ngrok_token"
        log_success "Ngrok auth token configured"
    else
        log_error "Ngrok auth token is required"
        exit 1
    fi

    # Get static domain
    local ngrok_domain
    echo ""
    read_with_default "Enter your Ngrok static domain (e.g., yourapp.ngrok-free.app)" "ngrok_domain" ""

    if [[ -z "$ngrok_domain" ]]; then
        log_error "Ngrok domain is required"
        exit 1
    fi

    NGROK_DOMAIN="$ngrok_domain"

    # Save domain to file
    echo "$NGROK_DOMAIN" > "$REPO_PATH/.ngrok-domain"
    log_success "Ngrok domain saved to .ngrok-domain"

    # Update .env with base URL
    local base_url="https://$NGROK_DOMAIN"
    update_env_var "BASE_API_URL" "$base_url" "$ENV_FILE"
    log_success "BASE_API_URL configured in .env"

    mark_step_completed "$step_name"
}

# Step 9: Install Google Cloud SDK
install_gcloud_sdk() {
    local step_name="install_gcloud_sdk"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 9: Google Cloud SDK (already completed)"
        return 0
    fi

    log_step "Step 9: Installing Google Cloud SDK"

    if command_exists gcloud; then
        log_success "Google Cloud SDK is already installed"
        gcloud version

        # Check if gcloud needs updating (check for Python 3.9 deprecation warning)
        log_info "Checking for gcloud updates..."
        if brew list google-cloud-sdk &>/dev/null; then
            log_info "Updating gcloud via Homebrew..."
            brew upgrade google-cloud-sdk || log_warning "gcloud already up to date"
        else
            log_warning "gcloud not installed via Homebrew - update manually if needed"
            log_info "To update: gcloud components update"
        fi
    else
        log_info "Installing Google Cloud SDK via Homebrew..."
        brew install google-cloud-sdk

        # Source the SDK paths
        if [[ -f "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc" ]]; then
            source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
        elif [[ -f "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc" ]]; then
            source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
        fi

        log_success "Google Cloud SDK installed successfully"
    fi

    # Final verification
    local gcloud_version=$(gcloud version --format="value(version)" 2>/dev/null || echo "unknown")
    log_info "gcloud version: $gcloud_version"

    mark_step_completed "$step_name"
}

# Step 10: Configure GCP project
configure_gcp_project() {
    local step_name="configure_gcp_project"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 10: GCP Project (already completed)"
        return 0
    fi

    log_step "Step 10: Configuring Google Cloud Project"

    # Prompt for project ID
    local project_id
    read_with_default "Enter your Google Cloud Project ID" "project_id" ""

    if [[ -z "$project_id" ]]; then
        log_error "Project ID cannot be empty"
        exit 1
    fi

    GCP_PROJECT_ID="$project_id"

    log_info "Authenticating with Google Cloud..."
    log_warning "A browser window will open for authentication."

    if ! gcloud auth login; then
        log_error "Authentication failed. Please try again."
        exit 1
    fi

    log_info "Setting active project to: $GCP_PROJECT_ID"
    gcloud config set project "$GCP_PROJECT_ID"

    log_info "Setting up application default credentials..."
    log_warning "Another browser window will open."
    gcloud auth application-default login --project "$GCP_PROJECT_ID"

    # Check for credentials file
    local creds_file="$HOME/.config/gcloud/application_default_credentials.json"
    if [[ -f "$creds_file" ]]; then
        log_success "Application default credentials configured successfully"
        export GOOGLE_APPLICATION_CREDENTIALS="$creds_file"

        # Update .env with credentials path
        update_env_var "GOOGLE_APPLICATION_CREDENTIALS" "$GOOGLE_APPLICATION_CREDENTIALS" "$ENV_FILE"
        log_success "GOOGLE_APPLICATION_CREDENTIALS configured in .env"
    else
        log_warning "Could not find application default credentials at: $creds_file"
        log_warning "You may need to set GOOGLE_APPLICATION_CREDENTIALS manually"
    fi

    mark_step_completed "$step_name"
}

# Step 11: Enable required GCP APIs
enable_gcp_apis() {
    local step_name="enable_gcp_apis"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 11: GCP APIs (already completed)"
        return 0
    fi

    log_step "Step 11: Enabling Required Google Cloud APIs"

    local apis=(
        "cloudresourcemanager.googleapis.com"
        "firebase.googleapis.com"
        "firestore.googleapis.com"
    )

    for api in "${apis[@]}"; do
        log_info "Checking if $api is enabled..."

        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            log_success "$api is already enabled"
        else
            log_info "Enabling $api..."
            if gcloud services enable "$api"; then
                log_success "$api enabled successfully"
            else
                log_error "Failed to enable $api. Please enable it manually in the GCP Console."
            fi
        fi
    done

    mark_step_completed "$step_name"
}

# Step 12: Configure Firestore indexes
configure_firestore_indexes() {
    local step_name="configure_firestore_indexes"

    if is_step_completed "$step_name"; then
        log_info "⏭️  Skipping Step 12: Firestore Indexes (already completed)"
        return 0
    fi

    log_step "Step 12: Configuring Firestore Composite Indexes"

    log_warning "Firestore composite indexes must be created for proper functionality."
    echo ""
    echo "Required indexes:"
    echo "  1. Collection: 'dev_api_keys'"
    echo "     Fields: user_id (Ascending) + created_at (Descending)"
    echo ""
    echo "  2. Collection: 'mcp_api_keys'"
    echo "     Fields: user_id (Ascending) + created_at (Descending)"
    echo ""
    echo "To create these indexes:"
    echo "  1. Go to: https://console.firebase.google.com/project/$GCP_PROJECT_ID/firestore/indexes"
    echo "  2. Click 'Add Index'"
    echo "  3. For each collection above:"
    echo "     - Set Collection ID"
    echo "     - Add field: user_id → Ascending"
    echo "     - Add field: created_at → Descending"
    echo "     - Click 'Create'"
    echo ""

    read -p "Press Enter once you have created these indexes (or if they already exist)..."
    log_success "Firestore indexes configuration acknowledged"

    mark_step_completed "$step_name"
}

# Step 13: Final setup and instructions
final_instructions() {
    log_step "Step 13: Setup Complete!"

    echo ""
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "  Omi Backend Setup Completed Successfully!"
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""

    log_info "Next Steps:"
    echo ""

    echo "1. Start Ngrok tunnel (in a separate terminal):"
    echo -e "   ${GREEN}ngrok http --domain=$NGROK_DOMAIN 8000${NC}"
    echo ""

    if [[ "$VENV_CREATED" == "yes" ]]; then
        echo "2. Activate the virtual environment:"
        echo -e "   ${GREEN}cd $BACKEND_PATH${NC}"
        echo -e "   ${GREEN}source venv/bin/activate${NC}"
        echo ""
        echo "3. Start the backend:"
        echo -e "   ${GREEN}uvicorn main:app --reload --env-file .env --host 0.0.0.0 --port 8000${NC}"
    else
        echo "2. Start the backend:"
        echo -e "   ${GREEN}cd $BACKEND_PATH${NC}"
        echo -e "   ${GREEN}uvicorn main:app --reload --env-file .env --host 0.0.0.0 --port 8000${NC}"
    fi

    echo ""
    log_warning "Important Notes:"
    echo "  • Keep the Ngrok tunnel running while using the backend"
    echo "  • Your backend will be accessible at: https://$NGROK_DOMAIN"
    echo "  • Environment variables are stored in: $ENV_FILE"
    echo "  • Application credentials: $GOOGLE_APPLICATION_CREDENTIALS"
    echo ""

    log_info "Troubleshooting:"
    echo "  • If you encounter SSL model download errors, you may need to patch"
    echo "    utils/stt/vad.py to add SSL context workaround"
    echo "  • Check logs in the backend directory for any startup errors"
    echo "  • Ensure all Firebase indexes are created before running"
    echo ""

    if confirm "Do you want to start the backend now?" "n"; then
        start_backend
    else
        log_info "You can start the backend manually using the commands above"
    fi
}

# Start backend server
start_backend() {
    log_step "Starting Backend Server"

    # Make sure we're in the backend directory
    cd "$BACKEND_PATH"

    # Activate venv if it was created
    if [[ "$VENV_CREATED" == "yes" ]]; then
        log_info "Activating virtual environment..."
        source "$VENV_PATH/bin/activate"
    fi

    # Check if uvicorn is available
    if ! command_exists uvicorn; then
        log_error "uvicorn is not available. Please install it:"
        log_error "  pip install uvicorn"
        exit 1
    fi

    log_info "Starting backend server..."
    log_warning "Press Ctrl+C to stop the server"
    echo ""

    uvicorn main:app --reload --env-file .env --host 0.0.0.0 --port 8000
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --reset)
                reset_state
                shift
                ;;
            --status)
                show_progress
                exit 0
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --reset    Reset progress and start from beginning"
                echo "  --status   Show current progress"
                echo "  --help     Show this help message"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Initialize state tracking
    init_state

    clear
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "       OMI BACKEND SETUP SCRIPT FOR MACOS"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    log_warning "This script will guide you through setting up the Omi backend"
    log_warning "for local development on macOS."
    echo ""

    # Show existing progress if any
    if [[ -f "$STATE_FILE" ]]; then
        local completed_count=$(cat "$STATE_FILE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('completed_steps', [])))")
        if [[ $completed_count -gt 0 ]]; then
            log_info "📋 Resuming setup - $completed_count steps already completed"
            log_info "   (Run with --status to see details, --reset to start over)"
            echo ""
        fi
    fi

    if ! confirm "Continue with setup?" "y"; then
        log_info "Setup cancelled by user"
        exit 0
    fi

    # Run setup steps
    install_homebrew
    install_python
    install_system_dependencies
    validate_repository
    configure_env_file
    collect_env_variables
    setup_python_venv
    configure_ngrok
    install_gcloud_sdk
    configure_gcp_project
    enable_gcp_apis
    configure_firestore_indexes
    final_instructions
}

# Run main function
main "$@"
