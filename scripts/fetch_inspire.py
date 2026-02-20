#!/usr/bin/env python3
"""
Fetch personal publications from INSPIRE-HEP and write to references/INSPIRE.bib.

Filters out large collaboration papers (LVK, etc.) using:
  1. Collaboration field contains known large collaborations
  2. First author surname in known list
  3. Author count >= 500

Run as Quarto pre-render hook or standalone.
"""

import json
import os
import sys
import urllib.request
import urllib.error
import urllib.parse

AUTHOR_ID = "S.R.Green.1"
INSPIRE_RECID = "1073848"
BIB_OUTPUT = os.path.join(os.path.dirname(__file__), "..", "references", "INSPIRE.bib")
CITATIONS_OUTPUT = os.path.join(os.path.dirname(__file__), "..", "references", "citations.json")

# Large collaborations to filter
COLLAB_KEYWORDS = [
    "LIGO", "Virgo", "KAGRA", "LVK", "LIGO Scientific",
    "IceCube", "ATLAS", "CMS", "Planck",
]

# Known first-author surnames for large collaboration papers
COLLAB_FIRST_AUTHORS = {"Abbott", "Abac", "Aasi", "Acernese", "Ade"}

# Minimum author count to be considered a large collaboration paper
COLLAB_AUTHOR_THRESHOLD = 500

API_BASE = "https://inspirehep.net/api"


def fetch_json(url):
    """Fetch JSON from a URL."""
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_bibtex(url):
    """Fetch BibTeX from a URL."""
    req = urllib.request.Request(url, headers={"Accept": "application/x-bibtex"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8")


def is_collaboration_paper(record):
    """Check whether a record is a large collaboration paper."""
    metadata = record.get("metadata", {})

    # Check 1: collaboration field
    collabs = metadata.get("collaborations", [])
    for c in collabs:
        name = c.get("value", "")
        for keyword in COLLAB_KEYWORDS:
            if keyword.lower() in name.lower():
                return True

    # Check 2: first author surname
    authors = metadata.get("authors", [])
    if authors:
        first = authors[0].get("last_name", "") or authors[0].get("full_name", "").split(",")[0]
        if first.strip() in COLLAB_FIRST_AUTHORS:
            return True

    # Check 3: author count
    author_count = metadata.get("number_of_authors", len(authors))
    if author_count >= COLLAB_AUTHOR_THRESHOLD:
        return True

    return False


def get_texkey(record):
    """Extract the texkey (cite key) from a record."""
    texkeys = record.get("metadata", {}).get("texkeys", [])
    return texkeys[0] if texkeys else None


def main():
    bib_path = os.path.abspath(BIB_OUTPUT)
    print(f"[INSPIRE] Fetching publications for {AUTHOR_ID}...")

    try:
        # Fetch all records for this author
        personal_keys = set()
        citation_counts = {}
        page = 1
        page_size = 100

        while True:
            url = (
                f"{API_BASE}/literature?sort=mostrecent&size={page_size}&page={page}"
                f"&q=a%20{urllib.parse.quote(AUTHOR_ID)}"
            )
            data = fetch_json(url)
            hits = data.get("hits", {}).get("hits", [])

            if not hits:
                break

            for record in hits:
                if not is_collaboration_paper(record):
                    key = get_texkey(record)
                    if key:
                        personal_keys.add(key)
                        count = record.get("metadata", {}).get("citation_count", 0)
                        citation_counts[key] = count or 0

            total = data.get("hits", {}).get("total", 0)
            if page * page_size >= total:
                break
            page += 1

        print(f"[INSPIRE] Found {len(personal_keys)} personal papers (filtered out collaboration papers)")

        if not personal_keys:
            print("[INSPIRE] WARNING: No papers found. Keeping existing .bib file.")
            return

        # Fetch BibTeX for all personal papers
        # Use the literature search to get bibtex format
        all_bibtex = []
        page = 1

        while True:
            url = (
                f"{API_BASE}/literature?sort=mostrecent&size={page_size}&page={page}"
                f"&q=a%20{urllib.parse.quote(AUTHOR_ID)}"
                f"&format=bibtex"
            )
            bibtex = fetch_bibtex(url)
            if bibtex.strip():
                all_bibtex.append(bibtex)

            # Check if we need more pages
            json_url = (
                f"{API_BASE}/literature?sort=mostrecent&size={page_size}&page={page}"
                f"&q=a%20{urllib.parse.quote(AUTHOR_ID)}"
            )
            data = fetch_json(json_url)
            total = data.get("hits", {}).get("total", 0)
            if page * page_size >= total:
                break
            page += 1

        # Parse and filter BibTeX entries
        combined_bib = "\n".join(all_bibtex)
        filtered_entries = []
        current_entry = []
        brace_depth = 0

        for line in combined_bib.split("\n"):
            if line.strip().startswith("@") and "{" in line:
                current_entry = [line]
                brace_depth = line.count("{") - line.count("}")
            elif current_entry:
                current_entry.append(line)
                brace_depth += line.count("{") - line.count("}")
                if brace_depth <= 0:
                    entry_text = "\n".join(current_entry)
                    # Extract key from @type{key,
                    first_line = current_entry[0]
                    if "{" in first_line:
                        key = first_line.split("{", 1)[1].split(",")[0].strip()
                        if key in personal_keys:
                            filtered_entries.append(entry_text)
                    current_entry = []
                    brace_depth = 0

        output = "\n\n".join(filtered_entries) + "\n"
        os.makedirs(os.path.dirname(bib_path), exist_ok=True)

        with open(bib_path, "w", encoding="utf-8") as f:
            f.write(output)

        print(f"[INSPIRE] Wrote {len(filtered_entries)} entries to {bib_path}")

        # Write citation counts JSON
        citations_path = os.path.abspath(CITATIONS_OUTPUT)
        with open(citations_path, "w", encoding="utf-8") as f:
            json.dump(citation_counts, f, indent=2, sort_keys=True)
            f.write("\n")

        print(f"[INSPIRE] Wrote citation counts for {len(citation_counts)} papers to {citations_path}")

    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        print(f"[INSPIRE] Network error: {e}")
        if os.path.exists(bib_path):
            print(f"[INSPIRE] Keeping existing {bib_path}")
        else:
            print(f"[INSPIRE] WARNING: No existing .bib file found at {bib_path}")
        return
    except Exception as e:
        print(f"[INSPIRE] Unexpected error: {e}")
        if os.path.exists(bib_path):
            print(f"[INSPIRE] Keeping existing {bib_path}")
        return


if __name__ == "__main__":
    main()
