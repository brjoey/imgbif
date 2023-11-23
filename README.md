# **Please do not use. Still under development.**

# imgbif

------------------------------------------------------------------------

## About

Pre-process and write images from GBIF multimedia files and classify them manually with a Shiny app.

------------------------------------------------------------------------

## How To...

------------------------------------------------------------------------

### Install

Install the package `devtools` if not already done.

```         
install.packages("devtools").
```

Use `devtools::install_git()` to install the package from the link to the github repository ("https://github.com/brjoey/imgbif.app.git").

```         
devtools::install_git("https://github.com/brjoey/imgbif.app.git")
```

### Use

The prerequisite is that you have already downloaded a data set from the [GBIF database](https://www.gbif.org/) directly or with the [rgbif](https://www.gbif.org/tool/81747/rgbif) R package.

#### Pre-process

The `preprocess_multimedia` function can be used to prepare the multimedia file for classification with the classification app. consists of removing occurrences that either do not have a gbidID (occurrence ID) or do not contain a link to an image. In addition, URLs to images in the iNaturalist database are repaired if necessary. Optionally, if the downloaded occurrence file includes publisher information, images from Herbarium databases can be removed. In addition, it is possible to select whether and which licences are to be removed. Possible arguments are 'all rights reserved', 'by-sa', 'by-nc', 'not applicable (NA)', and 'unclear'. By default, 'all rights reserved' and 'unclear'.

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
