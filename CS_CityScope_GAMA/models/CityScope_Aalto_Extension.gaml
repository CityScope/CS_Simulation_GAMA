/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/



model CityScope_ABM_Aalto


import "CityScope_main.gaml"

/* Insert your model definition here */

global{
	
	string cityGISFolder <- "./../includes/City/otaniemi";
	// GIS FILES
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp");
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp");
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp");
	file amenities_shapefile <- file(cityGISFolder + "/Amenities.shp");
	file table_bound_shapefile <- file(cityGISFolder + "/table_bounds.shp");
	file imageRaster <- file('./../images/gama_black.png');
	geometry shape <- envelope(bound_shapefile);
	
	
	// Variables used to initialize the table's grid.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24;
	
//	Sliders that dont exisit in Aalto table
	int	toggle1 <- 2;
	int	slider1 <-2;
	list<float> density_array<-[];

	
	// TODO: mapping needs to be fixed for Aalto inputs
	map<int, list> citymatrix_map_settings <- [-1::["Green", "Green"], 0::["R", "L"], 1::["R", "M"], 2::["R", "S"], 3::["O", "L"], 4::["O", "M"], 5::["O", "S"], 6::["A", "Road"], 7::["A", "Plaza"], 
		8::["Pa", "Park"], 9::["P", "Parking"], 20::["Green", "Green"], 21::["Green", "Green"]
	];
	
//	city_io
	string CITY_IO_URL <- "https://cityio.media.mit.edu/api/table/cs_aalto_2";
	// Offline backup data to use when server data unavailable.
	string BACKUP_DATA <- "../includes/City/otaniemi/cityIO_Aalto.json";
	
	
	
	action initGrid {
	/* 
		 * initGrid queries the cityIO server for data from the table,
		 * and sets up the model accordingly.
		 * If online data is not available, it uses preset data.
		 */
		ask amenity where (each.fromGrid = true) {
			do die;
		}

		try {
			cityMatrixData <- json_file(CITY_IO_URL).contents;
		}

		catch {
			cityMatrixData <- json_file(BACKUP_DATA).contents;
			write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_Kendall.json";
		}

		list<int> gridCells <- cityMatrixData["grid"];

		int nrows<-cityMatrixData['header']['spatial']['nrows'];
		int ncols<-cityMatrixData['header']['spatial']['ncols'];
		brickSize<- cityMatrixData['header']['spatial']['cellsize'];
//		TODO: hard coding density because Aalto has no density slider
		loop i from: 0 to: ncols-1 {
			loop j from: 0 to: nrows -1{
				create amenity {					
					id <- int(gridCells[j*ncols+i]);
					write ('creating amenity with id :'+id);
					x<-center.x + i * brickSize;
					y<-center.y + j * brickSize;
					location <- {x,y};
					location <- {(location.x * cos(angle) + location.y * sin(angle)), -location.x * sin(angle) + location.y * cos(angle)};
					shape <- square(brickSize * 0.9) at_location location;
					size <- 10 + rnd(10);
					fromGrid <- true;
					scale <- citymatrix_map_settings[id][1];
					usage <- citymatrix_map_settings[id][0];
					color <- color_map[scale];
					if (id != -1 and id != -2 and id != 7 and id != 6) {
						// TODO: Hard-coding densty because the Aalto table doesnt have it.
						density <- 2;
					}
				}
			}			
		}

		ask amenity {
			if ((x = 0 and y = 0) and fromGrid = true) {
				do die;
			}

		}
	}
	
}

