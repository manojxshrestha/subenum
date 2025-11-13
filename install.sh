#!/bin/bash

# Subdomain Enumeration Tool - Installation Script

set -e

# Colors
green="\033[0;32m"
red="\033[0;31m"
bold="\033[1m"
reset="\033[0m"

# Helper
print_info() {
    echo -e "${green}${bold}[+] $1${reset}"
}
print_error() {
    echo -e "${red}[-] $1${reset}"
}

print_info "Installing system dependencies..."
sudo apt update
sudo apt install -y git python3-pip python3-venv python3-dev libssl-dev libffi-dev nmap unzip
sudo apt install -y jq curl ca-certificates moreutils parallel

print_info "Installing pipx (for Python CLI tools like Anubis)..."
if ! command -v pipx &> /dev/null; then
    sudo apt install -y pipx
    pipx ensurepath
    source ~/.bashrc  # Ensure pipx is available in current session
fi

print_info "Installing Go tools..."

# Ensure GOPATH/bin is in PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/go/bin"
fi

# Install tools via Go
GO111MODULE=on go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
GO111MODULE=on go install -v github.com/owasp-amass/amass/v3/...@master
GO111MODULE=on go install github.com/tomnomnom/assetfinder@latest
GO111MODULE=on go install -v github.com/gwen001/github-subdomains@latest
GO111MODULE=on go install github.com/gwen001/gitlab-subdomains@latest
GO111MODULE=on go install -v github.com/glebarez/cero@latest
GO111MODULE=on go install github.com/incogbyte/shosubgo@latest
GO111MODULE=on go install -v github.com/tomnomnom/anew@latest

print_info "Installing Findomain..."
wget -q https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip
unzip -q findomain-linux.zip
chmod +x findomain
sudo mv findomain /usr/bin/findomain
rm findomain-linux.zip

print_info "Installing Anubis..."
if ! command -v anubis &> /dev/null; then
    git clone https://github.com/jonluca/Anubis.git
    cd Anubis
    pipx install .
    cd ..
    rm -rf Anubis
    print_info "Anubis installed successfully via pipx"
else
    print_info "Anubis is already installed"
fi

print_info "✔ All tools installed successfully! Make sure to reload your shell (or run: source ~/.bashrc) if needed"
