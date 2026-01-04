#!/usr/bin/env python3
"""
THC Recon - Fetch subdomains & hosts from ip.thc.org

Features:
- Supports domain (subdomains) and IP (rDNS hosts)
- Fetches A/AAAA and/or CNAME records
- Auto-resumes from output file if interrupted
- Rate-limit aware sleeping
- Exponential backoff **only on errors**
- Checkpointing every 5 pages + always on last page
"""

import requests
import argparse
import sys
import time
import re
import os
import signal
import ipaddress
from typing import Set, List, Optional, Dict, Any

# ────────────────────────────────────────────────
# ANSI Colors
# ────────────────────────────────────────────────
class Colors:
    CYAN   = '\033[96m'
    GREEN  = '\033[92m'
    YELLOW = '\033[93m'
    WHITE  = '\033[97m'
    GRAY   = '\033[90m'
    BOLD   = '\033[1m'
    RED    = '\033[91m'
    END    = '\033[0m'

# Banner – using raw string for ASCII art to prevent backslash escaping issues
BANNER = (
    f"{Colors.CYAN}{Colors.BOLD}"
    r"""
  __  .__                                              
_/  |_|  |__   ___________   ____   ____  ____   ____  
\   __\  |  \_/ ___\_  __ \_/ __ \_/ ___\/  _ \ /    \ 
 |  | |   Y  \  \___|  | \/\  ___/\  \__(  <_> )   |  \
 |__| |___|  /\___  >__|    \___  >\___  >____/|___|  /
           \/     \/            \/     \/           \/ 
    """
    f"{Colors.END}\n"
    f"       Fetch hosts & subdomains from ip.thc.org\n"
)

def strip_ansi(s: str) -> str:
    if not s:
        return ""
    s = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', s)
    s = re.sub(r'\x1B[@-Z\\-_][0-?]*[ -/]*[@-~]', '', s)
    s = re.sub(r'\x1B\([AB0-2]', '', s)
    return s.strip()

def parse_response(text: str) -> tuple[Optional[int], Optional[int], Optional[str], List[str]]:
    total_entries = None
    rate_limit = None
    next_page = None
    results = []

    for raw_line in text.splitlines():
        line = strip_ansi(raw_line)
        if not line:
            continue

        if line.startswith(";;Entries:"):
            parts = line.split("/")
            if len(parts) >= 2:
                try:
                    total_entries = int(parts[1].split()[0].strip())
                except (ValueError, IndexError):
                    pass

        elif line.startswith(";;Rate Limit:"):
            match = re.search(r'You can make (\d+)', line, re.IGNORECASE)
            if match:
                try:
                    rate_limit = int(match.group(1))
                except ValueError:
                    pass

        elif line.startswith(";;Next Page:"):
            candidate = line.split(":", 1)[1].strip() if ":" in line else ""
            cleaned = strip_ansi(candidate)
            if cleaned.startswith("https://ip.thc.org/") and "?p=" in cleaned:
                next_page = cleaned

        elif not line.startswith(";;"):
            cleaned = strip_ansi(raw_line).strip()
            if cleaned and "." in cleaned:  # basic sanity check
                results.append(cleaned)

    return total_entries, rate_limit, next_page, results

def get_sleep_time(remaining: Optional[int]) -> float:
    if remaining is None:
        return 2.1
    if remaining >= 50:
        return 0.1
    if remaining >= 20:
        return 0.5
    if remaining >= 10:
        return 1.0
    return max(0.3, 2.2 - remaining * 0.1)

def print_status(
    target: str,
    fetched: int,
    total: Optional[int],
    rate_limit: Optional[int],
    requests_made: int,
    mode_str: str,
    resuming: bool = False
) -> None:
    remaining = total - fetched if total is not None else "?"
    total_str = total if total is not None else "?"
    resume_note = " (resuming)" if resuming else ""

    status = (
        f"{Colors.CYAN}{Colors.BOLD}Target:{Colors.END} {Colors.WHITE}{target}{Colors.END}{resume_note}  |  "
        f"{Colors.GRAY}Mode:{Colors.END} {Colors.YELLOW}{mode_str}{Colors.END}  |  "
        f"{Colors.GRAY}Fetched:{Colors.END} {Colors.GREEN}{fetched}{Colors.END}/{Colors.GREEN}{total_str}{Colors.END}  "
        f"({Colors.GRAY}left:{Colors.END} {Colors.GREEN}{remaining}{Colors.END})  |  "
        f"{Colors.GRAY}RL:{Colors.END} {Colors.YELLOW}{rate_limit if rate_limit is not None else '?'}{Colors.END}  |  "
        f"{Colors.GRAY}Reqs:{Colors.END} {Colors.WHITE}{requests_made}{Colors.END}"
    )
    print(f"\r\033[K{status}", end="", flush=True)

def fetch_all(
    base_url: str,
    session: requests.Session,
    results_set: Set[str],
    counters: Dict[str, Any],
    target: str,
    mode_str: str,
    output_file: str,
) -> None:
    url = f"{base_url}?l=100"
    backoff = 1.0
    page = 0

    while url:
        counters["requests"] += 1

        try:
            resp = session.get(url, timeout=(7, 18))
            resp.raise_for_status()
            backoff = 1.0  # reset on success

            total_new, rl_new, next_url, page_results = parse_response(resp.text)

            if total_new is not None:
                counters["expected"] = total_new
            if rl_new is not None:
                counters["rate_limit"] = rl_new

            added = sum(1 for item in page_results if item not in results_set)
            results_set.update(page_results)

            page += 1

            # Checkpoint: every 5 pages OR final page
            if page % 5 == 0 or next_url is None:
                with open(output_file, "w", encoding="utf-8") as f:
                    for r in sorted(results_set):
                        f.write(f"{r}\n")

            print_status(
                target,
                len(results_set),
                counters.get("expected"),
                counters.get("rate_limit"),
                counters["requests"],
                mode_str
            )

            url = next_url
            time.sleep(get_sleep_time(counters.get("rate_limit")))

        except requests.exceptions.RequestException as e:
            counters["errors"] += 1

            if isinstance(e, requests.exceptions.HTTPError) and e.response is not None:
                if e.response.status_code == 404:
                    print(f"\n{Colors.GRAY}No data found (404) — stopping this endpoint.{Colors.END}")
                    break

            print(f"\n{Colors.RED}Request failed: {e}{Colors.END}")
            sleep_time = min(60, backoff * 8)
            print(f"{Colors.YELLOW}Backing off {sleep_time:.1f}s (attempt {int(backoff):d}x)...{Colors.END}")
            time.sleep(sleep_time)
            backoff *= 2
            # do NOT update url → retry same page

def signal_handler(sig, frame) -> None:
    if 'state' not in globals() or state is None:
        print("\nInterrupted early — no progress to save.")
        sys.exit(130)

    print(f"\n\n{Colors.YELLOW}Interrupted by user (Ctrl+C){Colors.END}")
    print(f"{Colors.CYAN}Target:{Colors.END} {state['target']}")
    print(f"{Colors.GREEN}Fetched so far:{Colors.END} {len(state['results'])}")
    print(f"{Colors.WHITE}Requests:{Colors.END} {state['counters']['requests']}")
    print(f"{Colors.YELLOW}Errors:{Colors.END} {state['counters']['errors']}")
    print(f"{Colors.WHITE}Saving to:{Colors.END} {state['output']}")

    with open(state['output'], "w", encoding="utf-8") as f:
        for r in sorted(state['results']):
            f.write(f"{r}\n")

    print(f"{Colors.RED}{Colors.BOLD}Run same command again to resume.{Colors.END}")
    sys.exit(130)

def main() -> None:
    global state
    state = None  # so signal handler knows if we crashed very early

    parser = argparse.ArgumentParser(
        description=f"{Colors.CYAN}{Colors.BOLD}THC Recon{Colors.END} – Fetch hosts/subdomains from ip.thc.org",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 thcrecon.py google.com -o google.txt
  python3 thcrecon.py google.com -o cnames.txt --cnames-only
  python3 thcrecon.py 8.8.8.8 -o dns8.txt
  python3 thcrecon.py 1.1.1.1 -o cloudflare.txt --no-cnames"""
    )
    parser.add_argument("target", help="Domain or IP address")
    parser.add_argument("-o", "--output", required=True, help="Output file (txt)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--cnames-only", action="store_true", help="Only CNAME records")
    group.add_argument("--no-cnames",   action="store_true", help="Only A/AAAA records")

    args = parser.parse_args()

    # Skip banner & fancy output when only showing help
    is_help = len(sys.argv) == 2 and sys.argv[1] in ('-h', '--help')
    if not is_help:
        print(BANNER)

    target = args.target.strip()
    try:
        ipaddress.ip_address(target)
        is_ip = True
        if not is_help:
            print(f"{Colors.YELLOW}Target is IP → rDNS mode (no CNAME support){Colors.END}")
    except ValueError:
        is_ip = False
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$', target):
            print(f"{Colors.RED}Invalid domain or IP: {target}{Colors.END}")
            sys.exit(1)

    fetch_a     = not args.cnames_only
    fetch_cname = args.cnames_only or not args.no_cnames
    if is_ip:
        fetch_cname = False

    mode_str = (
        "rDNS hosts" if is_ip else
        "CNAMEs only" if args.cnames_only else
        "A/AAAA only" if args.no_cnames else
        "A + CNAME"
    )

    if not is_help:
        print(f"  Target : {Colors.WHITE}{target}{Colors.END}")
        print(f"  Output : {Colors.WHITE}{args.output}{Colors.END}")
        print(f"  Mode   : {Colors.YELLOW}{mode_str}{Colors.END}\n")

    state = {
        "target": target,
        "output": args.output,
        "results": set(),
        "counters": {"requests": 0, "errors": 0, "expected": None, "rate_limit": None}
    }

    resuming = False
    if os.path.isfile(args.output):
        try:
            with open(args.output, encoding="utf-8") as f:
                lines = {line.strip() for line in f if line.strip()}
            state["results"].update(lines)
            if lines and not is_help:
                resuming = True
                print(f"{Colors.YELLOW}Resuming — {len(lines)} entries loaded{Colors.END}")
        except Exception as e:
            print(f"{Colors.RED}Could not read file: {e}{Colors.END}")

    if not is_help:
        print_status(
            target, len(state["results"]), state["counters"].get("expected"),
            state["counters"].get("rate_limit"), state["counters"]["requests"],
            mode_str, resuming
        )

    signal.signal(signal.SIGINT, signal_handler)

    session = requests.Session()
    session.headers["User-Agent"] = "thcrecon/1.0 (recon tool)"

    if fetch_a:
        url = f"https://ip.thc.org/{target}" if is_ip else f"https://ip.thc.org/sb/{target}"
        if not is_help:
            print(f"{Colors.WHITE}Fetching {'rDNS hosts' if is_ip else 'A/AAAA'}...{Colors.END}")
        fetch_all(url, session, state["results"], state["counters"], target, mode_str, args.output)

    if fetch_cname:
        url = f"https://ip.thc.org/cn/{target}"
        if not is_help:
            print(f"{Colors.WHITE}Fetching CNAMEs...{Colors.END}")
        fetch_all(url, session, state["results"], state["counters"], target, mode_str, args.output)

    if not is_help:
        # Final save
        with open(args.output, "w", encoding="utf-8") as f:
            for item in sorted(state["results"]):
                f.write(f"{item}\n")

        print("\n" + "═" * 70)
        print(f"{Colors.BOLD}SUMMARY{Colors.END}")
        print("═" * 70)
        print(f"  Target          : {Colors.CYAN}{target}{Colors.END}")
        print(f"  Mode            : {Colors.YELLOW}{mode_str}{Colors.END}")
        print(f"  Unique results  : {Colors.GREEN}{len(state['results'])}{Colors.END}")
        print(f"  Requests made   : {state['counters']['requests']}")
        print(f"  Errors          : {Colors.RED}{state['counters']['errors']}{Colors.END}")
        print(f"  Saved to        : {args.output}")
        print("═" * 70)

if __name__ == "__main__":
    main()