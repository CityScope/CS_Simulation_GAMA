model citIOGAMA

global {

	string city_io_table<-'dungeonmaster';
	file geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
	file geogrid_data <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRIDDATA");	
	geometry shape <- envelope(geogrid);
	init {
		create block from:geogrid with:[type::read("land_use")];
		do udpateGrid;
	}
	action udpateGrid {
		loop b over: geogrid_data {
			loop l over: list(b) {
				map m <- map(l);
				ask block(int(m["id"])) {
					self.color <- m["color"];
				}
			}
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
		display map_mode type:opengl background:#black draw_env:false{	

			species block aspect:base;

		}
	}
}
