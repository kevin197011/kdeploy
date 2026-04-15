#!/bin/bash
# Test script for Kdeploy nginx deployment

set -e

echo "🚀 Kdeploy Nginx Deployment Test Script"
echo "=========================================="
echo ""

rake run

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if vagrant is installed
if ! command -v vagrant &> /dev/null; then
    echo -e "${RED}❌ Vagrant is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if kdeploy is installed
if ! command -v kdeploy &> /dev/null; then
    echo -e "${RED}❌ Kdeploy is not installed. Please install it first:${NC}"
    echo "   gem install kdeploy"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Step 1: Start VMs
echo -e "${YELLOW}Step 1: Starting Vagrant VMs...${NC}"
vagrant up
echo ""

# Step 2: Wait for VMs to be ready and check SSH connectivity
echo -e "${YELLOW}Step 2: Waiting for VMs to be ready and checking SSH...${NC}"
sleep 5

# Check SSH connectivity using vagrant ssh
check_ssh() {
    local host=$1
    local ip=$2
    local max_attempts=15
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if vagrant ssh "$host" -c "echo 'SSH OK'" &> /dev/null 2>&1; then
            echo -e "${GREEN}✅ $host ($ip) is ready${NC}"
            return 0
        fi
        local mod_result=$((attempt % 3))
        if [ "$mod_result" -eq 0 ]; then
            echo -e "${YELLOW}⏳ Waiting for $host ($ip) to be ready... (attempt $attempt/$max_attempts)${NC}"
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    echo -e "${RED}❌ $host ($ip) is not responding after $max_attempts attempts${NC}"
    echo -e "${YELLOW}💡 Try running: vagrant ssh $host${NC}"
    return 1
}

if ! check_ssh web01 10.0.0.1; then
    echo -e "${RED}⚠️  web01 SSH check failed, but continuing...${NC}"
fi

echo ""

# # Step 3: Test connection with dry run
# echo -e "${YELLOW}Step 3: Testing connection (dry run)...${NC}"
# kdeploy execute deploy.rb --dry-run || true
# echo ""

# Step 4: Execute all tasks
echo -e "${YELLOW}Step 4: Executing all tasks...${NC}"
echo -e "${YELLOW}⚠️  This will execute ALL tasks defined in deploy.rb${NC}"
echo -e "${YELLOW}   Tasks include: nginx installation, configuration, node-exporter deployment, etc.${NC}"
echo ""
kdeploy execute deploy.rb
echo ""


