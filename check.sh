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
check_tool "parallel" "parallel"
check_tool "jq" "jq"
check_tool "curl" "curl"
check_tool "python3" "python3"
check_tool "pip" "pip"
check_tool "subfinder" "subfinder"
check_tool "amass" "amass"
check_tool "assetfinder" "assetfinder"
check_tool "findomain" "findomain"
check_tool "github-subdomains" "github-subdomains"
check_tool "gitlab-subdomains" "gitlab-subdomains"
check_tool "cero" "cero"
check_tool "shosubgo" "shosubgo"
check_tool "anew" "anew"
check_tool "anubis" "anubis"

echo -e "\n${GREEN}✔ All checks completed!${RESET}"
echo "Note: If a tool is not found, ensure it’s in your PATH (run 'source ~/.bashrc' or restart your terminal)."
