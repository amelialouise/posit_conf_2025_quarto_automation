# Main Automation Control Script
# Keaton Wilson - KS&R
# kwilson@ksrinc.com

# Packages and functions ------------------------------------------------------
library(purrr)
library(dplyr)
library(stringr)
library(readr)
library(data.table)
library(here)

list.files(here("R"), full.names = TRUE) |>
  walk(source)

# Data Load ---------------------------------------------------------------

## Deal w/ Conversion from UTF-16LE to UTF-8
infile = here("data", "anon_data.tsv")

the_data <- readr::read_delim(
  infile,
  delim = "\t", # change to "\t" if it’s TSV
  # locale = locale(encoding = "UTF-16LE"),
  quote = "" # keep if you want to avoid surprises
) |>
  clean_df() |>
  mutate(main_q_text = strip_html_tags(main_q_text))

# Data Filtering -----------------------------------------------------------

start_date <- lubridate::as_datetime("2025-05-01 00:00:01")
end_date <- lubridate::as_datetime("2025-08-05 12:59:00")

# data within window
filtered_data <- filter_resps(the_data, start_date, end_date)

if (nrow(filtered_data) == 0) {
  cli::cli_abort("No data in selected window")
}

list_of_resps <- unique(filtered_data$respid)
cli::cli_alert_info(
  "{length(list_of_resps)} unique respondents in the selected window"
)

# pull params for each respondent
resps_info_list = list_of_resps |>
  map(\(ind_respid) {
    list(
      respid = ind_respid,
      last_name = filtered_data |>
        filter(respid == ind_respid) |>
        pull(last_name) |>
        unique(),
      first_name = filtered_data |>
        filter(respid == ind_respid) |>
        pull(first_name) |>
        unique(),
      customer = filtered_data |>
        filter(respid == ind_respid) |>
        mutate(customer = str_replace(customer, "/", "-")) |>
        pull(customer) |>
        unique()
    )
  })

# Generate Dynamic .qmd files corresponding to each report --------------------

# temporary files
temp_qmd_dir = "./tmp_qmds/"

# create tmp_qmds directory if doesn't exist
if (!dir.exists(temp_qmd_dir)) {
  dir.create(temp_qmd_dir)
}

# Generate dynamic yaml headers for each .qmd file
yaml_headers <- resps_info_list |>
  map(\(ind_resp_info) {
    glue::glue(
      "---
output-file: Online Results - {ind_resp_info$customer}, {ind_resp_info$first_name} {ind_resp_info$last_name}.pdf
params:
  respid: {ind_resp_info$respid}
---"
    )
  })

# pull in no-yml version of template
quarto_template_strings <- read_file(
  "./report_template/report_template.qmd"
)

# combine headers with template
qmd_text_strings <- yaml_headers |>
  map(\(ind_yaml_header) {
    paste0(ind_yaml_header, "\n", quarto_template_strings)
  })

# write files
walk2(qmd_text_strings, resps_info_list, \(ind_qmd_text, resps_info) {
  write_file(
    ind_qmd_text,
    glue::glue("{temp_qmd_dir}report_{resps_info$respid}.qmd")
  )
})

# Render ------------------------------------------------------------------
files_to_render <- list.files(temp_qmd_dir, full.names = TRUE)

# only .qmd files
files_to_render <- files_to_render |>
  keep(~ str_detect(.x, ".qmd$"))

files_to_render |> walk(~ quarto::quarto_render(.))

# Cleanup and File Mover -------------------------------------------------

# make sub folder in output with today's date
output_dir = "./output/"
today_str = lubridate::today()

if (!dir.exists(glue::glue("{output_dir}{today_str}"))) {
  dir.create(glue::glue("{output_dir}{today_str}"))
}

to_write_to = glue::glue("{output_dir}{today_str}/")

# move all pdf files in tmp_qmds directory to output directory
pdf_files = list.files(temp_qmd_dir, pattern = ".pdf", full.names = TRUE)

pdf_files |> walk(~ file.copy(., to_write_to, overwrite = TRUE))

# remove all files (qmd and pdf) in tmp_qmds directory

walk(pdf_files, ~ file.remove(.))
walk(files_to_render, ~ file.remove(.))

# write a log file outlining start and end dates in output subdirectory
write_file(
  glue::glue(
    "Start Date: {start_date}
                       End Date: {end_date}
                       Number of Respondents: {length(list_of_resps)}"
  ),
  glue::glue("{to_write_to}log.txt")
)

# Alert User -------------------------------------------------------------

cli::cli_alert_success("Automation Complete - check output folder for PDFs")
