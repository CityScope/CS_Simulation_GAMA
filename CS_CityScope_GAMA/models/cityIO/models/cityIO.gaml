model citIOGAMA

global {

	string city_io_table<-'dungeonmaster';
	file meta_grid_file <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");	
	geometry shape <- envelope(meta_grid_file);
	init {
		create block from:meta_grid_file with:[land_use::read("land_use"), interactive::bool(read("interactive"))]{
		}
	}
}

species block{
	string land_use;
	bool interactive;
	aspect base {
		  draw shape color: #white border:#black;	
	}
}

experiment Dev type: gui autorun:false{
	output {
		display map_mode type:opengl background:#black draw_env:false{	

			species block aspect:base;

		}
	}
}
