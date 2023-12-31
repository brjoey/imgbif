% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/write_identifier.R
\name{write_identifier}
\alias{write_identifier}
\title{Write Identifiers from GBIF Multimedia File to Disk with Parallel Processing}
\usage{
write_identifier(multimedia, destDir, format = "png")
}
\arguments{
\item{multimedia}{A `data.frame` containing the multimedia data or a string with the path to the multimedia file.}

\item{destDir}{A string with the path to the destination directory where images should be saved.}

\item{format}{A string specifying the output format of the images, with supported formats including "png", "jpeg", "gif", "rgb", or "rgba". Default is "png".}
}
\description{
Downloads and saves images referenced by URL identifiers from a GBIF multimedia file to disk using parallel processing. Images are saved with the corresponding gbifID and, if available, a label. It is recommended to pre-process the file with `prepr_multimedia()` before use.
}
\examples{
\dontrun{
write_identifier(multimedia = multimedia_df, destDir = "path/to/images", format = "png")
}
}
