#' Create DuckDB Database with GBIF Data
#'
#' Creates a persistent DuckDB database containing GBIF occurrence and multimedia tables. Drops empty columns and joins the multimedia and occurrence tables.
#'
#' @param multimedia A `data.frame` containing the multimedia data or the path to the multimedia file (with the extension "txt", "csv").
#' @param occurrence A `data.frame` containing the occurrence data or the path to the occurrence file (with the extension "txt", "csv").
#' @param db_path A `character` string specifying the path where the DuckDB database should be created.
#' @param memory_limit A `character` string specifying the memory limit for DuckDB (e.g., "4GB", "512MB"). Default is "2GB".
#' @param drop_tables A `logical` value indicating whether to keep just the joined multimedia and occurrence tables. Default is TRUE.
#'
#' @return The path to the created DuckDB database.
#' @importFrom DBI dbConnect dbDisconnect dbWriteTable dbExecute
#' @importFrom duckdb duckdb
#' @export
#'
#' @examples
#' \dontrun{
#' create_gbif_duckdb(
#'   multimedia = "path/to/multimedia.txt",
#'   occurrence = "path/to/occurrence.txt",
#'   db_path = "gbif_data.duckdb"
#' )
#' }
create_gbif_duckdb <- function(
    multimedia,
    occurrence,
    db_path,
    memory_limit = "4GB",
    drop_tables = TRUE) {
  if (!file.exists(multimedia)) {
    stop("Multimedia file not found: ", multimedia)
  }
  if (!file.exists(occurrence)) {
    stop("Occurrence file not found: ", occurrence)
  }

  check_ext <- all(
    c(
      tolower(tools::file_ext(multimedia)),
      tolower(tools::file_ext(occurrence))
    ) %in% c("csv", "txt")
  )

  if (!check_ext) {
    stop("Unsupported file extension. Must be 'txt' or 'csv'.")
  }

  message("Connecting to DuckDB database.")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  DBI::dbExecute(con, paste0("SET memory_limit='", memory_limit, "'"))

  message("Creating multimedia_raw table.")
  DBI::dbExecute(con, paste0(
    "CREATE TABLE multimedia_raw AS SELECT * FROM read_csv_auto('", multimedia, "')"
  ))

  message("Creating occurrence_raw table.")
  DBI::dbExecute(con, paste0(
    "CREATE TABLE occurrence_raw AS SELECT * FROM read_csv_auto('", occurrence, "')"
  ))

  message("Removing empty columns from tables.")
  cols_m <- DBI::dbGetQuery(con, "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name='multimedia_raw'
  ")$column_name

  counts_query_m <- paste0(
    "SELECT ",
    paste0(
      "COUNT(", cols_m, ") AS ",
      cols_m,
      collapse = ", "
    ),
    " FROM multimedia_raw"
  )

  counts_m <- DBI::dbGetQuery(con, counts_query_m)

  non_empty_cols_m <- names(counts_m)[unlist(counts_m[1, ]) > 0]

  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE TABLE multimedia_raw AS SELECT ",
    paste(non_empty_cols_m, collapse = ", "),
    " FROM multimedia_raw"
  ))

  cols_o <- DBI::dbGetQuery(con, "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name='occurrence_raw'
  ")$column_name

  counts_query_o <- paste0(
    "SELECT ",
    paste0(
      "COUNT(", cols_o, ") AS ",
      cols_o,
      collapse = ", "
    ),
    " FROM occurrence_raw"
  )

  counts_o <- DBI::dbGetQuery(con, counts_query_o)
  non_empty_cols_o <- names(counts_o)[unlist(counts_o[1, ]) > 0]

  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE TABLE occurrence_raw AS SELECT ",
    paste(non_empty_cols_o, collapse = ", "),
    " FROM occurrence_raw"
  ))

  message("Joining multimedia and occurrence tables.")
  DBI::dbExecute(con, "
    CREATE OR REPLACE TABLE gbif_full AS
    SELECT m.*, o.*
    FROM multimedia_raw m
    LEFT JOIN occurrence_raw o
      ON m.gbifID = o.gbifID
  ")

  message("Creating index for gbifID and publisher columns.")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_gbif_full_gbifid ON gbif_full(gbifID)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_gbif_full_publisher ON gbif_full(publisher)")

  if (drop_tables) {
    DBI::dbExecute(con, "DROP TABLE multimedia_raw")
    DBI::dbExecute(con, "DROP TABLE occurrence_raw")

    message("DuckDB created at '", db_path, "' with indexed table 'gbif_full'.")
  } else {
    message(
      "DuckDB created at '",
      db_path,
      "' with (indexed) tables 'multimedia_raw', 'occurrence_raw', and 'gbif_full'."
    )
  }

  DBI::dbDisconnect(con)
  return(db_path)
}
