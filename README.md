<h1 align="center">
  <br>
  <a href="https://github.com/manojxshrestha/">
    <img src="https://github.com/user-attachments/assets/4c789b56-73ed-4925-ad34-5c327a30810f" alt="subenum" width="600">
  </a>
  <br>
  subenum
  <br>
</h1>


<p align="center">
An Automated Subdomain Enumeration Tool with FFUF bruteforce, HTTP probing, and ASN enumeration.
</p>

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/manojxshrestha/subenum/blob/main/LICENSE) 
[![GitHub Repo](https://img.shields.io/badge/repo-GitHub-black?logo=github)](https://github.com/manojxshrestha/subenum) 
[![Issues](https://img.shields.io/github/issues/manojxshrestha/subenum)](https://github.com/manojxshrestha/subenum/issues) 
[![Stars](https://img.shields.io/github/stars/manojxshrestha/subenum?style=social)](https://github.com/manojxshrestha/subenum)

</div>

---

**subenum** is a powerful bash-based automation tool for subdomain enumeration. It combines multiple tools and includes FFUF bruteforce, HTTP probing, and ASN/organization-based enumeration. **No API keys required!**

---

## 🚀 Features

* Passive subdomain enumeration using multiple tools
* FFUF bruteforce for additional subdomain discovery
* HTTP/HTTPS probing with status codes, titles, and tech detection
* ASN/Organization-based enumeration using Metabigor
* Certificate transparency search
* Parallel execution mode for faster results
* Auto-cleanup of temporary files
* Results organized in `temp/` and `results/` folders
* Safe CIDR expansion (prevents memory issues)

---

## ⚙ Supported Tools

### Subdomain Enumeration
* [subfinder](https://github.com/projectdiscovery/subfinder)
* [amass](https://github.com/owasp-amass/amass)
* [assetfinder](https://github.com/tomnomnom/assetfinder)
* [findomain](https://github.com/Findomain/Findomain)

### FFUF & HTTP Probing
* [ffuf](https://github.com/ffuf/ffuf)
* [dnsx](https://github.com/projectdiscovery/dnsx)
* [httpx](https://github.com/projectdiscovery/httpx)

### ASN/Network Enumeration
* [metabigor](https://github.com/j3ssie/metabigor)
* [prips](https://github.com/imusabkhan/prips)

### Utilities
* [anew](https://github.com/tomnomnom/anew) (for deduplication)

---

## 📦 Installation

### 1. Clone the repository

```bash
git clone https://github.com/manojxshrestha/subenum.git
cd subenum
```

### 2. Run the installer

```bash
chmod +x install.sh
./install.sh
```

### Installation Options

```bash
./install.sh              # Install all tools (skips already installed)
./install.sh --check     # Check installation status
./install.sh --help      # Show help message
./install.sh --force     # Force reinstall all tools
```

### 3. Setup wordlist

Create a wordlists directory in your home folder and add your wordlist:

```bash
mkdir -p ~/wordlists
# Place your wordlist at: ~/wordlists/subdomains-top1million-110000.txt
```

### 4. Refresh shell

```bash
source ~/.bashrc
```

---

## ✅ Verify Installation

```bash
chmod +x check.sh
./check.sh
```

---

## 🛠 Usage

```bash
chmod +x subenum.sh
./subenum.sh -d example.com
```

### Options

| Option | Description |
|--------|-------------|
| `-d, --domain` | Target domain |
| `-l, --list` | File with list of root domains |
| `-o, --output` | Output filename |
| `-s, --silent` | Silent mode (outputs only subdomains) |
| `-fb, --ffuf` | Run FFUF bruteforce after enumeration |
| `-fw, --ffuf-wordlist` | Custom wordlist for FFUF (default: ~/wordlists/) |
| `-ft, --ffuf-threads` | FFUF threads (default: 200) |
| `-hp, --http-probe` | Run HTTP probing (requires -fb) |
| `-ao, --asn-org` | Find IP ranges by organization name |
| `-aa, --asn-asn` | Find IP ranges by ASN (e.g., AS13335) |
| `-ad, --asn-domain` | Find IP ranges by domain |
| `-ac, --asn-cert` | Search subdomains via certificate transparency |
| `-an, --asn-enum` | Auto ASN enumeration using target domain |
| `-p, --parallel` | Run tools in parallel (faster) |
| `-h, --help` | Show help |
| `-v, --version` | Show version |
| `-ls, --list-sources` | List all integrated tools |

---

## 🧪 Examples

### Basic subdomain enumeration
```bash
./subenum.sh -d example.com
```

### With FFUF bruteforce
```bash
./subenum.sh -d example.com -fb
```

### With FFUF + HTTP probing
```bash
./subenum.sh -d example.com -fb -hp
```

### Parallel mode (auto runs FFUF + HTTP probe)
```bash
./subenum.sh -d example.com -p
```

### With ASN enumeration
```bash
./subenum.sh -d example.com -an
```

### Full mode (parallel + ASN)
```bash
./subenum.sh -d example.com -p -an
```

### ASN by organization
```bash
./subenum.sh -ao "Google"
```

### ASN by number
```bash
./subenum.sh -aa AS13335
```

### Certificate transparency search
```bash
./subenum.sh -ac example.com
```

### Domain list in parallel
```bash
./subenum.sh -l domains.txt -p
```

### Custom wordlist
```bash
./subenum.sh -d example.com -fb -fw /path/to/wordlist.txt
```

---

## 📁 Output Structure

```
subenum/
├── subenum.sh
├── install.sh
├── check.sh
├── README.md
│
├── temp/                          # Temporary files (auto-cleaned)
│   ├── tmp-subfinder-{domain}.txt
│   ├── tmp-amass-{domain}.txt
│   ├── tmp-assetfinder-{domain}.txt
│   ├── tmp-findomain-{domain}.txt
│   ├── subdomains.txt
│   ├── ffufsubdomains.txt
│   ├── finalsubdomains.txt
│   ├── alivesubdomains.txt
│   ├── filtersubdomains.txt
│   ├── asn-numbers.txt
│   ├── asn-cidrs.txt
│   └── asn-ips.txt
│
└── results/                       # Final outputs (kept)
    ├── alive-domains.txt         # (if -hp)
    ├── https-subs.txt           # (if -hp)
    └── asnresults.txt           # (if -ao/-aa/-ad/-ac/-an)
```

---

## ⚠️ ASN Enumeration Safety

The ASN enumeration module uses safe CIDR expansion:
- Only expands CIDRs /22 and smaller (prevents memory issues)
- Max 5,000 IPs to avoid system crashes
- Skips large ranges to avoid memory issues
- Filters results to match target domain

---

## 🧾 License

This project is open-source and available under the [MIT License](LICENSE).
