#' Filter a response dataframe based on a datetime range
#'
#' @param data [dataframe] a dataframe following the format outlined in the
#' data template
#' @param start_datetime [datetime] the start of the datetime range
#' @param end_datetime [datetime] the end of the datetime range
#' @param datetime_col_name [character] the name of the datetime column in the
#'
#' @return [dataframe] a subset dataframe with responses within the datetime range
#' @export
#'
filter_resps = function(
  data,
  start_datetime,
  end_datetime,
  datetime_col_name = "complete_datetime"
) {
  column_sym = rlang::sym(datetime_col_name)

  data |>
    dplyr::filter(
      {{ column_sym }} >= start_datetime,
      {{ column_sym }} <= end_datetime
    )
}
