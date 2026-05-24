#!/usr/bin/env bash
# Concatenates the project's .bib files into references/_all.bib so that
# Obsidian's Citations plugin (which only accepts a single path) sees both
# the INSPIRE-fetched and the manually-curated entries.
#
# Wired into Quarto via the pre-render hook in _quarto.yml. Can also be run
# manually if you're editing references without `quarto preview` running.

set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)/references"
cat "$DIR/INSPIRE.bib" "$DIR/references-other.bib" > "$DIR/_all.bib"
