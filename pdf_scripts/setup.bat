@echo off
setlocal EnableDelayedExpansion

echo ===================================================
echo     OCRmyPDF, Tesseract ^& PyPDF Setup Script
echo ===================================================

:: 1. Check Python
python --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    echo [!] Python is not installed or not in PATH.
    echo [*] Attempting to install Python via winget...
    winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent
    IF !ERRORLEVEL! NEQ 0 (
        echo [X] Failed to install Python via winget. Please install it manually.
        IF /I NOT "%~1"=="--auto" pause
        exit /b 1
    )
    :: Try to refresh PATH for the current session (best effort)
    FOR /F "tokens=2*" %%A IN ('REG QUERY "HKCU\Environment" /v PATH 2^>nul') DO SET "PATH=%%B;!PATH!"
) ELSE (
    echo [+] Python is installed.
)

:: 2. Check Tesseract
tesseract --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    IF EXIST "C:\Program Files\Tesseract-OCR\tesseract.exe" (
        echo [+] Tesseract is installed in Program Files.
    ) ELSE (
        echo [!] Tesseract OCR not found.
        echo [*] Attempting to install Tesseract via winget...
        winget install UB-Mannheim.TesseractOCR --accept-package-agreements --accept-source-agreements --silent
        IF !ERRORLEVEL! NEQ 0 (
            echo [*] Winget failed. Trying Chocolatey...
            choco install tesseract -y >nul 2>&1
            IF !ERRORLEVEL! NEQ 0 (
                echo [X] Failed to install Tesseract. Please install manually.
                IF /I NOT "%~1"=="--auto" pause
                exit /b 1
            )
        )
    )
) ELSE (
    echo [+] Tesseract OCR is installed.
)

:: 3. Check Ghostscript
gswin64c --version >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    echo [!] Ghostscript not found in PATH.
    echo [*] Attempting to install Ghostscript via winget...
    winget install ArtifexSoftware.GhostScript --accept-package-agreements --accept-source-agreements --silent >nul 2>&1
    IF !ERRORLEVEL! NEQ 0 (
        choco install ghostscript -y >nul 2>&1
    )
) ELSE (
    echo [+] Ghostscript is installed.
)

:: 4. Install pip packages
echo [*] Installing python dependencies...
python -m pip install --upgrade pip >nul 2>&1
python -m pip install ocrmypdf pypdf >nul 2>&1
IF !ERRORLEVEL! NEQ 0 (
    echo [X] Failed to install python packages.
    IF /I NOT "%~1"=="--auto" pause
    exit /b 1
) ELSE (
    echo [+] Python packages installed successfully.
)

echo ===================================================
echo Setup complete!
echo ===================================================
IF /I NOT "%~1"=="--auto" pause
exit /b 0
