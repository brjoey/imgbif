#' Remove duplicate files such as images that are stored on disk
#'
#' This function uses the digest::digest function with the md5 algorithm to create hashes with parallel processing using the foreach package.
#'
#' @param folder_path A `character vector` containing the path to the folder that is to be evaluated.
#' @param rm_duplicates A `Boolean` value that indicates if the detected duplicates should be deleted.
#' `TRUE` by default.
#' @param algorithm A `character vector` to select the algorithm that the digest::digest function should use.
#'  "md5" is the default. Other alternatives are "sha1", "crc32", "sha256", "sha512", "xxhash32", "xxhash64", "murmur32", "spookyhash", "blake3", and "crc32c".
#'
#' @return A `character vector` containing the names of the detected (and if rm_duplicates = TRUE, deleted) duplicates.
#' @import foreach
#' @importFrom parallelly availableCores
#' @importFrom doParallel registerDoParallel
#' @importFrom doParallel stopImplicitCluster
#' @importFrom digest digest
#'
#' @examples
#' \dontrun{
#' remove_duplicates(folder_path = "path/to/our/folder_with_images", rm_duplicates = TRUE)
#' }
#' @export
remove_duplicates <- function(folder_path, rm_duplicates = TRUE, algorithm = 'md5') {
  file_names <- list.files(path = folder_path, full.names = TRUE)

  numCores <- parallelly::availableCores(constraints = "connections")
  doParallel::registerDoParallel(numCores)

  file_hashes <- foreach(i = seq_along(file_names), .combine = c) %dopar% {
    digest::digest(object = file_names[i], algo = algorithm, file = TRUE)
  }
  doParallel::stopImplicitCluster()

  duplicates <- duplicated(file_hashes)

  if (rm_duplicates) {
    file.remove(file_names[duplicates])
    return(file_names[duplicates])
  } else {
    return(file_names[duplicates])
  }
}
