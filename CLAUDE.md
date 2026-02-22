# Stephen Green's Academic Website

## Overview

Quarto website for Dr. Stephen Green, Principal Research Fellow at the University of Nottingham, School of Mathematical Sciences. Research: machine learning for gravitational waves (simulation-based inference / Dingo) and classical gravity (black hole perturbation theory, AdS dynamics, cosmological backreaction).

**Name**: Use "Stephen Green" (not "Stephen R. Green") throughout.

Deployed to GitHub Pages from `/docs` on the `main` branch at [stephenrgreen.com](https://stephenrgreen.com).

## Tech Stack

- **Quarto** (v1.8+) static site generator
- **SCSS** themes: `styles/theme-light.scss`, `styles/theme-dark.scss`, `styles/custom.scss`
- **Lua filter**: `scripts/group-refs-by-year.lua` — groups bibliography by year on the publications page. Uses `pandoc.utils.citeproc(doc)` internally because Quarto runs user filters before citeproc; requires `citeproc: false` in publications/index.qmd YAML.
- **Python script**: `scripts/fetch_inspire.py` — pulls personal publications from INSPIRE-HEP API, filtering out LVK collaboration papers. Currently commented out as pre-render hook in `_quarto.yml`.
- **Extension**: `mcanouil/quarto-iconify` — only extension used.

## Key Design Decisions

- **Fonts**: Source Serif 4 (body/headings), Source Sans 3 (UI elements: navbar, buttons, labels, dates), JetBrains Mono (code). Serif is the primary body font.
- **Colors**: Warm cream background (#faf9f6), scholarly blue accent (#1e5a96), navy text (#1b2a4a). Dark mode: deep blue-grey (#101824), muted blue (#6ba3d6).
- **No title-block-banner** anywhere. No Cosmo/Solar themes. Built on Quarto's `default` theme.
- **Homepage** uses `page-layout: custom` with centered photo/bio hero.
- Publications page has hand-curated highlights at top, then full auto-generated bibliography grouped by year.

## Structure

```
_quarto.yml          # Site config, navbar, footer, bibliography
_variables.yml       # Social links, IDs (orcid, github, email, etc.)
index.qmd            # Homepage (page-layout: custom)
research/
  index.qmd          # Overview
  sbi/index.qmd      # ML for gravitational waves
  gravity/index.qmd  # Classical gravity
publications/index.qmd  # Highlights + full bibliography
talks/index.qmd      # Selected recorded talks
team/index.qmd       # Research group
blog/                # News posts (navbar says "News")
  index.qmd          # Listing page
  nature-publication/ # Nature 2025 paper
  flf/               # FLF announcement
  gwfreeride/         # Sexten workshop
  max-dax-phd/       # Max Dax PhD defence
cv/index.qmd         # CV with grid layout
styles/              # SCSS files
scripts/             # Lua filter, INSPIRE fetch script
references/          # .bib and .csl files
```

## Common Pitfalls

- **Quarto wraps div content in `<p>` tags** — all layout components need `> p { margin-bottom: 0; }` in custom.scss.
- **Lua filter must list `quarto` before itself** in the filters array, and needs `citeproc: false` in YAML.
- **All navbar icons use iconify shortcodes** — don't mix with Bootstrap Icons (`icon:` field) as they render at different sizes. Different icon families (fa6-brands, academicons, mdi) have different visual weights at the same font-size; use per-icon `size=` in shortcodes to compensate (e.g., academicons needs ~1.3em to match fa6-brands at 1.2em).
- **Citeproc "References" heading** — `pandoc.utils.citeproc()` and Quarto's appendix system both add "References" headings. Hidden via CSS (`#quarto-appendix .quarto-appendix-heading { display: none; }`) and removed in the Lua filter.
- **Pre-render INSPIRE script** is commented out to avoid blocking preview. Uncomment when ready for production builds.

## Build & Preview

```bash
quarto preview    # Runs on localhost:22222
quarto render     # Builds to docs/
```

## Team (Current)

- Stephen Green (PI)
- Alexandre Göttel (postdoc)
- Lorenzo Pompili (postdoc)
- Matthew Mould (1851 Research Fellow)
- Jacopo Lestingi (PhD)
- Alex Roussopoulos (PhD)
- Cecilia Fabbri (PhD)
- Annalena Kofler (affiliated PhD, MPI-IS)

## Notes

- Blog directory is `/blog/` but the navbar label is "News".
- The team page deliberately does not have an "Alumni" section. MPI-IS collaborators (Max Dax et al.) are mentioned via the intro text linking to MPI-IS/AEI rather than individual entries, to avoid ambiguity about the supervisory relationship.
- Stephen co-supervises MPI-IS students day-to-day but B. Schölkopf is their official supervisor. Be careful about how this is framed.
