#' Create Computer Vision Dataset from GBIF Processed Data
#'
#' @description
#' Creates a structured computer vision dataset from processed GBIF multimedia data stored in a DuckDB database.
#' Downloads images and organizes them into folders by primary classification target (e.g., phenological stages, life stages)
#' and optionally ensures diversity within each class using a secondary grouping variable (e.g., species, genus).
#' Supports subsampling, train/validation/test splits, and parallel downloading.
#'
#' The resulting folder structure is optimized for HuggingFace ImageFolder format and computer vision training.
#' For phenological stage classification, use group_by = "lifeStage" and subgroup_by = "species" to create
#' classes for each phenological stage while maintaining species diversity within each class.
#'
#' @param db_path A `character` string specifying the path to the DuckDB database.
#' @param source_table A `character` string specifying the name of the processed multimedia table. Default is "gbif_all_processed".
#' @param destDir A `character` string specifying the destination directory for the dataset.
#' @param group_by A `character` string specifying the primary classification target column (e.g., "lifeStage", "basisOfRecord"). Each unique value becomes a class folder.
#' @param subgroup_by A `character` string specifying the column for ensuring diversity within each class (e.g., "species", "genus"). Helps balance representation across this variable within each primary class. Optional.
#' @param subsample_per_group An `integer` specifying the maximum number of images per group. If NULL, all images are used.
#' @param subsample_per_subgroup An `integer` specifying the maximum number of images per subgroup within each group. If NULL, all images are used.
#' @param split_ratios A `numeric` vector specifying the train/validation/test split ratios.
#'   Examples: c(0.8, 0.2) for train/test, c(0.7, 0.15, 0.15) for train/val/test, or NULL for no split.
#' @param split_names A `character` vector specifying the names for the split folders. Default is c("train", "val", "test").
#' @param min_group_size An `integer` specifying the minimum number of images required per group to be included. Default is 10.
#' @param min_subgroup_size An `integer` specifying the minimum number of images required per subgroup to be included. Default is 5.
#' @param format A `character` string specifying the image format ("png", "jpeg", "gif"). Default is "jpeg".
#' @param parallel_cores An `integer` specifying the number of cores for parallel downloading. Default is NULL (auto-detect).
#' @param memory_limit A `character` string specifying the memory limit for DuckDB. Default is "4GB".
#' @param verbose An `integer` indicating verbosity level (0-2). Default is 1.
#' @param seed An `integer` specifying the random seed for reproducible train/val/test splits and subsampling. Default is 42.
#' @param dry_run A `logical` indicating whether to perform a dry run (no actual downloads). Default is FALSE.
#'
#' @return A list containing dataset statistics and file paths.
#' @importFrom duckdb duckdb
#' @importFrom parallelly availableCores
#' @importFrom doParallel registerDoParallel stopImplicitCluster
#' @importFrom foreach foreach %dopar%
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic usage: group by species, no subgroups, no splits
#' create_cv_dataset(
#'   db_path = "gbif_data.duckdb",
#'   destDir = "cv_dataset",
#'   group_by = "species",
#'   subsample_per_group = 100
#' )
#'
#' # Reproducible dataset with fixed seed
#' create_cv_dataset(
#'   db_path = "gbif_data.duckdb",
#'   destDir = "cv_dataset",
#'   group_by = "species",
#'   subgroup_by = "label",
#'   subsample_per_group = 500,
#'   split_ratios = c(0.7, 0.15, 0.15),
#'   seed = 42
#' )
#' }
create_cv_dataset <- function(
    db_path,
    source_table = "gbif_all_processed",
    destDir,
    group_by,
    subgroup_by = NULL,
    subsample_per_group = NULL,
    subsample_per_subgroup = NULL,
    split_ratios = NULL,
    split_names = c("train", "val", "test"),
    min_group_size = 10,
    min_subgroup_size = 5,
    format = "jpeg",
    parallel_cores = NULL,
    memory_limit = "4GB",
    verbose = 1,
    seed = 42,
    dry_run = FALSE) {
  if (!file.exists(db_path)) {
    stop("Database file not found: ", db_path)
  }

  if (missing(destDir)) {
    stop("destDir is required.")
  }
  if (missing(group_by)) {
    stop("group_by column is required.")
  }
  if (!is.null(split_ratios) && abs(sum(split_ratios) - 1.0) > 1e-8) {
    stop("split_ratios must sum to 1.0")
  }
  if (!format %in% c("png", "jpeg", "gif")) {
    stop("format must be one of: png, jpeg, gif")
  }

  if (!dry_run && !dir.exists(destDir)) {
    dir.create(destDir, recursive = TRUE)
    if (verbose >= 1) message("Created destination directory: ", destDir)
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  DBI::dbExecute(con, paste0("SET memory_limit='", memory_limit, "'"))

  tables <- DBI::dbGetQuery(con, "SHOW TABLES")$name
  if (!source_table %in% tables) {
    DBI::dbDisconnect(con)
    stop("Table '", source_table, "' not found in database")
  }

  columns <- DBI::dbGetQuery(con, paste0(
    "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name='", source_table,
    "'"
  ))$column_name

  if (!group_by %in% columns) {
    DBI::dbDisconnect(con)
    stop("Column '", group_by, "' not found in table '", source_table, "'")
  }
  if (!is.null(subgroup_by) && !subgroup_by %in% columns) {
    DBI::dbDisconnect(con)
    stop("Column '", subgroup_by, "' not found in table '", source_table, "'")
  }

  seed_ <- if (is.null(seed)) "NULL" else DBI::dbQuoteString(con, as.character(seed))

  where_clauses <- c(
    paste0(group_by, " IS NOT NULL"),
    "identifier IS NOT NULL",
    "gbifID IS NOT NULL"
  )
  if (!is.null(subgroup_by)) {
    where_clauses <- c(where_clauses, paste0(subgroup_by, " IS NOT NULL"))
  }
  where_sql <- paste("WHERE", paste(where_clauses, collapse = " AND "))

  columns_to_select <- group_by
  if (!is.null(subgroup_by)) {
    columns_to_select <- paste(columns_to_select, subgroup_by, sep = ", ")
  }

  group_stats_sql <- paste0("
    WITH group_stats AS (
      SELECT ", columns_to_select, ", COUNT(*) AS subgroup_count
      FROM ", source_table, "
      ", where_sql, "
      GROUP BY ", columns_to_select, "
      HAVING COUNT(*) >= ", min_subgroup_size, "
    ),
    group_summary AS (
      SELECT ", group_by, ", COUNT(*) AS group_count
      FROM group_stats
      GROUP BY ", group_by, "
      HAVING COUNT(*) >= ", min_group_size, "
    )
    ")



  # https://news.ycombinator.com/item?id=41894528
  partition_by <- paste0("PARTITION BY s.", group_by)
  if (!is.null(subgroup_by)) {
    partition_by <- paste0(partition_by, ", s.", subgroup_by)
  }

  sampled_data_sql <- paste0(
    "
    , sampled_data AS (
      SELECT s.*, gs.subgroup_count, gsum.group_count,
        ROW_NUMBER() OVER (PARTITION BY s.", group_by,
    if (!is.null(subgroup_by)) paste0(", s.", subgroup_by), "",
    " ORDER BY hash(CAST(s.gbifID AS VARCHAR) || ", seed_, ")) AS rn_subgroup,
        ROW_NUMBER() OVER (PARTITION BY s.", group_by, " ORDER BY hash(CAST(s.gbifID AS VARCHAR) || ", seed_, ")) AS rn_group
      FROM ", source_table, " s
      JOIN group_stats gs
        ON s.", group_by, " = gs.", group_by,
    if (!is.null(subgroup_by)) paste0(" AND s.", subgroup_by, " = gs.", subgroup_by), "", "
      JOIN group_summary gsum
        ON s.", group_by, " = gsum.", group_by, "
      ", where_sql, "
    )
    "
  )


  where_query <- "WHERE 1=1"
  if (!is.null(subsample_per_subgroup) && !is.null(subgroup_by)) {
    where_query <- paste0(where_query, " AND rn <= ", subsample_per_subgroup)
  } else if (!is.null(subsample_per_group) && is.null(subgroup_by)) {
    where_query <- paste0(where_query, " AND rn <= ", subsample_per_group)
  }

  split_query <- ""
  if (!is.null(split_ratios)) {
    split_query <- paste0("
    , sampled_data_split AS (
      SELECT *,
        ROW_NUMBER() OVER (", partition_by, " ORDER BY hash(CAST(gbifID AS VARCHAR) || ", seed_, " || '_split')) AS rn_split
      FROM sampled_data
    )
  ")
  }

  query <- paste(
    group_stats_sql,
    sampled_data_sql,
    split_query,
    if (!is.null(split_ratios)) "SELECT * FROM sampled_data_split" else "SELECT * FROM sampled_data",
    where_query,
    "ORDER BY ", group_by,
    if (!is.null(subgroup_by)) paste0(", ", subgroup_by),
    ", rn",
    sep = "\n"
  )

  if (verbose >= 2) {
    message(substr(query, 1, 2000))
  }

  dataset <- DBI::dbGetQuery(con, query)
  if (nrow(dataset) == 0) {
    stop("No data found matching the criteria")
  }

  if (!is.null(split_ratios)) {
    dataset$split <- NA_character_
    for (g in unique(dataset[[group_by]])) {
      idx <- which(dataset[[group_by]] == g)
      n_group <- length(idx)
      split_sizes <- round(n_group * split_ratios)
      split_sizes[length(split_sizes)] <- n_group - sum(split_sizes[-length(split_sizes)])
      start_idx <- 1
      for (i in seq_along(split_ratios)) {
        end_idx <- start_idx + split_sizes[i] - 1
        if (end_idx >= start_idx) dataset$split[idx[start_idx:end_idx]] <- split_names[i]
        start_idx <- end_idx + 1
      }
    }
  }

  download_list <- vector("list", nrow(dataset))
  dir_structure <- list()
  for (i in seq_len(nrow(dataset))) {
    row <- dataset[i, ]
    group_name <- gsub("[^A-Za-z0-9_-]", "_", as.character(row[[group_by]]))
    path_parts <- destDir
    if (!is.null(split_ratios)) path_parts <- file.path(path_parts, row$split)
    if (!is.null(subgroup_by)) {
      subgroup_name <- gsub("[^A-Za-z0-9_-]", "_", as.character(row[[subgroup_by]]))
      combined_group_name <- paste(group_name, subgroup_name, sep = "_")
    } else {
      combined_group_name <- group_name
    }
    dir_path <- file.path(path_parts, combined_group_name)
    if (!dry_run && !dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE)
    filename <- paste0(row$gbifID, ".", format)
    full_path <- file.path(dir_path, filename)
    if (!dry_run && file.exists(full_path)) {
      counter <- 1
      repeat {
        filename2 <- paste0(row$gbifID, "_", counter, ".", format)
        full_path2 <- file.path(dir_path, filename2)
        if (!file.exists(full_path2)) {
          full_path <- full_path2
          break
        }
        counter <- counter + 1
      }
    }
    download_list[[i]] <- list(
      url = as.character(row$identifier),
      path = full_path,
      group = as.character(row[[group_by]]),
      subgroup = if (!is.null(subgroup_by)) as.character(row[[subgroup_by]]) else NA_character_,
      split = if (!is.null(split_ratios)) as.character(row$split) else NA_character_
    )
    dir_structure[[dir_path]] <- (dir_structure[[dir_path]] %||% 0) + 1
  }

  if (dry_run) {
    message("Dry run complete. No images downloaded.")
    return(list(
      total_images = nrow(dataset),
      groups = length(unique(dataset[[group_by]])),
      directory_structure = dir_structure,
      download_list = download_list
    ))
  }

  if (is.null(parallel_cores)) parallel_cores <- parallelly::availableCores(constraints = "connections")
  doParallel::registerDoParallel(parallel_cores)
  results <- foreach::foreach(item = download_list, .packages = c()) %dopar% {
    tryCatch(
      {
        img <- try2read(item$url)
        if (identical(img, "try-error")) {
          return(list(success = FALSE))
        }
        magick::image_write(img, path = item$path)
        list(success = TRUE)
      },
      error = function(e) list(success = FALSE)
    )
  }
  doParallel::stopImplicitCluster()
  successful <- sum(vapply(results, function(x) x$success, logical(1)))

  return(list(
    total_images = nrow(dataset),
    downloaded_images = successful,
    groups = length(unique(dataset[[group_by]])),
    subgroups = if (!is.null(subgroup_by)) length(unique(dataset[[subgroup_by]])) else 0,
    directory_structure = dir_structure,
    success_rate = successful / length(download_list),
    dataset_path = destDir
  ))
}
