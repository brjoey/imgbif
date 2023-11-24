backupDataServer <- function(data, label_list, backupPath) {
  new_label <- unlist(lapply(label_list, paste, collapse = ", "))
  new_label[new_label == ""] <- NA_character_
  data$label <- new_label
  try2write <- try(
    {
      feather::write_feather(data, file.path(backupPath, "multimedia.feather"))
    },
    silent = TRUE
  )
  if (is(try2write, "try-error")) {
    feather::write_feather(data, file.path(getwd(), "/multimedia.feather"))
    cat(paste0("Could not find provided path. Wrote to: ", getwd()))
  }
}
