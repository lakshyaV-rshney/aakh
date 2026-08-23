@echo off
REM ============================================================
REM  Aakh - Local Build Script
REM  Runs the full nightly pipeline on your machine.
REM  Usage: double-click this file, or run from cmd/PowerShell:
REM         .\build.bat
REM ============================================================

chcp 65001 >nul 2>&1

echo.
echo ============================================
echo   Aakh Local Build
echo ============================================
echo.

echo [1/9] Installing dependencies...
pip install -q -r requirements.txt

echo [2/9] Fetching GitHub trending repos...
python scripts/fetch_github_trending.py

echo [3/9] Fetching competitions...
python scripts/fetch_competitions.py

echo [4/9] Fetching bug bounty programs...
python scripts/fetch_bug_bounties.py

echo [5/9] Fetching Hacker News stories...
python scripts/fetch_hackernews_rss.py

echo [6/9] Fetching word of the day...
python scripts/fetch_word_of_day.py

echo [7/9] Ranking hot topics with Groq LLM...
python scripts/rank_hot_topics.py

echo [8/9] Building dashboard data...
python scripts/build_dashboard_data.py

echo [9/9] Generating audio briefings...
python scripts/generate_audio.py

echo.
echo ============================================
echo   Build complete!
echo   Starting local server on port 8000...
echo   Opening http://localhost:8000
echo   Press Ctrl+C to stop the server.
echo ============================================
echo.

start http://localhost:8000
cd docs
python -m http.server 8000
