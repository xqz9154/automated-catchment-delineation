# global.R

# ---- Explicit Package Declarations for rsconnect Bundle Building ----
library(shiny)
library(shinyjs)
library(shinyWidgets)
library(shinyFeedback)
library(bslib)
library(bsicons)
library(leaflet)
library(leaflet.extras)
library(leafem)
library(stars)
library(terra)
library(sf)
library(whitebox)
library(osmdata)
library(ncdf4)
library(rstac)
library(tools)
library(curl)
library(jsonlite)

# ---- Cross-Platform Geospatial Environment Setup ----
geospatial_env_lock <- function() {
  sf_proj <- system.file("proj", package = "sf")
  if (!dir.exists(sf_proj)) {
    stop("sf PROJ database not found. sf installation is broken.")
  }
  
  Sys.setenv(
    PROJ_LIB = sf_proj,
    PROJ_DATA = sf_proj,
    GDAL_DATA = system.file("gdal", package = "sf")
  )
  
  # CROSS-PLATFORM PATH SEPARATOR FIX: Semicolon for Windows, colon for Linux (shinyapps.io)
  sep <- if (.Platform$OS.type == "windows") ";" else ":"
  
  path_vec <- strsplit(Sys.getenv("PATH"), sep, fixed = TRUE)[[1]]
  path_vec <- path_vec[!grepl("conda|miniconda", path_vec, ignore.case = TRUE)]
  Sys.setenv(PATH = paste(path_vec, collapse = sep))
  
  message("✔ Geospatial environment locked to sf/terra stack (Platform: ", .Platform$OS.type, ")")
}
geospatial_env_lock()

# ---- Embedded Whitebox Engine Configuration ----
# Looks inside app root space for a bundled binary executable folder setup
wbox_bin_path <- file.path("bin", "whitebox", "whitebox_tools")
if (file.exists(wbox_bin_path)) {
  whitebox::set_whitebox_path(wbox_bin_path)
} else {
  # Local development environment automatic path fallback integration
  whitebox::wbt_init()
}

# ---- Global Runtime Constants & Configurations ----
MAX_DISPLAY_DIM <- 800
DEFAULT_POUR_LAT <- 52.3
DEFAULT_POUR_LNG <- 10.5

options(timeout = 600)
options(shiny.sanitize.errors = FALSE)

# ---- GDAL Engine Settings ----
tryCatch({
  terra::setGDALconfig("GDAL_HTTP_TIMEOUT", "600")
  terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "TRUE")
  terra::setGDALconfig("GDAL_HTTP_MAX_RETRY", "10")
  terra::setGDALconfig("GDAL_HTTP_RETRY_DELAY", "5")
  terra::setGDALconfig("CPL_CURL_IGNORE_ERROR", "YES")
}, error = function(e) message("Could not configure GDAL engine defaults: ", e$message))

# ---- Spatial Helper Functions ----
get_valid_bbox <- function(rvs) {
  if (!is.null(rvs$dem)) {
    e <- terra::ext(rvs$dem)
    crs_dem <- terra::crs(rvs$dem)
    if (!is.na(crs_dem) && crs_dem != "") {
      corners <- matrix(
        c(e[1], e[3], e[2], e[3], e[2], e[4], e[1], e[4], e[1], e[3]),
        ncol = 2, byrow = TRUE
      )
      poly <- sf::st_polygon(list(corners))
      poly_sf <- sf::st_sfc(poly, crs = crs_dem)
      poly_wgs84 <- sf::st_transform(poly_sf, 4326)
      bbox <- sf::st_bbox(poly_wgs84)
      return(list(xmin = bbox[["xmin"]], ymin = bbox[["ymin"]], xmax = bbox[["xmax"]], ymax = bbox[["ymax"]]))
    } else {
      return(list(xmin = e[1], ymin = e[3], xmax = e[2], ymax = e[4]))
    }
  }
  if (!is.null(rvs$aoi_polygon)) {
    bbox <- sf::st_bbox(rvs$aoi_polygon)
    return(list(xmin = bbox[["xmin"]], ymin = bbox[["ymin"]], xmax = bbox[["xmax"]], ymax = bbox[["ymax"]]))
  }
  return(NULL)
}