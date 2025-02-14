#' Write Identifiers from GBIF Multimedia File to Disk with Parallel Processing
#'
#' Downloads and saves images referenced by URL identifiers from a GBIF multimedia file to disk using parallel processing. Images are saved with the corresponding gbifID and, if available, a label. It is recommended to pre-process the file with `prepr_multimedia()` before use.
#'
#' @param multimedia A `data.frame` containing the multimedia data or a string with the path to the multimedia file.
#' @param destDir A string with the path to the destination directory where images should be saved.
#' @param format A string specifying the output format of the images, with supported formats including "png", "jpeg", "gif", "rgb", or "rgba". Default is "png".
#' @param return_results Logical indicating whether to return a list containing detailed results of each download attempt, including error messages. Default is FALSE.
#' @return If return_results is TRUE, returns a list where each element contains 'success' (logical) and either 'path' (for successful downloads) or 'error' (for failures). If FALSE, returns nothing.
#' @import foreach
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
                             format = "png",
                             return_results = FALSE) {
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

  if (!(format %in% c("png", "jpeg", "gif", "rgb", "rgba"))) {
    stop("Invalid format. Supported formats are png, jpeg, gif, rgb, and rgba.")
  }

  multimedia <- remove_na_identifier_gbifID(m.df = multimedia)

  numCores <- parallelly::availableCores(constraints = "connections")
  doParallel::registerDoParallel(numCores)


  URL_list <- multimedia$identifier

  results <- foreach::foreach(URL = URL_list, .packages = c("httr", "rvest", "magick")) %dopar% {
    index_ua <- round(runif(1, min = 1, max = length(useragent)))
    ua <- httr::user_agent(useragent[index_ua])


    tryCatch(
      {
        session_with_ua <- rvest::session(URL, ua)


        if (is(session_with_ua, "try-error")) {
          return(list(success = FALSE, error = geterrmessage()))
        }

        if (session_with_ua$response$status_code != 200) {
          return(list(success = FALSE, error = paste0("HTTP error: ", session_with_ua$response$status_code)))
        }

        content_type <- session_with_ua$response$headers$`content-type`

        if (!stringr::str_detect(content_type, "image[:graph:]")) {
          return(list(success = FALSE, error = "Content is not an image"))
        }

        content <- session_with_ua$response$content

        img <- tryCatch(
          {
            magick::image_read(content)
          },
          error = function(e) {
            return(NULL)
          }
        )

        if (is.null(img)) {
          return(list(success = FALSE, error = "Failed to download image data"))
        }

        base_filename <- if ("label" %in% names(multimedia)) {
          paste0(
            multimedia[which(multimedia$identifier == URL), "gbifID"],
            "-",
            multimedia[which(multimedia$identifier == URL), "label"]
          )
        } else {
          as.character(multimedia[which(multimedia$identifier == URL), "gbifID"])
        }

        existing_files <- list.files(
          path = destDir,
          pattern = paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", base_filename), ".*\\.", format, "$")
        )

        if (length(existing_files) > 0) {
          image_path <- file.path(
            destDir,
            paste0(base_filename, " (", length(existing_files) + 1, ").", format)
          )
        } else {
          image_path <- file.path(destDir, paste0(base_filename, ".", format))
        }


        magick::image_write(img, path = image_path)

        Sys.sleep(2)
        return(list(success = TRUE, path = image_path))
      },
      error = function(e) {
        return(list(success = FALSE, error = as.character(e)))
      }
    )
  }

  doParallel::stopImplicitCluster()


  successful <- sum(sapply(results, function(x) x$success))
  message(successful, " of ", nrow(multimedia), " images successfully downloaded and saved.")

  if (return_results) {
    return(results)
  }
}
