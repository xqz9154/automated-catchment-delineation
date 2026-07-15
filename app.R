# app.R
# Set maximum upload allocation footprint to 500 MB for large DEM inputs
options(shiny.maxRequestSize = 500 * 1024^2)

# Source core runtime configurations and spatial modules
source("global.R")
source("R/catchment_utils.R")
source("R/mod_catchment.R") 
source("R/mod_map.R")

# ---- User Interface ----
ui <- page_sidebar(
  title = "Automated Catchment Delineation Engine",
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    width = 380,
    title = tags$span(bsicons::bs_icon("sliders"), " Delineation Pipeline"),
    # Focus exclusively on the functional catchment orchestration module
    mod_catchment_ui("catchment")
  ),
  # Primary geographic map layout viewport
  card(
    mod_map_ui("map"),
    full_screen = TRUE,
    height = "100%"
  )
)

# ---- Server Logic ----
server <- function(input, output, session) {
  
  # Initialize shared global reactive container matching module expectations
  rvs <- reactiveValues(
    aoi_polygon       = NULL,  # Map bounding coordinates for STAC queries
    map_click         = NULL,  # Target coordinate registration for pour points
    river_shp_path    = NULL,  # Cached disk path for hydro-enforcement vector layers
    dem               = NULL,
    dem_loaded        = FALSE,
    rivers            = NULL,
    filled_dem        = NULL,
    flow_direction    = NULL,
    flow_accumulation = NULL,
    streams           = NULL
  )
  
  # Instantiate interactive Leaflet map interface wrapper
  map_proxy <- mod_map_server("map", rvs)
  
  # Execute WhiteboxTools processing server engine
  mod_catchment_server("catchment", rvs, map_proxy)
}

# Run the Shiny Application
shinyApp(ui, server, options = list(launch.browser = TRUE))