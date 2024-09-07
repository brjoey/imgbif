#' Write Images to Disk (Server Helper Function)
#'
#' The `server.write_image` function saves images to a specified directory. It handles both single-label and multi-label cases.
#'  Images are saved in a user-specified format (e.g., PNG, JPG) and are organized into directories based on their labels.
#'
#' @import ggplot2
#' @import tools
#'
server.write_image <- function(multi_label, image_cache, image_format, currentRows, imageSelection, multimedia, backupDir) {
  if (!multi_label) {
    output_folder <- file.path(backupDir, "GBIF_multimedia_file_images", multimedia[currentRows[imageSelection], "label"][1])
  } else {
    output_folder <- file.path(backupDir, "GBIF_multimedia_file_images")
  }
  lapply(
    seq_along(imageSelection),
    function(idx) {
      img2save <- image_cache[[imageSelection[[idx]]]]
      output_file_name <- paste0(multimedia[currentRows[imageSelection], "gbifID"][idx], " (", idx, ") ", multimedia[currentRows[imageSelection], "label"][idx], " ", ".", image_format)
      suppressMessages(
        ggplot2::ggsave(
          filename = output_file_name,
          plot = img2save,
          path = output_folder
        )
      )
    }
  )
}
