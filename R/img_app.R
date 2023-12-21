#' Setup Classification App to Label Images from Local Folder.
#'
#' Sets up and launches a Shiny application to manually classify images from a local folder.
#'
#' @param sourceDir The path to the directory where the images to be labeled are located.
#' @param classSize A numeric value with the desired number of images per class (label) for tracking purposes.
#' @param label A character vector that contains the label for each class.
#' @param multi_label A `Boolean` value that indicates if multiple label (TRUE) can be assigned to one image or not (FALSE).
#'   The app launches with check boxes if "multi_label = TRUE" and with action buttons if "multi_label = FALSE".
#' @note The app creates a folder for each label inside "sourceDir" and copies the images from "sourceDir" into the
#'   corresponding subfolder. Afterwards, the image is removed from "sourceDir".
#'
#' @import shiny
#' @import shinyjs
#' @import htmltools
#' @import magick
#' @import feather
#' @import shinyWidgets
#' @import stringr
#' @import tools
#' @export
#' @examples
#' \dontrun{
#' img_app(
#'   sourceDir = "Dir/to/images",
#'   label = c("flowering", "fruiting"),
#'   multi_label = FALSE,
#'   classSize = 100
#' )
#' }
img_app <- function(
    sourceDir,
    label,
    multi_label = FALSE,
    classSize = 100) {
  if (missing(label)) {
    stop("label character vector is required.")
  }


  if (!dir.exists(file.path(sourceDir))) {
    stop("Could not find the provided sourceDir")
  }


  if (dir.exists(file.path(sourceDir))) {
    lapply(label, function(l) {
      dir.create(path = file.path(sourceDir, l))
    })
    dir.create(path = file.path(sourceDir, "exclude"))
  }


  if (!is.numeric(classSize) || length(classSize) != 1) {
    stop("classSize must be a single numeric value.")
  }

  jscode <- "shinyjs.closeWindow = function() { window.close(); }"

  labelId <- paste0("btn", seq_along(label))

  pbID <- paste0("pb", seq_along(label))

  static_labelBtn <- c("exclude", "backup", "lastImage", "nextImage")
  if (!multi_label) {
    labelBtn <- c(labelId, static_labelBtn)
  } else {
    labelBtn <- c("submitBtn", static_labelBtn)
  }


  image_list <- list.files(path = sourceDir, pattern = "\\.jpg$|\\.png$|\\.jpeg$|\\.tiff$|\\.bmp$", full.names = TRUE)


  ui <- ui.img_app(
    label = label, multi_label = multi_label, jscode = jscode, classSize = classSize, pbID = pbID
  )
  server <- server.img_app(
    labelBtn = labelBtn,
    classSize = classSize,
    labelId = labelId, label = label,
    multi_label = multi_label,
    image_list = image_list,
    sourceDir = sourceDir,
    pbID = pbID
  )
  shiny::shinyApp(ui = ui, server = server)
}
