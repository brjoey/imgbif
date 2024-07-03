backupDataServer <- function(data, backupPath, backup_cache) {
  try2write <- try(
    {
      backupTime <- Sys.time() |> format("%Y-%m-%d %H-%M-%S")
      backup_file <- paste0("multimedia-", backupTime, ".feather")

      backup2remove <- backup_cache[3]
      if (file.exists(file.path(backupPath, backup2remove)) && backup_cache[3] != "") {
        file.remove(file.path(backupPath, backup2remove))
      }
      backup_cache <- c(backup_file, backup_cache[1:2])

      feather::write_feather(data, file.path(backupPath, backup_file))
    },
    silent = TRUE
  )
  if (is(try2write, "try-error")) {
    feather::write_feather(data, file.path(getwd(), "/multimedia.feather"))
    cat(paste0("Could not find provided path. Wrote to: ", getwd()))
  }
}
