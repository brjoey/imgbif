#' Remove Dates without Time Specification and Dates recorded on 01.01. of a year at 00.00.00.
#'
#' @description
#' The function removes images without a specified date of creation (if date.rm = TRUE)
#' and removes images without a specified time and suspicious date and time combinations, i. e. 01.01.yyyy 00:00:00.
#'
#'
#' @param m.df  A `data.frame` containing the multimedia data.
#' @param rm_wo_times A `boolean` value to remove dates without time specifications. If `TRUE`, the dates will be removed. The default is `FALSE`.
#' @importFrom stringr str_extract
#' @importFrom lubridate ymd_hms
#' @importFrom lubridate ymd
#' @importFrom lubridate hour
#' @importFrom lubridate minute
#' @importFrom lubridate second
#' @importFrom lubridate day
#' @importFrom lubridate month
#'
remove_date <- function(m.df = multimedia, date.rm = TRUE, time.rm = FALSE) {
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
