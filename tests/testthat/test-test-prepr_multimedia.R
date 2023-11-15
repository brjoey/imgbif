library(testthat)
library(imgbif)

test_multimedia <- readRDS("~/imgbif/tests/testthat/test_multimedia.rds")
test_occurrence <- readRDS("~/imgbif/tests/testthat/test_occurrence.rds")


test_that("prepr_multimedia filters out records without a GBIF ID or image link", {
  filtered_multimedia <- prepr_multimedia(multimedia = test_multimedia, occurrence = test_occurrence)

  expect_false(any(is.na(filtered_multimedia$gbifID)))
  expect_false(any(is.na(filtered_multimedia$identifier)))

  expect_equal(nrow(filtered_multimedia), 8)

  expect_equal(filtered_multimedia$gbifID, test_multimedia$gbifID[3:10])
  expect_equal(filtered_multimedia$identifier, test_multimedia$identifier[3:10])
})
