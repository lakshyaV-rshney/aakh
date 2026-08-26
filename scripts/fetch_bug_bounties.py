"""
fetch_bug_bounties.py
Scrapes bug bounty programs from arkadiyt/bounty-targets-data datasets.
"""

import json, os
from datetime import datetime, timezone
import requests

OUTPUT_PATH = "data/bug_bounties.json"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Aakh/1.2"}

def fetch_hackerone():
    results = []
    try:
        r = requests.get("https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/hackerone_data.json", headers=HEADERS, timeout=15)
        for h in r.json():
            if h.get("offers_bounties") and h.get("submission_state") == "open":
                results.append({
                    "title": h.get("name"),
                    "url": h.get("url"),
                    "bounty": "Bounty offered",
                    "source": "HackerOne"
                })
        print(f"  HackerOne: {len(results)}")
    except Exception as e:
        print(f"  x HackerOne: {e}")
    return results

def fetch_bugcrowd():
    results = []
    try:
        r = requests.get("https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/bugcrowd_data.json", headers=HEADERS, timeout=15)
        for b in r.json():
            max_p = b.get("max_payout", 0)
            if max_p:
                results.append({
                    "title": b.get("name"),
                    "url": b.get("url"),
                    "bounty": f"${max_p:,.0f}",
                    "source": "Bugcrowd"
                })
        print(f"  Bugcrowd: {len(results)}")
    except Exception as e:
        print(f"  x Bugcrowd: {e}")
    return results

def fetch_intigriti():
    results = []
    try:
        r = requests.get("https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/intigriti_data.json", headers=HEADERS, timeout=15)
        for i in r.json():
            if i.get("status") == "open":
                max_b = i.get("max_bounty", {}).get("value", 0)
                cur = i.get("max_bounty", {}).get("currency", "EUR")
                sym = "€" if cur == "EUR" else "$" if cur == "USD" else cur
                results.append({
                    "title": i.get("name"),
                    "url": i.get("url"),
                    "bounty": f"{sym}{max_b:,.0f}" if max_b else "Bounty offered",
                    "source": "Intigriti"
                })
        print(f"  Intigriti: {len(results)}")
    except Exception as e:
        print(f"  x Intigriti: {e}")
    return results

def main():
    all_bounties = []
    all_bounties.extend(fetch_hackerone())
    all_bounties.extend(fetch_bugcrowd())
    all_bounties.extend(fetch_intigriti())

    seen, unique = set(), []
    for b in all_bounties:
        k = b["title"].lower().strip() if b.get("title") else ""
        if k and k not in seen:
            seen.add(k); unique.append(b)

    os.makedirs("data", exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump({"fetched_at": datetime.now(timezone.utc).isoformat(),
                   "bug_bounties": unique}, f, indent=2)
    print(f"Done: {len(unique)} bug bounties")

if __name__ == "__main__":
    main()
