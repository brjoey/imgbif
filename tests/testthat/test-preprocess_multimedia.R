library(testthat)
library(imgbif)

test_multimedia <- readRDS("~/imgbif/tests/testthat/test_multimedia.rds")
test_occurrence <- readRDS("~/imgbif/tests/testthat/test_occurrence.rds")


test_that("prepr_multimedia filters out records without a GBIF ID or image link, the correct license and the Herbarium file", {
  filtered_multimedia <- preprocess_multimedia(multimedia = test_multimedia,
                                               occurrence = test_occurrence,
                                               license.rm = c("NA")
                                               )

  expect_false(any(is.na(filtered_multimedia$gbifID)))
  expect_false(any(is.na(filtered_multimedia$identifier)))

  expect_equal(nrow(filtered_multimedia), 7)

  expect_equal(filtered_multimedia$gbifID, test_multimedia$gbifID[c(3:7, 9:10)])

  expect_equal(filtered_multimedia$identifier[3], "https://inaturalist-open-data.s3.amazonaws.com/photos/129410184/original.jpg")
})


