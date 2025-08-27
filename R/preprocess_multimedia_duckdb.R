#' Pre-Process GBIF Multimedia File Using DuckDB
#'
#' @description
#' Pre-processes a GBIF multimedia file stored in a DuckDB database by filtering out records without a GBIF ID (occurrence ID) or image link, processing URLs to images in the iNaturalist database, and optionally removing images from Herbarium databases. Users can also specify which image licenses to exclude from the dataset.
#'
#' @param db_path A `character` string specifying the path to the DuckDB database.
#' @param output_table A `character` string specifying the name of the output table. Default is "multimedia_processed".
#' @param herbarium.rm A `boolean` indicating whether to remove Herbarium database records (the default is `TRUE`). When set to `FALSE`, Herbarium data is retained.
#' @param license.rm A `character vector` specifying the license types to be excluded. Common licenses include 'all rights reserved', 'by-sa', 'by-nc', 'NA', and 'unclear'.
#' @param date.rm A `logical` value indicating whether to remove rows with missing date information. If `TRUE`, rows with `NA` values in the "created" column will be removed. Default is `TRUE`.
#' @param time.rm A `logical` value indicating whether to remove rows with missing time specifications or suspicious date and time combinations. If `TRUE`, rows where the date is 01.01.yyyy and the time is 00:00:00 will be removed. Default is `FALSE`.
#' @param memory_limit A `character` string specifying the memory limit for DuckDB (e.g., "4GB", "512MB"). Default is "2GB".
#' @param verbose An `integer` indicating the verbosity level:
#'   * `0`: No verbose output (default)
#'   * `1`: Quick verbose - shows initial and final counts only
#'   * `2`: Full verbose - shows detailed step-by-step filtering counts (high overhead for large datasets)
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom duckdb duckdb
#' @export
#'
#' @examples
#' \dontrun{
#' # Using default parameters
#' preprocess_multimedia_duckdb(db_path = "gbif_data.duckdb")
#'
#' # Custom parameters
#' preprocess_multimedia_duckdb(
#'   db_path = "gbif_data.duckdb",
#'   output_table = "processed_data",
#'   herbarium.rm = FALSE,
#'   license.rm = c("all rights reserved", "by-nc", "by-nd"),
#'   verbose = 1
#' )
#' }
preprocess_multimedia_duckdb <- function(
    db_path,
    output_table = "gbif_all_processed",
    herbarium.rm = TRUE,
    license.rm = c("all rights reserved", "by-sa", "by-nc", "NA", "unclear"),
    date.rm = TRUE,
    time.rm = FALSE,
    memory_limit = "2GB",
    verbose = FALSE) {
  if (!file.exists(db_path)) stop("Database file not found: ", db_path)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  DBI::dbExecute(con, paste0("SET memory_limit='", memory_limit, "'"))

  if (herbarium.rm) {
    tmp_df <- data.frame(
      publisher = gbif_herbarium_title,
      stringsAsFactors = FALSE
    )
    DBI::dbWriteTable(
      con,
      "tmp_herbarium_publishers",
      tmp_df,
      temporary = TRUE,
      overwrite = TRUE
    )

    herbarium_filter_sql <- "
    NOT EXISTS (
      SELECT 1
      FROM occurrence_raw o
      JOIN tmp_herbarium_publishers h
        ON o.publisher = h.publisher
      WHERE o.gbifID = m.gbifID
    )"
  } else {
    herbarium_filter_sql <- "TRUE"
  }

  license_conditions <- c()
  if ("NA" %in% license.rm) {
    license_conditions <- c(license_conditions, "license IS NOT NULL")
  }
  if ("all rights reserved" %in% license.rm) {
    license_conditions <- c(
      license_conditions,
      "NOT REGEXP_MATCHES(license, 'all rights reserved')"
    )
  }
  if ("by-nc" %in% license.rm) {
    license_conditions <- c(
      license_conditions,
      "NOT REGEXP_MATCHES(license, 'by-nc')"
    )
  }
  if ("by-sa" %in% license.rm) {
    license_conditions <- c(
      license_conditions,
      "NOT REGEXP_MATCHES(license, 'by-sa')"
    )
  }
  if ("by-nd" %in% license.rm) {
    license_conditions <- c(
      license_conditions,
      "NOT REGEXP_MATCHES(license, 'by-nd')"
    )
  }
  if ("unclear" %in% license.rm) {
    license_conditions <- c(
      license_conditions,
      "NOT REGEXP_MATCHES(license, 'zero|unclear|http://creativecommons.org/licenses/by/[0-9]+\\.0/|http://creativecommons.org/publicdomain/zero/1.0/')"
    )
  }

  if (length(license_conditions) > 0) {
    license_filter_sql <- paste(license_conditions, collapse = " AND ")
  } else {
    "TRUE"
  }

  date_conditions <- c()
  if (date.rm) {
    date_conditions <- c(date_conditions, "created IS NOT NULL")
  }

  if (time.rm) {
    date_conditions <- c(
      date_conditions,
      "REGEXP_MATCHES(created, '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}')",
      "NOT REGEXP_MATCHES(created, '[0-9]{4}-01-01T00:00:00|[0-9]{4}/01/01 00:00:00')"
    )
  }

  if (length(date_conditions) > 0) {
    date_filter_sql <- paste(date_conditions, collapse = " AND ")
  } else {
    "TRUE"
  }

  sql <- paste0("
    CREATE OR REPLACE TABLE ", output_table, " AS
    SELECT
      gbifID,
      identifier,
      CASE
        WHEN REGEXP_MATCHES(identifier, 'htt[a-z]{1,2}://static\\.inaturalist\\.org/')
        THEN REGEXP_REPLACE(identifier,
                            'htt[a-z]{1,2}://static\\.inaturalist\\.org/',
                            'https://inaturalist-open-data.s3.amazonaws.com/')
        ELSE identifier
      END AS identifier,
      format,
      license,
      created
    FROM multimedia_raw
    WHERE (format IS NULL OR NOT REGEXP_MATCHES(format, 'application'))
      AND identifier IS NOT NULL
      AND gbifID IS NOT NULL
      AND (", herbarium_filter_sql, ")
      AND (", license_filter_sql, ")
      AND (", date_filter_sql, ")
  ")

  DBI::dbExecute(con, sql)

  if (verbose == 1) {
    initial_count <- DBI::dbGetQuery(
      con,
      "SELECT COUNT(*) AS n FROM multimedia_raw"
    )$n

    final_count <- DBI::dbGetQuery(
      con,
      paste0("SELECT COUNT(*) AS n FROM ", output_table)
    )$n

    message("Removed ", initial_count - final_count, " records total.")
  } else if (verbose == 2) {
      initial_count <- DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM multimedia_raw"
      )$n

    count_query <- paste0("
      SELECT
        COUNT(*) AS initial_count,
        SUM(CASE WHEN format IS NULL OR NOT REGEXP_MATCHES(format, 'application') THEN 1 ELSE 0 END) AS after_format,
        SUM(CASE WHEN (format IS NULL OR NOT REGEXP_MATCHES(format, 'application'))
                 AND identifier IS NOT NULL AND gbifID IS NOT NULL
               THEN 1 ELSE 0 END) AS after_id,
        SUM(CASE WHEN (format IS NULL OR NOT REGEXP_MATCHES(format, 'application'))
                 AND identifier IS NOT NULL AND gbifID IS NOT NULL
                 AND (", herbarium_filter_sql, ")
               THEN 1 ELSE 0 END) AS after_herbarium,
        SUM(CASE WHEN (format IS NULL OR NOT REGEXP_MATCHES(format, 'application'))
                 AND identifier IS NOT NULL AND gbifID IS NOT NULL
                 AND (", herbarium_filter_sql, ")
                 AND (", license_filter_sql, ")
               THEN 1 ELSE 0 END) AS after_license,
        SUM(CASE WHEN (format IS NULL OR NOT REGEXP_MATCHES(format, 'application'))
                 AND identifier IS NOT NULL AND gbifID IS NOT NULL
                 AND (", herbarium_filter_sql, ")
                 AND (", license_filter_sql, ")
                 AND (", date_filter_sql, ")
               THEN 1 ELSE 0 END) AS after_date,
        (SELECT COUNT(*) FROM ", output_table, ") AS final_count
      FROM multimedia_raw;
    ")

    step_counts <- DBI::dbGetQuery(con, count_query)

    message(
      step_counts$initial_count - step_counts$after_format,
      " occurrences (format: application) removed."
    )
    message(
      step_counts$after_format - step_counts$after_id,
      " occurrences removed due to missing identifier or gbifID."
    )
    message(
      step_counts$after_id - step_counts$after_herbarium,
      " Herbarium occurrences removed."
    )
    message(
      step_counts$after_herbarium - step_counts$after_license,
      " occurrences removed according to the license filter."
    )
    message(
      step_counts$after_license - step_counts$after_date,
      " images with missing or suspicious date/time removed."
    )
    message(
      "Processing complete. Final table '",
      output_table,
      "' contains ",
      step_counts$final_count,
      " records."
    )
  }

  DBI::dbDisconnect(con)
}
