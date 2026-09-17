@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo         Production PDF Split Tool
echo ==========================================

:: 1. Validate Input
IF "%~1"=="" (
    echo [X] Usage: %~nx0 "path\to\your\file.pdf" [ranges] [--single] [--force] [-o "output.pdf"]
    echo [i] Examples:
    echo     %~nx0 "doc.pdf"                 -^> Splits into individual pages
    echo     %~nx0 "doc.pdf" [1 10] [50 60] 100 -^> Extracts ranges and specific pages
    echo     %~nx0 "doc.pdf" [1 5] 10 --single  -^> Extracts and merges them into one file
    echo     %~nx0 "doc.pdf" 5 6 -o out.pdf     -^> Extracts pages 5^&6 into out.pdf
    exit /b 1
)

:: 2. Auto-Dependency Check
SET "MISSING_DEPS=0"

python --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 SET "MISSING_DEPS=1"

python -c "import pypdf" >nul 2>&1
IF !ERRORLEVEL! NEQ 0 SET "MISSING_DEPS=1"

IF !MISSING_DEPS! EQU 1 (
    echo [*] Missing dependencies detected. Running setup automatically...
    call "%~dp0setup.bat" --auto
    IF !ERRORLEVEL! NEQ 0 (
        echo [X] Setup failed. Cannot proceed.
        exit /b 1
    )
)

:: 3. Run embedded Python script to handle complex parsing and splitting
SET "PY_SCRIPT=%TEMP%\split_pdf_temp_!RANDOM!.py"

>  "!PY_SCRIPT!" echo import sys, re, os
>> "!PY_SCRIPT!" echo from pypdf import PdfReader, PdfWriter
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo def main():
>> "!PY_SCRIPT!" echo     if len(sys.argv) ^< 2:
>> "!PY_SCRIPT!" echo         sys.exit(1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     input_file = sys.argv[1]
>> "!PY_SCRIPT!" echo     if not os.path.isfile(input_file):
>> "!PY_SCRIPT!" echo         print(f"[X] Error: File '{input_file}' does not exist.")
>> "!PY_SCRIPT!" echo         sys.exit(1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     reader = PdfReader(input_file)
>> "!PY_SCRIPT!" echo     total_pages = len(reader.pages)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     file_dir = os.path.dirname(os.path.abspath(input_file))
>> "!PY_SCRIPT!" echo     base_name = os.path.splitext(os.path.basename(input_file))[0]
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     args_list = sys.argv[2:]
>> "!PY_SCRIPT!" echo     custom_output = None
>> "!PY_SCRIPT!" echo     if "-o" in args_list:
>> "!PY_SCRIPT!" echo         idx = args_list.index("-o")
>> "!PY_SCRIPT!" echo         if idx + 1 ^< len(args_list):
>> "!PY_SCRIPT!" echo             custom_output = args_list[idx+1]
>> "!PY_SCRIPT!" echo             args_list.pop(idx+1)
>> "!PY_SCRIPT!" echo             args_list.pop(idx)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     args_str = " ".join(args_list)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     merge_output = False
>> "!PY_SCRIPT!" echo     if "--single" in args_str or "--merge" in args_str or custom_output:
>> "!PY_SCRIPT!" echo         merge_output = True
>> "!PY_SCRIPT!" echo         args_str = args_str.replace("--single", "").replace("--merge", "")
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     force_mode = False
>> "!PY_SCRIPT!" echo     if "--force" in args_str:
>> "!PY_SCRIPT!" echo         force_mode = True
>> "!PY_SCRIPT!" echo         args_str = args_str.replace("--force", "")
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     ranges_to_extract = []
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     if not args_str.strip():
>> "!PY_SCRIPT!" echo         print("[*] Mode: Split all pages")
>> "!PY_SCRIPT!" echo         for i in range(total_pages):
>> "!PY_SCRIPT!" echo             ranges_to_extract.append((i+1, i+1))
>> "!PY_SCRIPT!" echo     else:
>> "!PY_SCRIPT!" echo         matches = re.finditer(r'\[\s*(\d+)\s+(\d+)\s*\]^|(\d+)', args_str)
>> "!PY_SCRIPT!" echo         for m in matches:
>> "!PY_SCRIPT!" echo             if m.group(1) and m.group(2):
>> "!PY_SCRIPT!" echo                 start = int(m.group(1))
>> "!PY_SCRIPT!" echo                 end = int(m.group(2))
>> "!PY_SCRIPT!" echo                 if start ^> end:
>> "!PY_SCRIPT!" echo                     start, end = end, start
>> "!PY_SCRIPT!" echo                 ranges_to_extract.append((start, end))
>> "!PY_SCRIPT!" echo             elif m.group(3):
>> "!PY_SCRIPT!" echo                 p = int(m.group(3))
>> "!PY_SCRIPT!" echo                 ranges_to_extract.append((p, p))
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         if not ranges_to_extract:
>> "!PY_SCRIPT!" echo             print("[X] Error: No valid ranges parsed.")
>> "!PY_SCRIPT!" echo             sys.exit(1)
>> "!PY_SCRIPT!" echo         print(f"[*] Mode: Extract {len(ranges_to_extract)} specified ranges")
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo     if merge_output:
>> "!PY_SCRIPT!" echo         suffix_parts = []
>> "!PY_SCRIPT!" echo         for r in ranges_to_extract:
>> "!PY_SCRIPT!" echo             start_p, end_p = r
>> "!PY_SCRIPT!" echo             if start_p == end_p:
>> "!PY_SCRIPT!" echo                 suffix_parts.append(f"p{start_p}")
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 suffix_parts.append(f"p{start_p}-{end_p}")
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         if custom_output:
>> "!PY_SCRIPT!" echo             out_path = os.path.abspath(custom_output)
>> "!PY_SCRIPT!" echo             out_name = os.path.basename(out_path)
>> "!PY_SCRIPT!" echo         elif suffix_parts:
>> "!PY_SCRIPT!" echo             suffix_str = "_".join(suffix_parts)
>> "!PY_SCRIPT!" echo             if len(suffix_str) ^> 40:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_extracted.pdf"
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_{suffix_str}.pdf"
>> "!PY_SCRIPT!" echo             out_path = os.path.join(file_dir, out_name)
>> "!PY_SCRIPT!" echo         else:
>> "!PY_SCRIPT!" echo             sys.exit(1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         if os.path.exists(out_path) and not force_mode:
>> "!PY_SCRIPT!" echo             print(f"[X] Error: Output file '{out_name}' already exists. Use --force to overwrite.")
>> "!PY_SCRIPT!" echo             sys.exit(1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         writer = PdfWriter()
>> "!PY_SCRIPT!" echo         added_pages = 0
>> "!PY_SCRIPT!" echo         for r in ranges_to_extract:
>> "!PY_SCRIPT!" echo             start_p, end_p = r
>> "!PY_SCRIPT!" echo             start_idx = max(0, start_p - 1)
>> "!PY_SCRIPT!" echo             end_idx = min(total_pages - 1, end_p - 1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             if start_idx ^> end_idx or start_idx ^>= total_pages:
>> "!PY_SCRIPT!" echo                 print(f"[!] Warning: Range {start_p}-{end_p} is out of bounds. Skipping.")
>> "!PY_SCRIPT!" echo                 continue
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             for p in range(start_idx, end_idx + 1):
>> "!PY_SCRIPT!" echo                 writer.add_page(reader.pages[p])
>> "!PY_SCRIPT!" echo                 added_pages += 1
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         if added_pages ^> 0:
>> "!PY_SCRIPT!" echo             with open(out_path, "wb") as f:
>> "!PY_SCRIPT!" echo                 writer.write(f)
>> "!PY_SCRIPT!" echo             if force_mode:
>> "!PY_SCRIPT!" echo                 print(f"[+] Overwrote single merged file: {out_name}")
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 print(f"[+] Created single merged file: {out_name}")
>> "!PY_SCRIPT!" echo         else:
>> "!PY_SCRIPT!" echo             print("[X] Error: No valid pages were extracted.")
>> "!PY_SCRIPT!" echo     else:
>> "!PY_SCRIPT!" echo         # Pre-flight check to abort early if ANY output file exists
>> "!PY_SCRIPT!" echo         for r in ranges_to_extract:
>> "!PY_SCRIPT!" echo             start_p, end_p = r
>> "!PY_SCRIPT!" echo             if start_p == end_p:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_p{start_p}.pdf"
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_p{start_p}-{end_p}.pdf"
>> "!PY_SCRIPT!" echo             out_path = os.path.join(file_dir, out_name)
>> "!PY_SCRIPT!" echo             if os.path.exists(out_path) and not force_mode:
>> "!PY_SCRIPT!" echo                 print(f"[X] Error: Output file '{out_name}' already exists. Use --force to overwrite.")
>> "!PY_SCRIPT!" echo                 sys.exit(1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo         # Actual extraction loop
>> "!PY_SCRIPT!" echo         for r in ranges_to_extract:
>> "!PY_SCRIPT!" echo             start_p, end_p = r
>> "!PY_SCRIPT!" echo             start_idx = max(0, start_p - 1)
>> "!PY_SCRIPT!" echo             end_idx = min(total_pages - 1, end_p - 1)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             if start_idx ^> end_idx or start_idx ^>= total_pages:
>> "!PY_SCRIPT!" echo                 print(f"[!] Warning: Range {start_p}-{end_p} is out of bounds. Skipping.")
>> "!PY_SCRIPT!" echo                 continue
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             writer = PdfWriter()
>> "!PY_SCRIPT!" echo             for p in range(start_idx, end_idx + 1):
>> "!PY_SCRIPT!" echo                 writer.add_page(reader.pages[p])
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             if start_p == end_p:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_p{start_p}.pdf"
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 out_name = f"{base_name}_p{start_p}-{end_p}.pdf"
>> "!PY_SCRIPT!" echo             out_path = os.path.join(file_dir, out_name)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             with open(out_path, "wb") as f:
>> "!PY_SCRIPT!" echo                 writer.write(f)
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo             if force_mode:
>> "!PY_SCRIPT!" echo                 print(f"[+] Overwrote: {out_name}")
>> "!PY_SCRIPT!" echo             else:
>> "!PY_SCRIPT!" echo                 print(f"[+] Created: {out_name}")
>> "!PY_SCRIPT!" echo.
>> "!PY_SCRIPT!" echo if __name__ == "__main__":
>> "!PY_SCRIPT!" echo     try:
>> "!PY_SCRIPT!" echo         main()
>> "!PY_SCRIPT!" echo     except Exception as e:
>> "!PY_SCRIPT!" echo         print(f"[X] An error occurred: {e}")
>> "!PY_SCRIPT!" echo         sys.exit(1)

python "!PY_SCRIPT!" %*
SET "RET=!ERRORLEVEL!"

del "!PY_SCRIPT!"
exit /b !RET!
