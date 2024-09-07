#' Remove Dates without Time Specification and Dates recorded on 01.01. of a year at 00.00.00.
#'
#' @description
#' The function removes images based on their date of creation. Specifically:
#' - Removes images without a specified date of creation if `date.rm = TRUE`.
#' - Removes images recorded with suspicious date and time combinations, i.e., dates with 01.01.yyyy and time 00:00:00, if `time.rm = TRUE`.
#'
#' @param m.df A `data.frame` containing the multimedia data. It must include a column named "created" with date-time information as character strings.
#' @param date.rm A `logical` value indicating whether to remove rows with missing date information. If `TRUE`, rows with `NA` values in the "created" column will be removed. Default is `TRUE`.
#' @param time.rm A `logical` value indicating whether to remove rows with missing time specifications or suspicious date and time combinations. If `TRUE`, rows where the date is 01.01.yyyy and the time is 00:00:00 will be removed. Default is `FALSE`.
#'
#' @importFrom stringr str_extract
#' @importFrom lubridate ymd_hms
#' @importFrom lubridate ymd
#' @importFrom lubridate hour
#' @importFrom lubridate minute
#' @importFrom lubridate second
#' @importFrom lubridate day
#' @importFrom lubridate month
#'
#' @return A `data.frame` with rows removed according to the specified date and time criteria.

remove_date <- function(m.df, date.rm = TRUE, time.rm = FALSE) {
  if (date.rm) {
    na_idx <- is.na(m.df[, "created"])
    m.df <- m.df[!na_idx, ]
    cat(sum(na_idx), " images without date and time removed.\n")
  }

  datetime <- lubridate::ymd_hms(m.df[, "created"], quiet = TRUE)
  if (time.rm) {
    m.df <- m.df[!is.na(datetime), ]
    cat(sum(is.na(datetime)), " images without time removed.\n")

    dates_str <- stringr::str_extract(m.df[, "created"], "[[:digit:]]{4}[[:punct:]]{1}[[:digit:]]{2}[[:punct:]]{1}[[:digit:]]{2}")
    dates <- lubridate::ymd(dates_str, quiet = TRUE)

    datetime_clean <- datetime[!is.na(datetime)]

    times_idx <-
      data.frame(
        hours = lubridate::hour(datetime_clean),
        minutes = lubridate::minute(datetime_clean),
        seconds = lubridate::second(datetime_clean)
      ) |> rowSums() == 0

    date_idx <- data.frame(
      day = lubridate::day(dates),
      month = lubridate::month(dates)
    ) |> rowSums() - 2 == 0

    suspZeros <- ((date_idx * times_idx) == 1)

    m.df <- m.df[!suspZeros, ]

    cat(sum(suspZeros), " images with suspicious date & time removed.\n")
  } else {
    cat(sum(is.na(datetime)), " images without time.\n")
  }

  return(m.df)
}
