"""
rank_hot_topics.py
Distribution: 2 repos, 2 HN, 1 competition, 1 bug bounty, 2 wildcards = 8 total
Includes JSON extraction fallback for when Groq wraps output in prose.
"""

import json, os, re
from datetime import datetime, timezone
from pathlib import Path
from groq import Groq
import yaml

CONFIG_PATH = "config/sources.yaml"
OUTPUT_PATH = "data/hot_topics.json"


def load_activity(path: str) -> str:
    p = Path(path)
    return p.read_text().strip() if p.exists() else ""


def build_pool() -> str:
    lines = []
    for path, key, tag in [
        ("data/repos.json",        "repos",        "REPO"),
        ("data/hn.json",           "stories",      "HN"),
        ("data/competitions.json", "competitions", "COMPETITION"),
        ("data/bug_bounties.json", "bug_bounties", "BUGBOUNTY"),
    ]:
        p = Path(path)
        if not p.exists():
            continue
        items = json.loads(p.read_text()).get(key, [])
        lines.append(f"\n=== {tag} ===")
        for item in items[:12]:
            title = item.get("title", item.get("name", ""))
            desc  = item.get("description", item.get("summary", ""))[:80]
            url   = item.get("url", "")
            lines.append(f"[{tag}] {title} -- {desc} {url}")
    return "\n".join(lines)


def extract_json(raw: str) -> list:
    """Multiple strategies to extract a JSON array from model output."""
    raw = raw.strip()

    # Strategy 1: already valid JSON array
    try:
        return json.loads(raw)
    except Exception:
        pass

    # Strategy 2: strip markdown fences
    cleaned = re.sub(r"```(?:json)?", "", raw).strip().rstrip("`").strip()
    try:
        return json.loads(cleaned)
    except Exception:
        pass

    # Strategy 3: find first [...] block
    match = re.search(r"\[.*\]", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except Exception:
            pass

    # Strategy 4: find all {...} objects individually
    objects = re.findall(r"\{[^{}]+\}", raw, re.DOTALL)
    if objects:
        parsed = []
        for obj in objects:
            try:
                parsed.append(json.loads(obj))
            except Exception:
                pass
        if parsed:
            return parsed

    raise ValueError(f"Could not extract JSON:\n{raw[:300]}")


def call_groq(activity: str, pool: str, fallback: str, model: str) -> list:
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    client = Groq(api_key=os.environ["GROQ_API_KEY"])

    activity_section = (
        f"User's recent activity:\n---\n{activity}\n---"
        if activity else f"No activity log. {fallback}"
    )

    system = (
        "You are a personalization engine for a student developer morning dashboard. "
        "Return EXACTLY 8 items as a raw JSON array. "
        "No markdown, no explanation, no text before or after. "
        "Start your response with [ and end with ].\n\n"
        "Required distribution:\n"
        "- 2 items type=repo\n"
        "- 2 items type=hn\n"
        "- 1 item  type=competition\n"
        "- 1 item  type=bugbounty\n"
        "- 2 items type=floater\n\n"
        "Format each item EXACTLY like this (use REAL data from the pool, NO literal '...' placeholders!):\n"
        '{"type": "repo", "title": "Actual Title", "description": "Actual Description", "url": "https://...", '
        '"big_question": "Your generated insight", "head_fake": "Your generated head fake"}'
    )

    for attempt in range(2):
        try:
            resp = client.chat.completions.create(
                model=model,
                max_tokens=2500,
                temperature=0.3,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user",   "content":
                        f"{activity_section}\n\nPool:\n{pool}\n\nReturn the JSON array now:"},
                ],
            )
            return extract_json(resp.choices[0].message.content)
        except Exception as e:
            print(f"  attempt {attempt + 1} failed: {e}")
            if attempt == 1:
                raise

    raise RuntimeError("Groq failed after 2 attempts")


def enforce_distribution(topics: list) -> list:
    # Filter out dummy items the LLM might hallucinate
    topics = [t for t in topics if t.get("title") and t.get("title") != "Actual Title" and t.get("title") != "..."]
    
    required = {"repo": 2, "hn": 2, "competition": 1, "bugbounty": 1, "floater": 2}
    by_type  = {}
    for t in topics:
        by_type.setdefault(t.get("type", "floater"), []).append(t)

    final = []
    for typ, count in required.items():
        final.extend(by_type.get(typ, [])[:count])

    used      = set(id(t) for t in final)
    remaining = [t for t in topics if id(t) not in used]
    while len(final) < 8 and remaining:
        final.append(remaining.pop(0))

    # Fallback to local files if LLM failed to provide 8 items
    if len(final) < 8:
        print("  LLM provided insufficient valid items. Falling back to local data.")
        try:
            with open("data/repos.json") as f:
                r_data = json.load(f).get("repos", [])[:2]
                for r in r_data:
                    if len(final) < 8: final.append({"type": "repo", "title": r.get("name",""), "url": r.get("url",""), "description": r.get("description","")})
            with open("data/hn.json") as f:
                h_data = json.load(f).get("stories", [])[:2]
                for h in h_data:
                    if len(final) < 8: final.append({"type": "hn", "title": h.get("title",""), "url": h.get("url","")})
            with open("data/competitions.json") as f:
                c_data = json.load(f).get("competitions", [])[:2]
                for c in c_data:
                    if len(final) < 8: final.append({"type": "competition", "title": c.get("title",""), "url": c.get("url","")})
            with open("data/bug_bounties.json") as f:
                b_data = json.load(f).get("bug_bounties", [])[:2]
                for b in b_data:
                    if len(final) < 8: final.append({"type": "bugbounty", "title": b.get("title",""), "url": b.get("url","")})
        except Exception as e:
            print(f"  Fallback failed: {e}")

    return final[:8]


def main():
    with open(CONFIG_PATH) as f:
        cfg = yaml.safe_load(f)

    activity = load_activity(cfg["activity"]["digest_path"])
    fallback = cfg["activity"]["fallback_prompt"]
    model    = cfg.get("groq", {}).get("model", "llama-3.3-70b-versatile")
    pool     = build_pool()

    print(f"  activity: {'loaded' if activity else 'using fallback'}")
    print(f"  pool: {len(pool.splitlines())} lines")
    print(f"  model: {model}")
    print("  calling Groq...")

    topics = call_groq(activity, pool, fallback, model)
    final  = enforce_distribution(topics)

    os.makedirs("data", exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump({
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "hot_topics": final,
        }, f, indent=2)

    print(f"Done: {len(final)} hot topics")
    for t in final:
        print(f"  [{t.get('type','?'):12}] {t.get('title','')[:55]}")


if __name__ == "__main__":
    main()
