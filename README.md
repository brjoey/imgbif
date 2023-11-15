# **Please do not use. Still under development.**

# imgbif

------------------------------------------------------------------------

## About

Pre-process and write images from GBIF multimedia files.

------------------------------------------------------------------------

## How To...

------------------------------------------------------------------------

### Install

Install the package `devtools` if not already done. install.packages("devtools").

Use `devtools::install_git()` to install the package from the link to the github repository ("https://github.com/brjoey/imgbif.git").

```         
devtools::install_git("https://github.com/brjoey/imgbif.git")
```

### Use

The prerequisite is that you have already downloaded a data set from the GBIF database.

#### Pre-process

You can use the `prepr_multimedia()` function to prepare the data set for classification with the classification app. The pre-processing consists of removing occurrences that either do not have a gbidID or do not contain a link to an image. In addition, URLs to images in the inaturalis database are processed. Optionally, images from Herbarium databases can be removed, provided that the downloaded records are complete. In addition, you can select whether and which licences are to be removed.

```         
imgbif::preprocess_multimedia(multimedia = path/to/multimedia/file OR data frame,
                         occurrence = path/to/occurrence_file,
                         herbarium.rm = TRUE,
                         license.rm = c("all rights reserved", "unclear")
                        )
```

See the help file for more information about `prepr_multimedia`.

```         
?preprocess_multimedia
```

#### write images

Use `write_identifier` to save images from URLs in the GBIF multimedia file locally. The function uses the `foreach` and `magick` packages to write the images with parallel processing into the destination folder. The images are labelled with the gbifID and if available the label that was assigned when classifying with the classification app.

```         
imgbif::write_identifier(multimedia = "path/to/multimedia/file" OR data frame,
                         destDir = "path/to/destination directory/",
                         format = "png"
                         )
```

See the help file for more information about `write_identifier`.

```         
?write_identifier
```
