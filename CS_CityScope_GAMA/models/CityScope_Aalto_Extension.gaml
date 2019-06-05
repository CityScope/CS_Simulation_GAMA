/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/

model CityScope_ABM_Aalto

import "CityScope_main.gaml"


global{
	
	string cityGISFolder <- "./../includes/City/otaniemi";	
	// Variables used to initialize the table's grid.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24.0;
	
   //	Sliders that dont exisit in Aalto table
	int	toggle1 <- 2;
	int	slider1 <-2;
	// TODO: Hard-coding density because the Aalto table doesnt have it.
	list<float> density_array<-[1.0,1.0,1.0,1.0,1.0,1.0];
	
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
			write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_Aalto.json";
		}
		
		do createAmenityv2;
		
		ask amenity {
			if ((x = 0 and y = 0) and fromGrid = true) {
				do die;
			}

		}
	}	
}

