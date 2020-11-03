model citIOGAMA

global {

	string city_io_table<-'dungeonmaster';
	file geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
	string grid_hash_id;
	int update_frequency<-10;
	bool forceUpdate<-true;
	
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
	
	action sendIndicator(string type, string _name, float value){
		string myIndicator;
		myIndicator<-"[{\"indicator_type\":\"" + type+"\",\"name\":\""+_name+"\",\"value\":"+value+",\"viz_type\":\"bar\"}]";
		save myIndicator to: "indicator.json" rewrite: true;
		file JsonFileResults <- json_file("./indicator.json");
        map<string, unknown> c <- JsonFileResults.contents;
        try{			
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c));		
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now +" Indicator (type="+ type + " name= " +_name +" value= " + value+") sucessfully sent to cityIO " + cycle;	  	
	}
	//HeatMap
	//https://cityio.media.mit.edu/api/table/corktown/access
	
	
	reflex update when: (cycle mod update_frequency = 0) {
		string new_grid_hash_id <- get_grid_hash();
		if ((new_grid_hash_id != grid_hash_id) or forceUpdate)  {
			grid_hash_id <- new_grid_hash_id; 
			do udpateGrid;
			do sendIndicator("numeric","Average Height",mean(block collect each.height));
			//do sendIndicator("bar");
		}
	}
}

species block{
	string type;
	float height update:rnd(100.0);
	rgb color;
	aspect base {
		  draw shape color:color border:color-50 depth:height;	
	}
}

experiment CityScope type: gui autorun:false{
	output {
		display map_mode type:opengl background:#black{	

			species block aspect:base;

		}
	}
}
