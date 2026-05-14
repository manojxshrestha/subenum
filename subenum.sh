#!/bin/bash

# Fix for metabigor Go 1.26 compatibility
export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.24

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
    \r    -fb, --ffuf             - Run ffuf bruteforce after enumeration
    \r    -fw, --ffuf-wordlist   - Wordlist for ffuf (Default: ~/wordlists/subdomains-top1million-110000.txt)
    \r    -ft, --ffuf-threads    - FFUF threads (Default: 200)
    \r    -hp, --http-probe      - Probe for working http/https servers (requires -fb)
    \r    -ao, --asn-org         - Find IP ranges by organization name
    \r    -aa, --asn-asn         - Find IP ranges by ASN (e.g., AS13335)
    \r    -ad, --asn-domain      - Find IP ranges by domain
    \r    -ac, --asn-cert        - Search subdomains via certificate transparency
    \r    -an, --asn-enum        - Auto ASN enumeration using target domain
    \r    -es, --exclude-sensitive - Block sensitive domains (gov, mil, edu, bank, healthcare)
    \r    -p, --parallel          - Run parallely for faster results. Doesn't work with -e/--exclude or -u/--use
    \r    -h, --help              - Display this help message and exit
    \r    -v, --version           - Display the version and exit
    \r    -ls, --list-sources     - Display all available sources/tools
EOF

    echo ""
    echo -e "${BOLD}${GREEN}Examples:${NC}"
    echo "  ./subenum.sh -d example.com                    # Basic subdomain enum"
    echo "  ./subenum.sh -d example.com -fb               # With FFUF bruteforce"
    echo "  ./subenum.sh -d example.com -fb -hp          # With FFUF + HTTP probe"
    echo "  ./subenum.sh -d example.com -p               # Parallel mode (faster)"
    echo "  ./subenum.sh -d example.com -an               # With ASN enumeration"
    echo "  ./subenum.sh -d example.com -p -an            # Full mode"
    echo "  ./subenum.sh -aa AS13335                      # Standalone ASN"
    echo "  ./subenum.sh -ao 'Google'                     # By organization"
    echo ""
    exit 1
}

ListSources() {
    echo -e "${BOLD}${CYAN}Available Sources/Tools:${NC}"
    echo "Subfinder"
    echo "Amass"
    echo "Assetfinder"
    echo "Findomain"
    exit 1
}

tool_enabled() {
    local tool="$1"
    if [ -n "$use" ]; then
        echo "$use" | tr ',' '\n' | grep -qi "$tool" || return 1
    fi
    if [ -n "$exclude" ]; then
        echo "$exclude" | tr ',' '\n' | grep -qi "$tool" && return 1
    fi
    return 0
}

is_sensitive_domain() {
    local check_domain="$1"
    local patterns_file="config/sensitive-domains.txt"

    [[ ! -f "$patterns_file" ]] && return 1

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$pattern" ]] && continue

        if [[ "$pattern" == \*.* ]]; then
            local suffix="${pattern#\*.}"
            if [[ "$check_domain" == *".$suffix" ]] || [[ "$check_domain" == "$suffix" ]]; then
                return 0
            fi
        else
            if [[ "$check_domain" == "$pattern" ]] || [[ "$check_domain" == *".$pattern" ]]; then
                return 0
            fi
        fi
    done < "$patterns_file"

    return 1
}

Subfinder() {
    tool_enabled "subfinder" || return
    if [ "$silent" == True ]; then
        subfinder -all -silent -d "$domain" 2>/dev/null | anew "$OUTPUT_DIR"/temp/temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Subfinder...${NC}"
            subfinder -all -silent -d "$domain" 1> "$OUTPUT_DIR"/temp/tmp-subfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Subfinder${NC}" &
            PID=$!
            subfinder -all -silent -d "$domain" 1> "$OUTPUT_DIR"/temp/tmp-subfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Subfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Subfinder: $(wc -l < "$OUTPUT_DIR"/temp/tmp-subfinder-"$domain") subdomains${NC}"
    fi
}

Amass() {
    tool_enabled "amass" || return
    if [ "$silent" == True ]; then
        amass enum -d "$domain" 2>/dev/null | anew "$OUTPUT_DIR"/temp/temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Amass...${NC}"
            amass enum -d "$domain" 1> "$OUTPUT_DIR"/temp/tmp-amass-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Amass${NC}" &
            PID=$!
            amass enum -d "$domain" 1> "$OUTPUT_DIR"/temp/tmp-amass-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Amass completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Amass: $(wc -l < "$OUTPUT_DIR"/temp/tmp-amass-"$domain") subdomains${NC}"
    fi
}

Assetfinder() {
    tool_enabled "assetfinder" || return
    if ! command -v assetfinder >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] assetfinder not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        assetfinder --subs-only "$domain" 2>/dev/null | anew "$OUTPUT_DIR"/temp/temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Assetfinder...${NC}"
            assetfinder --subs-only "$domain" > "$OUTPUT_DIR"/temp/tmp-assetfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Assetfinder${NC}" &
            PID=$!
            assetfinder --subs-only "$domain" > "$OUTPUT_DIR"/temp/tmp-assetfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Assetfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Assetfinder: $(wc -l < "$OUTPUT_DIR"/temp/tmp-assetfinder-"$domain") subdomains${NC}"
    fi
}

Findomain() {
    tool_enabled "findomain" || return
    if [ "$silent" == True ]; then
        findomain -t "$domain" -q -r 2>/dev/null | anew "$OUTPUT_DIR"/temp/temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Findomain...${NC}"
            findomain -t "$domain" -q -r > "$OUTPUT_DIR"/temp/tmp-findomain-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Findomain${NC}" &
            PID=$!
            findomain -t "$domain" -q -r > "$OUTPUT_DIR"/temp/tmp-findomain-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Findomain completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Findomain: $(wc -l < "$OUTPUT_DIR"/temp/tmp-findomain-"$domain") subdomains${NC}"
    fi
}

Out() {
    local output=$1
    [ -f "$OUTPUT_DIR/temp/$output" ] && rm -f "$OUTPUT_DIR/temp/$output"

    if compgen -G "$OUTPUT_DIR/temp/tmp-*" > /dev/null; then
        sort -u "$OUTPUT_DIR"/temp/tmp-* > "$OUTPUT_DIR/temp/$output"
        result=$(wc -l < "$OUTPUT_DIR/temp/$output")
        echo -e "${GREEN}${BOLD}[+] Total unique subdomains found: $result${NC}"
    else
        echo -e "${YELLOW}${BOLD}[-] No temporary files found.${NC}"
        result=0
    fi
}

run_ffuf() {
    local input_file=$1
    local domain=$2
    
    if ! command -v ffuf >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] ffuf not installed, skipping${NC}"
        return
    fi
    
    if [ ! -f "$FFUF_WORDLIST" ]; then
        echo -e "${YELLOW}${BOLD}[-] Wordlist not found: $FFUF_WORDLIST, skipping ffuf${NC}"
        return
    fi
    
    echo -e "${BOLD}${MAGENTA}[*] Running FFUF bruteforce on $domain...${NC}"
    
    ffuf -u "https://FUZZ.$domain" -w "$FFUF_WORDLIST" -t "$FFUF_THREADS" -timeout 20 -rate 100 -noninteractive -o "$OUTPUT_DIR"/temp/ffuf.json -of json </dev/null 2>&1 || true
    
    if [ -f "$OUTPUT_DIR/temp/ffuf.json" ]; then
        jq -r '.results[].url' "$OUTPUT_DIR/temp/ffuf.json" 2>/dev/null > "$OUTPUT_DIR"/temp/ffufsubdomains.txt
        rm -f "$OUTPUT_DIR/temp/ffuf.json"
        ffuf_count=$(wc -l < "$OUTPUT_DIR/temp/ffufsubdomains.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}${BOLD}[*] FFUF: $ffuf_count subdomains discovered${NC}"
    else
        echo -e "${YELLOW}${BOLD}[-] FFUF failed to produce output${NC}"
    fi
}

run_http_probe() {
    local domain=$1
    local subdomains_file=$2
    
    if ! command -v dnsx >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] dnsx not installed, skipping http probe${NC}"
        return
    fi
    
    if ! command -v httpx >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] httpx not installed, skipping http probe${NC}"
        return
    fi
    
    echo -e "${BOLD}${MAGENTA}[*] Running DNSX + HTTPX probe...${NC}"
    
    # Combine subdomains + ffuf results
    cat "$OUTPUT_DIR/temp/$subdomains_file" "$OUTPUT_DIR"/temp/ffufsubdomains.txt 2>/dev/null | sort -u > "$OUTPUT_DIR"/temp/finalsubdomains.txt
    
    dnsx -l "$OUTPUT_DIR/temp/finalsubdomains.txt" -silent -a 2>/dev/null | cut -d' ' -f1 | httpx -ports 80,443 -status-code -mc 200,301,302,403,500 -title -tech-detect -web-server -threads 100 -silent -o "$OUTPUT_DIR"/temp/alivesubdomains.txt 2>/dev/null
    
    cat "$OUTPUT_DIR/temp/alivesubdomains.txt" 2>/dev/null | sort -u > "$OUTPUT_DIR"/temp/filtersubdomains.txt
    
    cat "$OUTPUT_DIR/temp/filtersubdomains.txt" | awk '{print $1}' | sed 's|https\?://||' | sed 's|/$||' | sort -u > "$OUTPUT_DIR"/alive/alive-domains.txt
    
    cut -d' ' -f1 "$OUTPUT_DIR/temp/filtersubdomains.txt" | grep "^https" > "$OUTPUT_DIR"/alive/https-subs.txt
    
    alive_count=$(wc -l < "$OUTPUT_DIR/temp/alivesubdomains.txt" 2>/dev/null || echo 0)
    domains_count=$(wc -l < "$OUTPUT_DIR/alive/alive-domains.txt" 2>/dev/null || echo 0)
    https_count=$(wc -l < "$OUTPUT_DIR/alive/https-subs.txt" 2>/dev/null || echo 0)
    
    echo -e "${GREEN}${BOLD}[*] HTTP Probe: $alive_count alive subdomains found${NC}"
    echo -e "${GREEN}${BOLD}[*] Clean domains: $domains_count${NC}"
    echo -e "${GREEN}${BOLD}[*] HTTPS URLs: $https_count${NC}"
}

run_asn_enum() {
    if ! command -v metabigor >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] metabigor not installed, skipping ASN enumeration${NC}"
        return
    fi
    
    if ! command -v prips >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] prips not installed, skipping ASN enumeration${NC}"
        return
    fi
    
    if ! command -v dnsx >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] dnsx not installed, skipping ASN enumeration${NC}"
        return
    fi
    
    if [ -n "$asn_org" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running ASN enumeration by organization: $asn_org${NC}"
        echo "$asn_org" | metabigor net --org 2>/dev/null > "$OUTPUT_DIR"/temp/asn-cidrs.txt
    fi
    
    if [ -n "$asn_asn" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running ASN enumeration by ASN: $asn_asn${NC}"
        local asn_num="${asn_asn#AS}"
        echo "$asn_num" | metabigor net --asn 2>/dev/null > "$OUTPUT_DIR"/temp/asn-cidrs.txt
    fi
    
    if [ -n "$asn_domain" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running ASN enumeration by domain: $asn_domain${NC}"
        echo "$asn_domain" | metabigor net --domain 2>/dev/null > "$OUTPUT_DIR"/temp/asn-cidrs.txt
        
        if [ ! -s "$OUTPUT_DIR/temp/asn-cidrs.txt" ]; then
            main_name=$(echo "$asn_domain" | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g')
            echo -e "${YELLOW}${BOLD}[*] Retrying with org search: $main_name${NC}"
            echo "$main_name" | metabigor net --org 2>/dev/null > "$OUTPUT_DIR"/temp/asn-cidrs.txt
        fi
    fi
    
    if [ -f "$OUTPUT_DIR/temp/asn-cidrs.txt" ] && [ -s "$OUTPUT_DIR/temp/asn-cidrs.txt" ]; then
        cidr_count=$(wc -l < "$OUTPUT_DIR/temp/asn-cidrs.txt")
        echo -e "${GREEN}${BOLD}[*] Found $cidr_count CIDR ranges${NC}"
        
        echo -e "${BOLD}${MAGENTA}[*] Analyzing CIDR sizes...${NC}"
        
        skipped_count=0
        expanded_count=0
        estimated_total=0
        
        > "$OUTPUT_DIR/temp/asn-ips.txt"
        
        while IFS= read -r cidr; do
            if [[ "$cidr" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)$ ]]; then
                mask="${BASH_REMATCH[2]}"
                
                if [ "$mask" -lt 22 ] || [ "$mask" -gt 24 ]; then
                    echo -e "${YELLOW}${BOLD}[-] Skipping large CIDR: $cidr${NC}"
                    ((skipped_count++))
                    continue
                fi
                
                estimated_total=$((estimated_total + 2**(32-mask)))
                prips "$cidr" 2>/dev/null >> "$OUTPUT_DIR"/temp/asn-ips.txt
                ((expanded_count++))
            fi
        done < "$OUTPUT_DIR/temp/asn-cidrs.txt"
        
        sort -u "$OUTPUT_DIR"/temp/asn-cidrs.txt > "$OUTPUT_DIR"/asn/cidrs.txt 2>/dev/null
        
        echo -e "${GREEN}${BOLD}[*] Expansion summary: $expanded_count CIDRs expanded, $skipped_count skipped${NC}"
        echo -e "${GREEN}${BOLD}[*] Estimated IPs: $estimated_total${NC}"
        
        if [ -f "$OUTPUT_DIR/temp/asn-ips.txt" ] && [ -s "$OUTPUT_DIR/temp/asn-ips.txt" ]; then
            ip_count=$(wc -l < "$OUTPUT_DIR/temp/asn-ips.txt")
            echo -e "${GREEN}${BOLD}[*] Expanded to $ip_count IP addresses${NC}"
            
            echo -e "${BOLD}${MAGENTA}[*] Finding live IPs with HTTP service (httpx)...${NC}"
            cat "$OUTPUT_DIR/temp/asn-ips.txt" | httpx -threads 300 -retries 2 2>&1 | grep -E "^http" | awk '{print $1}' | sed 's|https\?://||' | cut -d':' -f1 | sort -u > "$OUTPUT_DIR"/temp/asn-live-ips.txt
            
            live_ip_count=$(wc -l < "$OUTPUT_DIR/temp/asn-live-ips.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}${BOLD}[*] Found $live_ip_count live IPs with HTTP${NC}"
            
            if [ "$live_ip_count" -gt 0 ]; then
                echo -e "${BOLD}${MAGENTA}[*] Running reverse DNS lookup on live IPs...${NC}"
                cat "$OUTPUT_DIR/temp/asn-live-ips.txt" | dnsx -retry 3 -threads 300 -resp-only -ptr 2>&1 | grep -v "^\[" | grep -i "$asn_domain" | sort -u > "$OUTPUT_DIR"/asn/hostnames.txt
                
                if [ -f "$OUTPUT_DIR/asn/hostnames.txt" ] && [ -s "$OUTPUT_DIR/asn/hostnames.txt" ]; then
                    result_count=$(wc -l < "$OUTPUT_DIR/asn/hostnames.txt")
                    echo -e "${GREEN}${BOLD}[*] ASN Enumeration: $result_count hostnames discovered${NC}"
                else
                    echo -e "${YELLOW}${BOLD}[-] No hostnames found from reverse DNS${NC}"
                fi
            else
                echo -e "${YELLOW}${BOLD}[-] No live IPs found${NC}"
            fi
        else
            echo -e "${YELLOW}${BOLD}[-] Failed to expand CIDRs to IPs${NC}"
        fi
    else
        echo -e "${YELLOW}${BOLD}[-] No CIDR ranges found for the given input${NC}"
    fi
    
    if [ -n "$asn_cert" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running certificate transparency search: $asn_cert${NC}"
        
        echo "$asn_cert" | metabigor cert --clean 2>/dev/null | anew "$OUTPUT_DIR"/temp/cert-subdomains.txt
        
        if [ -f "$OUTPUT_DIR/temp/cert-subdomains.txt" ] && [ -s "$OUTPUT_DIR/temp/cert-subdomains.txt" ]; then
            cert_count=$(wc -l < "$OUTPUT_DIR/temp/cert-subdomains.txt")
            echo -e "${GREEN}${BOLD}[*] Certificate Search: $cert_count subdomains discovered${NC}"
            
            sort -u "$OUTPUT_DIR"/temp/cert-subdomains.txt > "$OUTPUT_DIR"/asn/certificates.txt 2>/dev/null
            cat "$OUTPUT_DIR"/asn/certificates.txt | anew "$OUTPUT_DIR"/asn/hostnames.txt
        else
            echo -e "${YELLOW}${BOLD}[-] No subdomains found from certificate search${NC}"
        fi
    fi
    
    if [ -f "$OUTPUT_DIR/asn/hostnames.txt" ] && [ -s "$OUTPUT_DIR/asn/hostnames.txt" ]; then
        total_count=$(wc -l < "$OUTPUT_DIR/asn/hostnames.txt")
        echo -e "${GREEN}${BOLD}[+] Total ASN results: $total_count hostnames${NC}"
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
        -fb|--ffuf)
            run_ffuf=True
            shift
            ;;
        -fw|--ffuf-wordlist)
            ffuf_wordlist="$2"
            shift 2
            ;;
        -ft|--ffuf-threads)
            ffuf_threads="$2"
            shift 2
            ;;
        -hp|--http-probe)
            http_probe=True
            shift
            ;;
        -ao|--asn-org)
            asn_org="$2"
            shift 2
            ;;
        -aa|--asn-asn)
            asn_asn="$2"
            shift 2
            ;;
        -ad|--asn-domain)
            asn_domain="$2"
            shift 2
            ;;
        -ac|--asn-cert)
            asn_cert="$2"
            shift 2
            ;;
        -an|--asn-enum)
            if [ -n "$domain" ]; then
                asn_domain="$domain"
            else
                echo -e "${YELLOW}${BOLD}[-] Domain required for ASN enumeration (-d example.com -an)${NC}"
                exit 1
            fi
            shift
            ;;
        -es|--exclude-sensitive)
            exclude_sensitive=True
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

# Default values
# Auto-detect wordlist from home directory
DEFAULT_WORDLIST="$HOME/wordlists/subdomains-top1million-110000.txt"
FFUF_WORDLIST="${ffuf_wordlist:-$DEFAULT_WORDLIST}"
FFUF_THREADS="${ffuf_threads:-200}"

# Create timestamped output directory
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_DIR="outputs/${domain:-multi}-${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"/{temp,alive,asn}

# Handle Ctrl+C gracefully
cleanup() {
    echo -e "\n${YELLOW}${BOLD}[*] Interrupted by user${NC}"
    pkill -P $$ 2>/dev/null
    jobs -p | xargs -r kill 2>/dev/null
    rm -rf "$OUTPUT_DIR" 2>/dev/null
    exit 130
}
trap cleanup INT

# Check for sensitive domains
if [ "$exclude_sensitive" == True ] && [ -n "$domain" ]; then
    if is_sensitive_domain "$domain"; then
        echo -e "${RED}${BOLD}[-] Domain '$domain' matches sensitive pattern. Use --exclude-sensitive to allow.${NC}"
        exit 1
    fi
fi

# Auto-enable ffuf and http-probe when using parallel mode
if [[ "${PARALLEL}" == True ]]; then
    run_ffuf=True
    http_probe=True
fi

# Check if any ASN enumeration is requested
ASN_REQUESTED=False
if [ -n "$asn_org" ] || [ -n "$asn_asn" ] || [ -n "$asn_domain" ] || [ -n "$asn_cert" ]; then
    ASN_REQUESTED=True
fi

# Validate domain or list input (not required if ASN is requested)
if [ -z "$domain" ] && [ -z "$list" ] && [ "$ASN_REQUESTED" != True ]; then
    echo -e "${RED}${BOLD}[-] Please specify a domain (-d) or list (-l).${NC}"
    exit 1
fi

# Run ASN enumeration if requested (can run alongside domain enum or standalone)
if [ "$ASN_REQUESTED" == True ]; then
    run_asn_enum
    
    # If no domain specified, we're done
    if [ -z "$domain" ] && [ -z "$list" ]; then
        echo -e "${CYAN}${BOLD}[*] ASN enumeration completed.${NC}"
        exit 0
    fi
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

            # Merge outputs
        SUBDOMAINS_FILE="${output:-subdomains.txt}"
        Out "$SUBDOMAINS_FILE"

        # Run FFUF bruteforce if enabled
        if [ "$run_ffuf" == True ]; then
            run_ffuf "$SUBDOMAINS_FILE" "$domain"
            
            # Run HTTP probe if enabled
            if [ "$http_probe" == True ]; then
                run_http_probe "$domain" "$SUBDOMAINS_FILE"
            fi
        fi
    done < "$list"
else
    echo -e "${BOLD}${GREEN}[*] Enumerating: $domain${NC}"
    # Call enumeration functions
    Subfinder
    Amass
    Assetfinder
    Findomain

    # Merge outputs
    SUBDOMAINS_FILE="${output:-subdomains.txt}"
    Out "$SUBDOMAINS_FILE"

    # Run FFUF bruteforce if enabled
    if [ "$run_ffuf" == True ]; then
        run_ffuf "$SUBDOMAINS_FILE" "$domain"
        
        # Run HTTP probe if enabled
        if [ "$http_probe" == True ]; then
            run_http_probe "$domain" "$SUBDOMAINS_FILE"
        fi
    fi
fi

# Save merged subdomain lists when HTTP probe is not used
if [ "$http_probe" != True ]; then
    if compgen -G "$OUTPUT_DIR/temp/tmp-*" > /dev/null 2>&1; then
        sort -u "$OUTPUT_DIR"/temp/tmp-* > "$OUTPUT_DIR"/all-subdomains.txt
        if [ -f "$OUTPUT_DIR/temp/ffufsubdomains.txt" ]; then
            cat "$OUTPUT_DIR"/all-subdomains.txt "$OUTPUT_DIR"/temp/ffufsubdomains.txt 2>/dev/null | sort -u > "$OUTPUT_DIR"/all-subdomains-ffuf.txt
        fi
    fi
fi

# Clean up temp files on success
rm -rf "$OUTPUT_DIR/temp"

echo -e "${CYAN}${BOLD}[*] Subdomain enumeration completed.${NC}"
