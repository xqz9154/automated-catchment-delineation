# R/mod_catchment.R

mod_catchment_ui <- function(id) {
  ns <- NS(id)
  tagList(
    useShinyFeedback(),
    accordion(
      id = ns("catchment_accordion"),
      open = "panel_load_dem",
      multiple = FALSE,
      
      # 1. DEM Loading Panel
      accordion_panel(
        value = "panel_load_dem",
        title = tags$span(bsicons::bs_icon("map", class = "text-primary me-2"), "1. Load DEM Raster"),
        radioButtons(ns("dem_source"), "DEM Extraction Method:",
                     choices = c("Upload Local GeoTIFF (.tif)" = "upload", "Query Global STAC Server" = "global"),
                     selected = "upload"),
        conditionalPanel(
          condition = "input.dem_source == 'upload'", ns = ns,
          fileInput(ns("dem_upload"), "Select Native GeoTIFF File:", accept = c(".tif", ".tiff", ".asc", ".dem", ".img"), width = "100%")
        ),
        conditionalPanel(
          condition = "input.dem_source == 'global'", ns = ns,
          selectInput(ns("global_collection"), "Target Planetary Dataset:",
                      choices = c("Copernicus GLO-30" = "cop-dem-glo-30", "Copernicus GLO-90" = "cop-dem-glo-90", "NASADEM" = "nasadem", "ALOS AW3D30" = "alos-dem"), selected = "cop-dem-glo-30"),
          radioButtons(ns("aoi_source"), "Area of Interest (AOI):", 
                       choices = c("Draw Bounds on Canvas" = "draw", "Upload Vector File" = "upload_aoi"), 
                       selected = "draw", inline = FALSE), # Changed to FALSE for vertical stacking
          conditionalPanel(
            condition = "input.aoi_source == 'upload_aoi'", ns = ns,
            fileInput(ns("aoi_upload"), "Upload Shapefile (.zip) or GeoJSON:", accept = c(".shp", ".zip", ".geojson", ".kml", ".kmz", ".gpkg"), width = "100%"),
            helpText(tags$em("Supported vector extensions: .zip (zipped shapefile bundle including .shp, .shx, .dbf, .prj), .geojson, .gpkg, .kml, or .kmz"))
          ),
          div(class = "d-flex gap-2 mt-3",
              actionButton(ns("fetch_dem"), tags$span(bsicons::bs_icon("cloud-download"), " Fetch DEM"), class = "btn-primary flex-grow-1"),
              actionButton(ns("clear_aoi"), "Clear AOI", class = "btn-outline-secondary"))
        )
      ),
      
      # 2. Burn Rivers Panel
      accordion_panel(
        value = "panel_burn_rivers",
        title = tags$span(bsicons::bs_icon("water", class = "text-info me-2"), "2. Hydro-Enforcement (Burn-in)"),
        radioButtons(ns("burn_source"), "River Network Source Alignment:",
                     choices = c("Upload Local Polyline Shapefile" = "upload", "HydroRIVERS (HydroSHEDS Cache)" = "hydrorivers"), selected = "upload"),
        conditionalPanel(
          condition = "input.burn_source == 'upload'", ns = ns,
          fileInput(ns("river_shp"), "Select River Vector Archive (.zip/.tar):", accept = c(".zip",".tar"), width = "100%"),
          helpText("Requires polyline string geometries reflecting target channels.")
        ),
        conditionalPanel(
          condition = "input.burn_source == 'hydrorivers'", ns = ns,
          selectInput(ns("continent"), "Target Regional Zone:",
                      choices = c("Africa" = "af", "Asia" = "as", "Europe" = "eu", "North America" = "na", "South America" = "sa", "Australia" = "au"), selected = "eu"),
          div(class = "text-muted small mb-2", bsicons::bs_icon("info-circle"), " Regional sets match ~50–500 MB arrays.")
        ),
        actionButton(ns("fetch_rivers"), tags$span(bsicons::bs_icon("cloud-download"), " Load / Fetch River Network"), class = "btn-info w-100 mt-1 mb-2"),
        hr(),
        actionButton(ns("burn_rivers"), tags$span(bsicons::bs_icon("fire"), " Execute Hydro-Enforcement"), class = "btn-warning w-100 mt-2")
      ),
      
      # 3. Hydro-processing Panel
      accordion_panel(
        value = "panel_hydro_processing",
        title = tags$span(bsicons::bs_icon("cpu", class = "text-success me-2"), "3. Routing & Accumulation"),
        prettyRadioButtons(ns("sink_method"), "Depression Sinking & Mitigation Technique:",
                           choices = c("Breach (Lindsay)" = "breach", "Wang & Liu Fill" = "wang_liu", "Breach + Fill (Recommended)" = "breach_then_fill"),
                           selected = "breach_then_fill", animation = "smooth", status = "primary"),
        conditionalPanel(
          condition = "input.sink_method == 'breach_then_fill' || input.sink_method == 'breach'", ns = ns,
          numericInput(ns("breach_dist"), "Maximum Search Breach Distance (m):", value = 500, min = 0, step = 100)
        ),
        div(class = "row g-2 mb-3",
            div(class = "col-6", prettyRadioButtons(ns("flow_dir_method"), "Flow Routing:", choices = c("D8" = "d8", "FD8" = "fd8"), selected = "d8", animation = "smooth", status = "info")),
            div(class = "col-6", prettyRadioButtons(ns("flow_acc_method"), "Accumulation:", choices = c("D8" = "d8", "FD8" = "fd8"), selected = "d8", animation = "smooth", status = "info"))),
        numericInput(ns("stream_thresh"), "Stream Channel Initiation Threshold (cells):", value = 1000, min = 10, step = 100),
        actionButton(ns("run_hydro"), tags$span(bsicons::bs_icon("play-fill"), " Run Hydrological Pipeline"), class = "btn-primary w-100 mt-2")
      ),
      
      # 4. Catchment Extraction Panel
      accordion_panel(
        value = "panel_delineate",
        title = tags$span(bsicons::bs_icon("geo-alt", class = "text-danger me-2"), "4. Catchment Extraction"),
        prettyRadioButtons(ns("outlet_method"), "Pour Point Initialization Mode:",
                           choices = c("Interactive Map Click" = "click", "Manual Numeric Coordinates" = "coords", "Point Vector Shapefile" = "shp"),
                           selected = "click", animation = "smooth", status = "danger"),
        conditionalPanel(
          condition = "input.outlet_method == 'coords'", ns = ns,
          div(class = "row g-2 mb-2",
              div(class = "col-6", numericInput(ns("pour_lat_input"), "Latitude (Y):", value = 0, step = 0.0001)),
              div(class = "col-6", numericInput(ns("pour_lng_input"), "Longitude (X):", value = 0, step = 0.0001)))
        ),
        conditionalPanel(
          condition = "input.outlet_method == 'shp'", ns = ns,
          fileInput(ns("pour_shp"), "Select Outlet Shapefile (.zip Archive):", accept = c(".zip", ".shp"), width = "100%")
        ),
        tooltip(
          trigger = numericInput(ns("snap_radius"), "Outlet Snap Search Radius (m):", value = 500, min = 0, step = 10),
          "Maximum grid cell allocation distance used to anchor a click position to high-accumulation channel trunks.", placement = "right"
        ),
        actionButton(ns("run_delineate"), tags$span(bsicons::bs_icon("bounding-box-circles"), " Delineate Watershed Area"), class = "btn-success w-100 mt-2")
      ),
      
      # 5. Export Results Panel
      accordion_panel(
        value = "panel_download",
        title = tags$span(bsicons::bs_icon("download", class = "text-secondary me-2"), "5. Export Results"),
        downloadButton(ns("download_package"), "Download Comprehensive Results (.zip)", class = "btn-dark w-100 mb-3"),
        div(class = "bg-light rounded p-2 border text-monospace small",
            verbatimTextOutput(ns("catchment_info"), placeholder = TRUE))
      )
    )
  )
}

mod_catchment_server <- function(id, rvs, map_proxy) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # ---- init ----
    shinyjs::useShinyjs()
    shinyFeedback::useShinyFeedback()
    active_dem <- reactiveVal(NULL)
    pour_point_coords <- reactiveVal(NULL)
    
    paths <- reactiveValues(
      dem = NULL, burned = NULL, filled = NULL, flow_dir = NULL, flow_acc = NULL, streams = NULL, watershed = NULL
    )
    
    local_session_dir <- tempfile(pattern = "hydro_session_")
    dir.create(local_session_dir, showWarnings = FALSE)
    
    # ============================================================
    # 1. DEM LOADING
    # ============================================================
    observeEvent(input$dem_upload, {
      req(input$dem_upload)
      
      tryCatch({
        # 1. Read raster
        r_raw <- terra::rast(input$dem_upload$datapath)
        message("Original CRS: ", terra::crs(r_raw))
        
        # 2. Repair CRS using the utility (it handles missing/invalid cases)
        r_repaired <- repair_crs(r_raw)   # no extra parameters needed for rasters
        
        # 3. Safety check: if still no CRS, throw error (should not happen after repair)
        if (is.na(terra::crs(r_repaired)) || terra::crs(r_repaired) == "") {
          stop("CRS could not be repaired. Please check the file.")
        }
        
        # 4. If geographic, project to a local UTM zone for metric operations
        if (terra::is.lonlat(r_repaired)) {
          message("Geographic CRS detected – projecting to local UTM.")
          r_utm <- project_to_local_utm(r_repaired)
        } else {
          message("CRS is already projected – keeping as is.")
          r_utm <- r_repaired
        }
        
        # 5. Save to temporary file and update reactive values
        p_dem <- tempfile(fileext = ".tif")
        terra::writeRaster(r_utm, p_dem, overwrite = TRUE, datatype = "FLT4S")
        paths$dem <- p_dem
        active_dem(r_utm)
        
        showNotification("DEM successfully uploaded and processed.", type = "message")
        
      }, error = function(e) {
        showNotification(paste("DEM upload failed:", e$message), type = "error", duration = 8)
      })
    })
    
    observeEvent(input$aoi_upload, {
      req(input$aoi_upload)
      
      ext <- tools::file_ext(input$aoi_upload$name)
      target_layer <- NULL
      
      tryCatch({
        # 1. Create a clean extraction directory in the session's temp workspace
        aoi_work_dir <- file.path(tempdir(), "aoi_extracted")
        if (dir.exists(aoi_work_dir)) unlink(aoi_work_dir, recursive = TRUE)
        dir.create(aoi_work_dir, showWarnings = FALSE, recursive = TRUE)
        
        # 2. Extract files if the format is a compressed container (.zip or .kmz)
        if (tolower(ext) %in% c("zip", "kmz")) {
          utils::unzip(input$aoi_upload$datapath, exdir = aoi_work_dir)
          
          if (tolower(ext) == "zip") {
            # Look for the .shp file extracted inside the temporary workspace
            shp_file <- list.files(aoi_work_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)[1]
            
            # Fallback check if they zipped a geojson/kml/gpkg inside the zip instead of a shapefile
            if (is.na(shp_file)) {
              shp_file <- list.files(aoi_work_dir, pattern = "\\.(geojson|gpkg|kml)$", full.names = TRUE, recursive = TRUE)[1]
            }
            
            if (is.na(shp_file)) {
              stop("No valid spatial layers (.shp, .geojson, .gpkg, .kml) found inside the ZIP archive.")
            }
            
            # Normalize path slashes for strict GDAL/PROJ compatibility on Windows
            shp_file <- normalizePath(shp_file, winslash = "/", mustWork = TRUE)
            
            v_raw <- terra::vect(shp_file)
            v_repaired <- repair_crs(v_raw)
            target_layer <- sf::st_as_sf(v_repaired)
            
          } else if (tolower(ext) == "kmz") {
            # Look for the unzipped internal .kml file
            kml_file <- list.files(aoi_work_dir, pattern = "\\.kml$", full.names = TRUE, recursive = TRUE)[1]
            
            if (is.na(kml_file)) {
              stop("Invalid KMZ archive: No internal .kml data structure found.")
            }
            
            kml_file <- normalizePath(kml_file, winslash = "/", mustWork = TRUE)
            
            v_raw <- terra::vect(kml_file)
            v_repaired <- repair_crs(v_raw)
            target_layer <- sf::st_as_sf(v_repaired)
          }
          
        } else {
          # Fallback for uncompressed raw flat vector layers (.geojson, .gpkg, .kml)
          raw_path <- normalizePath(input$aoi_upload$datapath, winslash = "/", mustWork = TRUE)
          v_raw <- terra::vect(raw_path)
          v_repaired <- repair_crs(v_raw)
          target_layer <- sf::st_as_sf(v_repaired)
        }
        
        req(target_layer)
        
        # 3. Standardize to Geographic WGS84 coordinates for Leaflet canvas mapping
        aoi_wgs84 <- sf::st_transform(target_layer, crs = 4326)
        rvs$aoi_polygon <- aoi_wgs84
        
        # 4. Render on map using the updated 'uploaded_AOI' group
        map_proxy$proxy() |>
          leaflet::clearGroup("uploaded_AOI") |>
          leaflet::addPolygons(
            data = aoi_wgs84, 
            color = "#ff0000", 
            weight = 3, 
            fillOpacity = 0.1, 
            group = "uploaded_AOI"
          )
        
        # 5. Fit map focus view area to the boundary bounds with safety delay and stripped names
        bbox <- sf::st_bbox(aoi_wgs84)
        later::later(function() {
          map_proxy$proxy() |>
            leaflet::fitBounds(
              lng1 = as.numeric(bbox["xmin"]), lat1 = as.numeric(bbox["ymin"]),
              lng2 = as.numeric(bbox["xmax"]), lat2 = as.numeric(bbox["ymax"])
            )
        }, 0.2)
        
        showNotification("Vector boundary layer successfully processed, verified, and mapped.", type = "message")
        
      }, error = function(e) {
        showNotification(paste("Vector parser error:", e$message), type = "error", duration = 8)
      })
    })
    
    observeEvent(input$fetch_dem, {
      # Validate AOI exists
      if (is.null(rvs$aoi_polygon)) {
        showNotification("Please upload or draw an AOI on the map first.", type = "warning", duration = 5)
        return()
      }
      
      tryCatch({
        withProgress(message = "Downloading and processing DEM...", value = 0, {
          # Step 1: Get bounding box (already in WGS84)
          bbox <- sf::st_bbox(rvs$aoi_polygon)
          incProgress(0.1, detail = "Preparing AOI bounds...")
          
          # Validate bounding box
          if (any(is.na(bbox)) || 
              bbox["xmin"] >= bbox["xmax"] || 
              bbox["ymin"] >= bbox["ymax"]) {
            stop("Invalid AOI bounding box dimensions.")
          }
          
          # Log for debugging
          message(sprintf("Fetching DEM for AOI: [%.4f, %.4f, %.4f, %.4f]",
                          bbox["xmin"], bbox["ymin"], bbox["xmax"], bbox["ymax"]))
          
          # Step 2: Fetch DEM from STAC
          incProgress(0.3, detail = "Querying STAC catalog...")
          r_raw <- download_project_dem(
            list(
              lng1 = bbox["xmin"], lat1 = bbox["ymin"],
              lng2 = bbox["xmax"], lat2 = bbox["ymax"]
            ),
            input$global_collection
          )
          
          # Validate fetch result
          if (is.null(r_raw)) {
            stop("STAC query returned no data. Try expanding your AOI or checking the collection.")
          }
          
          if (!inherits(r_raw, "SpatRaster")) {
            stop("STAC query returned an invalid raster object.")
          }
          
          incProgress(0.6, detail = "Repairing and validating CRS...")
          
          # Step 3: Repair CRS
          r_repaired <- tryCatch({
            repair_crs(r_raw)
          }, error = function(e) {
            message("CRS repair failed: ", e$message)
            r_raw  # return raw and try to proceed
          })
          
          # Step 4: Validate CRS after repair
          if (is.na(terra::crs(r_repaired)) || terra::crs(r_repaired) == "") {
            warning("CRS is still missing after repair. Attempting fallback...")
            # Attempt to assign based on extent
            e <- terra::ext(r_repaired)
            if (e[1] >= -180 && e[2] <= 180 && e[3] >= -90 && e[4] <= 90) {
              terra::crs(r_repaired) <- "EPSG:4326"
              message("Fallback: assigned EPSG:4326")
            } else {
              stop("Cannot determine CRS. The DEM may be corrupted or in an unsupported format.")
            }
          }
          
          
          # Step 5: Save to temporary file
          incProgress(0.9, detail = "Saving processed DEM...")
          p_dem <- tempfile(fileext = ".tif")
          
          # Write with compression for efficiency
          terra::writeRaster(
            r_repaired, 
            p_dem, 
            overwrite = TRUE, 
            datatype = "FLT4S",
            gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "ZLEVEL=6")  # Optimize for storage
          )
          
          # Validate file was created
          if (!file.exists(p_dem) || file.size(p_dem) == 0) {
            stop("Failed to save DEM to temporary file.")
          }
          
          # Step 6: Update reactive values
          paths$dem <- p_dem
          active_dem(r_repaired)
          
          incProgress(1.0, detail = "Done!")
          
          # Show success message with metadata
          showNotification(
            sprintf("DEM successfully fetched and processed. Resolution: %.2f x %.2f units",
                    terra::res(r_repaired)[1], terra::res(r_repaired)[2]),
            type = "message",
            duration = 5
          )
        })
        
      }, error = function(e) {
        # Clean up any partially downloaded files
        if (exists("p_dem") && file.exists(p_dem)) {
          unlink(p_dem)
        }
        
        error_msg <- paste("DEM download failed:", e$message)
        message(error_msg)
        showNotification(error_msg, type = "error", duration = 8)
      })
    })
    
    # #  DEM observer: add raster layer and zoom to DEM extent
    observeEvent(active_dem(), {
      req(active_dem(), paths$dem)
      
      crs_str <- terra::crs(active_dem())
      if (is.na(crs_str) || crs_str == "") return()
      
      tryCatch({
        e <- terra::ext(active_dem())
        mat <- matrix(c(
          e[1], e[3], e[2], e[3], e[2], e[4], e[1], e[4], e[1], e[3]
        ), ncol = 2, byrow = TRUE)
        
        poly_sf <- sf::st_sfc(sf::st_polygon(list(mat)), crs = crs_str)
        poly_wgs84 <- sf::st_transform(poly_sf, 4326)
        bbox <- sf::st_bbox(poly_wgs84)
        
        lng_min <- as.numeric(bbox["xmin"])
        lat_min <- as.numeric(bbox["ymin"])
        lng_max <- as.numeric(bbox["xmax"])
        lat_max <- as.numeric(bbox["ymax"])
        
        p <- map_proxy$proxy()
        add_raster_layer(p, "dem_overlay", paths$dem, grDevices::terrain.colors) 
        later::later(function() {
            leaflet::fitBounds(p, lng1 = lng_min, lat1 = lat_min, lng2 = lng_max, lat2 = lat_max)
        }, 0.3)
      }, error = function(e) {
        showNotification(paste("Auto-zoom failed:", e$message), type = "error")
        message("Auto-zoom tracing failed: ", e$message)
      })
    }) 
    
    # AOI observer: zoom to uploaded polygon extent
    observeEvent(rvs$aoi_polygon, {
      req(rvs$aoi_polygon)
      
      # AOI is already in WGS84 (after transformation in upload observer)
      bbox <- sf::st_bbox(rvs$aoi_polygon)
      p <- map_proxy$proxy()
      
      later::later(function() {
        leaflet::fitBounds(p,
                           lng1 = bbox["xmin"], lat1 = bbox["ymin"],
                           lng2 = bbox["xmax"], lat2 = bbox["ymax"])
      }, 0.3)
    })
    
    # ============================================================
    # 2. RIVER BURNING
    # ============================================================
    # 2A. Upload river network and display on map---------------------------------------
    observeEvent(input$river_shp, {
      req(input$river_shp)
      
      tryCatch({
        upload_unzip_dir <- file.path(tempdir(), "uploaded_rivers_extracted")
        if (dir.exists(upload_unzip_dir)) unlink(upload_unzip_dir, recursive = TRUE)
        dir.create(upload_unzip_dir, showWarnings = FALSE, recursive = TRUE)
        
        unzip(input$river_shp$datapath, exdir = upload_unzip_dir)
        
        shp_file <- list.files(
          upload_unzip_dir,
          pattern = "\\.shp$",
          full.names = TRUE,
          recursive = TRUE
        )[1]
        
        if (is.na(shp_file) || length(shp_file) == 0) {
          stop("No valid .shp file found inside the uploaded zip archive.")
        }
        
        prj_file <- sub("\\.shp$", ".prj", shp_file)
        rivers <- sf::st_read(shp_file, quiet = TRUE, options = "ENCODING=UTF-8")
        
        if (is.na(sf::st_crs(rivers))) {
          message("No CRS found in shapefile.")
          if (file.exists(prj_file)) {
            message("Trying to read CRS from .prj")
            prj_txt <- paste(readLines(prj_file), collapse = "")
            crs_obj <- tryCatch(
              sf::st_crs(prj_txt),
              error = function(e) {
                msg <- paste(
                  "Failed to parse the Coordinate Reference System (CRS) from the .prj file.",
                  "PRJ file: ", basename(prj_file),
                  "Reason: ", e$message,
                  sep = "\n"
                )
                warning(msg, call. = FALSE)
                NULL
              }
            )
            if (!is.null(crs_obj)) {
              rivers <- sf::st_set_crs(rivers, crs_obj)
            }
          }
        }
        
        rvs$river_shp_path <- shp_file
        rivers_wgs84 <- sf::st_transform(rivers, crs = 4326)
        
        map_proxy$proxy() |>
          leaflet::clearGroup("user_rivers") |> 
          leaflet::addPolylines(
            data = rivers_wgs84, 
            color = "#4a90d9", 
            weight = 4.0, 
            opacity = 0.7, 
            group = "user_rivers",
            label = "Uploaded Rivers"
          )
        
        showNotification("River shapefile uploaded and unpacked successfully.", type = "message")
        
      }, error = function(e) {
        showNotification(paste("Shapefile parsing error:", e$message), type = "error")
      })
    })
    
    # 2B. NETWORK STAGING: DOWNLOAD, CROP OR IDENTIFY VECTOR ASSETS--------------
    observeEvent(input$fetch_rivers, {
      req(active_dem(), paths$dem)
      
      if (input$burn_source == "upload") {
        if (is.null(rvs$river_shp_path) || !file.exists(rvs$river_shp_path)) {
          showNotification("Please upload a local file archive first.", type = "warning")
        } else {
          showNotification("Uploaded local shapefile staged successfully for processing.", type = "message")
        }
        return()
      }
      
      # Execute Remote Download Pipeline if 'hydrorivers' selected
      withProgress(message = "Staging Continental HydroRIVERS Array...", value = 0.1, {
        dem_temp <- terra::rast(paths$dem)
        bbox_check <- sf::st_bbox(extent_to_wgs84(dem_temp))
        
        # --- EASING THE LIMIT: Changed from 15 to 30 degrees ---
        # Adjust '15.0' below to an even higher number (e.g. 30.0) if you are running 
        # on a high-memory server. Set to Inf to completely disable the limit.
        max_allowed_span <- 15.0 
        
        span_x <- abs(bbox_check["xmax"] - bbox_check["xmin"])
        span_y <- abs(bbox_check["ymax"] - bbox_check["ymin"])
        
        if (span_x > max_allowed_span || span_y > max_allowed_span) {
          showNotification(
            sprintf(
              "Your active workspace domain (%.2f° x %.2f°) is larger than the allowed %.1f° limit. Please use a smaller AOI or edit 'max_allowed_span' in the code.", 
              span_x, span_y, max_allowed_span
            ), 
            type = "error", 
            duration = 10
          )
          return()
        }
        
        continent <- input$continent
        url <- switch(continent,
                      af = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_af_shp.zip",
                      as = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_as_shp.zip",
                      eu = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_eu_shp.zip",
                      na = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_na_shp.zip",
                      sa = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_sa_shp.zip",
                      au = "https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_au_shp.zip"
        )
        
        cache_dir <- file.path(Sys.getenv("HOME"), "hydrorivers_cache")
        dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
        zip_path <- file.path(cache_dir, paste0("HydroRIVERS_", continent, ".zip"))
        unzip_dir <- file.path(cache_dir, paste0("HydroRIVERS_", continent, "_extracted"))
        
        shp_file <- list.files(unzip_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)[1]
        
        if (is.na(shp_file) || !file.exists(shp_file)) {
          if (!file.exists(zip_path)) {
            incProgress(0.2, detail = "Downloading archive from HydroSHEDS...")
            curl::curl_download(url, zip_path, quiet = FALSE, mode = "wb")
          }
          incProgress(0.3, detail = "Extracting shapefile components...")
          unzip(zip_path, exdir = unzip_dir)
          shp_file <- list.files(unzip_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)[1]
        } else {
          incProgress(0.4, detail = "Found valid cached continental array...")
        }
        
        req(!is.na(shp_file) && file.exists(shp_file))
        
        bbox_wgs84 <- extent_to_wgs84(dem_temp)
        wkt_string <- sf::st_as_text(sf::st_as_sfc(sf::st_bbox(bbox_wgs84)))
        
        incProgress(0.2, detail = "Executing native GDAL spatial filter...")
        rivers_cropped <- sf::st_read(shp_file, wkt_filter = wkt_string, quiet = TRUE)
        
        if (nrow(rivers_cropped) == 0) {
          showNotification("No HydroRIVERS channels found inside your active DEM workspace boundary.", type = "warning")
          return()
        }
        
        rivers_proj <- sf::st_transform(rivers_cropped, crs = terra::crs(dem_temp))
        river_path <- file.path(local_session_dir, "hydrorivers_cropped.shp")
        sf::st_write(rivers_proj, river_path, delete_layer = TRUE, quiet = TRUE)
        
        # Globally stage the cropped path in reactive variables
        rvs$river_shp_path <- river_path
        
        # Render previews immediately on canvas
        major <- rivers_cropped[rivers_cropped$ORD_STRA >= 4, ]
        if (nrow(major) > 0) {
          map_proxy$proxy() |>
            leaflet::clearGroup("HydroRIVERS") |>
            leaflet::addPolylines(data = major, color = "#4a90d9", weight = 4.5, opacity = 0.6, group = "HydroRIVERS")
        }
        showNotification(paste("HydroRIVERS pulled & cached:", nrow(rivers_cropped), "segments localized."), type = "message")
      })
    })

    # 2C. CALCULATION RUNTIME: BURN-IN PROCESSING ENFORCEMENT-------------------------------
    observeEvent(input$burn_rivers, { 
      req(active_dem(), paths$dem)
      
      # Verify that an asset path exists regardless of how it got there
      if (is.null(rvs$river_shp_path) || !file.exists(rvs$river_shp_path)) {
        showNotification("No river shapefile staged in workspace cache. Run 'Load / Fetch River Network' first.", type = "error")
        return()
      }
      
      withProgress(message = "Executing Trench Burn-In Engine...", value = 0.3, {
        p_burned <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        
        # Run WhiteboxTools fill burn execution
        whitebox::wbt_fill_burn(
          dem = paths$dem, 
          streams = rvs$river_shp_path, 
          output = p_burned
        )
        
        paths$burned <- p_burned
        
        # Re-add map rendering layers
        add_raster_layer(map_proxy$proxy(), "burn_dem", paths$burned, grDevices::terrain.colors)
        showNotification("Hydro-Enforcement terrain carving complete.", type = "message")
      })
    })
    
    # ============================================================
    # 3. ROUTING & ACCUMULATION
    # ============================================================
    observeEvent(input$run_hydro, { 
      working_dem <- if (!is.null(paths$burned)) paths$burned else paths$dem
      req(working_dem)
      
      withProgress(message = "Executing Grid Pipeline...", value = 0.1, {
        incProgress(0.2, detail = "Correcting depressions...")
        p_filled <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        
        if (input$sink_method == "wang_liu") {
          whitebox::wbt_fill_depressions_wang_and_liu(dem = working_dem, output = p_filled)
        } else if (input$sink_method == "breach") {
          whitebox::wbt_breach_depressions(dem = working_dem, output = p_filled, max_depth = input$breach_dist)
        } else {
          p_breached <- tempfile(tmpdir = tempdir(), fileext = ".tif")
          whitebox::wbt_breach_depressions(dem = working_dem, output = p_breached, max_depth = input$breach_dist)
          whitebox::wbt_fill_depressions_wang_and_liu(dem = p_breached, output = p_filled)
        }
        paths$filled <- p_filled
        add_raster_layer(map_proxy$proxy(), "filled_dem", paths$filled, grDevices::terrain.colors)
        
        incProgress(0.3, detail = "Calculating pointer matrices...")
        p_fdir <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        
        if (input$flow_dir_method == "d8") {
          whitebox::wbt_d8_pointer(dem = paths$filled, output = p_fdir)
        } else {
          whitebox::wbt_fd8_pointer(dem = paths$filled, output = p_fdir)
        }
        paths$flow_dir <- p_fdir
        
        add_raster_layer(
          map_proxy$proxy(), 
          layer_id = "flow_dir", 
          file_path = paths$flow_dir, 
          palette_input = grDevices::hcl.colors(8, "Viridis"), 
          opacity = 0.65
        )
        
        incProgress(0.2, detail = "Accumulating flow areas...")
        p_facc <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        if (input$flow_acc_method == "d8") {
          whitebox::wbt_d8_flow_accumulation(input = paths$filled, output = p_facc, out_type = "cells")
        } else {
          whitebox::wbt_fd8_flow_accumulation(dem = paths$filled, output = p_facc, out_type = "cells")
        }
        paths$flow_acc <- p_facc
        add_raster_layer(map_proxy$proxy(), "flow_acc", paths$flow_acc, function(n) grDevices::hcl.colors(n, "Plasma"))
        
        incProgress(0.2, detail = "Extracting stream vectors...")
        p_str <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        whitebox::wbt_extract_streams(flow_accum = paths$flow_acc, output = p_str, threshold = input$stream_thresh)
        paths$streams <- p_str
        add_raster_layer(map_proxy$proxy(), "river_network", 
                         paths$streams, c("transparent", "#1a75ff"), opacity = 0.9)
        
        showNotification("Hydrological routing pipeline completed.", type = "message")
      })
    })
    
    # ============================================================
    # 4. CATCHMENT EXTRACTION
    # ============================================================
    observeEvent(rvs$map_click, {
      req(paths$streams)
      if (input$outlet_method != "click") return()
      click <- rvs$map_click
      pour_point_coords(c(click$lng, click$lat))
      
      map_proxy$proxy() |>
        leaflet::clearGroup("pour_point") |>
        leaflet::addMarkers(lng = click$lng, lat = click$lat, group = "pour_point", label = "Target Pour Point Outlet")
    })
    
    observeEvent(input$run_delineate, { 
      req(paths$flow_dir, paths$flow_acc)
      
      withProgress(message = "Extracting Basin Boundary...", value = 0.2, {
        if (input$outlet_method == "coords") {
          pt_df <- data.frame(lon = input$pour_lng_input, lat = input$pour_lat_input)
          pt_sf <- sf::st_as_sf(pt_df, coords = c("lon", "lat"), crs = 4326)
        } else if (input$outlet_method == "click") {
          req(pour_point_coords())
          pt_df <- data.frame(lon = pour_point_coords()[1], lat = pour_point_coords()[2])
          pt_sf <- sf::st_as_sf(pt_df, coords = c("lon", "lat"), crs = 4326)
        } else {
          req(input$pour_shp)
          pt_sf <- sf::st_read(input$pour_shp$datapath, quiet = TRUE) |> sf::st_transform(4326)
        }
        
        pt_projected <- sf::st_transform(pt_sf, terra::crs(active_dem()))
        p_pt_shp <- file.path(local_session_dir, "original_pour_point.shp")
        sf::write_sf(pt_projected, p_pt_shp, delete_layer = TRUE, quiet = TRUE)
        
        incProgress(0.3, detail = "Snapping outlet points...")
        p_snapped <- file.path(local_session_dir, "snapped_pour_point.shp")
        whitebox::wbt_snap_pour_points(
          pour_pts = p_pt_shp, flow_accum = paths$flow_acc, output = p_snapped, snap_dist = input$snap_radius
        )
        
        incProgress(0.4, detail = "Delineating catchment boundaries...")
        p_watershed <- tempfile(tmpdir = tempdir(), fileext = ".tif")
        whitebox::wbt_watershed(d8_pntr = paths$flow_dir, pour_pts = p_snapped, output = p_watershed)
        paths$watershed <- p_watershed
        
        w_rast <- terra::rast(paths$watershed)
        w_poly <- terra::as.polygons(w_rast, round = TRUE)
        w_sf <- sf::st_as_sf(w_poly) |> sf::st_transform(4326)
        
        map_proxy$proxy() |>
          leaflet::clearGroup("watershed") |>
          leaflet::addPolygons(
            data = w_sf, group = "watershed", color = "#ff007f", weight = 3, fillOpacity = 0.25, fillColor = "#ff007f"
          )
        
        showNotification("Catchment boundaries mapped successfully.", type = "message")
      })
    })
    
    # ============================================================
    # 5. DOWNLOAD AND STATUS SUMMARY LOGGER
    # ============================================================
    output$download_package <- downloadHandler(
      filename = function() {
        paste0("hydro_catchment_export_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".zip")
      },
      content = function(file) {
        shiny::withProgress(message = "Assembling hydro-processing export bundle...", value = 0.0, {
          
          tmp_zip_dir <- tempfile(pattern = "export_bundle_")
          dir.create(tmp_zip_dir, showWarnings = FALSE, recursive = TRUE)
          on.exit(unlink(tmp_zip_dir, recursive = TRUE, force = TRUE), add = TRUE)
          
          shiny::incProgress(0.2, detail = "Staging processed grid rasters...")
          raster_targets <- list(
            "dem_input.tif"          = paths$dem,
            "dem_burned.tif"         = paths$burned,
            "dem_filled.tif"         = paths$filled,
            "flow_direction.tif"     = paths$flow_dir,
            "flow_accumulation.tif"  = paths$flow_acc,
            "extracted_streams.tif"  = paths$streams,
            "delineated_basin.tif"   = paths$watershed
          )
          
          for (target_name in names(raster_targets)) {
            source_raster <- raster_targets[[target_name]]
            if (!is.null(source_raster) && file.exists(source_raster)) {
              file.copy(source_raster, file.path(tmp_zip_dir, target_name), overwrite = TRUE)
            }
          }
          
          shiny::incProgress(0.2, detail = "Staging AOI boundaries...")
          if (!is.null(rvs$aoi_polygon)) {
            tryCatch({
              aoi_sf <- rvs$aoi_polygon
              if (!inherits(aoi_sf, "sf")) {
                aoi_sf <- sf::st_as_sf(aoi_sf)
              }
              sf::st_write(aoi_sf, file.path(tmp_zip_dir, "drawn_aoi.shp"), delete_layer = TRUE, quiet = TRUE)
            }, error = function(e) {
              message("Drawn AOI Shapefile export compilation failed: ", e$message)
            })
          }
          
          shiny::incProgress(0.1, detail = "Staging pour point configurations...")
          if (!is.null(local_session_dir) && dir.exists(local_session_dir)) {
            pour_point_assets <- list.files(local_session_dir, pattern = "pour_point", full.names = TRUE)
            if (length(pour_point_assets) > 0) {
              file.copy(pour_point_assets, tmp_zip_dir, overwrite = TRUE)
            }
          }
          
          shiny::incProgress(0.1, detail = "Staging cropped HydroRIVERS layers...")
          if (!is.null(rvs$river_shp_path) && file.exists(rvs$river_shp_path)) {
            river_dir <- dirname(rvs$river_shp_path)
            river_prefix <- tools::file_path_sans_ext(basename(rvs$river_shp_path))
            
            river_sidecars <- list.files(river_dir, pattern = paste0("^", river_prefix), full.names = TRUE)
            file.copy(river_sidecars, tmp_zip_dir, overwrite = TRUE)
          }
          
          shiny::incProgress(0.3, detail = "Converting stream raster to polyline vector...")
          if (!is.null(paths$streams) && file.exists(paths$streams)) {
            stream_shp_out <- file.path(tmp_zip_dir, "extracted_streams_lines.shp")
            
            whitebox::wbt_raster_to_vector_lines(
              input = paths$streams,
              output = stream_shp_out
            )
            
            if (file.exists(stream_shp_out) && !is.null(paths$dem)) {
              tryCatch({
                dem_crs_wkt <- sf::st_crs(terra::rast(paths$dem))$wkt
                if (!is.null(dem_crs_wkt) && dem_crs_wkt != "") {
                  writeLines(dem_crs_wkt, file.path(tmp_zip_dir, "extracted_streams_lines.prj"))
                }
              }, error = function(e) NULL)
            }
          }
          
          files_to_bundle <- list.files(tmp_zip_dir, full.names = FALSE)
          if (length(files_to_bundle) == 0) {
            showNotification("No spatial execution vectors or rasters found to download.", type = "warning")
            return(NULL)
          }
          
          old_wd <- getwd()
          on.exit(setwd(old_wd), add = TRUE)
          setwd(tmp_zip_dir)
          
          shiny::incProgress(0.1, detail = "Compressing bundle package...")
          utils::zip(zipfile = file, files = files_to_bundle, flags = "-j")
        })
      }
    )
    
    output$catchment_info <- renderText({
      log_lines <- c("[Session Task Matrix Status]")
      log_lines <- c(log_lines, paste("1. Base DEM Matrix:    ", if(!is.null(paths$dem)) "READY" else "EMPTY"))
      log_lines <- c(log_lines, paste("2. Burn Enforced Layer:", if(!is.null(paths$burned)) "READY" else "SKIPPED/EMPTY"))
      log_lines <- c(log_lines, paste("3. Depression Fix Set: ", if(!is.null(paths$filled)) "READY" else "EMPTY"))
      log_lines <- c(log_lines, paste("4. Flow Directions:    ", if(!is.null(paths$flow_dir)) "READY" else "EMPTY"))
      log_lines <- c(log_lines, paste("5. Flow Accumulation:  ", if(!is.null(paths$flow_acc)) "READY" else "EMPTY"))
      log_lines <- c(log_lines, paste("6. Derived Streams:    ", if(!is.null(paths$streams)) "READY" else "EMPTY"))
      log_lines <- c(log_lines, paste("7. Delineated Basin:   ", if(!is.null(paths$watershed)) "READY" else "EMPTY"))
      
      if (!is.null(paths$dem)) {
        tryCatch({
          r <- terra::rast(paths$dem)
          log_lines <- c(log_lines, "", "[Active Workspace Raster Specs]",
                         paste("Resolution: ", paste(round(terra::res(r), 4), collapse = " x ")),
                         paste("Grid Extent:", paste(dim(r)[1:2], collapse = " rows x "), "columns"))
        }, error = function(e) NULL)
      }
      paste(log_lines, collapse = "\n")
    })
    
    # Persistent Garbage Collection
    onSessionEnded(function() {
      session_files <- isolate(c(
        paths$dem, paths$burned, paths$filled, paths$flow_dir, paths$flow_acc, paths$streams, paths$watershed
      ))
      for (file_item in session_files) {
        if (!is.null(file_item) && file.exists(file_item)) unlink(file_item, force = TRUE)
      }
      if (dir.exists(local_session_dir)) unlink(local_session_dir, recursive = TRUE, force = TRUE)
    })
  })
}