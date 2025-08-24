<h1 align="center">
  <br>
  <a href="https://github.com/manojxshrestha/">
    <img src="https://github.com/user-attachments/assets/4608d1f5-123c-4784-a0e4-317994c07405" alt="subenum" width="600">
  </a>
  <br>
  subenum
  <br>
</h1>


<p align="center">
An Automated Subdomain Enumeration Tool. 
</p>

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/manojxshrestha/subenum/blob/main/LICENSE) 
[![GitHub Repo](https://img.shields.io/badge/repo-GitHub-black?logo=github)](https://github.com/manojxshrestha/subenum) 
[![Issues](https://img.shields.io/github/issues/manojxshrestha/xSQL)](https://github.com/manojxshrestha/subenum/issues) 
[![Stars](https://img.shields.io/github/stars/manojxshrestha/xSQL?style=social)](https://github.com/manojxshrestha/subenum)

</div>

---
**subenum** is a powerful bash-based automation tool designed to discover subdomains using multiple open-source tools and APIs. It supports both passive and active enumeration with optional parallel processing for faster results.

---

## 🚀 Features

* Combines multiple enumeration tools for extensive coverage
* Supports single domain or domain lists
* Options to include/exclude tools
* Parallel execution mode for speed
* Silent output mode for scripting
* Merges and deduplicates results
* Optional HTTP probing support
* Saves final results to timestamped files
* Spinner UI for better UX

---

## ⚙ Supported Tools

Subenum integrates with the following tools:

* [subfinder](https://github.com/projectdiscovery/subfinder)
* [amass](https://github.com/owasp-amass/amass)
* [assetfinder](https://github.com/tomnomnom/assetfinder)
* [findomain](https://github.com/Findomain/Findomain)
* [github-subdomains](https://github.com/gwen001/github-subdomains)
* [gitlab-subdomains](https://github.com/gwen001/gitlab-subdomains)
* [cero](https://github.com/glebarez/cero)
* [shosubgo](https://github.com/incogbyte/shosubgo)
* [crt.sh](https://crt.sh/)
* [Anubis](https://github.com/jonluca/Anubis)
* [anew](https://github.com/tomnomnom/anew) (for output deduplication)

---

## 📦 Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/manojxshrestha/subenum.git
cd subenum
chmod +x install.sh
./install.sh
```

Ensure your shell environment is refreshed:

```bash
source ~/.bashrc
```

---

## 🔐 Configuration

Before running Subenum, set up your API keys in `config.txt`:

```bash
# config.txt
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
export GITLAB_TOKEN="YOUR_GITLAB_TOKEN"
export SHODAN_API_KEY="YOUR_SHODAN_API_KEY"
```

---

## ✅ Ensure Tools Are Installed (Optional)

Run the following script to check if all tools are installed and available:

```bash
chmod +x check.sh
./check.sh
```

---

## 🛠 Usage

```bash
chmod +x subenum.sh
./subenum.sh -d example.com -o subdomains.txt
```

### Options

| Option                | Description                                                   |
| --------------------- | ------------------------------------------------------------- |
| `-d, --domain`        | Target domain                                                 |
| `-l, --list`          | File with list of root domains                                |
| `-u, --use`           | Comma-separated tools to **include** (e.g. `subfinder,amass`) |
| `-e, --exclude`       | Comma-separated tools to **exclude**                          |
| `-o, --output`        | Output filename (default: `<domain>-Date-Time.txt`)           |
| `-s, --silent`        | Silent mode (outputs only subdomains)                         |
| `-hp, --http-probe`   | Run HTTP probing after enumeration                            |
| `-k, --keep`          | Keep temporary tool outputs                                   |
| `-p, --parallel`      | Run tools in parallel (faster)                                |
| `-h, --help`          | Show help                                                     |
| `-v, --version`       | Show version                                                  |
| `-ls, --list-sources` | List all integrated tools                                     |

---

## 🧪 Examples

### Enumerate a single domain

```bash
./subenum.sh -d example.com
```

### Enumerate a list of domains in parallel

```bash
./subenum.sh -l domains.txt -p
```

### Use only subfinder and amass

```bash
./subenum.sh -d example.com -u subfinder,amass
```

### Exclude findomain and assetfinder

```bash
./subenum.sh -d example.com -e findomain,assetfinder
```

### Silent mode (just subdomains)

```bash
./subenum.sh -d example.com -s
```

---

## 📁 Output

* Results are saved in a deduplicated format.
* Temporary files are removed unless `--keep` is used.

---

## 🧼 Cleanup

To remove all temporary tool outputs:

```bash
rm tmp-*
```

---

## 🧾 License

This project is open-source and available under the [MIT License](LICENSE).
