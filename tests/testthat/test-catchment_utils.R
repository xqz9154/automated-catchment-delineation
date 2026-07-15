# tests/testthat/test-catchment_utils.R
library(testthat)
library(terra)
library(sf)

# Source the utility functions
source("../../R/catchment_utils.R")

test_that("repair_crs handles raster inputs with missing CRS properly", {
  # 1. FORCE empty CRS during raster creation
  r <- terra::rast(
    ncols = 10, nrows = 10, 
    xmin = -120, xmax = -110, 
    ymin = 35, ymax = 45, 
    crs = ""  # Explicitly force empty CRS
  )
  values(r) <- runif(100)
  
  # Ensure CRS starts completely empty
  expect_true(terra::crs(r) == "")
  
  # 2. Run repair_crs (should detect geographic bounds and assign WGS84)
  r_repaired <- repair_crs(r)
  
  # 3. Flexible assertions for modern GDAL environments
  expect_s4_class(r_repaired, "SpatRaster")
  expect_true(terra::is.lonlat(r_repaired))
  
  # Accept either standard code mapping to WGS84
  repaired_code <- terra::crs(r_repaired, describe = TRUE)$code
  expect_true(repaired_code %in% c("4326", "CRS84"))
})