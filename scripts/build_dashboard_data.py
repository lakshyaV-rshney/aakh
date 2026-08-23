"""
build_dashboard_data.py — merges all data into docs/data/data.json for the frontend.
Maintains 7-day rolling history for weekly digest.
"""

import json, os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

OUTPUT_PATH  = "docs/data/data.json"
HISTORY_PATH = "data/data_history.json"


def load(path, key, default=None):
    p = Path(path)
    if not p.exists():
        print(f"  missing: {path}")
        return default if default is not None else []
    return json.loads(p.read_text()).get(key, default if default is not None else [])


def update_history(repos):
    path = Path(HISTORY_PATH)
    history = json.loads(path.read_text()) if path.exists() else {"days": []}
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    days  = [d for d in history["days"] if d["date"] != today]
    days.append({"date": today, "repo_names": [r["name"] for r in repos]})
    history["days"] = sorted(days, key=lambda d: d["date"])[-7:]
    with open(HISTORY_PATH, "w") as f:
        json.dump(history, f, indent=2)
    counts = Counter(n for d in history["days"] for n in d["repo_names"])
    return {n for n, c in counts.items() if c >= 2}


def tag_competitions(competitions):
    today = datetime.now(timezone.utc)
    for comp in competitions:
        comp["closing_soon"] = False
        try:
            from dateutil import parser as dp
            dt = dp.parse(comp.get("deadline", ""))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            days = (dt - today).days
            comp["closing_soon"] = 0 <= days <= 7
            comp["days_left"]    = days
        except Exception:
            pass


def main():
    repos        = load("data/repos.json",        "repos")
    competitions = load("data/competitions.json",  "competitions")
    stories      = load("data/hn.json",            "stories")
    hot_topics   = load("data/hot_topics.json",    "hot_topics")
    word_of_day  = load("data/word_of_day.json",   "word_of_day", {})
    bug_bounties = load("data/bug_bounties.json",  "bug_bounties")

    os.makedirs("data", exist_ok=True)
    os.makedirs("docs/data", exist_ok=True)
    trending = update_history(repos)
    for r in repos:
        r["trending_multiday"] = r["name"] in trending

    tag_competitions(competitions)
    monday = datetime.now(timezone.utc).weekday() == 0

    data = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "date_label":   datetime.now(timezone.utc).strftime("%A, %d %B %Y"),
        "is_monday":    monday,
        "word_of_day":  word_of_day,
        "hot_topics":   hot_topics,
        "repos":        repos[:20],
        "competitions": competitions[:8],
        "bug_bounties": bug_bounties[:10],
        "hn_stories":   stories[:8],
    }

    with open(OUTPUT_PATH, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Done: repos={len(data['repos'])} comps={len(data['competitions'])} bounties={len(data['bug_bounties'])} hn={len(data['hn_stories'])}")


if __name__ == "__main__":
    main()
