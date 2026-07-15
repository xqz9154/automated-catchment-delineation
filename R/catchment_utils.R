# R/catchment_utils.R

repair_crs <- function(r) {
  if (!inherits(r, "SpatRaster") && !inherits(r, "SpatVector")) {
    stop("'r' must be a SpatRaster or SpatVector object")
  }
  
  crs_raw <- terra::crs(r)
  message("Original CRS: ", ifelse(is.na(crs_raw) || crs_raw == "", "<empty>", crs_raw))
  e <- terra::ext(r)
  x_range <- e[2] - e[1]
  y_range <- e[4] - e[3]
  
  # ---- Validation helpers ----
  is_geographic <- function(crs) {
    if (is.na(crs) || crs == "") return(FALSE)
    tryCatch(terra::is.lonlat(crs), error = function(e) FALSE)
  }
  
  validate_crs <- function(crs, ext) {
    if (is.na(crs) || crs == "") return(FALSE)
    if (is_geographic(crs)) {
      # Must be within valid lat/lon bounds
      if (ext[1] >= -180 && ext[2] <= 180 &&
          ext[3] >= -90  && ext[4] <= 90 &&
          x_range <= 360 && y_range <= 180) {
        return(TRUE)
      } else {
        message("Rejecting geographic CRS: extents are not in degrees.")
        return(FALSE)
      }
    } else {
      # Projected CRS: basic sanity – accept unless it's a tiny numeric range
      # that might indicate degrees mislabelled as metres.
      if (x_range < 1 && y_range < 1) {
        message("Warning: projected CRS with extremely small range – possible misassignment.")
        # Still accept, but warn
      }
      return(TRUE)   # accept projected CRSs by default
    }
  }
  
  # ---- Helper to extract ALL EPSG codes from WKT ----
  extract_all_epsg <- function(wkt_text) {
    # Pattern: ID["EPSG",1234] or AUTHORITY["EPSG","1234"]
    pattern <- '(?:ID|AUTHORITY)\\s*\\[\\s*"EPSG"\\s*,\\s*"?(\\d+)"?\\s*\\]'
    all_codes <- integer()
    # Get start positions of all matches
    matches <- gregexpr(pattern, wkt_text, ignore.case = TRUE, perl = TRUE)[[1]]
    if (length(matches) == 1 && matches[1] == -1) return(all_codes)
    
    for (i in seq_along(matches)) {
      start <- matches[i]
      len <- attr(matches, "match.length")[i]
      substr_text <- substr(wkt_text, start, start + len - 1)
      # Extract the numeric part using the same pattern
      num <- as.integer(regmatches(substr_text,
                                   regexec(pattern, substr_text, ignore.case = TRUE))[[1]][2])
      if (!is.na(num) && num > 0) all_codes <- c(all_codes, num)
    }
    return(all_codes)
  }
  
  # --------------------------------------------------------------------
  # 1. If existing CRS is valid, keep it
  if (!is.na(crs_raw) && crs_raw != "" && validate_crs(crs_raw, e)) {
    message("Existing CRS is valid and compatible with extents.")
    return(r)
  }
  
  # 2. Extract ALL EPSG codes from companion .prj file
  src <- terra::sources(r)
  if (length(src) > 0 && src[1] != "") {
    prj_file <- sub("\\.[^.]+$", ".prj", src[1])
    if (file.exists(prj_file)) {
      prj_text <- paste(readLines(prj_file, warn = FALSE), collapse = " ")
      message("Scanning .prj file for EPSG codes...")
      epsg_codes <- extract_all_epsg(prj_text)
      
      if (length(epsg_codes) > 0) {
        # Try codes in reverse order (outermost / top‑level CRS first)
        for (epsg in rev(epsg_codes)) {
          candidate <- paste0("EPSG:", epsg)
          if (validate_crs(candidate, e)) {
            terra::crs(r) <- candidate
            message("Assigned EPSG:", epsg, " from .prj (validated, selected from ", 
                    length(epsg_codes), " candidates).")
            return(r)
          } else {
            message("EPSG:", epsg, " rejected after validation.")
          }
        }
      }
    }
  }
  
  # 3. If CRS missing and extents are geographic, assign EPSG:4326
  if ((is.na(crs_raw) || crs_raw == "") &&
      e[1] >= -180 && e[2] <= 180 && e[3] >= -90 && e[4] <= 90) {
    terra::crs(r) <- "EPSG:4326"
    message("Assigned EPSG:4326 based on geographic extent.")
    return(r)
  }
  
  # 4. Try UTM extraction from the CRS string itself (if any)
  if (!is.na(crs_raw) && grepl("UTM|zone", crs_raw, ignore.case = TRUE)) {
    m <- regexec("UTM\\s+zone\\s+([0-9]+)([NS])?", crs_raw, ignore.case = TRUE)
    parts <- regmatches(crs_raw, m)
    if (length(parts) > 0 && length(parts[[1]]) >= 2) {
      zone <- as.numeric(parts[[1]][2])
      hem <- toupper(parts[[1]][3])
      if (!is.na(zone) && zone >= 1 && zone <= 60) {
        epsg <- if (grepl("ETRS89", crs_raw, ignore.case = TRUE)) {
          25800 + zone
        } else {
          if (is.na(hem) || hem == "N") 32600 + zone else 32700 + zone
        }
        candidate <- paste0("EPSG:", epsg)
        if (validate_crs(candidate, e)) {
          terra::crs(r) <- candidate
          message("Assigned EPSG:", epsg, " from UTM zone in CRS string.")
          return(r)
        }
      }
    }
  }
  
 
  
  # 5. Last resort: derive UTM from data centroid
  cx <- (e[1] + e[2]) / 2
  cy <- (e[3] + e[4]) / 2
  if (cx >= -180 && cx <= 180 && cy >= -90 && cy <= 90) {
    zone <- floor((cx + 180) / 6) + 1
    zone <- pmax(1, pmin(60, zone))
    epsg <- if (cy >= 0) 32600 + zone else 32700 + zone
    candidate <- paste0("EPSG:", epsg)
    if (validate_crs(candidate, e)) {
      terra::crs(r) <- candidate
      message("Assigned EPSG:", epsg, " from data centroid UTM.")
      return(r)
    }
  }
  
  # 6. Give up
  warning("Could not repair CRS; returning object with original (possibly NA) CRS.")
  return(r)
}

# 
extent_to_wgs84 <- function(r) {
  ext <- terra::ext(r)
  crs <- terra::crs(r)
  if (crs != "EPSG:4326") {
    coords <- data.frame(x = c(ext[1], ext[2], ext[1], ext[2]),
                         y = c(ext[3], ext[3], ext[4], ext[4]))
    pts <- sf::st_as_sf(coords, coords = c("x", "y"), crs = crs)
    pts <- sf::st_transform(pts, 4326)
    bbox <- sf::st_bbox(pts)
    return(bbox)   # 直接返回 st_bbox 对象
  } else {
    return(sf::st_bbox(c(xmin = ext[1], ymin = ext[3], xmax = ext[2], ymax = ext[4]), crs = 4326))
  }
}


# 

#' Orchestrate full DEM download and reprojection pipeline for hydrological modeling
#'
#' @param bbox List containing lng1, lng2, lat1, lat2
#' @param collection Character string of the STAC collection
#' @return A projected, metric SpatRaster ready for flow direction calculations
download_project_dem <- function(bbox, collection = "cop-dem-glo-30") {
  
  # Helper to safely update shiny progress if inside a reactive environment
  update_stage <- function(amount, message) {
    if (requireNamespace("shiny", quietly = TRUE) && !is.null(shiny::getDefaultReactiveDomain())) {
      shiny::incProgress(amount = amount, detail = message)
    }
  }
  
  # Stage 1: Fetch and Crop Geographic DEM from Cloud Mosaic
  update_stage(0.1, "Initializing cloud DEM stream pipeline...")
  r_geo <- fetch_dem_stac(bbox, collection = collection)
  
  if (is.null(r_geo)) {
    stop("Failed to retrieve or mosaic geographic DEM from STAC server.")
  }
  
  # Stage 2: Reproject to Local Metric UTM Zone
  update_stage(0.3, "Analyzing local centroid and projecting to metric UTM...")
  r_metric <- tryCatch({
    project_to_local_utm(r_geo)
  }, error = function(e) {
    message("Reprojection failed: ", e$message)
    NULL
  })
  
  if (is.null(r_metric)) {
    stop("Failed to project DEM into a metric coordinate system. Hydrological calculations cannot proceed.")
  }
  
  update_stage(0.1, "DEM processing pipeline complete!")
  return(r_metric)
}

# ---- Optimized Cloud-Native DEM Fetch Engine (Production-Hardened) ----
# R/catchment_utils.R

fetch_dem_stac <- function(bbox, collection = "cop-dem-glo-30") {
  # 1. DEFENSIVE FIX: Guarantee strict coordinate serialization order
  xmin <- min(as.numeric(bbox$lng1), as.numeric(bbox$lng2))
  xmax <- max(as.numeric(bbox$lng1), as.numeric(bbox$lng2))
  ymin <- min(as.numeric(bbox$lat1), as.numeric(bbox$lat2))
  ymax <- max(as.numeric(bbox$lat1), as.numeric(bbox$lat2))
  
  bbox_vec <- c(xmin, ymin, xmax, ymax)
  
  # Helper to update progress if running inside a live Shiny session
  update_progress <- function(amount, message) {
    if (requireNamespace("shiny", quietly = TRUE) && !is.null(shiny::getDefaultReactiveDomain())) {
      shiny::incProgress(amount = amount, detail = message)
    }
  }
  
  # 2. Guard against missing or uninitialized coordinates from UI events
  if (any(is.na(bbox_vec)) || length(bbox_vec) != 4) {
    message("STAC Fetch Aborted: Bounding box contains NA or missing values.")
    return(NULL)
  }
  
  # 3. Guard against invalid geographic extents (STAC strictly requires WGS84 bounds)
  if (bbox_vec[1] < -180 || bbox_vec[3] > 180 || bbox_vec[2] < -90 || bbox_vec[4] > 90) {
    message("STAC Fetch Aborted: Coordinates fall out of WGS84 bounds. Verify map projection.")
    return(NULL)
  }
  
  stac_url <- "https://planetarycomputer.microsoft.com/api/stac/v1"
  
  # 4. Session-isolated storage to completely prevent concurrent user overwrites in Shiny
  vrt_path <- tempfile(pattern = "session_mosaic_", fileext = ".vrt")
  local_cache_path <- tempfile(pattern = "local_dem_cache_", fileext = ".tif")
  
  # Absolute teardown hook: guarantees scratch space disk footprint is cleared
  on.exit({
    if (file.exists(vrt_path)) unlink(vrt_path)
  }, add = TRUE)
  
  result <- tryCatch({
    # 5. Execute STAC API connection and fetch metadata properties
    update_progress(0.1, "Querying Microsoft Planetary Computer STAC catalog...")
    
    items <- rstac::stac(stac_url) |>
      rstac::stac_search(
        collections = collection,
        bbox = bbox_vec,
        limit = 50
      ) |>
      rstac::get_request() |>
      rstac::items_sign(rstac::sign_planetary_computer())
    
    if (is.null(items) || length(items$features) == 0) {
      message("No cloud data tiles matched the target spatial footprint.")
      return(NULL)
    }
    
    # 6. Safe Multi-Collection Asset Extraction Pipeline
    update_progress(0.2, "Extracting asset links and signing secure URLs...")
    vsi_urls <- character(0)
    for (feat in items$features) {
      asset_url <- NULL
      
      # Explicitly scan keys matching standard STAC DEM structures
      for (key in c("data", "elevation")) {
        if (!is.null(feat$assets[[key]]$href)) {
          asset_url <- feat$assets[[key]]$href
          break
        }
      }
      
      # Fallback: check MIME type
      if (is.null(asset_url)) {
        for (asset_name in names(feat$assets)) {
          asset_type <- feat$assets[[asset_name]]$type
          if (!is.null(asset_type) && grepl("image/tiff|image/x.geotiff", asset_type, ignore.case = TRUE)) {
            asset_url <- feat$assets[[asset_name]]$href
            break
          }
        }
      }
      
      if (!is.null(asset_url)) {
        vsi_urls <- c(vsi_urls, paste0("/vsicurl/", asset_url))
      }
    }
    
    if (length(vsi_urls) == 0) {
      message("No structural raster intersections found with available tile footprints.")
      return(NULL)
    }
    
    # 7. Build Virtual Dataset (VRT) matching the highest native grid resolution
    update_progress(0.2, "Building virtual raster mosaic grid (VRT)...")
    
    sf::gdal_utils(
      "buildvrt",
      source = vsi_urls,
      destination = vrt_path,
      options = c("-resolution", "highest")
    )
    
    # 8. Multi-threaded Warp & Crop via GDAL C++
    update_progress(0.2, "Warping & streaming raster window from cloud assets...")
    
    warp_opts <- c(
      "-te", as.character(bbox_vec[1]), as.character(bbox_vec[2]), 
      as.character(bbox_vec[3]), as.character(bbox_vec[4]),
      "-te_srs", "EPSG:4326",
      "-r", "bilinear",
      "-ovr", "AUTO",            # Dynamic overviews to minimize data transfer
      "-multi",                  # Asynchronous pipeline execution
      "-wo", "NUM_THREADS=ALL_CPUS",
      "-wo", "OPTIMIZE_SIZE=YES",
      "-wo", "SKIP_NOSOURCE=YES",
      "-co", "COMPRESS=DEFLATE", # DEFLATE ensures WhiteboxTools can read raw streams
      "-co", "ZLEVEL=6",
      "-co", "TILED=YES",        # Force explicit block tiling configuration
      "-co", "BLOCKXSIZE=512",
      "-co", "BLOCKYSIZE=512",
      "-co", "BIGTIFF=IF_SAFER"
    )
    
    message("Streaming native cloud mosaic window via GDAL engine...")
    sf::gdal_utils(
      "warp",
      source = vrt_path,
      destination = local_cache_path,
      options = warp_opts
    )
    
    if (!file.exists(local_cache_path) || file.size(local_cache_path) == 0) {
      message("GDAL native operation returned empty.")
      return(NULL)
    }
    
    # 9. Load the materialized, cropped local file into memory
    update_progress(0.25, "Loading raster grid into session memory...")
    r_local <- terra::rast(local_cache_path)
    
    # Assign native geographic CRS if missing
    if (is.na(terra::crs(r_local)) || terra::crs(r_local) == "") {
      terra::crs(r_local) <- "EPSG:4326"
    }
    
    update_progress(0.05, "Raster load complete!")
    message(sprintf("✔ Localized extraction complete: %d x %d cells.", ncol(r_local), nrow(r_local)))
    return(r_local)
    
  }, error = function(e) {
    message("STAC/GDAL pipeline intercepted an exception: ", e$message)
    if (file.exists(local_cache_path)) unlink(local_cache_path)
    return(NULL)
  })
  
  return(result)
}

# 
project_to_local_utm <- function(r) {
  # 1. Check if the raster is already in a metric planar coordinate system
  if (!terra::is.lonlat(r)) {
    message(sprintf(
      "Raster is already in a projected metric coordinate system (%s). Skipping reprojection.", 
      terra::crs(r, describe = TRUE)$code
    ))
    return(r)
  }
  
  # 2. If it IS geographic, safely extract the centroid coordinates in WGS84
  ext_native <- terra::ext(r)
  lon_native <- mean(c(ext_native[1], ext_native[2]))
  lat_native <- mean(c(ext_native[3], ext_native[4]))
  
  # Create a temporary point vector in the native CRS and transform to true WGS84
  pt_native <- terra::vect(matrix(c(lon_native, lat_native), ncol = 2), crs = terra::crs(r))
  pt_wgs84 <- terra::project(pt_native, "EPSG:4326")
  coords_wgs84 <- terra::geom(pt_wgs84)
  
  lon <- coords_wgs84[1, "x"]
  lat <- coords_wgs84[1, "y"]
  
  # 3. Calculate accurate UTM Zone from true decimal degrees
  zone <- floor((lon + 180) / 6) + 1
  
  # Determine correct EPSG prefix (326XX for Northern Hemisphere, 327XX for Southern)
  epsg_code <- if (lat >= 0) {
    32600 + zone
  } else {
    32700 + zone
  }
  
  target_crs <- paste0("EPSG:", epsg_code)
  message(sprintf("Reprojecting grid from geographic to local metric planar system: %s", target_crs))
  
  # Project using bilinear interpolation for continuous terrain elevations
  r_projected <- terra::project(r, target_crs, method = "bilinear")
  return(r_projected)
}

# Downscale raster for display
prepare_display_raster <- function(r, max_dim = 1000) {
  if (nrow(r) > max_dim || ncol(r) > max_dim) {
    fact <- ceiling(max(nrow(r), ncol(r)) / max_dim)
    r <- terra::aggregate(r, fact = fact, fun = mean, na.rm = TRUE)
  }
  r
}


# Fixed Layer Dispatcher Interface
add_raster_layer <- function(map_proxy, layer_id, file_path, palette_input, agg_fun = "mean", opacity = 0.75) {
  req(file_path, file.exists(file_path))
  
  r <- terra::rast(file_path)
  r_display <- prepare_display_raster(r, max_dim = 1000)
  mm <- terra::minmax(r_display)
  
  domain <- if (any(is.na(mm)) || mm[1] == mm[2]) c(0, 1) else c(mm[1], mm[2])
  
  map_proxy |> leaflet::clearGroup(layer_id)
  
  # 转换为 stars 对象  
  r_stars <- stars::st_as_stars(r_display)
  
  leafem::addGeoRaster(
    map_proxy,
    r_stars,
    group = layer_id,
    opacity = opacity,
    project = TRUE,
    colorOptions = leafem::colorOptions(
      palette = palette_input,
      na.color = "transparent"
    )
  )
}

