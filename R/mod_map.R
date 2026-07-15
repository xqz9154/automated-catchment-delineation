# R/mod_map.R

mod_map_ui <- function(id) {
  ns <- NS(id)
  leaflet::leafletOutput(ns("map"), height = "100%")
}

mod_map_server <- function(id, rvs) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Render primary interactive leaflet canvas base maps
    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet(options = leaflet::leafletOptions(zoomControl = TRUE)) |>
        leaflet::addTiles(group = "OpenStreetMap") |>
        leaflet::addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
        leaflet::addProviderTiles("CartoDB.Positron", group = "Light") |>
        leaflet::setView(lng = 0.0, lat = 0.0, zoom = 3) |>
        leaflet.extras::addDrawToolbar(
          targetGroup = "draw",
          polylineOptions = FALSE,
          circleOptions = FALSE,
          circleMarkerOptions = FALSE,
          rectangleOptions = leaflet.extras::drawRectangleOptions(
            shapeOptions = leaflet.extras::drawShapeOptions(
              color = "#ff0000",
              weight = 3
            ),
            repeatMode = FALSE
          ),
          polygonOptions = leaflet.extras::drawPolygonOptions(
            shapeOptions = leaflet.extras::drawShapeOptions(
              color = "#ff0000",
              weight = 3
            ),
            repeatMode = FALSE
          ),
          markerOptions = FALSE,
          editOptions = leaflet.extras::editToolbarOptions(
            edit = FALSE,
            remove = TRUE
          )
        ) |>
        leaflet::addLayersControl(
          baseGroups = c("OpenStreetMap", "Satellite", "Light"),
          overlayGroups = c("dem_overlay", "filled_dem", "flow_dir",
                            "flow_acc", "catchment", "river_network", "uploaded_AOI",
                            "user_rivers","HydroRIVERS"),
          options = leaflet::layersControlOptions(collapsed = FALSE)
        )
    })
    
    # Capture map clicks for dynamic pour point initialization
    observeEvent(input$map_click, {
      rvs$map_click <- input$map_click
    })
    
    # Listen to map drawing events for geographic bounds tracking
    observeEvent(input$map_draw_new_feature, {
      feature <- input$map_draw_new_feature
      
      if (feature$properties$feature_type %in% c("polygon", "rectangle")) {
        coords <- feature$geometry$coordinates[[1]]
        polygon <- sf::st_polygon(list(matrix(
          unlist(coords), 
          ncol = 2, 
          byrow = TRUE
        )))
        
        polygon_sf <- sf::st_sfc(polygon, crs = 4326)
        rvs$aoi_polygon <- polygon_sf
        
        showNotification(
          "AOI polygon drawn successfully!",
          type = "message",
          duration = 3
        )
      }
    })
    
    # Listen to geometry update/editing events
    observeEvent(input$map_draw_edited_features, {
      features <- input$map_draw_edited_features
      
      if (length(features$features) > 0) {
        feature <- features$features[[1]]
        
        if (feature$properties$feature_type %in% c("polygon", "rectangle")) {
          coords <- feature$geometry$coordinates[[1]]
          polygon <- sf::st_polygon(list(matrix(
            unlist(coords), 
            ncol = 2, 
            byrow = TRUE
          )))
          polygon_sf <- sf::st_sfc(polygon, crs = 4326)
          rvs$aoi_polygon <- polygon_sf
          
          showNotification("AOI polygon updated!", type = "message", duration = 3)
        }
      }
    })
    
    # Listen to geometry deletion/removal events
    observeEvent(input$map_draw_deleted_features, {
      rvs$aoi_polygon <- NULL
      showNotification("AOI polygon removed.", type = "warning", duration = 3)
    })
    
    # Return map proxy object container for downstream cross-module actions
    # FIXED: Explicitly bind the map module's session environment context 
    # to the proxy function, locking actions to the "map-map" target canvas.
    return(list(
      proxy = function() leaflet::leafletProxy("map", session = session)
    ))
  })
}