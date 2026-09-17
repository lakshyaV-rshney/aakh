# Local PDF Utilities

This directory contains robust, offline, production-level utilities for manipulating and OCRing PDF files. These tools handle their own dependencies, resolve paths dynamically, and include strict safety checks.

## Setup

All utilities rely on [setup.bat](./setup.bat) to ensure the required environment is present.
If any dependencies (like Python, Tesseract, Ghostscript, or pip packages) are missing when you run a utility, `setup.bat` will be automatically triggered in the background. You can also run it manually once to prepare your environment.

---

## 1. OCR Tool (`ocr.bat`)

Uses `OCRmyPDF` and `Tesseract OCR` to convert scanned documents or image-based PDFs into fully searchable text documents.

### Features
- **Offline & Private**: Runs 100% locally.
- **Fail-safe Engine**: Automatically ignores digital protections and uses `--force-ocr` to rasterize and ensure OCR happens. If the strict conversion fails, it safely falls back to `--skip-text`.
- **Anti-overwrite Protection**: Safely aborts if the target file already exists.
- **Automatic Pathing**: Locates Ghostscript and Tesseract even if they aren't on your System PATH.

### Usage
```powershell
# Basic usage (outputs to original_folder/filename_ocr.pdf)
.\ocr.bat "path\to\file.pdf"

# Specify a custom output name/path
.\ocr.bat "path\to\file.pdf" -o "C:\MyFolder\custom_name.pdf"

# Force overwrite if the output file already exists
.\ocr.bat "path\to\file.pdf" --force
```

---

## 2. Split Tool (`split.bat`)

Uses `pypdf` to quickly and safely extract pages or ranges from a PDF.

### Features
- **Flexible Ranges**: Supports Python-like array syntax for specifying multiple ranges and individual pages simultaneously (e.g., `[1 10] [50 60] 100`).
- **Merge Extraction**: Can stitch multiple scattered ranges together into a single continuous PDF using `--single` or `-o`.
- **Custom Naming**: If you don't specify an output file, it auto-generates descriptive filenames based on the extracted ranges (e.g., `doc_p1-10_p50-60.pdf`).
- **Pre-flight Checks**: Instantly calculates output paths and checks for file collisions before reading the PDF objects into memory, preventing wasted processing time.

### Usage
```powershell
# Split a document into individual 1-page files (page_1, page_2, etc.)
.\split.bat "path\to\file.pdf"

# Extract multiple specific ranges into separate files
.\split.bat "path\to\file.pdf" [1 5] [20 22] 100

# Extract multiple ranges and MERGE them into one continuous file
.\split.bat "path\to\file.pdf" [1 5] [20 22] 100 --single

# Extract ranges and specify an exact output filename (automatically enables merging)
.\split.bat "path\to\file.pdf" [1 5] [20 22] -o "my_merged_notes.pdf"

# Overwrite existing files without throwing an error
.\split.bat "path\to\file.pdf" [1 5] --force
```
