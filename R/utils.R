#' Escape LaTeX special characters (regex-based)
#'
#' Safely escapes LaTeX-reserved characters in a character vector so the text
#' can be inserted into LaTeX documents (e.g., via R Markdown). Backslashes are
#' rendered as `\\textbackslash{}`, ASCII tilde as `\\textasciitilde{}`, and
#' caret as `\\textasciicircum{}`. Other special characters are prefixed with
#' a backslash.
#'
#' @param raw_text A character vector to be escaped.
#'
#' @return A character vector of the same length as `raw_text`, with LaTeX
#'   special characters escaped.
#'
#' @details
#' This implementation uses regular expressions. The replacement order matters:
#' we replace backslashes first, then escape the character class `[#\\$%&_{}]`,
#' then replace `~` and `^` with their text equivalents. If you see braces in
#' `\\textbackslash{}`, `\\textasciitilde{}`, or `\\textasciicircum{}` getting
#' re-escaped in your output, consider a placeholder strategy (see notes) to
#' avoid double-escaping braces introduced by the replacements.
#'
#' The commands `\\textbackslash{}`, `\\textasciitilde{}`, and
#' `\\textasciicircum{}` are available in modern LaTeX; historically,
#' `\\usepackage{textcomp}` was recommended.
#'
#' @examples
#' \dontrun{
#' escape_latex("20% & rising ~ ^ \\ {curly}")
#' # "20\\% \\& rising \\textasciitilde{} \\textasciicircum{} \\textbackslash{} \\ \\{curly\\}"
#' }
#'
#' @seealso xfun::escape_latex, kableExtra::escape_latex
#'
#' @importFrom stringr str_replace_all
#' @export
escape_latex <- function(raw_text) {
  raw_text |>
    # Render literal backslash first
    stringr::str_replace_all("\\\\", "\\\\textbackslash{}") |>
    # Escape standard LaTeX specials (note braces are included)
    stringr::str_replace_all("([#$%&_{}])", "\\\\\\1") |>
    # Replace ASCII tilde/caret with their text forms
    stringr::str_replace_all("~", "\\\\textasciitilde{}") |>
    stringr::str_replace_all("\\^", "\\\\textasciicircum{}")
}


#' Escape LaTeX special characters (vectorised, fixed-string mapping)
#'
#' Escapes LaTeX-reserved characters using a fixed (non-regex) mapping in a
#' purely vectorised manner. Useful for inline text where regex semantics are
#' unnecessary, and you want a predictable, literal substitution.
#'
#' @param x A character vector to be escaped.
#'
#' @return A character vector of the same length as `x`, with LaTeX special
#'   characters escaped.
#'
#' @details
#' Replacements are applied sequentially using `purrr::reduce2()` with
#' `stringr::fixed()` to ensure literal matching. Because substitutions are
#' sequential, **order still matters**: characters introduced by an earlier
#' replacement (e.g., braces in `\\textbackslash{}`) may be candidates for a
#' later replacement (e.g., `{` → `\\{`). If that becomes an issue in your
#' workflow, consider a two-phase placeholder approach (protect braces in
#' generated macros, escape user braces, then restore placeholders).
#'
#' @examples
#' \dontrun{
#' escape_latex_inline(c("50% & $5", "Use ^ and ~"))
#' }
#'
#' @seealso xfun::escape_latex, kableExtra::escape_latex
#'
#' @importFrom purrr reduce2
#' @importFrom stringr str_replace_all fixed
#' @export
escape_latex_inline <- function(x) {
  # Vectorised: returns a character vector of the same length as `x`
  specials <- c("\\", "&", "%", "$", "#", "_", "{", "}", "~", "^")
  replacements <- c(
    "\\textbackslash{}",
    "\\&",
    "\\%",
    "\\$",
    "\\#",
    "\\_",
    "\\{",
    "\\}",
    "\\textasciitilde{}",
    "\\textasciicircum{}"
  )

  purrr::reduce2(
    .x = specials,
    .y = replacements,
    .init = x,
    .f = function(z, s, r) stringr::str_replace_all(z, stringr::fixed(s), r)
  )
}
