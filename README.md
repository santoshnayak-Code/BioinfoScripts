# ENA Paired-End FASTQ Downloader & Verifier

A robust Bash script designed for bioinformatics researchers to download large-scale genomic datasets (like RNA-Seq or DNA-Seq) from the **European Nucleotide Archive (ENA)**. It features automatic resumption, MD5 checksum verification, and a multi-cycle retry mechanism to ensure data integrity.

> **Note:** This script is specifically configured for **Paired-End** data (where two MD5s and two FTP links are provided per sample).

## 🚀 Key Features

* **Auto-Resume**: Uses `wget -c` to pick up where a download left off if the connection drops.
* **Integrity Check**: Automatically calculates MD5 hashes and compares them against ENA records.
* **Self-Healing**: Deletes corrupted files and retries the download (up to 5 cycles).
* **Server-Friendly**: Designed to run in the background using `nohup`.

---

## 📋 Prerequisites

* **OS**: Linux Server (recommended) or macOS.
* **Tools**: `wget`, `md5sum` (Linux) or `md5` (Mac).
* **Input**: A TSV file from the ENA Browser.

---

## 🛠 How to Generate the Input TSV

To use this script, you must download a specific TSV format from the [ENA Browser](https://www.ebi.ac.uk/ena/browser/home):

1. Search for your study or project accession.
2. In the **Report Builder** or **Downloads** section, customize your columns.
3. **Important**: Select only these checkboxes:
* `run_accession` (Sample name)
* `fastq_md5`
* `fastq_ftp`


4. Click **Download TSV**.
5. The resulting file should have a header and rows containing values separated by semicolons (e.g., `hash1;hash2` and `ftp_link1;ftp_link2`).

---

## 🏃 Usage Instructions

### 1. Preparation

Clone this repository and make the script executable:

```bash
chmod +x download_fastq.sh

```

### 2. Run in the Background

Since genomic data is often hundreds of gigabytes, run the script using `nohup` to ensure it continues even if you disconnect from the server:

```bash
nohup ./download_fastq.sh your_ena_file.tsv &

```

### 3. Monitor Progress

You can check the live progress, including download speeds and MD5 verification results, by viewing the generated log file:

```bash
tail -f process.log

```

---

## 📂 Logic Flow

* **Cycle 1**: Iterates through the TSV. If a file is missing, it downloads it. If a file is present, it verifies the MD5.
* **Error Handling**: If an MD5 mismatch is found, the script prints an "ERROR" to the log, deletes the corrupted file, and marks the cycle as failed.
* **Retry Mechanism**: If any file was corrupted or missed, the script waits 10 seconds and starts a new cycle (Max 5 cycles).
* **Completion**: Exits with a "SUCCESS" message only when every file in the list passes the MD5 check.
