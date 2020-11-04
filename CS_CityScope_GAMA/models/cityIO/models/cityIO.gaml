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
		
		create cityio_indicator with: (indicator_name: "hello", indicator_type: "numeric");
		create cityio_indicator with: (indicator_name: "world", indicator_type: "numeric");
		create mean_height_indicator with: (indicator_name: "mean_height", indicator_type: "numeric");
		do sendIndicators;
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
	

	//HeatMap
	//https://cityio.media.mit.edu/api/table/corktown/access
	
	action sendIndicators {
		list<cityio_indicator> numeric_indicators <- (cityio_indicator where (each.indicator_type="numeric")); // This should also select indicator agents that are subspecies of the cityio_indicator species

		string update_package<-"[";
		ask numeric_indicators {
			write "Updating: "+indicator_name;
			string myIndicator;
			myIndicator<-"{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+indicator_name+"\",\"value\":"+return_indicator()+",\""+viz_type+"\":\"bar\"}";
			if length(update_package)=1 {
				update_package <- update_package+myIndicator;				
			}else{
				update_package <- update_package+","+myIndicator;
			}
		}
		update_package <- update_package+"]";
		write update_package;
		save update_package to: "indicator.json" rewrite: true;
		file JsonFileResults <- json_file("./indicator.json");
	    map<string, unknown> c <- JsonFileResults.contents;
		try{			
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c)); // This still updates a dictionary with 'contents' as a key
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now +" Indicator Sucessfully sent to cityIO at iteration:" + cycle ;		
	}
	
	reflex update when: (cycle mod update_frequency = 0) {
		string new_grid_hash_id <- get_grid_hash();
		if ((new_grid_hash_id != grid_hash_id) or forceUpdate)  {
			grid_hash_id <- new_grid_hash_id; 
			do udpateGrid;
			do sendIndicators;
		}
	}
}

species cityio_indicator {
	string indicator_name;
	string indicator_type<-"numeric";
	string viz_type<-"bar";
	
	float return_indicator {
		return length(block);
		// return mean(block collect each.height))
	}
}

species mean_height_indicator parent: cityio_indicator {
	float return_indicator {
		 return mean(block collect each.height);
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
