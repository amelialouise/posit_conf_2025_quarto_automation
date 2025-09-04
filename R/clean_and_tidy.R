#' Format loaded Dataframe
#'
#' This function takes the raw dataframe and cleans it up by removing
#' unnecessary columns, renaming columns, and filling in missing values.
#' @param raw_df [dataframe] The raw dataframe
#' @param drop_resp_na [logical] If TRUE, drop rows with NAs in last_name,
#' first_name, country, customer, or title
#'
#' @return [dataframe] The cleaned  dataframe
#' @export
#'
clean_df = function(raw_df, drop_resp_na = FALSE) {
  # some basic data qc
  cols = length(colnames(raw_df))

  if (cols != 14) {
    cli::cli_abort(c("{.var raw_df} has {cols} columns, expected 14"))
  }

  # remove unnecessary columns and remove pdf_export prefix
  df_better_names = raw_df |>
    dplyr::select(-pdf_loop, -responseid) |>
    dplyr::rename_with(~ stringr::str_remove(., "pdf_export_"))

  # replace NAs with 1 in sub_qid column
  df_no_na = df_better_names |>
    dplyr::mutate(
      sub_qid = dplyr::case_when(is.na(sub_qid) ~ 1, .default = sub_qid)
    )

  # remove ", and" from start of char string in response col (if present)
  df_no_and = df_no_na |>
    dplyr::mutate(response = stringr::str_remove(response, "^, and")) |>
    dplyr::mutate(response = stringr::str_trim(response))

  # create appropriate numbering system in sub_qid column
  out = df_no_and |>
    dplyr::group_split(qid) |>
    purrr::map(~ dplyr::mutate(., sub_qid = dplyr::row_number())) |>
    purrr::list_rbind()

  # remove amphersands if present in customer column
  out = out |>
    dplyr::mutate(customer = stringr::str_replace(customer, "&", "and"))

  # replace
  out = out |>
    dplyr::mutate(sub_q_text = stringr::str_replace(sub_q_text, "’", "'"))

  # if drop_resp_na is true, drop rows with NAs in last_name, first_name, country, customer or title
  if (drop_resp_na) {
    out = out |>
      dplyr::filter(
        !is.na(last_name),
        !is.na(first_name),
        !is.na(country),
        !is.na(customer),
        !is.na(title)
      )
  }

  return(out)
}
