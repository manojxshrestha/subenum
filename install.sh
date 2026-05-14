#!/bin/bash

# Subdomain Enumeration Tool - Installation Script

set -e

# Colors
green="\033[0;32m"
red="\033[0;31m"
yellow="\033[1;33m"
bold="\033[1m"
reset="\033[0m"

# Default values
FORCE=false

# Helper
print_info() {
    echo -e "${green}${bold}[+] $1${reset}"
}
print_warn() {
    echo -e "${yellow}[!] $1${reset}"
}
print_error() {
    echo -e "${red}[-] $1${reset}"
}
print_help() {
    echo -e "${bold}Usage:${reset} $0 [OPTIONS]"
    echo ""
    echo -e "${bold}OPTIONS:${reset}"
    echo "  --check     Check installation status"
    echo "  --force     Force reinstall all tools"
    echo "  --help      Show this help message"
    echo ""
    echo -e "${bold}EXAMPLES:${reset}"
    echo "  $0              # Install all tools (skips already installed)"
    echo "  $0 --check      # Check installation status"
    echo "  $0 --force      # Force reinstall all tools"
}

# Check tool function
check_tool() {
    local tool=$1
    local name=$2
    if hash "$tool" 2>/dev/null; then
        printf "${green}[✓]${reset} %-20s Installed\n" "$name"
    else
        printf "${red}[✗]${reset} %-20s Not found\n" "$name"
    fi
}

# Check installation status
check_installation() {
    echo -e "${bold}Checking installation status...${reset}"
    echo ""

    echo -e "${bold}=== Core Tools ===${reset}"
    check_tool "parallel" "parallel"
    check_tool "jq" "jq"
    check_tool "curl" "curl"

    echo ""
    echo -e "${bold}=== Subdomain Enumeration ===${reset}"
    check_tool "subfinder" "subfinder"
    check_tool "amass" "amass"
    check_tool "assetfinder" "assetfinder"
    check_tool "findomain" "findomain"
    check_tool "anew" "anew"

    echo ""
    echo -e "${bold}=== FFUF & HTTP Probing ===${reset}"
    check_tool "ffuf" "ffuf"
    check_tool "dnsx" "dnsx"
    check_tool "httpx" "httpx"

    echo ""
    echo -e "${bold}=== ASN/Network Enumeration ===${reset}"
    check_tool "metabigor" "metabigor"
    check_tool "prips" "prips"

    echo ""
    echo -e "${bold}=== Wordlists ===${reset}"
    if [ -f ~/wordlists/subdomains-top1million-110000.txt ]; then
        printf "${green}[✓]${reset} %-20s Found\n" "wordlist"
    else
        printf "${red}[✗]${reset} %-20s Not found\n" "wordlist"
    fi

    echo ""
    echo "============================================"
}

# Install system dependencies
install_deps() {
    print_info "Installing system dependencies..."
    sudo apt update
    sudo apt install -y --fix-missing git unzip jq ca-certificates
}

# Install Go tools
install_go_tools() {
    print_info "Installing Go tools..."

    # Ensure GOPATH/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
        echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
        export PATH="$PATH:$HOME/go/bin"
    fi

    # Install tools via Go
    if [ "$FORCE" = true ] || ! command -v subfinder &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: subfinder" || print_info "Installing: subfinder"
        GO111MODULE=on go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    else
        print_warn "Skipping: subfinder (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v amass &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: amass" || print_info "Installing: amass"
        GO111MODULE=on go install -v github.com/owasp-amass/amass/v3/...@master
    else
        print_warn "Skipping: amass (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v assetfinder &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: assetfinder" || print_info "Installing: assetfinder"
        GO111MODULE=on go install github.com/tomnomnom/assetfinder@latest
    else
        print_warn "Skipping: assetfinder (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v dnsx &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: dnsx" || print_info "Installing: dnsx"
        GO111MODULE=on go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
    else
        print_warn "Skipping: dnsx (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v httpx &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: httpx" || print_info "Installing: httpx"
        GO111MODULE=on go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
    else
        print_warn "Skipping: httpx (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v ffuf &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: ffuf" || print_info "Installing: ffuf"
        GO111MODULE=on go install -v github.com/ffuf/ffuf/v2@latest
    else
        print_warn "Skipping: ffuf (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v anew &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: anew" || print_info "Installing: anew"
        GO111MODULE=on go install -v github.com/tomnomnom/anew@latest
    else
        print_warn "Skipping: anew (already installed)"
    fi

    if [ "$FORCE" = true ] || ! command -v metabigor &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: metabigor" || print_info "Installing: metabigor"
        GO111MODULE=on go install -v github.com/j3ssie/metabigor@latest
    else
        print_warn "Skipping: metabigor (already installed)"
    fi

    print_info "Go tools installed successfully"
}

# Install Findomain
install_findomain() {
    print_info "Installing Findomain..."

    if [ "$FORCE" = true ] || ! command -v findomain &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: findomain" || print_info "Installing: findomain"
        wget -q https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip
        unzip -q findomain-linux.zip
        chmod +x findomain
        sudo mv findomain /usr/bin/findomain
        rm findomain-linux.zip
        print_info "Findomain installed successfully"
    else
        print_warn "Skipping: findomain (already installed)"
    fi
}

# Install prips
install_prips() {
    print_info "Installing prips..."

    if [ "$FORCE" = true ] || ! command -v prips &> /dev/null; then
        [ "$FORCE" = true ] && print_info "Forcing install: prips" || print_info "Installing: prips"
        GO111MODULE=on go install github.com/imusabkhan/prips@latest
        print_info "prips installed successfully"
    else
        print_warn "Skipping: prips (already installed)"
    fi
}

# Main installation
install_all() {
    print_info "Starting installation..."
    echo ""

    install_deps
    install_go_tools
    install_findomain
    install_prips

    print_info "Setting up wordlists directory..."
    if [ ! -d ~/wordlists ]; then
        mkdir -p ~/wordlists
        print_info "Created ~/wordlists directory"
    else
        print_warn "Wordlists directory already exists"
    fi

    echo ""
    print_info "✔ All tools installed successfully!"
    print_info "Make sure to reload your shell (run: source ~/.bashrc)"
    print_info "Place your wordlist at: ~/wordlists/subdomains-top1million-110000.txt"
}

# Parse arguments
case "${1:-}" in
    --check)
        check_installation
        exit 0
        ;;
    --help|-h)
        print_help
        exit 0
        ;;
    --force)
        FORCE=true
        install_all
        exit 0
        ;;
    --)
        install_all
        exit 0
        ;;
    "")
        install_all
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        print_help
        exit 1
        ;;
esac
