#!/bin/bash

# Fix for metabigor Go compatibility
export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.24

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

VERSION="3.0"

# ─── Banner ───────────────────────────────────────────────────────────────────
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

# ─── Spinner ──────────────────────────────────────────────────────────────────
spinner() {
    local label="$1"
    local spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while true; do
        for char in "${spin_chars[@]}"; do
            printf "\r${CYAN}${BOLD}[%s] %s 🔎${NC}" "${char}" "${label}"
            sleep 0.1
        done
    done
}

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}${GREEN}Options:${NC}"
    cat <<-EOF
    -d, --domain            Domain to enumerate
    -l, --list              File containing list of root domains to enumerate
    -u, --use               Comma-separated tools to use       (e.g. subfinder,findomain)
    -e, --exclude           Comma-separated tools to exclude   (e.g. assetfinder)
    -o, --output            Output filename  (Default: subdomains.txt inside output dir)
    -s, --silent            Show only subdomains in output
    -fb, --ffuf             Run ffuf bruteforce after enumeration
    -fw, --ffuf-wordlist    Wordlist for ffuf (Default: ~/wordlists/subdomains-top1million-110000.txt)
    -ft, --ffuf-threads     FFUF threads (Default: 300)
    -fr, --ffuf-rate        FFUF request rate/sec (Default: 300, 0 = unlimited)
    -hp, --http-probe       Probe subdomains for live http/https servers
    -ao, --asn-org          Find IP ranges by organization name
    -aa, --asn-asn          Find IP ranges by ASN (e.g. AS13335)
    -ad, --asn-domain       Find IP ranges by domain
    -ac, --asn-cert         Search subdomains via certificate transparency
    -an, --asn-enum         Auto ASN enumeration using target domain (requires -d)
    -es, --exclude-sensitive  Block enumeration on sensitive domains (gov, mil, edu, bank, healthcare)
    -p,  --parallel         Run tools in parallel for faster results (enables -hp automatically)
    -h,  --help             Display this help message and exit
    -v,  --version          Display version and exit
    -ls, --list-sources     Display all available sources/tools
EOF

    echo ""
    echo -e "${BOLD}${GREEN}Examples:${NC}"
    echo "  ./subenum.sh -d example.com                   # Basic subdomain enum"
    echo "  ./subenum.sh -d example.com -hp               # With HTTP probe only"
    echo "  ./subenum.sh -d example.com -fb               # With FFUF bruteforce"
    echo "  ./subenum.sh -d example.com -fb -hp           # With FFUF + HTTP probe"
    echo "  ./subenum.sh -d example.com -p                # Parallel mode (faster)"
    echo "  ./subenum.sh -d example.com -an               # With auto ASN enumeration"
    echo "  ./subenum.sh -d example.com -p -an            # Full parallel mode"
    echo "  ./subenum.sh -l domains.txt                   # Enumerate from list"
    echo "  ./subenum.sh -aa AS13335                      # Standalone ASN lookup"
    echo "  ./subenum.sh -ao 'Google'                     # ASN by organization"
    echo ""
    exit 1
}

# ─── List Sources ─────────────────────────────────────────────────────────────
list_sources() {
    echo -e "${BOLD}${CYAN}Available Sources/Tools:${NC}"
    echo "  - subfinder"
    echo "  - assetfinder"
    echo "  - findomain"
    exit 0
}

# ─── Tool Filter ──────────────────────────────────────────────────────────────
# Returns 0 (enabled) or 1 (disabled) for a given tool name.
tool_enabled() {
    local tool="$1"
    if [[ -n "$USE" ]]; then
        echo "$USE" | tr ',' '\n' | grep -qi "^${tool}$" || return 1
    fi
    if [[ -n "$EXCLUDE" ]]; then
        echo "$EXCLUDE" | tr ',' '\n' | grep -qi "^${tool}$" && return 1
    fi
    return 0
}

# ─── Sensitive Domain Check ───────────────────────────────────────────────────
is_sensitive_domain() {
    local check_domain="$1"
    local patterns_file="config/sensitive-domains.txt"

    [[ ! -f "$patterns_file" ]] && return 1

    while IFS= read -r pattern; do
        # Skip blank lines and comments
        [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$pattern" ]] && continue

        if [[ "$pattern" == \*.* ]]; then
            local suffix="${pattern#\*.}"
            [[ "$check_domain" == *".$suffix" || "$check_domain" == "$suffix" ]] && return 0
        else
            [[ "$check_domain" == "$pattern" || "$check_domain" == *".$pattern" ]] && return 0
        fi
    done < "$patterns_file"

    return 1
}

# ─── Per-domain temp dir helper ───────────────────────────────────────────────
# Each domain gets its own temp subdirectory to avoid result cross-contamination
# when processing a list of domains.
domain_temp_dir() {
    echo "${OUTPUT_DIR}/temp/${1}"
}

# ─── Enumeration Tools ────────────────────────────────────────────────────────
run_subfinder() {
    local dom="$1"
    tool_enabled "subfinder" || return
    if ! command -v subfinder &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] subfinder not installed, skipping${NC}"
        return
    fi
    local tmpdir
    tmpdir=$(domain_temp_dir "$dom")
    mkdir -p "$tmpdir"

    if [[ "$SILENT" == True ]]; then
        subfinder -all -silent -d "$dom" 2>/dev/null \
            | anew "${OUTPUT_DIR}/temp/temp-subenum-${dom}.txt"
    elif [[ "$PARALLEL" == True ]]; then
        echo -e "${BOLD}${MAGENTA}[*] Running Subfinder...${NC}"
        subfinder -all -silent -d "$dom" 1>"${tmpdir}/subfinder.txt" 2>/dev/null
        echo -e "${GREEN}${BOLD}[*] Subfinder: $(wc -l < "${tmpdir}/subfinder.txt") subdomains${NC}"
    else
        spinner "Running Subfinder" &
        local pid=$!
        subfinder -all -silent -d "$dom" 1>"${tmpdir}/subfinder.txt" 2>/dev/null
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        printf "\r${GREEN}${BOLD}[+] Subfinder completed${NC}                    \n"
        echo -e "${GREEN}${BOLD}[*] Subfinder: $(wc -l < "${tmpdir}/subfinder.txt") subdomains${NC}"
    fi
}

run_assetfinder() {
    local dom="$1"
    tool_enabled "assetfinder" || return
    if ! command -v assetfinder &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] assetfinder not installed, skipping${NC}"
        return
    fi
    local tmpdir
    tmpdir=$(domain_temp_dir "$dom")
    mkdir -p "$tmpdir"

    if [[ "$SILENT" == True ]]; then
        assetfinder --subs-only "$dom" 2>/dev/null \
            | anew "${OUTPUT_DIR}/temp/temp-subenum-${dom}.txt"
    elif [[ "$PARALLEL" == True ]]; then
        echo -e "${BOLD}${MAGENTA}[*] Running Assetfinder...${NC}"
        assetfinder --subs-only "$dom" 1>"${tmpdir}/assetfinder.txt" 2>/dev/null
        echo -e "${GREEN}${BOLD}[*] Assetfinder: $(wc -l < "${tmpdir}/assetfinder.txt") subdomains${NC}"
    else
        spinner "Running Assetfinder" &
        local pid=$!
        assetfinder --subs-only "$dom" 1>"${tmpdir}/assetfinder.txt" 2>/dev/null
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        printf "\r${GREEN}${BOLD}[+] Assetfinder completed${NC}                    \n"
        echo -e "${GREEN}${BOLD}[*] Assetfinder: $(wc -l < "${tmpdir}/assetfinder.txt") subdomains${NC}"
    fi
}

run_findomain() {
    local dom="$1"
    tool_enabled "findomain" || return
    if ! command -v findomain &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] findomain not installed, skipping${NC}"
        return
    fi
    local tmpdir
    tmpdir=$(domain_temp_dir "$dom")
    mkdir -p "$tmpdir"

    if [[ "$SILENT" == True ]]; then
        findomain -t "$dom" -q -r 2>/dev/null \
            | anew "${OUTPUT_DIR}/temp/temp-subenum-${dom}.txt"
    elif [[ "$PARALLEL" == True ]]; then
        echo -e "${BOLD}${MAGENTA}[*] Running Findomain...${NC}"
        findomain -t "$dom" -q -r 1>"${tmpdir}/findomain.txt" 2>/dev/null
        echo -e "${GREEN}${BOLD}[*] Findomain: $(wc -l < "${tmpdir}/findomain.txt") subdomains${NC}"
    else
        spinner "Running Findomain" &
        local pid=$!
        findomain -t "$dom" -q -r 1>"${tmpdir}/findomain.txt" 2>/dev/null
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        printf "\r${GREEN}${BOLD}[+] Findomain completed${NC}                    \n"
        echo -e "${GREEN}${BOLD}[*] Findomain: $(wc -l < "${tmpdir}/findomain.txt") subdomains${NC}"
    fi
}

# ─── Merge Results ────────────────────────────────────────────────────────────
# Merges all per-tool temp files for a single domain into one deduplicated file.
# FIX: each domain now writes to its own subdirectory so list-mode runs don't
#      cross-contaminate results across domains.
# FIX: path returned via $MERGE_RESULT global so color output never corrupts
#      the value when callers previously used $() to capture it.
MERGE_RESULT=""
merge_results() {
    local dom="$1"
    local out_file="$2"
    local tmpdir
    tmpdir=$(domain_temp_dir "$dom")
    local prefix=""; [[ -n "$LIST" ]] && prefix="${dom}-"
    local dest="${OUTPUT_DIR}/${prefix}${out_file}"
    MERGE_RESULT=""

    if compgen -G "${tmpdir}/*.txt" &>/dev/null; then
        sort -u "${tmpdir}"/*.txt > "$dest"
        local count
        count=$(wc -l < "$dest")
        echo -e "${GREEN}${BOLD}[+] Total unique subdomains found for ${dom}: ${count}${NC}"
        MERGE_RESULT="$dest"
    else
        echo -e "${YELLOW}${BOLD}[-] No results found for ${dom}.${NC}"
    fi
}

# ─── DNS Wildcard Filter ──────────────────────────────────────────────────────
# Reads hostnames from stdin, resolves them alongside random probe hosts, and
# drops any host sharing an A record with a probe (a wildcard DNS signature).
# Backstops ffuf auto-calibration against catch-alls that reflect input text.
filter_wildcard_hosts() {
    local dom="$1"
    command -v dnsx &>/dev/null || { cat; return; }
    command -v jq  &>/dev/null || { cat; return; }

    local tmp="${OUTPUT_DIR}/temp/${dom}-wildcard.txt"
    local probes
    probes="rnd-${RANDOM}${RANDOM}-1.${dom}
rnd-${RANDOM}${RANDOM}-2.${dom}"

    { cat; printf '%s\n' "$probes"; } \
        | dnsx -a -resp -json -silent 2>/dev/null \
        | jq -r '.host + "\t" + (.a[] // "")' 2>/dev/null \
        | sort -u > "$tmp"

    [[ -s "$tmp" ]] || { rm -f "$tmp"; return; }

    local probe_ips
    probe_ips=$(printf '%s\n' "$probes" | while IFS= read -r p; do
        awk -F'\t' -v h="$p" '$1 == h { print $2 }' "$tmp"
    done | sort -u)

    awk -F'\t' -v filter="$probe_ips" '
        BEGIN { n = split(filter, ips, "\n"); for (i = 1; i <= n; i++) bad[ips[i]] = 1 }
        ($2 != "" && !($2 in bad)) { print $1 }
    ' "$tmp" | sort -u

    rm -f "$tmp"
}

# ─── FFUF Bruteforce ──────────────────────────────────────────────────────────
# FIX: now actually uses the merged subdomains file path passed in as $1
run_ffuf() {
    local subdomains_file="$1"
    local dom="$2"

    if ! command -v ffuf &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] ffuf not installed, skipping${NC}"
        return
    fi
    if [[ ! -f "$FFUF_WORDLIST" ]]; then
        echo -e "${YELLOW}${BOLD}[-] Wordlist not found: $FFUF_WORDLIST, skipping ffuf${NC}"
        return
    fi

    echo -e "${BOLD}${MAGENTA}[*] Running FFUF bruteforce on ${dom}...${NC}"
    local ffuf_json="${OUTPUT_DIR}/temp/${dom}-ffuf.json"

    ffuf -u "https://FUZZ.${dom}" \
         -w "$FFUF_WORDLIST" \
         -t "$FFUF_THREADS" \
         -timeout 20 \
         -rate "$FFUF_RATE" \
         -ac \
         -o "$ffuf_json" \
         -of json || true

    local ffuf_out="${OUTPUT_DIR}/temp/${dom}-ffufsubdomains.txt"
    if [[ -f "$ffuf_json" ]]; then
        jq -r '.results[].url' "$ffuf_json" 2>/dev/null \
            | sed 's|^https\?://||; s|/.*||' \
            | sort -u \
            | filter_wildcard_hosts "$dom" \
            > "$ffuf_out"
        rm -f "$ffuf_json"
        local ffuf_count
        ffuf_count=$(wc -l < "$ffuf_out" 2>/dev/null || echo 0)
        echo -e "${GREEN}${BOLD}[*] FFUF: ${ffuf_count} subdomains discovered${NC}"
    else
        echo -e "${YELLOW}${BOLD}[-] FFUF produced no output${NC}"
        touch "$ffuf_out"   # ensure file exists for later cat operations
    fi
}

# ─── HTTP Probe ───────────────────────────────────────────────────────────────
run_http_probe() {
    local dom="$1"
    local subdomains_file="$2"

    if ! command -v dnsx &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] dnsx not installed, skipping http probe${NC}"
        return
    fi
    if ! command -v httpx &>/dev/null; then
        echo -e "${YELLOW}${BOLD}[-] httpx not installed, skipping http probe${NC}"
        return
    fi

    echo -e "${BOLD}${MAGENTA}[*] Running DNSX + HTTPX probe for ${dom}...${NC}"

    local ffuf_out="${OUTPUT_DIR}/temp/${dom}-ffufsubdomains.txt"
    local final_subs="${OUTPUT_DIR}/temp/${dom}-finalsubdomains.txt"
    local alive_raw="${OUTPUT_DIR}/temp/${dom}-alive.txt"
    local prefix=""; [[ -n "$LIST" ]] && prefix="${dom}-"
    local alive_clean="${OUTPUT_DIR}/alive/${prefix}alive-domains.txt"
    local https_only="${OUTPUT_DIR}/alive/${prefix}https-subs.txt"

    # Combine enumeration + ffuf results (ffuf file may not exist — tolerate that)
    cat "$subdomains_file" "$ffuf_out" 2>/dev/null | sort -u > "$final_subs"

    dnsx -l "$final_subs" -silent -a 2>/dev/null \
        | cut -d' ' -f1 \
        | httpx -ports 80,443 \
                -status-code \
                -mc 200,301,302,403,500 \
                -title \
                -tech-detect \
                -web-server \
                -threads 200 \
                -silent \
                -o "$alive_raw" 2>/dev/null

    # Clean domain list (strip URL scheme / path / trailing slash)
    awk '{print $1}' "$alive_raw" 2>/dev/null \
        | sed 's|https\?://||; s|/$||' \
        | sort -u > "$alive_clean"

    # HTTPS-only URLs
    cut -d' ' -f1 "$alive_raw" 2>/dev/null \
        | grep "^https" \
        | sort -u > "$https_only"

    local alive_count domains_count https_count
    alive_count=$(wc -l < "$alive_raw"   2>/dev/null || echo 0)
    domains_count=$(wc -l < "$alive_clean" 2>/dev/null || echo 0)
    https_count=$(wc -l < "$https_only"  2>/dev/null || echo 0)

    echo -e "${GREEN}${BOLD}[*] HTTP Probe  : ${alive_count} alive subdomains${NC}"
    echo -e "${GREEN}${BOLD}[*] Clean domains: ${domains_count}${NC}"
    echo -e "${GREEN}${BOLD}[*] HTTPS URLs  : ${https_count}${NC}"
}

# ─── ASN Enumeration ──────────────────────────────────────────────────────────
run_asn_enum() {
    local missing=()
    command -v metabigor &>/dev/null || missing+=("metabigor")
    command -v prips     &>/dev/null || missing+=("prips")
    command -v dnsx      &>/dev/null || missing+=("dnsx")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}[-] Missing tools for ASN enumeration: ${missing[*]} — skipping${NC}"
        return
    fi

    local cidr_file="${OUTPUT_DIR}/temp/asn-cidrs.txt"

    # ── Collect CIDRs ─────────────────────────────────────────────────────────
    if [[ -n "$ASN_ORG" ]]; then
        echo -e "${BOLD}${MAGENTA}[*] ASN lookup by organization: ${ASN_ORG}${NC}"
        echo "$ASN_ORG" | metabigor net --org 2>/dev/null > "$cidr_file"
    fi

    if [[ -n "$ASN_ASN" ]]; then
        echo -e "${BOLD}${MAGENTA}[*] ASN lookup by ASN: ${ASN_ASN}${NC}"
        local asn_num="${ASN_ASN#AS}"
        echo "$asn_num" | metabigor net --asn 2>/dev/null > "$cidr_file"
    fi

    if [[ -n "$ASN_DOMAIN" ]]; then
        echo -e "${BOLD}${MAGENTA}[*] ASN lookup by domain: ${ASN_DOMAIN}${NC}"
        echo "$ASN_DOMAIN" | metabigor net --domain 2>/dev/null > "$cidr_file"

        # Fallback to org search when domain lookup returns nothing
        if [[ ! -s "$cidr_file" ]]; then
            local org_name
            org_name=$(echo "$ASN_DOMAIN" | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g')
            echo -e "${YELLOW}${BOLD}[*] Retrying with org search: ${org_name}${NC}"
            echo "$org_name" | metabigor net --org 2>/dev/null > "$cidr_file"
        fi
    fi

    # ── Expand CIDRs → IPs ────────────────────────────────────────────────────
    if [[ -f "$cidr_file" && -s "$cidr_file" ]]; then
        local cidr_count
        cidr_count=$(wc -l < "$cidr_file")
        echo -e "${GREEN}${BOLD}[*] Found ${cidr_count} CIDR ranges${NC}"
        echo -e "${BOLD}${MAGENTA}[*] Analyzing CIDR sizes...${NC}"

        local ip_file="${OUTPUT_DIR}/temp/asn-ips.txt"
        local skipped=0 expanded=0 total_ips=0
        local max_ips=50000
        true > "$ip_file"

        while IFS= read -r cidr; do
            [[ "$cidr" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/([0-9]+)$ ]] || continue
            local mask="${BASH_REMATCH[2]}"

            # Skip CIDRs outside /16–/24 range (too large or too small)
            if (( mask < 16 || mask > 24 )); then
                echo -e "${YELLOW}${BOLD}[-] Skipping out-of-range CIDR: ${cidr}${NC}"
                (( skipped++ ))
                continue
            fi

            local cidr_ips=$(( 2 ** (32 - mask) ))

            if (( total_ips >= max_ips )); then
                echo -e "${YELLOW}${BOLD}[-] Reached ${max_ips} IP limit, skipping: ${cidr}${NC}"
                (( skipped++ ))
                continue
            fi

            if (( total_ips + cidr_ips > max_ips )); then
                local remaining=$(( max_ips - total_ips ))
                echo -e "${YELLOW}${BOLD}[-] Truncating ${cidr} to ${remaining} IPs${NC}"
                prips "$cidr" 2>/dev/null | head -"$remaining" >> "$ip_file"
                total_ips=$max_ips
            else
                prips "$cidr" 2>/dev/null >> "$ip_file"
                (( total_ips += cidr_ips ))
            fi
            (( expanded++ ))
        done < "$cidr_file"

        sort -u "$cidr_file" > "${OUTPUT_DIR}/asn/cidrs.txt"
        echo -e "${GREEN}${BOLD}[*] CIDRs expanded: ${expanded}, skipped: ${skipped}, IPs: ${total_ips}${NC}"

        # ── Probe live IPs ────────────────────────────────────────────────────
        if [[ -s "$ip_file" ]]; then
            local ip_count
            ip_count=$(wc -l < "$ip_file")
            echo -e "${GREEN}${BOLD}[*] Expanded to ${ip_count} IPs${NC}"
            echo -e "${BOLD}${MAGENTA}[*] Finding live IPs via httpx...${NC}"

            local live_ips="${OUTPUT_DIR}/temp/asn-live-ips.txt"
            head -5000 "$ip_file" \
                | httpx -ports 80,443 -threads 200 -timeout 5 -retries 1 -silent 2>/dev/null \
                | awk '{print $1}' \
                | sed 's|https\?://||; s|:.*||' \
                | sort -u > "$live_ips"

            local live_count
            live_count=$(wc -l < "$live_ips" 2>/dev/null || echo 0)
            echo -e "${GREEN}${BOLD}[*] Live IPs with HTTP: ${live_count}${NC}"

            # ── Reverse DNS ───────────────────────────────────────────────────
            if (( live_count > 0 )); then
                echo -e "${BOLD}${MAGENTA}[*] Running reverse DNS on live IPs...${NC}"
                local ptr_filter="${ASN_DOMAIN:-${domain}}"
                dnsx -l "$live_ips" -retry 3 -threads 300 -resp-only -ptr 2>&1 \
                    | grep -v "^\[" \
                    | grep -i "$ptr_filter" \
                    | sort -u > "${OUTPUT_DIR}/asn/hostnames.txt"

                if [[ -s "${OUTPUT_DIR}/asn/hostnames.txt" ]]; then
                    echo -e "${GREEN}${BOLD}[*] ASN hostnames discovered: $(wc -l < "${OUTPUT_DIR}/asn/hostnames.txt")${NC}"
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
        echo -e "${YELLOW}${BOLD}[-] No CIDR ranges found${NC}"
    fi

    # ── Certificate Transparency ──────────────────────────────────────────────
    if [[ -n "$ASN_CERT" ]]; then
        echo -e "${BOLD}${MAGENTA}[*] Certificate transparency search: ${ASN_CERT}${NC}"
        local cert_file="${OUTPUT_DIR}/temp/cert-subdomains.txt"
        echo "$ASN_CERT" | metabigor cert --clean 2>/dev/null | anew "$cert_file"

        if [[ -s "$cert_file" ]]; then
            local cert_count
            cert_count=$(wc -l < "$cert_file")
            echo -e "${GREEN}${BOLD}[*] Certificate Search: ${cert_count} subdomains${NC}"
            sort -u "$cert_file" > "${OUTPUT_DIR}/asn/certificates.txt"
            anew "${OUTPUT_DIR}/asn/hostnames.txt" < "${OUTPUT_DIR}/asn/certificates.txt"
        else
            echo -e "${YELLOW}${BOLD}[-] No subdomains found via certificate search${NC}"
        fi
    fi

    if [[ -s "${OUTPUT_DIR}/asn/hostnames.txt" ]]; then
        echo -e "${GREEN}${BOLD}[+] Total ASN results: $(wc -l < "${OUTPUT_DIR}/asn/hostnames.txt") hostnames${NC}"
    fi
}

# ─── Enumerate one domain ─────────────────────────────────────────────────────
enumerate_domain() {
    local dom="$1"
    echo -e "\n${BOLD}${GREEN}[*] Enumerating: ${dom}${NC}"

    if [[ "$PARALLEL" == True ]]; then
        run_subfinder   "$dom" &
        run_assetfinder "$dom" &
        run_findomain   "$dom" &
        wait
    else
        run_subfinder   "$dom"
        run_assetfinder "$dom"
        run_findomain   "$dom"
    fi

    local out_file="${OUTPUT_FILE:-subdomains.txt}"
    merge_results "$dom" "$out_file"
    local merged="$MERGE_RESULT"

    # FFUF bruteforce
    if [[ "$RUN_FFUF" == True && -n "$merged" ]]; then
        run_ffuf "$merged" "$dom"
    fi

    # HTTP probe
    if [[ "$HTTP_PROBE" == True && -n "$merged" ]]; then
        run_http_probe "$dom" "$merged"
    fi

    # Final merged file (no http-probe path)
    if [[ "$HTTP_PROBE" != True ]]; then
        local prefix=""; [[ -n "$LIST" ]] && prefix="${dom}-"
        local all_file="${OUTPUT_DIR}/${prefix}all-subdomains.txt"
        cp "$merged" "$all_file" 2>/dev/null

        local ffuf_out="${OUTPUT_DIR}/temp/${dom}-ffufsubdomains.txt"
        if [[ -f "$ffuf_out" && -s "$ffuf_out" ]]; then
            cat "$all_file" "$ffuf_out" | sort -u \
                > "${OUTPUT_DIR}/${prefix}all-subdomains-ffuf.txt"
        fi
    fi
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    print_banner
    usage
fi

print_banner

# Uppercase globals to avoid shadowing local variables in functions
DOMAIN=""
LIST=""
USE=""
EXCLUDE=""

OUTPUT_FILE=""
SILENT=False
RUN_FFUF=False
FFUF_WORDLIST=""
FFUF_THREADS=""
FFUF_RATE=""
HTTP_PROBE=False
ASN_ORG=""
ASN_ASN=""
ASN_DOMAIN=""
ASN_CERT=""
EXCLUDE_SENSITIVE=False
PARALLEL=False

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)           DOMAIN="$2";         shift 2 ;;
        -l|--list)             LIST="$2";            shift 2 ;;
        -u|--use)              USE="$2";             shift 2 ;;
        -e|--exclude)          EXCLUDE="$2";         shift 2 ;;
        -o|--output)           OUTPUT_FILE="$2";     shift 2 ;;
        -s|--silent)           SILENT=True;          shift   ;;
        -fb|--ffuf)            RUN_FFUF=True;        shift   ;;
        -fw|--ffuf-wordlist)   FFUF_WORDLIST="$2";   shift 2 ;;
        -ft|--ffuf-threads)    FFUF_THREADS="$2";    shift 2 ;;
        -fr|--ffuf-rate)       FFUF_RATE="$2";       shift 2 ;;
        -hp|--http-probe)      HTTP_PROBE=True;      shift   ;;
        -ao|--asn-org)         ASN_ORG="$2";         shift 2 ;;
        -aa|--asn-asn)         ASN_ASN="$2";         shift 2 ;;
        -ad|--asn-domain)      ASN_DOMAIN="$2";      shift 2 ;;
        -ac|--asn-cert)        ASN_CERT="$2";        shift 2 ;;
        -an|--asn-enum)
            if [[ -z "$DOMAIN" ]]; then
                # -an may appear before -d; defer resolution to post-parse
                ASN_ENUM_DEFER=True
            else
                ASN_DOMAIN="$DOMAIN"
            fi
            shift ;;
        -es|--exclude-sensitive) EXCLUDE_SENSITIVE=True; shift ;;
        -p|--parallel)         PARALLEL=True;        shift   ;;
        -h|--help)             usage ;;
        -v|--version)          echo -e "${CYAN}Version: ${VERSION}${NC}"; exit 0 ;;
        -ls|--list-sources)    list_sources ;;
        *)
            echo -e "${RED}${BOLD}[-] Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Resolve deferred -an now that -d has been parsed
if [[ "$ASN_ENUM_DEFER" == True ]]; then
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}${BOLD}[-] -an / --asn-enum requires -d <domain>${NC}"
        exit 1
    fi
    ASN_DOMAIN="$DOMAIN"
fi

# ─── Post-parse Defaults ──────────────────────────────────────────────────────
FFUF_WORDLIST="${FFUF_WORDLIST:-$HOME/wordlists/subdomains-top1million-110000.txt}"
FFUF_THREADS="${FFUF_THREADS:-500}"
FFUF_RATE="${FFUF_RATE:-500}"

# Keep lowercase domain in sync (used by spinner labels and dnsx ptr filter)
domain="$DOMAIN"

# Parallel mode implicitly enables HTTP probe
[[ "$PARALLEL" == True ]] && HTTP_PROBE=True

# Output directory (per-domain or "multi" for list mode)
OUTPUT_DIR="outputs/${DOMAIN:-multi}"
mkdir -p "${OUTPUT_DIR}"/{temp,alive,asn}

# ─── Cleanup on Ctrl+C ────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n${YELLOW}${BOLD}[*] Interrupted by user${NC}"
    pkill -P $$ 2>/dev/null
    # shellcheck disable=SC2046
    kill $(jobs -p) 2>/dev/null
    rm -rf "$OUTPUT_DIR" 2>/dev/null
    exit 130
}
trap cleanup INT TERM

# ─── Sensitive Domain Guard ───────────────────────────────────────────────────
if [[ "$EXCLUDE_SENSITIVE" == True && -n "$DOMAIN" ]]; then
    if is_sensitive_domain "$DOMAIN"; then
        echo -e "${RED}${BOLD}[-] Domain '${DOMAIN}' matches a sensitive pattern. Aborting.${NC}"
        exit 1
    fi
fi

# ─── ASN Enumeration ──────────────────────────────────────────────────────────
ASN_REQUESTED=False
[[ -n "$ASN_ORG" || -n "$ASN_ASN" || -n "$ASN_DOMAIN" || -n "$ASN_CERT" ]] && ASN_REQUESTED=True

if [[ "$ASN_REQUESTED" == True ]]; then
    run_asn_enum
    if [[ -z "$DOMAIN" && -z "$LIST" ]]; then
        echo -e "${CYAN}${BOLD}[*] ASN enumeration completed.${NC}"
        exit 0
    fi
fi

# ─── Validate Input ───────────────────────────────────────────────────────────
if [[ -z "$DOMAIN" && -z "$LIST" && "$ASN_REQUESTED" != True ]]; then
    echo -e "${RED}${BOLD}[-] Please specify a domain (-d) or list (-l).${NC}"
    exit 1
fi

# ─── Run Enumeration ──────────────────────────────────────────────────────────
if [[ -n "$LIST" ]]; then
    if [[ ! -f "$LIST" ]]; then
        echo -e "${RED}${BOLD}[-] List file not found: ${LIST}${NC}"
        exit 1
    fi
    echo -e "${BOLD}${MAGENTA}[*] Processing domains from: ${LIST}${NC}"
    while IFS= read -r line; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        domain="$line"   # keep global in sync for tool_enabled/spinner
        enumerate_domain "$line"
    done < "$LIST"
else
    enumerate_domain "$DOMAIN"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
rm -rf "${OUTPUT_DIR}/temp"
echo -e "\n${CYAN}${BOLD}[*] Subdomain enumeration completed. Results saved to: ${OUTPUT_DIR}/${NC}"
