# Automated Catchment Delineation Engine

An advanced, cloud-native R Shiny application for high-performance hydrological analysis and catchment boundary delineation. The application utilizes the Microsoft Planetary Computer STAC API to stream digital elevation models (DEMs) directly into a local multi-threaded GDAL warp-and-crop engine, reprojecting the coordinate reference systems on-the-fly to a metric UTM projection.

Once localized to a metric system, the engine routes the DEM through a comprehensive, step-by-step WhiteboxTools processing pipeline—executing stream network burning, depression filling, flow pointer direction, flow accumulation calculations, and snapped pour point watershed extraction.

---

## 🗺️ Pipeline Architecture

The application is engineered on a decoupled modular framework, separating the UI visual layers from the heavy geospatial computation. Below is the complete logical workflow executed by the backend engine:

```
                  +-----------------------------------+
                  |      1. User Draws AOI on Map      |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |    2. STAC API Spatial Query      |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |  3. Multi-threaded GDAL Warp/VRT  |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |  4. On-the-fly Local UTM Project  |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |      5. Hydro-Enforcement         |
                  |         (wbt_fill_burn)           |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |     6. Fill Sinks & Depressions   |
                  |    (wbt_breach_depressions/       |
                  | wbt_fill_depressions_wang_and_liu)|
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |    7. Flow Direction (Pointer)    |
                  |  (wbt_d8_pointer/wbt_fd8_pointer) |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |     8. Flow Accumulation (FAC)    |
                  |  (wbt_d8_flow_acc/wbt_fd8_flow_acc)
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |  9. Snap Pour Point Coordinates   |
                  |       (wbt_snap_pour_points)      |
                  +-----------------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |    10. Watershed Delineation      |
                  |          (wbt_watershed)          |
                  +-----------------------------------+

```

### 1. Spatial Targeting (Draw or Upload Polygon)

* **User Drawing**: Users can manually define an Area of Interest (AOI) polygon directly on the Leaflet canvas.
* **Vector Polygon Upload**: Alternatively, users can upload their own pre-defined spatial boundary vector files (e.g., GeoJSON, Esri Shapefiles, or KML). The engine automatically validates the file, repairs any missing or non-standard Coordinate Reference Systems (CRS) to WGS84, extracts the bounding limits, and centers the interactive map on the uploaded polygon features.
* **STAC Querying**: The backend queries the Microsoft Planetary Computer (using Copernicus GLO-30/90, NASADEM, or ALOS), builds a virtual raster mosaic (`.vrt`), and streams the clipped bounds via multi-threaded GDAL `/vsicurl/` reads.
* **Centroid Projection**: The geographic raster is projected to its localized metric UTM zone. This guarantees square metric grid cells (e.g. $30\text{m} \times 30\text{m}$), which is mathematically required for accurate surface flow routing.

### 2. Stream Burning (Hydro-Enforcement)

* **The Tool**: `wbt_fill_burn()`
* **The Process**: To ensure flow continues through digital blockages (like bridges, roads, or localized DEM anomalies), stream vector networks (fetched from OpenStreetMap or uploaded locally) are rasterized and "burned" into the DEM. This utility trench-carves the elevation profile along known stream channels to enforce downstream flow accumulation.

### 3. Sink/Depression Resolution

* **The Tool**: `wbt_fill_depressions()`
* **The Process**: To prevent artificial "dead ends" where flow gets trapped, a robust depression-filling pass is run. This ensures that every grid cell in the DEM has a continuous downhill path to the edge of the raster or an output outlet.

### 4. Flow Direction (Pointer) Calculations

* **The Tools**: `wbt_d8_pointer()` or `wbt_fd8_pointer()`
* **The Process**: The engine computes the direction of water flow from each cell to its downslope neighbors.
* **D8 Pointer**: Generates a classic single-flow direction raster where water drains to the single steepest neighboring cell out of eight directions.
* **FD8 Pointer**: Generates a multi-flow direction pointer, enabling dispersive flow routing over complex topography.



### 5. Flow Accumulation (FAC) Calculations

* **The Tools**: `wbt_d8_flow_accumulation()` or `wbt_fd8_flow_accumulation()`
* **The Process**: Using the flow pointer grid, the engine calculates the upslope contributing area for every single cell. Cells with extremely high values represent natural stream channels, which are rendered as a high-contrast drainage network overlay on the interactive map.

### 6. Pour Point Snapping

* **The Tool**: `wbt_snap_pour_points()`
* **The Process**: Because manual user map clicks rarely land exactly on the center of a $30\text{m}$ flow channel, the coordinate is processed using this snap utility. The engine searches a configurable search radius (e.g., $15$ cells) and snaps the user's coordinate directly onto the cell of maximum flow accumulation, eliminating zero-contributing basin errors.

### 7. Watershed Delineation

* **The Tool**: `wbt_watershed()`
* **The Process**: By combining the snapped pour point and the flow pointer raster, this utility performs a recursive upstream trace. It isolates every single pixel on the DEM that hydrologically drains to that specific point, polygonizes the boundary, and exports the final catchment file.

---

## ⚡ Core Features

* **Flexible Bounds Targeting**: Draw an AOI polygon directly on the map or upload your own spatial boundary files (GeoJSON, Shapefile, or KML) to automate DEM streaming.
* **Zero Local Data Footprint**: Stream planetary-scale elevation data (Copernicus DEM, NASADEM, ALOS AW3D30) instantly without pre-downloading gigabytes of files.
* **Deterministic Whitebox Backend**: Native execution of optimized C++ compiled geospatial libraries directly through R's `whitebox` interface.
* **Intelligent Pour Point Snapping**: Built-in algorithm to automatically correct map coordinate click deviations, preventing broken/zero-acre catchments.
* **Dynamic Visualizations**: Step-by-step map overlays including hillshades, burned DEMs, calculated flow pathways, and final vector catchments using Leaflet.js.
* **Session Isolation**: Multi-user protection via isolated session directories to entirely prevent concurrent workspace overwrites.

---

## 📂 Repository Structure

```tree
├── app.R                  # Main UI & Server entrypoint containing global reactives
├── global.R               # High-concurrency GDAL, package, and environment configurations
├── R/
│   ├── catchment_utils.R  # Production spatial pipelines (STAC streams, UTM warp, CRS repair)
│   ├── mod_catchment.R    # Catchment processing module (Burn-in, FDR, FAC, watershed routing)
│   └── mod_map.R          # Leaflet drawing, editing, and spatial mapping interface
├── tests/
│   └── testthat/
│       ├── test-catchment_utils.R  # Unit tests verifying CRS healing transformations
│       └── test-mod_catchment.R    # Integration server-tests mocking file uploads
└── .github/
    └── workflows/
        └── shiny-tests.yaml        # Automated GitHub Actions test execution workflow

```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have R (>= 4.2.0) installed alongside system libraries for spatial data handling (`GDAL`, `PROJ`, and `GEOS`):

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y libgdal-dev libproj-dev libgeos-dev libudunits2-dev

# macOS (Homebrew)
brew install gdal proj geos udunits

```

### Installation

1. **Clone the Repository:**
```bash
git clone https://github.com/YOUR-USERNAME/automated-catchment-delineation.git
cd automated-catchment-delineation

```


2. **Install R Dependencies:**
Run the following commands inside your R console to install the required libraries:
```R
install.packages(c(
  "shiny", "shinyjs", "shinyWidgets", "shinyFeedback", "bslib", "bsicons",
  "leaflet", "leaflet.extras", "leafem", "stars", "terra", "sf", 
  "whitebox", "osmdata", "ncdf4", "rstac", "tools", "curl", "jsonlite", "testthat"
))

```


3. **Initialize WhiteboxTools Binaries:**
The app uses the high-performance C++ `whitebox` backend. Initialize the native command-line interface tools:
```R
whitebox::wbt_init()

```



### Running the Application

To run the Shiny app locally:

```R
shiny::runApp()

```

---

## 🧪 Testing Suite

Tests are structured using the `testthat` and Shiny native `testServer` frameworks.

To run the complete automated test suite locally:

```R
testthat::test_local()

```

The test suite checks:

* **CRS Reprojections**: Ensures that missing CRSs are repaired and converted into valid projected metric formats (`test-catchment_utils.R`).
* **Reactive Logic Execution**: Simulated mock file uploads ensure the reactive modules correctly extract, validate, and store AOI spatial polygons (`test-mod_catchment.R`).

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.