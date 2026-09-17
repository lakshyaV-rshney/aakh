@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo         Production PDF OCR Tool
echo ==========================================

:: 1. Validate Input
IF "%~1"=="" (
    echo [X] Usage: %~nx0 "path\to\your\file.pdf" [-o "output.pdf"] [--force]
    exit /b 1
)

SET "INPUT_FILE=%~1"
IF NOT EXIST "!INPUT_FILE!" (
    echo [X] Error: File "!INPUT_FILE!" does not exist.
    exit /b 1
)

:: Extract drive, path, name, and extension
SET "FILE_DRIVE=%~d1"
SET "FILE_PATH=%~p1"
SET "FILE_NAME=%~n1"
SET "FILE_EXT=%~x1"

:: Check if it's a PDF
IF /I NOT "!FILE_EXT!"==".pdf" (
    echo [X] Error: The input file must be a PDF.
    exit /b 1
)

:: Construct Output File Name and Parse Flags
SET "CUSTOM_OUTPUT="
SET "prev="
for %%A in (%*) do (
    IF "!prev!"=="-o" (
        SET "CUSTOM_OUTPUT=%%~A"
        SET "prev="
    ) ELSE IF /I "%%~A"=="-o" (
        SET "prev=-o"
    )
)

IF NOT "!CUSTOM_OUTPUT!"=="" (
    FOR %%I IN ("!CUSTOM_OUTPUT!") DO SET "OUTPUT_FILE=%%~fI"
) ELSE (
    SET "OUTPUT_FILE=!FILE_DRIVE!!FILE_PATH!!FILE_NAME!_ocr.pdf"
)

echo %* | findstr /i "\<--force\>" >nul
IF !ERRORLEVEL! EQU 0 (
    SET "FORCE_MODE=1"
) ELSE (
    SET "FORCE_MODE=0"
)

IF EXIST "!OUTPUT_FILE!" (
    IF "!FORCE_MODE!"=="1" (
        echo [*] Output file "!OUTPUT_FILE!" already exists. --force specified, overwriting...
    ) ELSE (
        echo [X] Error: Output file "!OUTPUT_FILE!" already exists. Use --force to overwrite.
        exit /b 1
    )
)

echo [*] Input:  "!INPUT_FILE!"
echo [*] Output: "!OUTPUT_FILE!"
echo ------------------------------------------

:: 2. Auto-Dependency Check
SET "MISSING_DEPS=0"

tesseract --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    IF NOT EXIST "C:\Program Files\Tesseract-OCR\tesseract.exe" IF NOT EXIST "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe" SET "MISSING_DEPS=1"
)

gswin64c --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    SET "GS_FOUND=0"
    FOR /D %%G IN ("C:\Program Files\gs\gs*") DO IF EXIST "%%G\bin\gswin64c.exe" SET "GS_FOUND=1"
    IF !GS_FOUND! EQU 0 SET "MISSING_DEPS=1"
)

python -c "import ocrmypdf" >nul 2>&1
IF !ERRORLEVEL! NEQ 0 SET "MISSING_DEPS=1"

IF !MISSING_DEPS! EQU 1 (
    echo [*] Missing dependencies detected. Running setup automatically...
    call "%~dp0setup.bat" --auto
    IF !ERRORLEVEL! NEQ 0 (
        echo [X] Setup failed. Cannot proceed.
        exit /b 1
    )
)

:: 3. Ensure Paths are resolved
tesseract --version >nul 2>&1
IF !ERRORLEVEL! EQU 0 goto tesseract_done
IF EXIST "C:\Program Files\Tesseract-OCR\tesseract.exe" SET "PATH=!PATH!;C:\Program Files\Tesseract-OCR" & goto tesseract_done
IF EXIST "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe" SET "PATH=!PATH!;C:\Program Files (x86)\Tesseract-OCR" & goto tesseract_done
:tesseract_done

gswin64c --version >nul 2>&1
IF !ERRORLEVEL! EQU 0 goto gs_done
FOR /D %%G IN ("C:\Program Files\gs\gs*") DO IF EXIST "%%G\bin\gswin64c.exe" SET "PATH=!PATH!;%%G\bin" & goto gs_done
:gs_done

ocrmypdf --version >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    SET "OCR_CMD=ocrmypdf"
    goto cmd_done
)
SET "OCR_CMD=python -m ocrmypdf"
:cmd_done

:: 4. Run OCRmyPDF
echo [*] Starting OCR process... This may take a while depending on file size.

!OCR_CMD! --force-ocr --optimize 1 --output-type pdf "!INPUT_FILE!" "!OUTPUT_FILE!"

IF !ERRORLEVEL! EQU 0 (
    echo [+] Success! Saved to: "!OUTPUT_FILE!"
    exit /b 0
)

echo [!] OCRmyPDF encountered an error ^(Code: !ERRORLEVEL!^).
echo [*] Attempting fallback with --skip-text instead of --force-ocr...
!OCR_CMD! --skip-text --optimize 1 --output-type pdf "!INPUT_FILE!" "!OUTPUT_FILE!"

IF !ERRORLEVEL! EQU 0 (
    echo [+] Fallback Success! Saved to: "!OUTPUT_FILE!"
    exit /b 0
)

echo [X] Fallback failed. Could not process the PDF.
exit /b !ERRORLEVEL!
