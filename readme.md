# Automated Quarto Report Generation (Reproducible Example)

Modern, scalable survey reporting with R, tidyverse, and Quarto — the anonymized companion repo for the Posit Conf 2025 talk “Using Quarto to Improve Formatting and Automate the Generation of Hundreds of Reports”.

## Why This Exists

KS&R’s DSI team automated weekly production of hundreds of personalized PDF reports over several months. This repo demonstrates the core pattern end‑to‑end on anonymized, fake data: clean inputs, generate parameterized Quarto files, render to PDF with consistent branding, and archive outputs — all reproducibly in Git with `renv`.

## What You Get

- Automated PDF generation for many recipients in one run
- Consistent formatting via Quarto + LaTeX (XeLaTeX, Arial)
- Simple, composable R functions for data prep and rendering
- Reproducible environment via `renv` (R 4.4.x lockfile included)

---

## Repository Layout

- `_quarto.yml`: Global Quarto config for PDF rendering (fonts, header/footer, engine).
- `run.R`: Orchestrates the full pipeline: load → filter → generate `.qmd` → render PDFs → archive.
- `report_template/report_template.qmd`: Parameterized report body (no YAML) used for every recipient.
- `R/clean_and_tidy.R`: Input cleanup and normalization.
- `R/filter_resps.R`: Date‑window filtering of responses.
- `R/report_building.R`: Utilities that build sections/tables from survey data.
- `R/html_tags.R`: HTML stripping helpers for text fields.
- `R/utils.R`: LaTeX escaping helpers for robust PDF output.
- `data/anon_data.tsv`: Example anonymized data in TSV.
- `renv.lock`, `renv/`: Reproducible R environment.

---

## Requirements

- R 4.4.x (lockfile was created with 4.4.3)
- Quarto CLI (https://quarto.org) with PDF support
- LaTeX with XeLaTeX (TinyTeX recommended: `tinytex::install_tinytex()`)
- Windows/macOS/Linux supported; examples assume RStudio or R terminal

---

## Setup

1) Clone and open the project (RStudio or terminal in the project root).

2) Restore the R library with `renv`:

```r
install.packages("renv")             # if not already installed
renv::restore()                       # installs the locked package versions
```

3) Verify Quarto + XeLaTeX are available:

```bash
quarto check
```

If PDF is missing, install TinyTeX from R:

```r
install.packages("tinytex")
tinytex::install_tinytex()
```

---

## Quick Start

1) Put your TSV in `data/anon_data.tsv` (the included file is a working example).
2) Adjust the date window in two places: a) `run.R` (search for `start_date` and `end_date`) and b) `report_template/report_template.qmd`
3) Run the automation:

```r
# or step through it line-by-line
source("run.R")
```

Outputs are written to `output/<YYYY-MM-DD>/` with a `log.txt` for the run. PDFs are named like:

```
Online Results - {customer}, {first_name} {last_name}.pdf
```

---

## How It Works

1) Data load and cleanup
   - Reads `data/anon_data.tsv` and normalizes columns (`R/clean_and_tidy.R`).
   - Strips HTML from question text and standardizes sub‑question numbering.

2) Filter the run window
   - `R/filter_resps.R` selects rows between `start_date` and `end_date` (default column: `complete_datetime`).

3) Generate dynamic `.qmd`
   - `run.R` builds a YAML header per respondent (parameter `respid`) and concatenates it with `report_template/report_template.qmd` to produce one `.qmd` per report in `./tmp_qmds/`.

4) Render
   - Each `.qmd` is rendered with `quarto::quarto_render()` to PDF using XeLaTeX, fonts, and header/footer defined in `_quarto.yml` and the template.

5) Organize outputs
   - PDFs are moved to `output/<today>/`; temporary `.qmd` and intermediate PDFs in `tmp_qmds/` are cleaned up.

---

## Data Contract (TSV)

The example uses a 14‑column TSV (tab‑delimited). `R/clean_and_tidy.R` drops some raw columns and renames others. Downstream code expects at least:

- Respondent identity: `respid`, `first_name`, `last_name`, `title`, `customer`, `country`
- Timing: `complete_datetime` (POSIXct‑parseable)
- Survey structure: `qid`, `sub_qid`, `main_q_text`, `sub_q_text`
- Values: `response`

Notes:
- `clean_df()` removes prefixes like `pdf_export_` and normalizes `sub_qid` per `qid`.
- `strip_html_tags()` removes any HTML tags in question text.
- Missing `customer` ampersands are replaced (e.g., `A & B` → `A and B`) to keep LaTeX stable.

---

## Formatting and Branding

- PDF engine: XeLaTeX with Arial (`_quarto.yml`).
- Custom header/footer: set via LaTeX in `_quarto.yml` and reinforced in the template to inject respondent metadata (name/customer/country) per report.
- Tables/sections: `R/report_building.R` generates LaTeX tables and labeled sections. Text is escaped for LaTeX safety (`R/utils.R`).

To update the visual identity (fonts, footer text, colors), edit:

- `_quarto.yml` (fonts, header‑includes)
- `report_template/report_template.qmd` (section layout, headings, injected footer text)

---

## Customizing the Workflow

- Date window: edit `start_date` / `end_date` in `run.R` and `report_template/report_template.qmd`.
- Recipient selection: change how `list_of_resps` is derived (e.g., filter by `customer`).
- File naming: adjust `output-file:` construction in `run.R` YAML header.
- Question blocks: modify or add sections in `report_template/report_template.qmd` and/or utilities in `R/report_building.R`.
- Data pre‑QC: set `drop_resp_na = TRUE` in `clean_df()` to enforce presence of key respondent fields.

---

## Troubleshooting

- PDF engine not found: run `quarto check` and install TinyTeX; ensure `xelatex` is on PATH.
- Fonts differ from screenshots: ensure Arial is installed; otherwise change `mainfont`/`sansfont` in `_quarto.yml`.
- “No data in selected window”: verify `start_date`/`end_date` and `complete_datetime` parsing.
- LaTeX errors with special characters: data likely contains characters like `&`, `%`, `{`, `}`. The provided escaping utilities handle this when values flow through the template; ensure any new inline text also passes through `escape_latex()`/`escape_latex_inline()`.

---

## Reproducibility

- Package versions are pinned in `renv.lock`. Use `renv::restore()` for a deterministic library.
- Quarto/LaTeX versions should be stable across runs; for CI or team use, standardize Quarto and TinyTeX versions.
- Outputs are date‑partitioned under `output/` to keep runs auditable alongside the generated `log.txt`.

---

## Attribution and Licensing

This project is licensed under the [MIT License](./LICENSE).

Anonymized example maintained by KS&R’s Decision Sciences & Innovation (DSI) team for the Posit Conf 2025 talk “Using Quarto to Improve Formatting and Automate the Generation of Hundreds of Reports”.
