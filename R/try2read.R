#' try to read the images from URL in multimedia file
#'
#' @param identifier The image URL.
#' @import stats
try2read <- function(identifier) {
  call_useragent <- round(runif(1, min = 1, max = length(useragent)))
  ua <- httr::user_agent(useragent[call_useragent])

  session_with_ua <- try(
    {
      rvest::session(identifier, ua, timeout = httr::timeout(30))
    },
    silent = TRUE
  )

  if (is(session_with_ua, "try-error")) {
    return(session_with_ua)
  }

  if (session_with_ua$response$status_code == 200) {
    content_type <- session_with_ua$response$headers$`content-type`

    if (stringr::str_detect(content_type, "image[:graph:]")) {
      image <- try(
        {
          magick::image_read(session_with_ua$response$content)
        },
        silent = TRUE
      )
    }
    return(image)
  } else {
    image <- "try-error"
    return(image)
  }
}
