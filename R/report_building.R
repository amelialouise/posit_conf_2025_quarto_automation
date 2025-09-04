#' ---------------------------------------------------------------------------
#' Helper functions for generating LaTeX tables and narrative from survey data
#' ---------------------------------------------------------------------------
#' The functions below assume `data` is a data.frame/tibble containing (at
#' minimum) the columns `qid`, `main_q_text`, `sub_q_text`, and `response`.
#' They make heavy use of the tidyverse.
#'
#' @section Conventions:
#' * `qid` values identify a question or a question+subpart (e.g., "q7c").
#' * Responses used in tables are assumed to be numeric or at least printable.
#' * LaTeX output is returned as character strings for inclusion in R Markdown.
#'
#' @keywords internal
NULL


# Generalized Extraction Functions --------------------------------------------

#' Get the main (stem) question text for a given question ID
#'
#' Retrieves the distinct `main_q_text` associated with a specific `qid`.
#'
#' @param data A data.frame or tibble with columns `qid` and `main_q_text`.
#' @param qid_string A single character scalar matching a value in `qid`.
#'
#' @return A character vector (length 1) containing the main question text.
#'   If multiple matches exist, the first distinct value is returned.
#'
#' @examples
#' \dontrun{
#' get_main_q_text(survey_df, "q5a")
#' }
#'
#' @importFrom dplyr filter distinct pull
#' @export
get_main_q_text = function(data, qid_string) {
  # Filter rows to the requested qid, keep distinct stem text, then pull vector
  data |>
    dplyr::filter(qid == qid_string) |>
    dplyr::distinct(main_q_text) |>
    dplyr::pull(main_q_text)
}

#' Get the response vector for a given question ID
#'
#' Pulls the `response` values associated with a specific `qid`.
#'
#' @param data A data.frame or tibble with columns `qid` and `response`.
#' @param qid_string A single character scalar matching a value in `qid`.
#'
#' @return A vector (often numeric) of responses corresponding to `qid_string`.
#'
#' @examples
#' \dontrun{
#' get_response(survey_df, "q7c")
#' }
#'
#' @importFrom dplyr filter pull
#' @export
get_response = function(data, qid_string) {
  # Filter to target qid and pull the response column as a vector
  data |>
    dplyr::filter(qid == qid_string) |>
    dplyr::pull(response)
}

#' Get the sub-question labels/text for a given question ID
#'
#' Pulls the `sub_q_text` values associated with a specific `qid`.
#'
#' @param data A data.frame or tibble with columns `qid` and `sub_q_text`.
#' @param qid_string A single character scalar matching a value in `qid`.
#'
#' @return A character vector of sub-question text associated with `qid_string`.
#'
#' @examples
#' \dontrun{
#' get_sub_q_text(survey_df, "q7c")
#' }
#'
#' @importFrom dplyr filter pull
#' @export
get_sub_q_text = function(data, qid_string) {
  # Filter to target qid and pull the sub-question text
  data |>
    dplyr::filter(qid == qid_string) |>
    dplyr::pull(sub_q_text)
}


# Dynamic row-number table generation -----------------------------------------

#' Create a LaTeX table for sub-items and scores
#'
#' Given parallel vectors of sub-question text and response values, builds a
#' LaTeX `tabular` environment with booktabs-style rules and light gray row
#' separators between items (except after the last row).
#'
#' @param response_vec A vector of responses (numeric or character). Length N.
#' @param sub_q_text_vec A character vector of sub-question labels/text. Length N.
#'
#' @return A single character string containing LaTeX code for the table.
#'
#' @details
#' The table uses two columns:
#' * `p{0.6\\linewidth}` for the item text
#' * `p{0.2\\linewidth}` for the score
#'
#' It expects `booktabs` and `xcolor` (for `\\arrayrulecolor`) to be available
#' in the LaTeX preamble.
#'
#' @examples
#' \dontrun{
#' latex_tbl <- create_table(response_vec = 1:3,
#'                           sub_q_text_vec = c("Clarity", "Ease", "Support"))
#' cat(latex_tbl)
#' }
#'
#' @importFrom glue glue glue_collapse
#' @importFrom purrr map2_chr
#' @export
create_table <- function(response_vec, sub_q_text_vec) {
  # Basic sanity: assume the user passes parallel vectors of equal length
  rows <- length(response_vec)

  # Define the LaTeX table header and column alignment
  header_setup <- "\\begin{tabular}{p{0.6\\linewidth} p{0.2\\linewidth}}\n\\toprule\n\\textbf{Item} & \\textbf{Score} \\\\ \\midrule"

  # Generate row text for all rows except the last—add thin gray rule after each
  row_text <- purrr::map2_chr(
    sub_q_text_vec[1:(rows - 1)],
    response_vec[1:(rows - 1)],
    function(question, score) {
      glue::glue(
        "\\addlinespace[0.2cm]\n{question} & {score} \\\\ \\addlinespace[0.2cm]\n\\arrayrulecolor[gray]{{0.8}}\\hline\\arrayrulecolor{{black}}"
      )
    }
  ) |>
    glue::glue_collapse(sep = "\n")

  # Last row: same spacing, but no gray rule afterward
  last_row <- glue::glue(
    "\\addlinespace[0.2cm]\n{sub_q_text_vec[[rows]]} & {response_vec[[rows]]} \\\\ \\addlinespace[0.2cm]"
  )

  # Table footer
  table_footer <- "\\bottomrule\n\\end{tabular}"

  # Stitch together header, body, and footer
  table_text <- glue::glue(
    "{header_setup}\n{row_text}\n{last_row}\n{table_footer}"
  )

  return(table_text)
}


# Iteratively build responses for Q5–Q10 (conditional on Q3 selection) --------

#' Generate narrative + tables for Q5–Q10 based on Q3 selections
#'
#' Builds LaTeX sections and tables for questions Q5–Q10, conditioned on which
#' product lines the respondent selected in Q3. Q3 responses are cleaned and
#' matched to a lookup of selection -> letter code (a–d), which is used to
#' identify dependent question IDs (e.g., `q5a`, `q6a`, ..., `q10a`).
#'
#' For each selected product line, the function prints:
#' 1) A LaTeX-styled header block, and
#' 2) For each dependent question, the question text + a two-column LaTeX table
#'    of sub-item text and scores, followed by a 5-point scale footnote.
#'
#' @param data A data.frame or tibble containing, at minimum, columns:
#'   `qid`, `main_q_text`, `sub_q_text`, and `response`.
#'
#' @return Invisibly returns `NULL`; the function prints LaTeX to the console
#'   via `cat()` for immediate use in R Markdown rendering.
#'
#' @section Dependencies:
#' Uses `dplyr`, `stringr`, `purrr`, `glue`, `tibble`, and `xfun::escape_latex()`.
#'
#' @note
#' This function uses `cat()` to emit LaTeX directly. If you prefer to capture
#' output instead (e.g., for unit tests), wrap calls in `capture.output()`.
#'
#' @examples
#' \dontrun{
#' generate_q5_q10(survey_df)
#' }
#'
#' @importFrom dplyr filter pull distinct
#' @importFrom stringr str_remove_all str_replace str_replace_all str_split str_detect
#' @importFrom purrr map map_lgl walk
#' @importFrom glue glue
#' @importFrom tibble tribble
#' @importFrom xfun escape_latex
#' @export
generate_q5_q10 = function(data) {
  # Pull and escape the Q3 response (product line selections)
  q3_resp = get_response(data, "q3") |>
    escape_latex()

  # Clean Q3 string:
  #  - remove any parenthetical notes
  #  - drop the literal word "and"
  #  - collapse double spaces
  #  - replace ", " with ";" to split on semicolons consistently
  q3_resp_clean = q3_resp |>
    stringr::str_remove_all("\\s*\\([^()]*\\)") |>
    stringr::str_remove_all("\\s*\\([^()]*\\)") |>
    stringr::str_replace("and", "") |>
    stringr::str_replace_all("\\s{2,}", " ") |>
    stringr::str_replace_all(", ", ";")

  # Mapping of selection text to sub-letter used in dependent qids
  lookup_table = tibble::tribble(
    ~selection,
    ~letter,
    "[Vendor] [Sector 1]",
    "a",
    "[Vendor] [Sector 2]",
    "b",
    "[Vendor] [Sector 3]",
    "c",
    "[Vendor] [Sector 4]",
    "d"
  )

  # Split cleaned Q3 into a character vector of selections
  resps = stringr::str_split(q3_resp_clean, ";") |>
    unlist()

  # Get corresponding letter codes for selected product lines
  list_of_sub_letters = lookup_table |>
    dplyr::filter(selection %in% resps) |>
    dplyr::pull(letter)

  # Remove letters that have no matching dependent qids in the data
  unique_qids = data |>
    dplyr::pull(qid) |>
    unique()

  # All dependent qids we might care about
  unique_qids_dep_qs = unique_qids[stringr::str_detect(
    unique_qids,
    "q5|q6|q7|q8|q9|q10"
  )]

  # For each letter, determine if any dependent qid exists; if not, mark to remove
  to_remove = list_of_sub_letters |>
    purrr::map(\(sub_letter) {
      stringr::str_detect(unique_qids_dep_qs, sub_letter)
    }) |>
    purrr:::map_lgl(\(x) {
      # NOTE: relies on non-exported purrr:::map_lgl as provided
      !any(x)
    })

  # Keep only letters that actually appear in dependent qids
  list_of_sub_letters = list_of_sub_letters[!to_remove]

  # The base qids for dependent questions (q5 through q10)
  list_of_qid_strings = glue::glue("q{5:10}")

  # Iterate over each selected letter and render a section for each product line
  walk(list_of_sub_letters, \(sub_letter) {
    # Construct the full qids for this product line (e.g., "q5a", "q6a", ...)
    full_qids = glue::glue("{list_of_qid_strings}{sub_letter}")

    # Human-readable product line name for the section header
    selection_type = lookup_table |>
      dplyr::filter(letter == sub_letter) |>
      dplyr::pull(selection)

    ## LaTeX-based section header (rule + tight spacing)
    cat(glue::glue("# Evaluation of {selection_type}"))
    cat('\n')
    cat('\\vspace{-1em}')
    cat('\\hrule')
    cat('\\vspace{0.5em}')

    # For each dependent qid, render stem + table (if any content exists)
    purrr::walk(full_qids, \(full_qid) {
      # Pull question stem, response vector, and sub-item text; escape for LaTeX
      q_text = get_main_q_text(data, full_qid) |>
        escape_latex()
      q_resp = get_response(data, full_qid) |>
        escape_latex()
      q_sub_text = get_sub_q_text(data, full_qid) |>
        escape_latex()

      # Only render when at least one of the pieces is non-empty
      if (!all(purrr::map_lgl(list(q_text, q_resp, q_sub_text), is_empty))) {
        # Pre-table: print the question number and stem as an H2
        glue::glue("## **{full_qid}.** {q_text}") |>
          cat()
        cat("\n")

        # Main table: sub-item text (left) vs. score (right)
        create_table(q_resp, q_sub_text) |>
          cat()

        # Footnote on the rating scale, then reset font size
        cat("\\scriptsize 5-point scale: 1=Strongly Disagree; 5=Strongly Agree")
        cat("\\normalsize")
        cat("\n\n")
      }
    })
  })
}
