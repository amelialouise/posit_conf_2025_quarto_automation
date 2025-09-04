#' Remove HTML tags from a supplied string
#'
#' This function takes a string and removes all html tags from it.
#' @param string_to_strip [character] The string to remove html tags from
#'
#' @return [character] The string with html tags removed
#' @export
#'
strip_html_tags = function(string_to_strip) {
  string_to_strip |>
    stringr::str_replace_all("<.*?>", "")
}
