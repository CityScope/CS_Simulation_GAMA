model citIOGAMA

global {

	string city_io_table<-'dungeonmaster';
	file geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
	string grid_hash_id;
	
	geometry shape <- envelope(geogrid);
	init {
		create block from:geogrid with:[type::read("land_use")];
		do udpateGrid;
	}
	
	string get_grid_hash {
		file grid_hashes <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/meta/hashes");
		string grid_hash <- first(grid_hashes at "GEOGRIDDATA");
		return grid_hash;
	}
	
	action udpateGrid {
	    write "Performing local grid update";
		file geogrid_data <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRIDDATA");
		loop b over: geogrid_data {
			loop l over: list(b) {
				map m <- map(l);
				ask block(int(m["id"])) {
					self.color <- m["color"];
				}
			}
		}
	}
	
	
	string computeIndicator (string viz_type){
		string indicator <- "{name: Gama Indicator,value:" + length(block)+",viz_type:"+viz_type+"}";
		return indicator;
	}
	
	action sendIndicator(string indicator){
		// What is the URL to POST here knowing that we have the string ready
	}
	
	
	reflex update{
		string new_grid_hash_id <- get_grid_hash();
		if new_grid_hash_id != grid_hash_id {
			grid_hash_id <- new_grid_hash_id; 
			do udpateGrid;
			do sendIndicator(computeIndicator("bar"));
		}
	}
}

species block{
	string type;
	rgb color;
	aspect base {
		  draw shape color:color border:#black;	
	}
}

experiment CityScope type: gui autorun:false{
	output {
		display map_mode type:opengl background:#black{	

			species block aspect:base;

		}
	}
}
