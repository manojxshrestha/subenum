#!/bin/bash

# Colors
GREEN='\e[32m'
RED='\e[31m'
RESET='\e[0m'

# Helper function to check command availability
check_tool() {
    local tool=$1
    local name=$2
    if hash "$tool" 2>/dev/null; then
        printf "[%s] %bInstalled%b\n" "$name" "$GREEN" "$RESET"
    else
        printf "[%s] %bInstall Manually%b\n" "$name" "$RED" "$RESET"
    fi
}

# Check required tools for subenum
echo "Checking required tools for subenum..."
echo ""
echo "=== Core Tools ==="
check_tool "jq" "jq"

echo ""
echo "=== Subdomain Enumeration Tools ==="
check_tool "subfinder" "subfinder"
check_tool "amass" "amass"
check_tool "assetfinder" "assetfinder"
check_tool "findomain" "findomain"
check_tool "anew" "anew"

echo ""
echo "=== FFUF & HTTP Probing ==="
check_tool "ffuf" "ffuf"
check_tool "dnsx" "dnsx"
check_tool "httpx" "httpx"

echo ""
echo "=== ASN/Network Enumeration ==="
check_tool "metabigor" "metabigor"
check_tool "prips" "prips"

echo ""
echo "=== Wordlists ==="
if [ -f ~/wordlists/subdomains-top1million-110000.txt ]; then
    printf "[wordlist] %bFound%b\n" "$GREEN" "$RESET"
else
    printf "[wordlist] %bMissing - Create ~/wordlists/subdomains-top1million-110000.txt%b\n" "$RED" "$RESET"
fi

echo ""
echo "============================================"
echo -e "${GREEN}✔ All checks completed!${RESET}"
echo "Note: If a tool is not found, ensure it's in your PATH (run 'source ~/.bashrc' or restart your terminal)."
