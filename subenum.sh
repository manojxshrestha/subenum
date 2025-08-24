#!/bin/bash

# Colors and styles using tput
BOLD=$(tput bold)
UNDERLINE=$(tput smul)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0) # Reset to normal
VERSION="3.0"

PRG=${0##*/}

# Source configuration file
source config.txt

# Print banner
print_banner() {
    echo -e "${BOLD}${CYAN}
               ___.
  ______ __ __ \\\_ |__    ____    ____   __ __   _____
 /  ___/|  |  \\ | __ \\  / __ \\  /    \\ |  |  \\ /     \\
 \\___ \\ |  |  / | \\_\\ \\ \\  ___/ |   |  \\|  |  /|  Y Y  \\
/____  >|____/  |___  /  \\___  >|___|  /|____/ |__|_|  /
     \\/             \\/      \\/      \\/             \\/
                           by ~/.manojxshrestha
${NC}"
    echo -e "${YELLOW}${BOLD} An Automated Subdomain Enumeration Tool. ${NC}\n"
}

# Spinner
spinner() {
    local processing="$1"
    local spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while true; do
        for char in "${spin_chars[@]}"; do
            printf "\r${CYAN}${BOLD}[%s] %s \U1F50E${NC}" "${char}" "${processing}"
            sleep 0.1
        done
    done
}

Usage() {
    echo -e "${BOLD}${GREEN}Options:${NC}"
    while read -r line; do
        printf "%b\n" "$line"
    done <<-EOF
    \r    -d, --domain            - Domain to enumerate
    \r    -l, --list              - List of root domains to enumerate
    \r    -u, --use               - Specify which tools to be used (Ex: subfinder, amass, crtsh,...)
    \r    -e, --exclude           - Specify which tools to be excluded (Ex: findomain,...)
    \r    -o, --output            - Output file to save final results (Default: <target>-Date-Time.txt)
    \r    -s, --silent            - Show only subdomains in output
    \r    -hp, --http-probe       - Probe for working http/https servers
    \r    -k, --keep              - Keep the temporary files (output from each tool)
    \r    -p, --parallel          - Run parallely for faster results. Doesn't work with -e/--exclude or -u/--use
    \r    -h, --help              - Display this help message and exit
    \r    -v, --version           - Display the version and exit
    \r    -ls, --list-sources     - Display all available sources/tools
EOF
    exit 1
}

ListSources() {
    echo -e "${BOLD}${CYAN}Available Sources/Tools:${NC}"
    echo "Subfinder"
    echo "Amass"
    echo "Assetfinder"
    echo "Findomain"
    echo "Github-subdomains"
    echo "Gitlab-subdomains"
    echo "Cero"
    echo "Shosubgo"
    echo "Crtsh"
    echo "Anubis"
    exit 1
}

Subfinder() {
    if [ "$silent" == True ]; then
        subfinder -all -silent -d "$domain" 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Subfinder...${NC}"
            subfinder -all -silent -d "$domain" 1> tmp-subfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Subfinder${NC}" &
            PID=$!
            subfinder -all -silent -d "$domain" 1> tmp-subfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Subfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Subfinder: $(wc -l < tmp-subfinder-"$domain") subdomains${NC}"
    fi
}

Amass() {
    if [ "$silent" == True ]; then
        amass enum -passive -d "$domain" 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Amass...${NC}"
            amass enum -passive -d "$domain" 1> tmp-amass-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Amass${NC}" &
            PID=$!
            amass enum -passive -d "$domain" 1> tmp-amass-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Amass completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Amass: $(wc -l < tmp-amass-"$domain") subdomains${NC}"
    fi
}

Assetfinder() {
    if ! command -v assetfinder >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] assetfinder not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        assetfinder --subs-only "$domain" 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Assetfinder...${NC}"
            assetfinder --subs-only "$domain" > tmp-assetfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Assetfinder${NC}" &
            PID=$!
            assetfinder --subs-only "$domain" > tmp-assetfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Assetfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Assetfinder: $(wc -l < tmp-assetfinder-"$domain") subdomains${NC}"
    fi
}

Findomain() {
    if [ "$silent" == True ]; then
        findomain -t "$domain" -q -r 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Findomain...${NC}"
            findomain -t "$domain" -q -r > tmp-findomain-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Findomain${NC}" &
            PID=$!
            findomain -t "$domain" -q -r > tmp-findomain-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Findomain completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Findomain: $(wc -l < tmp-findomain-"$domain") subdomains${NC}"
    fi
}

Github_subdomains() {
    if ! command -v github-subdomains >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] github-subdomains not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        github-subdomains -d "$domain" -e -raw 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Github-subdomains...${NC}"
            github-subdomains -d "$domain" -e -raw > tmp-github-subdomains-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Github-subdomains${NC}" &
            PID=$!
            github-subdomains -d "$domain" -e -raw > tmp-github-subdomains-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Github-subdomains completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Github-subdomains: $(wc -l < tmp-github-subdomains-"$domain") subdomains${NC}"
    fi
}

Gitlab_subdomains() {
    if ! command -v gitlab-subdomains >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] gitlab-subdomains not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        gitlab-subdomains -d "$domain" -e -raw 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Gitlab-subdomains...${NC}"
            gitlab-subdomains -d "$domain" -e -raw > tmp-gitlab-subdomains-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Gitlab-subdomains${NC}" &
            PID=$!
            gitlab-subdomains -d "$domain" -e -raw > tmp-gitlab-subdomains-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Gitlab-subdomains completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Gitlab-subdomains: $(wc -l < tmp-gitlab-subdomains-"$domain") subdomains${NC}"
    fi
}

Cero() {
    if ! command -v cero >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] cero not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        cero -d "$domain" -q 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Cero...${NC}"
            cero -d "$domain" -q > tmp-cero-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Cero${NC}" &
            PID=$!
            cero -d "$domain" -q > tmp-cero-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Cero completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Cero: $(wc -l < tmp-cero-"$domain") subdomains${NC}"
    fi
}

Shosubgo() {
    if ! command -v shosubgo >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] shosubgo not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        shosubgo -d "$domain" -s "$SHODAN_API_KEY" 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Shosubgo...${NC}"
            shosubgo -d "$domain" -s "$SHODAN_API_KEY" > tmp-shosubgo-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Shosubgo${NC}" &
            PID=$!
            shosubgo -d "$domain" -s "$SHODAN_API_KEY" > tmp-shosubgo-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Shosubgo completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Shosubgo: $(wc -l < tmp-shosubgo-"$domain") subdomains${NC}"
    fi
}

Crtsh() {
    if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] curl or jq not installed, skipping Crtsh${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        # Retry curl up to 3 times with 5s delay
        local response
        response=$(curl -s --retry 3 --retry-delay 5 "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null)
        if [[ -z "$response" || "$response" == *"error"* ]]; then
            echo -e "${YELLOW}${BOLD}[-] Crtsh failed: Empty or invalid response${NC}"
            return
        fi
        echo "$response" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > tmp-crtsh-raw-"$domain"
        if [ -s tmp-crtsh-raw-"$domain" ]; then
            escaped_domain=$(printf "%s" "$domain" | sed 's/\./\\./g')
            grep -Eo "([a-zA-Z0-9_-]+\.)+${escaped_domain}" tmp-crtsh-raw-"$domain" | sed 's/\.$//' | sort -u | anew subenum-"$domain".txt
        else
            echo -e "${YELLOW}${BOLD}[-] Crtsh: No valid subdomains found${NC}"
        fi
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Crtsh...${NC}"
            local response
            response=$(curl -s --retry 3 --retry-delay 5 "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null)
            if [[ -z "$response" || "$response" == *"error"* ]]; then
                echo -e "${YELLOW}${BOLD}[-] Crtsh failed: Empty or invalid response${NC}"
                return
            fi
            echo "$response" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > tmp-crtsh-raw-"$domain"
            if [ -s tmp-crtsh-raw-"$domain" ]; then
                escaped_domain=$(printf "%s" "$domain" | sed 's/\./\\./g')
                grep -Eo "([a-zA-Z0-9_-]+\.)+${escaped_domain}" tmp-crtsh-raw-"$domain" | sed 's/\.$//' | sort -u > tmp-crtsh-"$domain"
            else
                echo -e "${YELLOW}${BOLD}[-] Crtsh: No valid subdomains found${NC}"
                touch tmp-crtsh-"$domain"
            fi
        else
            spinner "${BOLD}Running Crtsh${NC}" &
            PID=$!
            local response
            response=$(curl -s --retry 3 --retry-delay 5 "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null)
            if [[ -z "$response" || "$response" == *"error"* ]]; then
                kill "$PID" 2>/dev/null
                printf "\r${YELLOW}${BOLD}[-] Crtsh failed: Empty or invalid response${NC}           \n"
                return
            fi
            echo "$response" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' > tmp-crtsh-raw-"$domain"
            if [ -s tmp-crtsh-raw-"$domain" ]; then
                escaped_domain=$(printf "%s" "$domain" | sed 's/\./\\./g')
                grep -Eo "([a-zA-Z0-9_-]+\.)+${escaped_domain}" tmp-crtsh-raw-"$domain" | sed 's/\.$//' | sort -u > tmp-crtsh-"$domain"
            else
                kill "$PID" 2>/dev/null
                printf "\r${YELLOW}${BOLD}[-] Crtsh: No valid subdomains found${NC}           \n"
                touch tmp-crtsh-"$domain"
            fi
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Crtsh completed${NC}           \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Crtsh: $(wc -l < tmp-crtsh-"$domain") subdomains${NC}"
    fi
}

Anubis() {
    if ! command -v anubis >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] anubis not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        anubis -t "$domain" -S 2>/dev/null | anew subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Anubis...${NC}"
            anubis -t "$domain" -S > tmp-anubis-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Anubis${NC}" &
            PID=$!
            anubis -t "$domain" -S > tmp-anubis-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Anubis completed${NC}           \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Anubis: $(wc -l < tmp-anubis-"$domain") subdomains${NC}"
    fi
}

Out() {
    local output=$1
    # Remove previous output file if exists
    [ -f "$output" ] && rm -f "$output"

    # Merge all temp files starting with tmp-
    if compgen -G "tmp-*" > /dev/null; then
        sort -u tmp-* > "$output"
        result=$(wc -l < "$output")
        echo -e "${GREEN}${BOLD}[+] Output saved to: $output${NC}"
        echo -e "${GREEN}${BOLD}[+] Total unique subdomains found: $result${NC}"
    else
        echo -e "${YELLOW}${BOLD}[-] No temporary files found.${NC}"
        result=0
    fi
}

# Main argument parsing
if [[ $# -eq 0 ]]; then
    print_banner
    Usage
fi

print_banner

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            domain="$2"
            shift 2
            ;;
        -l|--list)
            list="$2"
            shift 2
            ;;
        -u|--use)
            use="$2"
            shift 2
            ;;
        -e|--exclude)
            exclude="$2"
            shift 2
            ;;
        -o|--output)
            output="$2"
            shift 2
            ;;
        -s|--silent)
            silent=True
            shift
            ;;
        -hp|--http-probe)
            http_probe=True
            shift
            ;;
        -k|--keep)
            keep=True
            shift
            ;;
        -p|--parallel)
            PARALLEL=True
            shift
            ;;
        -h|--help)
            Usage
            ;;
        -v|--version)
            echo -e "${CYAN}Version: $VERSION${NC}"
            exit 0
            ;;
        -ls|--list-sources)
            ListSources
            ;;
        *)
            echo -e "${RED}${BOLD}[-] Unknown option: $1${NC}"
            Usage
            ;;
    esac
done

# Validate domain or list input
if [ -z "$domain" ] && [ -z "$list" ]; then
    echo -e "${RED}${BOLD}[-] Please specify a domain (-d) or list (-l).${NC}"
    exit 1
fi

# If list is given, read domains from file and run enumeration per domain
if [ -n "$list" ]; then
    echo -e "${BOLD}${MAGENTA}[*] Processing domains from list: $list${NC}"
    while IFS= read -r domain; do
        echo -e "${BOLD}${GREEN}[*] Enumerating: $domain${NC}"
        # Call enumeration functions
        Subfinder
        Amass
        Assetfinder
        Findomain
        Github_subdomains
        Gitlab_subdomains
        Cero
        Shosubgo
        Crtsh
        Anubis

        # Merge outputs
        Out "${output:-${domain}-$(date +%Y%m%d-%H%M%S).txt}"

        # Cleanup if not keep
        if [ "$keep" != True ]; then
            rm -f tmp-*
        fi
    done < "$list"
else
    echo -e "${BOLD}${GREEN}[*] Enumerating: $domain${NC}"
    # Call enumeration functions
    Subfinder
    Amass
    Assetfinder
    Findomain
    Github_subdomains
    Gitlab_subdomains
    Cero
    Shosubgo
    Crtsh
    Anubis

    # Merge outputs
    Out "${output:-${domain}-$(date +%Y%m%d-%H%M%S).txt}"

    # Cleanup if not keep
    if [ "$keep" != True ]; then
        rm -f tmp-*
    fi
fi

echo -e "${CYAN}${BOLD}[*] Subdomain enumeration completed.${NC}"
