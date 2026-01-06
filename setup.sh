#!/bin/bash
# =============================================================================
# Matrix Server Setup Script
# Generates deployment configuration files from templates
# =============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEPLOY_DIR="${SCRIPT_DIR}/deploy"
ALLOW_REGISTRATION="false"
ALLOW_FEDERATION="true"
ROCKSDB_CACHE_MB="256"
HOMESERVER="conduit"

# Print banner
echo -e "${BLUE}"
echo "=============================================="
echo "       Matrix Server Setup Script"
echo "=============================================="
echo -e "${NC}"

# Check if templates exist
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo -e "${RED}Error: Templates directory not found at ${TEMPLATE_DIR}${NC}"
    exit 1
fi

# Function to prompt for required input
prompt_required() {
    local var_name="$1"
    local prompt_text="$2"
    local value=""
    
    while [[ -z "$value" ]]; do
        read -p "$prompt_text: " value
        if [[ -z "$value" ]]; then
            echo -e "${RED}This field is required.${NC}"
        fi
    done
    echo "$value"
}

# Function to prompt for optional input with default
prompt_optional() {
    local prompt_text="$1"
    local default="$2"
    local value=""
    
    read -p "$prompt_text [$default]: " value
    echo "${value:-$default}"
}

# Function to prompt yes/no
prompt_yesno() {
    local prompt_text="$1"
    local default="$2"
    local value=""
    
    read -p "$prompt_text (y/n) [$default]: " value
    value="${value:-$default}"
    if [[ "$value" =~ ^[Yy] ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to prompt for homeserver choice
prompt_homeserver() {
    echo -e "${CYAN}Choose your Matrix homeserver:${NC}" >&2
    echo "" >&2
    echo "  1) Conduit  - Lightweight, fast, written in Rust" >&2
    echo "                Best for: Small deployments, low resources" >&2
    echo "" >&2
    echo "  2) Synapse  - Reference implementation, feature-complete" >&2
    echo "                Best for: Full compatibility, larger deployments" >&2
    echo "" >&2
    
    local choice=""
    while [[ ! "$choice" =~ ^[12]$ ]]; do
        read -p "Enter choice (1 or 2) [1]: " choice
        choice="${choice:-1}"
        if [[ ! "$choice" =~ ^[12]$ ]]; then
            echo -e "${RED}Please enter 1 or 2${NC}" >&2
        fi
    done
    
    if [[ "$choice" == "1" ]]; then
        echo "conduit"
    else
        echo "synapse"
    fi
}

# Function to generate random string
generate_secret() {
    openssl rand -hex "$1" 2>/dev/null || head -c "$1" /dev/urandom | xxd -p | tr -d '\n' | head -c "$((2 * $1))"
}

# Function to process template file
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    sed -e "s|{{MATRIX_DOMAIN}}|${MATRIX_DOMAIN}|g" \
        -e "s|{{LIVEKIT_DOMAIN}}|${LIVEKIT_DOMAIN}|g" \
        -e "s|{{ADMIN_EMAIL}}|${ADMIN_EMAIL}|g" \
        -e "s|{{ALLOW_REGISTRATION}}|${ALLOW_REGISTRATION}|g" \
        -e "s|{{ALLOW_FEDERATION}}|${ALLOW_FEDERATION}|g" \
        -e "s|{{ROCKSDB_CACHE_MB}}|${ROCKSDB_CACHE_MB}|g" \
        -e "s|{{LIVEKIT_API_KEY}}|${LIVEKIT_API_KEY}|g" \
        -e "s|{{LIVEKIT_API_SECRET}}|${LIVEKIT_API_SECRET}|g" \
        -e "s|{{MACAROON_SECRET}}|${MACAROON_SECRET}|g" \
        -e "s|{{FORM_SECRET}}|${FORM_SECRET}|g" \
        -e "s|{{REGISTRATION_SECRET}}|${REGISTRATION_SECRET}|g" \
        "$template_file" > "$output_file"
}

# Select homeserver
HOMESERVER=$(prompt_homeserver)
echo ""
echo -e "${GREEN}Selected: ${HOMESERVER}${NC}"
echo ""

# Set template directory based on choice
HOMESERVER_TEMPLATE_DIR="${TEMPLATE_DIR}/${HOMESERVER}"

if [[ ! -d "$HOMESERVER_TEMPLATE_DIR" ]]; then
    echo -e "${RED}Error: Template directory not found at ${HOMESERVER_TEMPLATE_DIR}${NC}"
    exit 1
fi

echo -e "${YELLOW}Please provide the following information:${NC}\n"

# Gather configuration
MATRIX_DOMAIN=$(prompt_required "MATRIX_DOMAIN" "Matrix server domain (e.g., matrix.example.com)")
LIVEKIT_DOMAIN=$(prompt_required "LIVEKIT_DOMAIN" "LiveKit server domain (e.g., livekit.example.com)")
ADMIN_EMAIL=$(prompt_required "ADMIN_EMAIL" "Admin email (for Let's Encrypt)")

echo ""
echo -e "${YELLOW}Optional configuration (press Enter for defaults):${NC}\n"

ALLOW_REGISTRATION=$(prompt_yesno "Allow public registration?" "n")
ALLOW_FEDERATION=$(prompt_yesno "Allow federation with other servers?" "y")

if [[ "$HOMESERVER" == "conduit" ]]; then
    ROCKSDB_CACHE_MB=$(prompt_optional "RocksDB cache size in MB" "256")
fi

# Generate LiveKit API credentials
echo ""
echo -e "${BLUE}Generating API credentials...${NC}"
LIVEKIT_API_KEY=$(generate_secret 16)
LIVEKIT_API_SECRET=$(generate_secret 32)

# Generate Synapse secrets if needed
if [[ "$HOMESERVER" == "synapse" ]]; then
    MACAROON_SECRET=$(generate_secret 32)
    FORM_SECRET=$(generate_secret 32)
    REGISTRATION_SECRET=$(generate_secret 32)
fi

# Create deploy directory
echo ""
echo -e "${BLUE}Creating deployment directory...${NC}"
mkdir -p "$DEPLOY_DIR"

# Process templates
echo -e "${BLUE}Processing templates...${NC}"

echo "  - docker-compose.yml"
process_template "$HOMESERVER_TEMPLATE_DIR/docker-compose.yml" "$DEPLOY_DIR/docker-compose.yml"

if [[ "$HOMESERVER" == "conduit" ]]; then
    echo "  - conduit.toml"
    process_template "$HOMESERVER_TEMPLATE_DIR/conduit.toml" "$DEPLOY_DIR/conduit.toml"
else
    echo "  - homeserver.yaml"
    process_template "$HOMESERVER_TEMPLATE_DIR/homeserver.yaml" "$DEPLOY_DIR/homeserver.yaml"
    
    echo "  - log.config"
    cp "$HOMESERVER_TEMPLATE_DIR/log.config" "$DEPLOY_DIR/log.config"
fi

echo "  - livekit.yaml"
process_template "$HOMESERVER_TEMPLATE_DIR/livekit.yaml" "$DEPLOY_DIR/livekit.yaml"

echo "  - Caddyfile"
process_template "$HOMESERVER_TEMPLATE_DIR/Caddyfile" "$DEPLOY_DIR/Caddyfile"

# Generate .env file with credentials
echo "  - .env"
cat > "$DEPLOY_DIR/.env" << EOF
# =============================================================================
# Matrix Server Environment Configuration
# Generated by setup.sh on $(date)
# Homeserver: ${HOMESERVER}
# =============================================================================

# Homeserver Type
HOMESERVER=${HOMESERVER}

# Domain Configuration
MATRIX_DOMAIN=${MATRIX_DOMAIN}
LIVEKIT_DOMAIN=${LIVEKIT_DOMAIN}
ADMIN_EMAIL=${ADMIN_EMAIL}

# LiveKit API Credentials (keep secret!)
LIVEKIT_API_KEY=${LIVEKIT_API_KEY}
LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}

# Server Configuration
ALLOW_REGISTRATION=${ALLOW_REGISTRATION}
ALLOW_FEDERATION=${ALLOW_FEDERATION}
EOF

if [[ "$HOMESERVER" == "conduit" ]]; then
    cat >> "$DEPLOY_DIR/.env" << EOF
ROCKSDB_CACHE_MB=${ROCKSDB_CACHE_MB}
EOF
else
    cat >> "$DEPLOY_DIR/.env" << EOF

# Synapse Secrets (keep these safe!)
MACAROON_SECRET=${MACAROON_SECRET}
FORM_SECRET=${FORM_SECRET}
REGISTRATION_SHARED_SECRET=${REGISTRATION_SECRET}
EOF
fi

# Print summary
echo ""
echo -e "${GREEN}=============================================="
echo "       Setup Complete!"
echo "==============================================${NC}"
echo ""
echo -e "Homeserver: ${CYAN}${HOMESERVER}${NC}"
echo -e "Deployment files created in: ${BLUE}${DEPLOY_DIR}/${NC}"
echo ""
echo -e "${YELLOW}Files generated:${NC}"
echo "  - docker-compose.yml"
if [[ "$HOMESERVER" == "conduit" ]]; then
    echo "  - conduit.toml"
else
    echo "  - homeserver.yaml"
    echo "  - log.config"
fi
echo "  - livekit.yaml"
echo "  - Caddyfile"
echo "  - .env (contains secrets)"
echo ""
echo -e "${YELLOW}LiveKit API Credentials (save these!):${NC}"
echo -e "  API Key:    ${BLUE}${LIVEKIT_API_KEY}${NC}"
echo -e "  API Secret: ${BLUE}${LIVEKIT_API_SECRET}${NC}"

if [[ "$HOMESERVER" == "synapse" ]]; then
    echo ""
    echo -e "${YELLOW}Synapse Registration Secret (for creating admin users):${NC}"
    echo -e "  ${BLUE}${REGISTRATION_SECRET}${NC}"
fi

echo ""
echo -e "${YELLOW}DNS Records Required:${NC}"
echo "  A record: ${MATRIX_DOMAIN} -> Your Server IP"
echo "  A record: ${LIVEKIT_DOMAIN} -> Your Server IP"
echo ""
echo -e "${YELLOW}Firewall Ports Required:${NC}"
echo "  TCP: 80, 443, 8448"
echo "  UDP: 443, 7882-7892"
echo ""
echo -e "${YELLOW}To start the server:${NC}"
echo -e "  cd ${DEPLOY_DIR}"
echo "  docker compose up -d"
echo ""
echo -e "${YELLOW}To view logs:${NC}"
echo "  docker compose logs -f"
echo ""

if [[ "$HOMESERVER" == "synapse" ]]; then
    echo -e "${YELLOW}To create an admin user (after starting):${NC}"
    echo "  docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -u admin -p YOUR_PASSWORD -a"
    echo ""
fi
