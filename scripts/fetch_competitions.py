"""
fetch_competitions.py
Uses Devpost JSON API + Devfolio JSON API + MLH scrape.
JSON APIs are more stable than scraping.
"""

import json, os, time
from datetime import datetime, timezone
import requests, yaml
from bs4 import BeautifulSoup

CONFIG_PATH = "config/sources.yaml"
OUTPUT_PATH = "data/competitions.json"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "application/json",
}


def fetch_devpost() -> list:
    results = []
    try:
        r = requests.get(
            "https://devpost.com/api/hackathons",
            headers=HEADERS,
            params={"status[]": "open", "order_by": "deadline", "per_page": 10},
            timeout=20,
        )
        r.raise_for_status()
        for h in r.json().get("hackathons", []):
            prize_raw = str(h.get("prize_amount", ""))
            prize_clean = ""
            if prize_raw and prize_raw != "None":
                prize_clean = BeautifulSoup(prize_raw, "html.parser").get_text()
            
            results.append({
                "title":    h.get("title", ""),
                "url":      h.get("url", ""),
                "deadline": h.get("submission_period_dates", "See link"),
                "prize":    prize_clean if prize_clean else None,
                "source":   "Devpost",
            })
        print(f"  Devpost: {len(results)}")
    except Exception as e:
        print(f"  x Devpost: {e}")
    return results


def fetch_devfolio() -> list:
    results = []
    try:
        r = requests.get(
            "https://api.devfolio.co/api/hackathons",
            headers=HEADERS,
            params={"page": 1, "per_page": 10},
            timeout=20,
        )
        r.raise_for_status()
        data = r.json()
        items = data if isinstance(data, list) else data.get("results", [])
        for h in items[:10]:
            ends = h.get("ends_at") or h.get("submission_deadline") or "See link"
            if "T" in str(ends):
                try:
                    ends = datetime.fromisoformat(
                        ends.replace("Z", "+00:00")
                    ).strftime("%b %d, %Y")
                except Exception:
                    pass
            results.append({
                "title":    h.get("name", h.get("title", "")),
                "url":      f"https://devfolio.co/hackathons/{h.get('slug','')}",
                "deadline": ends,
                "source":   "Devfolio",
            })
        print(f"  Devfolio: {len(results)}")
    except Exception as e:
        print(f"  x Devfolio: {e}")
    return results


def fetch_mlh(year: int) -> list:
    results = []
    try:
        r = requests.get(
            f"https://mlh.io/seasons/{year}/events",
            headers={**HEADERS, "Accept": "text/html"},
            timeout=20,
        )
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        for event in soup.select(".event, div.feature.event")[:10]:
            title = event.select_one("h3.event-name, h3, h2")
            link  = event.select_one("a[href]")
            date  = event.select_one("p.event-date, [class*='date'], time")
            if not title:
                continue
            href = link["href"] if link else "#"
            if href.startswith("/"):
                href = "https://mlh.io" + href
            results.append({
                "title":    title.get_text(strip=True),
                "url":      href,
                "deadline": date.get_text(strip=True) if date else "See link",
                "source":   "MLH",
            })
        print(f"  MLH: {len(results)}")
    except Exception as e:
        print(f"  x MLH: {e}")
    return results


def main():
    with open(CONFIG_PATH) as f:
        cfg = yaml.safe_load(f)
    sources = cfg["competitions"]["sources"]
    mlh_year = next((s["mlh_year"] for s in sources if s.get("mlh_year")), datetime.now().year)

    all_comps = []
    all_comps.extend(fetch_devpost());  time.sleep(1)
    all_comps.extend(fetch_devfolio()); time.sleep(1)
    all_comps.extend(fetch_mlh(mlh_year))

    seen, unique = set(), []
    for c in all_comps:
        k = c["title"].lower().strip()
        if k and k not in seen:
            seen.add(k); unique.append(c)

    os.makedirs("data", exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump({"fetched_at": datetime.now(timezone.utc).isoformat(),
                   "competitions": unique}, f, indent=2)
    print(f"Done: {len(unique)} competitions")

if __name__ == "__main__":
    main()
