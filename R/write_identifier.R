#' Write Identifiers from GBIF Multimedia File to Disk with Parallel Processing
#'
#' Downloads and saves images referenced by URL identifiers from a GBIF multimedia file to disk using parallel processing. Images are saved with the corresponding gbifID and, if available, a label. It is recommended to pre-process the file with `prepr_multimedia()` before use.
#'
#' @param multimedia A `data.frame` containing the multimedia data or a string with the path to the multimedia file.
#' @param destDir A string with the path to the destination directory where images should be saved.
#' @param format A string specifying the output format of the images, with supported formats including "png", "jpeg", "gif", "rgb", or "rgba". Default is "png".
#' @importFrom foreach %dopar%
#' @importFrom parallelly availableCores
#' @importFrom doParallel registerDoParallel
#' @importFrom httr user_agent
#' @importFrom rvest session
#' @importFrom stringr str_detect
#' @importFrom magick image_read
#' @importFrom magick image_write
#' @importFrom doParallel stopImplicitCluster
#' @export
#' @examples
#' \dontrun{
#' write_identifier(multimedia = multimedia_df, destDir = "path/to/images", format = "png")
#' }
write_identifier <- function(multimedia,
                             destDir,
                             format = "png") {
  if (missing(multimedia)) {
    stop("Multimedia data frame or path to multimedia.txt file is required")
  } else {
    if (!is(multimedia, "tbl_df") && !is(multimedia, "data.frame")) {
      if (file.access("multimedia")) {
        multimedia <- try({
          read.csv2(multimedia, sep = "\t", na.strings = "", quote = "")
        })
        if (is(multimedia, "try-error")) {
          stop("Could not find provided path (multimedia): ", multimedia)
        }
      }
    }
  }

  if (!all(c("identifier", "gbifID") %in% names(multimedia))) {
    stop("The 'multimedia' data frame must contain both 'identifier' and 'gbifID' columns.")
  }

  if (missing(destDir)) {
    stop("destDir is required.")
  }

  if (!dir.exists(file.path(destDir))) {
    stop("The specified destination directory does not exist: ", destDir)
  }

  if (!format %in% c("png", "jpeg", "gif", "rgb", "rgba")) {
    stop("Invalid format. Supported formats are png, jpeg, gif, rgb, and rgba.")
  }

  multimedia <- remove_na_identifier_gbifID(m.df = multimedia)

  numCores <- parallelly::availableCores(constraints = "connections")
  doParallel::registerDoParallel(numCores)


  URL_list <- multimedia$identifier

  foreach_list <- foreach::foreach(URL = URL_list, .packages = c("httr", "rvest", "magick")) %dopar% {
    index_ua <- round(runif(1, min = 1, max = length(useragent)))
    ua <- httr::user_agent(useragent[index_ua])
    session_with_ua <- try({
      rvest::session(URL, ua)
    })


    if (is(session_with_ua, "try-error")) {
      img <- geterrmessage()
    } else {
      if (session_with_ua$response$status_code == 200) {
        content_type <- session_with_ua$response$headers$`content-type`

        if (stringr::str_detect(content_type, "image[:graph:]")) {
          img <- try(
            {
              content <- session_with_ua$response$content
              magick::image_read(content)
            },
            silent = TRUE
          )
          try(
            {
              feather_files <- list.files(path = destDir, pattern = paste0("\\.", format, "$"))
              files <- stringr::str_remove(feather_files, ".feather")
              str_detect_sum <- sum(stringr::str_detect(files, as.character(multimedia[which(multimedia$identifier == URL), "gbifID"])))
              if ("label" %in% names(multimedia)) {
                if (str_detect_sum == 0) {
                image_path <- file.path(
                  destDir,
                  paste0(
                    multimedia[which(multimedia$identifier == URL), "gbifID"],
                    "_",
                    multimedia[which(multimedia$identifier == URL), "label"],
                    ".",
                    format
                  )
                )
                } else {
                  image_path <- file.path(
                    destDir,
                    paste0(
                      multimedia[which(multimedia$identifier == URL), "gbifID"],
                      "_",
                      multimedia[which(multimedia$identifier == URL), "label"],
                      " (",
                      (str_detect_sum + 1),
                      " )",
                      ".",
                      format
                    )
                  )
                }
              } else {
                if (str_detect_sum == 0) {
                  image_path <- file.path(
                    destDir,
                    paste0(
                      multimedia[which(multimedia$identifier == URL), "gbifID"],
                      ".",
                      format
                    )
                  )
                } else {
                  image_path <- file.path(
                    destDir,
                    paste0(
                      multimedia[which(multimedia$identifier == URL), "gbifID"],
                      " (",
                      (str_detect_sum + 1),
                      " )",
                      ".",
                      format
                    )
                  )
                }
              }
              magick::image_write(img,
                path = image_path
              )
            },
            silent = TRUE
          )
        }
      }
    }
  }
  doParallel::stopImplicitCluster()

  successful <- length(foreach_list)
  nrow0 <- nrow(multimedia)
  message(successful, " of ", nrow0, " images created.")
}
