#!/usr/bin/env python3
"""
livecon - Check hosts/subdomains for live web servers
Uses socket for port checks + requests for fingerprinting/title grabbing
Screenshots (optional) are handled separately by gowitness at the end
"""

import argparse
import sys
import os
import socket
import time
import queue
import threading
import signal
import requests
import urllib3
from pathlib import Path
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ────────────────────────────────────────────────
# ANSI Colors
# ────────────────────────────────────────────────
class Colors:
    CYAN    = '\033[96m'
    GREEN   = '\033[92m'
    YELLOW  = '\033[93m'
    WHITE   = '\033[97m'
    GRAY    = '\033[90m'
    BOLD    = '\033[1m'
    RED     = '\033[91m'
    MAGENTA = '\033[95m'
    END     = '\033[0m'

# Banner
BANNER = (
    f"{Colors.CYAN}{Colors.BOLD}"
    r"""
 _     _  _     _____ ____ ____  _     
/ \   / \/ \ |\/  __//   _Y  _ \/ \  /|
| |   | || | //|  \  |  / | / \|| |\ ||
| |_/\| || \// |  /_ |  \_| \_/|| | \||
\____/\_/\__/  \____\\____|____/\_/  \|                                      
    """
    f"{Colors.END}\n"
    f"          livecon – live host & web checker\n"
)

WEB_PORTS = [80, 443, 8080, 8443, 8000, 3000, 8081, 8444]

interrupted = False
status_lock = threading.Lock()

# ────────────────────────────────────────────────
# Utilities
# ────────────────────────────────────────────────
def is_private_ip(ip: str) -> bool:
    try:
        octets = list(map(int, ip.split('.')))
        if octets[0] == 10:
            return True
        if octets[0] == 172 and 16 <= octets[1] <= 31:
            return True
        if octets[0] == 192 and octets[1] == 168:
            return True
    except:
        pass
    return False

def print_status(scanned, total, found, internal, screenshots):
    screenshot_str = f"  |  {Colors.MAGENTA}Pending screenshots: {screenshots}{Colors.END}"
    status = (
        f"{Colors.CYAN}{Colors.BOLD}Scanning:{Colors.END} {Colors.WHITE}{scanned}/{total}{Colors.END}  |  "
        f"{Colors.GRAY}Live web servers:{Colors.END} {Colors.GREEN}{found}{Colors.END}  |  "
        f"{Colors.YELLOW}Internal IPs: {internal}{Colors.END}{screenshot_str}"
    )
    print(f"\r{status}          ", end="", flush=True)

def sigint_handler(total_targets, output_dir):
    global interrupted
    interrupted = True
    print(f"\n\n{Colors.YELLOW}Interrupted by user (Ctrl+C){Colors.END}")
    print_status(scanned_counter[0], total_targets, found_counter[0], len(internal_list), screenshot_counter[0])
    print(f"\n{Colors.CYAN}Scanned:{Colors.END} {scanned_counter[0]}/{total_targets}")
    print(f"{Colors.GREEN}Live web servers found:{Colors.END} {found_counter[0]}")
    print(f"{Colors.YELLOW}Internal IPs detected:{Colors.END} {len(internal_list)}")
    print(f"{Colors.MAGENTA}URLs collected for screenshots:{Colors.END} {screenshot_counter[0]}")
    print(f"{Colors.WHITE}Partial results saved to: ./{output_dir}/{Colors.END}")
    print(f"{Colors.RED}{Colors.BOLD}Exiting now.{Colors.END}")
    os._exit(0)

# ────────────────────────────────────────────────
# Worker thread
# ────────────────────────────────────────────────
def worker(task_queue, internal_list, titles_list, fingerprint_list, live_results, url_list_for_screenshots, total):
    global interrupted
    session = requests.Session()
    session.verify = False
    session.headers.update({"User-Agent": "Mozilla/5.0 (compatible; livecon/1.0)"})

    while not interrupted:
        try:
            host = task_queue.get(timeout=1)
        except queue.Empty:
            break

        open_ports = []
        resolved_ip = None
        try:
            resolved_ip = socket.gethostbyname(host)
            if is_private_ip(resolved_ip):
                with status_lock:
                    internal_list.append(f"{host} → {resolved_ip}")

            for port in WEB_PORTS:
                if interrupted:
                    break
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2)
                result = sock.connect_ex((resolved_ip, port))
                sock.close()
                if result == 0:
                    open_ports.append(port)
        except (socket.gaierror, OSError):
            pass

        with status_lock:
            scanned_counter[0] += 1
            if open_ports:
                found_counter[0] += 1
            print_status(scanned_counter[0], total, found_counter[0], len(internal_list), screenshot_counter[0])

        if open_ports:
            open_ports.sort()
            port_str = ", ".join(map(str, open_ports))
            with status_lock:
                live_results.append(f"{host} web servers: {port_str}")

            for port in open_ports:
                if interrupted:
                    break
                scheme = "https" if port in [443, 8443, 8444] else "http"
                url = f"{scheme}://{host}:{port}/"
                try:
                    r = session.get(url, timeout=6, allow_redirects=True)
                    server = r.headers.get("Server", "Unknown")
                    powered_by = r.headers.get("X-Powered-By", "")
                    server_str = server
                    if powered_by:
                        server_str += f" ({powered_by})"

                    title = "No title"
                    text_lower = r.text.lower()
                    if "<title" in text_lower:
                        start = text_lower.find("<title")
                        if start != -1:
                            start = r.text.find(">", start) + 1
                            end = r.text.lower().find("</title>", start)
                            if end != -1:
                                title = r.text[start:end].strip().replace("\n", " ").replace("\r", " ")

                    if titles_list is not None:
                        titles_list.append(f"{host} Port: {port} Root Page Title: {title}")
                    if fingerprint_list is not None:
                        fingerprint_list.append(f"{host} Port: {port} Server: {server_str}")

                    # Collect for later gowitness batch
                    with status_lock:
                        url_list_for_screenshots.append(url)
                        screenshot_counter[0] += 1

                except Exception:
                    pass

        if not interrupted:
            task_queue.task_done()

# ────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────
def main():
    global interrupted, scanned_counter, found_counter, internal_list, screenshot_counter

    parser = argparse.ArgumentParser(
        description=f"{Colors.CYAN}{Colors.BOLD}livecon{Colors.END} – Check hosts for live web servers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"{Colors.CYAN}Examples:{Colors.END}\n"
              f"  python3 livecon.py -i subdomains.txt -o livesubs.txt\n"
              f"  python3 livecon.py -i subdomains.txt -o livesubs.txt -t titles.txt -f fingerprint.txt -s --threads 80"
    )
    parser.add_argument("-i", "--input",    required=True, help="Input file with hosts/subdomains")
    parser.add_argument("-o", "--output",   required=True, help="Output filename (e.g. livesubs.txt)")
    parser.add_argument("-t", "--titles",                  help="Output file for page titles")
    parser.add_argument("-f", "--fingerprint",             help="Output file for server fingerprints")
    parser.add_argument("-s", "--screenshots", action="store_true", help="Collect URLs for later gowitness screenshot")
    parser.add_argument("--threads", type=int, default=100, help="Number of worker threads (default: 100)")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"{Colors.RED}[-] Input file not found: {args.input}{Colors.END}")
        sys.exit(1)

    with open(args.input, 'r', encoding='utf-8') as f:
        hosts = [line.strip() for line in f if line.strip()]

    total = len(hosts)
    if total == 0:
        print(f"{Colors.YELLOW}[-] No hosts found in input file.{Colors.END}")
        sys.exit(0)

    # Output setup
    domain_guess = args.output.split('.')[0] if '.' in args.output else "results"
    output_dir = Path(domain_guess)
    output_dir.mkdir(exist_ok=True)

    live_output        = output_dir / args.output
    titles_output      = output_dir / args.titles       if args.titles       else None
    fingerprint_output = output_dir / args.fingerprint if args.fingerprint else None
    screenshot_urls_file = output_dir / "live_urls_for_gowitness.txt"

    print(BANNER)
    print(f"{Colors.WHITE}Loaded {total} hosts from {args.input}{Colors.END}")
    print(f"{Colors.WHITE}Results will be saved in ./{domain_guess}/{Colors.END}")
    print(f"{Colors.WHITE}Scanning ports {WEB_PORTS} with {args.threads} threads...{Colors.END}")
    if args.titles:
        print(f"{Colors.WHITE}Page titles        → {titles_output}{Colors.END}")
    if args.fingerprint:
        print(f"{Colors.WHITE}Fingerprints       → {fingerprint_output}{Colors.END}")
    if args.screenshots:
        print(f"{Colors.MAGENTA}Screenshots: URLs will be saved → {screenshot_urls_file}{Colors.END}")
        print(f"  Run afterwards: gowitness scan file -f {screenshot_urls_file} --screenshot-path ./screenshots --threads 10 --timeout 60 --fullpage --write-db --write-jsonl")
    print()

    scanned_counter    = [0]
    found_counter      = [0]
    internal_list      = []
    titles_list        = [] if args.titles else None
    fingerprint_list   = [] if args.fingerprint else None
    live_results       = []
    screenshot_urls    = []
    screenshot_counter = [0]

    print_status(0, total, 0, 0, 0)

    task_queue = queue.Queue()
    for host in hosts:
        task_queue.put(host)

    signal.signal(signal.SIGINT, lambda sig, frame: sigint_handler(total, domain_guess))

    # Start worker threads
    threads = []
    for _ in range(args.threads):
        t = threading.Thread(
            target=worker,
            args=(task_queue, internal_list, titles_list, fingerprint_list, live_results,
                  screenshot_urls, total)
        )
        t.daemon = True
        t.start()
        threads.append(t)

    # Wait for tasks to complete while handling Ctrl+C
    try:
        while not interrupted and not task_queue.empty():
            time.sleep(0.2)
    except KeyboardInterrupt:
        interrupted = True
        os._exit(0)

    # Join threads
    for t in threads:
        t.join(timeout=1.0)

    # ── Save results ─────────────────────────────────────────────────────
    with open(live_output, 'w', encoding='utf-8') as f:
        for line in live_results:
            f.write(line + "\n")

    internal_file = output_dir / f"{domain_guess}_internal.txt"
    if internal_list:
        with open(internal_file, 'w', encoding='utf-8') as f:
            for line in internal_list:
                f.write(line + "\n")

    if args.titles and titles_list:
        with open(titles_output, 'w', encoding='utf-8') as f:
            for line in titles_list:
                f.write(line + "\n")

    if args.fingerprint and fingerprint_list:
        with open(fingerprint_output, 'w', encoding='utf-8') as f:
            for line in fingerprint_list:
                f.write(line + "\n")

    # Save URLs for gowitness (deduplicate)
    unique_urls = list(set(screenshot_urls))
    if args.screenshots and unique_urls:
        with open(screenshot_urls_file, 'w', encoding='utf-8') as f:
            for url in unique_urls:
                f.write(url + "\n")
        print(f"{Colors.GREEN}Collected {len(unique_urls)} unique URLs for screenshots → {screenshot_urls_file}{Colors.END}")

    # ── Summary ─────────────────────────────────────────────────────────
    print(f"\n\n{Colors.BOLD}SCAN COMPLETE{Colors.END}")
    print(f"{Colors.GREEN}Live web servers found: {len(live_results)}{Colors.END}")
    if args.screenshots:
        print(f"{Colors.MAGENTA}URLs ready for gowitness: {len(unique_urls)}{Colors.END}")
    print(f"{Colors.WHITE}Results saved to: ./{domain_guess}/{Colors.END}")
    if internal_list:
        print(f"{Colors.YELLOW}Internal IPs found: {len(internal_list)}{Colors.END} → {internal_file}")

# ────────────────────────────────────────────────
if __name__ == "__main__":
    main()
