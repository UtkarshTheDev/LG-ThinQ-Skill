#!/bin/bash
# LG ThinQ Universal - Setup Script
# Automated setup for device discovery and skill generation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
VENV_DIR="${PROJECT_ROOT}/venv"
REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements.txt"
ENV_FILE="${PROJECT_ROOT}/.env"
SKILL_DIR="${PROJECT_ROOT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies
install_deps() {
    log_info "Setting up Python virtual environment..."
    
    if [ -d "$VENV_DIR" ]; then
        log_warn "Virtual environment exists, skipping creation"
    else
        python3 -m venv "$VENV_DIR"
        log_info "Virtual environment created at $VENV_DIR"
    fi
    
    log_info "Installing dependencies..."
    "$VENV_DIR/bin/pip" install -q -r "$REQUIREMENTS_FILE"
    log_info "Dependencies installed"
}

# Check environment variables
check_env() {
    log_info "Checking environment configuration..."
    
    source "$VENV_DIR/bin/activate"
    
    CONFIG_OUTPUT=$(python3 "$SCRIPT_DIR/lg_api_tool.py" check-config 2>/dev/null || echo "")
    echo "$CONFIG_OUTPUT"
    
    if echo "$CONFIG_OUTPUT" | grep -q "❌"; then
        log_error "Environment configuration incomplete"
        log_info "Please set LG_PAT and LG_COUNTRY in your environment or .env file"
        echo ""
        echo "Example .env content:"
        echo "LG_PAT=your_personal_access_token_here"
        echo "LG_COUNTRY=IN"
        exit 1
    fi
    
    log_info "Environment configuration OK"
}

# Save API route
save_api_route() {
    log_info "Saving API route..."
    
    source "$VENV_DIR/bin/activate"
    
    ROUTE_OUTPUT=$(python3 "$SCRIPT_DIR/lg_api_tool.py" save-route 2>/dev/null)
    
    if echo "$ROUTE_OUTPUT" | grep -q '"success": true'; then
        API_SERVER=$(echo "$ROUTE_OUTPUT" | python3 -c "import sys, json; print(json.load(sys.stdin)['apiServer'])")
        log_info "API route saved: $API_SERVER"
    else
        log_error "Failed to save API route"
        echo "$ROUTE_OUTPUT"
        exit 1
    fi
}

# Fetch and save device profiles
fetch_profiles() {
    log_info "Fetching device list..."
    
    source "$VENV_DIR/bin/activate"
    
    DEVICES_OUTPUT=$(python3 "$SCRIPT_DIR/lg_api_tool.py" list-devices 2>/dev/null)
    
    if echo "$DEVICES_OUTPUT" | grep -q '"success": false'; then
        log_error "Failed to fetch devices"
        echo "$DEVICES_OUTPUT"
        exit 1
    fi
    
    # Parse device IDs
    DEVICE_IDS=$(echo "$DEVICES_OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
devices = data.get('response', {}).get('deviceList', [])
for d in devices:
    print(d.get('deviceId', ''))
" 2>/dev/null || true)
    
    if [ -z "$DEVICE_IDS" ]; then
        log_warn "No devices found"
        return
    fi
    
    log_info "Found devices, fetching profiles..."
    
    PROFILES_DIR="${SKILL_DIR}/profiles"
    mkdir -p "$PROFILES_DIR"
    
    declare -A DEVICE_INFO
    
    for DEVICE_ID in $DEVICE_IDS; do
        PROFILE_FILE="${PROFILES_DIR}/device_${DEVICE_ID}.json"
        
        log_info "Fetching profile for: $DEVICE_ID"
        PROFILE_OUTPUT=$(python3 "$SCRIPT_DIR/lg_api_tool.py" get-profile "$DEVICE_ID" 2>/dev/null)
        
        if echo "$PROFILE_OUTPUT" | grep -q '"success": true'; then
            echo "$PROFILE_OUTPUT" > "$PROFILE_FILE"
            log_info "  Saved to: $PROFILE_FILE"
            
            # Extract device name for summary
            DEVICE_NAME=$(echo "$PROFILE_OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
props = data.get('response', {}).get('property', {})
alias = props.get('basic', {}).get('alias', {})
name = alias.get('thirdParty', alias.get('device', 'Unknown'))
print(name)
" 2>/dev/null || echo "Unknown")
            
            DEVICE_TYPE=$(echo "$PROFILE_OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
props = data.get('response', {}).get('property', {})
model = props.get('basic', {}).get('modelName', 'Unknown')
print(model)
" 2>/dev/null || echo "Unknown")
            
            DEVICE_INFO["$DEVICE_ID"]="$DEVICE_NAME|$DEVICE_TYPE|$PROFILE_FILE"
        else
            log_warn "  Failed to fetch profile for: $DEVICE_ID"
        fi
    done
    
    # Output summary JSON
    echo ""
    echo "========================================"
    log_info "Setup Complete - Devices Ready"
    echo "========================================"
    echo ""
    echo "{"
    echo "  \"success\": true,"
    echo "  \"apiServer\": \"$API_SERVER\","
    echo "  \"profilesDir\": \"$PROFILES_DIR\","
    echo "  \"devices\": ["
    
    FIRST=true
    for DEVICE_ID in $DEVICE_IDS; do
        INFO="${DEVICE_INFO[$DEVICE_ID]}"
        if [ -n "$INFO" ]; then
            IFS='|' read -r NAME TYPE PROFILE <<< "$INFO"
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo "    ,"
            fi
            echo "    {"
            echo "      \"id\": \"$DEVICE_ID\","
            echo "      \"name\": \"$NAME\","
            echo "      \"type\": \"$TYPE\","
            echo "      \"profilePath\": \"$PROFILE\""
            echo -n "    }"
        fi
    done
    
    echo ""
    echo "  ]"
    echo "}"
    echo ""
    echo "Next steps for OpenClaw:"
    echo "1. Select a device from the list above"
    echo "2. Generate control script: python3 scripts/generate_control_script.py <profile_path> > lg_control.py"
    echo "3. Create skill directory and move generated files"
}

# Main execution
main() {
    echo "========================================"
    echo "LG ThinQ Universal - Setup"
    echo "========================================"
    echo ""
    
    install_deps
    check_env
    save_api_route
    fetch_profiles
    
    log_info "Setup complete!"
}

main "$@"
