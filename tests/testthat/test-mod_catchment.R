# tests/testthat/test-mod_catchment.R
library(shiny)
library(testthat)

# 1. Source the global configurations, utility functions, and the module itself
source("../../global.R")
source("../../R/catchment_utils.R")
source("../../R/mod_catchment.R")

test_that("mod_catchment_server reacts to mock user file uploads", {
  # Mock global/shared reactive values container
  rvs <- reactiveValues(
    aoi_polygon       = NULL,
    map_click         = NULL,
    river_shp_path    = NULL,
    dem               = NULL
  )
  
  # Mock map proxy interface
  map_proxy_mock <- list(
    proxy = function() {
      leaflet::leafletProxy("dummy-map-id")
    }
  )
  
  shiny::testServer(mod_catchment_server, args = list(rvs = rvs, map_proxy = map_proxy_mock), {
    # Access reactives and check empty baseline
    expect_null(active_dem())
    
    # Mock vector AOI upload (passing a dummy geojson string)
    dummy_file_path <- tempfile(fileext = ".geojson")
    dummy_geojson <- '{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-10,30],[-5,30],[-5,35],[-10,35],[-10,30]]]},"properties":{}}'
    writeLines(dummy_geojson, dummy_file_path)
    
    # Set the Shiny fileInput mock trigger
    session$setInputs(aoi_upload = list(
      name = "mock_aoi.geojson",
      datapath = dummy_file_path
    ))
    
    # Allow asynchronous events to catch up
    session$flushReact()
    
    # Verify that the parsed vector bounding limits were converted to WGS84 & registered 
    expect_s3_class(rvs$aoi_polygon, "sf")
    expect_equal(sf::st_crs(rvs$aoi_polygon)$epsg, 4326)
  })
})