#!/bin/bash

# Fix for metabigor Go 1.26 compatibility
export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.26

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
        subfinder -all -silent -d "$domain" 2>/dev/null | anew temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Subfinder...${NC}"
            subfinder -all -silent -d "$domain" 1> temp/tmp-subfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Subfinder${NC}" &
            PID=$!
            subfinder -all -silent -d "$domain" 1> temp/tmp-subfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Subfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Subfinder: $(wc -l < temp/tmp-subfinder-"$domain") subdomains${NC}"
    fi
}

Amass() {
    if [ "$silent" == True ]; then
        amass enum -passive -d "$domain" 2>/dev/null | anew temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Amass...${NC}"
            amass enum -passive -d "$domain" 1> temp/tmp-amass-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Amass${NC}" &
            PID=$!
            amass enum -passive -d "$domain" 1> temp/tmp-amass-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Amass completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Amass: $(wc -l < temp/tmp-amass-"$domain") subdomains${NC}"
    fi
}

Assetfinder() {
    if ! command -v assetfinder >/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] assetfinder not installed, skipping${NC}"
        return
    fi
    if [ "$silent" == True ]; then
        assetfinder --subs-only "$domain" 2>/dev/null | anew temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Assetfinder...${NC}"
            assetfinder --subs-only "$domain" > temp/tmp-assetfinder-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Assetfinder${NC}" &
            PID=$!
            assetfinder --subs-only "$domain" > temp/tmp-assetfinder-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Assetfinder completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Assetfinder: $(wc -l < temp/tmp-assetfinder-"$domain") subdomains${NC}"
    fi
}

Findomain() {
    if [ "$silent" == True ]; then
        findomain -t "$domain" -q -r 2>/dev/null | anew temp-subenum-"$domain".txt
    else
        if [[ ${PARALLEL} == True ]]; then
            echo -e "${BOLD}${MAGENTA}[*] Running Findomain...${NC}"
            findomain -t "$domain" -q -r > temp/tmp-findomain-"$domain" 2>/dev/null
        else
            spinner "${BOLD}Running Findomain${NC}" &
            PID=$!
            findomain -t "$domain" -q -r > temp/tmp-findomain-"$domain" 2>/dev/null
            kill "$PID" 2>/dev/null
            printf "\r${GREEN}${BOLD}[+] Findomain completed${NC}          \n"
        fi
        echo -e "${GREEN}${BOLD}[*] Findomain: $(wc -l < temp/tmp-findomain-"$domain") subdomains${NC}"
    fi
}

Out() {
    local output=$1
    # Remove previous output file if exists
    [ -f "temp/$output" ] && rm -f "temp/$output"

    # Merge all temp files starting with tmp-
    if compgen -G "temp/tmp-*" > /dev/null; then
        sort -u temp/tmp-* > "temp/$output"
        result=$(wc -l < "temp/$output")
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
    
    ffuf -u "https://FUZZ.$domain" -w "$FFUF_WORDLIST" -t "$FFUF_THREADS" -timeout 20 -rate 100 -noninteractive -o temp/ffuf.json -of json </dev/null 2>&1 || true
    
    if [ -f temp/ffuf.json ]; then
        jq -r '.results[].url' temp/ffuf.json 2>/dev/null > temp/ffufsubdomains.txt
        rm -f temp/ffuf.json
        ffuf_count=$(wc -l < temp/ffufsubdomains.txt 2>/dev/null || echo 0)
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
    cat "temp/$subdomains_file" temp/ffufsubdomains.txt 2>/dev/null | sort -u > temp/finalsubdomains.txt
    
    # DNS resolution + HTTP probing
    dnsx -l temp/finalsubdomains.txt -silent -a 2>/dev/null | cut -d' ' -f1 | httpx -ports 80,443 -status-code -mc 200,301,302,403,500 -title -tech-detect -web-server -threads 100 -silent -o temp/alivesubdomains.txt 2>/dev/null
    
    # Filter and extract clean domains
    cat temp/alivesubdomains.txt 2>/dev/null | sort -u > temp/filtersubdomains.txt
    
    # Extract clean domain names - save to results
    cat temp/filtersubdomains.txt | awk '{print $1}' | sed 's|https\?://||' | sed 's|/$||' | sort -u > results/alive-domains.txt
    
    # Extract HTTPS URLs - save to results
    cut -d' ' -f1 temp/filtersubdomains.txt | grep "^https" > results/https-subs.txt
    
    alive_count=$(wc -l < temp/alivesubdomains.txt 2>/dev/null || echo 0)
    domains_count=$(wc -l < results/alive-domains.txt 2>/dev/null || echo 0)
    https_count=$(wc -l < results/https-subs.txt 2>/dev/null || echo 0)
    
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
        echo "$asn_org" | metabigor net --org -v 2>/dev/null | tee temp/metabigor-output.txt | grep -E "^[0-9]+ - " | awk -F' - ' '{print $1}' | sort -u > temp/asn-numbers.txt
        cat temp/metabigor-output.txt | grep -E "^[0-9]+ - .*/[0-9]+" | awk -F' - ' '{print $2}' | sort -u > temp/asn-cidrs.txt
    fi
    
    if [ -n "$asn_asn" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running ASN enumeration by ASN: $asn_asn${NC}"
        echo "$asn_asn" | metabigor net -v 2>/dev/null | tee temp/metabigor-output.txt | grep -E "^[0-9]+ - " | awk -F' - ' '{print $1}' | sort -u > temp/asn-numbers.txt
        cat temp/metabigor-output.txt | grep -E "^[0-9]+ - .*/[0-9]+" | awk -F' - ' '{print $2}' | sort -u > temp/asn-cidrs.txt
    fi
    
    if [ -n "$asn_domain" ]; then
        echo -e "${BOLD}${MAGENTA}[*] Running ASN enumeration by domain: $asn_domain${NC}"
        # Try --domain first, if no results try --org with extracted name
        echo "$asn_domain" | metabigor net --domain -v 2>/dev/null | tee temp/metabigor-output.txt | grep -E "^[0-9]+ - " | awk -F' - ' '{print $1}' | sort -u > temp/asn-numbers.txt
        cat temp/metabigor-output.txt | grep -E "^[0-9]+ - .*/[0-9]+" | awk -F' - ' '{print $2}' | sort -u > temp/asn-cidrs.txt
        
        # If no CIDRs found, try --org with the main domain name
        if [ ! -s temp/asn-cidrs.txt ]; then
            main_name=$(echo "$asn_domain" | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g')
            echo -e "${YELLOW}${BOLD}[*] Retrying with org search: $main_name${NC}"
            echo "$main_name" | metabigor net --org -v 2>/dev/null | tee temp/metabigor-output2.txt | grep -E "^[0-9]+ - " | awk -F' - ' '{print $1}' | sort -u >> temp/asn-numbers.txt
            cat temp/metabigor-output2.txt | grep -E "^[0-9]+ - .*/[0-9]+" | awk -F' - ' '{print $2}' | sort -u >> temp/asn-cidrs.txt
            rm -f temp/metabigor-output2.txt
        fi
    fi
    
    if [ -f temp/asn-numbers.txt ] && [ -s temp/asn-numbers.txt ]; then
        asn_count=$(wc -l < temp/asn-numbers.txt)
        echo -e "${GREEN}${BOLD}[*] Found $asn_count ASN numbers${NC}"
    fi
    
    rm -f temp/metabigor-output.txt
    
    if [ -f temp/asn-cidrs.txt ] && [ -s temp/asn-cidrs.txt ]; then
        cidr_count=$(wc -l < temp/asn-cidrs.txt)
        echo -e "${GREEN}${BOLD}[*] Found $cidr_count CIDR ranges${NC}"
        
        echo -e "${BOLD}${MAGENTA}[*] Analyzing CIDR sizes...${NC}"
        
        MAX_IPS=5000
        skipped_count=0
        expanded_count=0
        estimated_total=0
        
        > temp/asn-ips.txt
        
        while IFS= read -r cidr; do
            if [[ "$cidr" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)$ ]]; then
                mask="${BASH_REMATCH[2]}"
                
                if [ "$mask" -lt 22 ] || [ "$mask" -gt 24 ]; then
                    echo -e "${YELLOW}${BOLD}[-] Skipping large CIDR: $cidr${NC}"
                    ((skipped_count++))
                    continue
                fi
                
                ip_count=$((2**(32-mask)))
                new_total=$((estimated_total + ip_count))
                
                if [ "$new_total" -gt "$MAX_IPS" ]; then
                    echo -e "${YELLOW}${BOLD}[!] Reached max IP limit ($MAX_IPs). Stopping expansion.${NC}"
                    echo -e "${YELLOW}${BOLD}[!] Skipped remaining large CIDRs to prevent memory issues.${NC}"
                    break
                fi
                
                estimated_total="$new_total"
                prips "$cidr" 2>/dev/null >> temp/asn-ips.txt
                ((expanded_count++))
            fi
        done < temp/asn-cidrs.txt
        
        echo -e "${GREEN}${BOLD}[*] Expansion summary: $expanded_count CIDRs expanded, $skipped_count skipped${NC}"
        echo -e "${GREEN}${BOLD}[*] Estimated IPs: $estimated_total${NC}"
        
        if [ -f temp/asn-ips.txt ] && [ -s temp/asn-ips.txt ]; then
            ip_count=$(wc -l < temp/asn-ips.txt)
            echo -e "${GREEN}${BOLD}[*] Expanded to $ip_count IP addresses${NC}"
            
            echo -e "${BOLD}${MAGENTA}[*] Finding live IPs with HTTP service (httpx)...${NC}"
            cat temp/asn-ips.txt | httpx -threads 300 -retries 2 2>&1 | grep -E "^http" | awk '{print $1}' | sed 's|https\?://||' | cut -d':' -f1 | sort -u > temp/asn-live-ips.txt
            
            live_ip_count=$(wc -l < temp/asn-live-ips.txt 2>/dev/null || echo 0)
            echo -e "${GREEN}${BOLD}[*] Found $live_ip_count live IPs with HTTP${NC}"
            
            if [ "$live_ip_count" -gt 0 ]; then
                echo -e "${BOLD}${MAGENTA}[*] Running reverse DNS lookup on live IPs...${NC}"
                cat temp/asn-live-ips.txt | dnsx -retry 3 -threads 300 -resp-only -ptr 2>&1 | grep -v "^\[" | grep -i "$asn_domain" | sort -u > results/asnresults.txt
                
                if [ -f results/asnresults.txt ] && [ -s results/asnresults.txt ]; then
                    result_count=$(wc -l < results/asnresults.txt)
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
        
        echo "$asn_cert" | metabigor cert --clean 2>/dev/null | anew temp/cert-subdomains.txt
        
        if [ -f temp/cert-subdomains.txt ] && [ -s temp/cert-subdomains.txt ]; then
            cert_count=$(wc -l < temp/cert-subdomains.txt)
            echo -e "${GREEN}${BOLD}[*] Certificate Search: $cert_count subdomains discovered${NC}"
            
            cat temp/cert-subdomains.txt | sort -u | anew results/asnresults.txt
        else
            echo -e "${YELLOW}${BOLD}[-] No subdomains found from certificate search${NC}"
        fi
    fi
    
    if [ -f results/asnresults.txt ] && [ -s results/asnresults.txt ]; then
        total_count=$(wc -l < results/asnresults.txt)
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

# Handle Ctrl+C gracefully
cleanup() {
    echo -e "\n${YELLOW}${BOLD}[*] Interrupted by user${NC}"
    pkill -P $$ 2>/dev/null
    jobs -p | xargs -r kill 2>/dev/null
    rm -rf temp/ 2>/dev/null
    exit 130
}
trap cleanup INT

# Default values
# Auto-detect wordlist from home directory
DEFAULT_WORDLIST="$HOME/wordlists/subdomains-top1million-110000.txt"
FFUF_WORDLIST="${ffuf_wordlist:-$DEFAULT_WORDLIST}"
FFUF_THREADS="${ffuf_threads:-200}"

# Create temp and results directories
mkdir -p temp results

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

echo -e "${CYAN}${BOLD}[*] Subdomain enumeration completed.${NC}"
