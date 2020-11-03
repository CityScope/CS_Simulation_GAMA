model citIOGAMA

global {

	string city_io_table<-'dungeonmaster';
	file geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
	string grid_hash_id;
	int update_frequency<-1;
	
	geometry shape <- envelope(geogrid);
	init {
		create block from:geogrid with:[type::read("land_use")];
		do udpateGrid;
		
		create cityio_indicator with: (indicator_name: "hello", indicator_type: "numeric");
		create cityio_indicator with: (indicator_name: "world", indicator_type: "numeric");
		do updateIndicators;
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
	
	action updateIndicators {
		string update_package <- "[";
		ask cityio_indicator {
			if indicator_type="numeric" {
				string myIndicator;
				float indicator_value <- return_indicator();
				myIndicator<-"{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+indicator_name+"\",\"value\":"+indicator_value+",\"viz_type\":\""+viz_type+"\"}";
				if length(update_package)=1 {
					update_package <- update_package + myIndicator;
				}else{
					update_package <- update_package + "," + myIndicator;					
				}
				
			}else{
				error "only numeric indicators supported at the moment";
			}
		}

		update_package <- update_package +"]";
		save update_package to: "numeric_indicators.json" rewrite: true;
		file JsonFileResults <- json_file("./numeric_indicators.json");
	    map<string, unknown> c <- JsonFileResults.contents;
	    write "C:";
	    write c;
//		save(file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c));
		
		

//		try{			
//		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", update_package));
//		}catch{
//		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
//		}
//		write #now +" Indicator Sucessfully sent to cityIO at iteration:" + cycle ;
	}
	
	reflex update when: (cycle mod 10 = update_frequency) {
		string new_grid_hash_id <- get_grid_hash();
		if new_grid_hash_id != grid_hash_id {
			grid_hash_id <- new_grid_hash_id; 
			do udpateGrid;
			do updateIndicators;
		}
	}
}

species cityio_indicator {
	string indicator_name;
	string indicator_type<-"numeric";
	string viz_type<-"bar";
	
	float return_indicator {
		return length(block);
	}
}

//species my_indicator parent: cityio_indicator {
//	action return_indicator (string viz_type){
//		string myIndicator;
//		myIndicator<-"[{\"indicator_type\":\"" + indicator_type+"\",\"name\":\"Gama Indicator\",\"value\":"+length(block)+",\"viz_type\":\"bar\"}]";
//		save myIndicator to: indicator_name+".json" rewrite: true;
//	}
//}

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
