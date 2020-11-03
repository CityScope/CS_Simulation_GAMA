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
	
	
	string computeIndicator (string viz_type){
		string indicator <- "{name: Gama Indicator,value:" + length(block)+",viz_type:"+viz_type+"}";
		return indicator;
	}
	
	action sendIndicator(string type){
		string myIndicator;
		myIndicator<-"[{\"indicator_type\":\"" + type+"\",\"name\":\"Gama Indicator\",\"value\":"+length(block)+",\"viz_type\":\"bar\"}]";
		save myIndicator to: "indicator.json" rewrite: true;
		file JsonFileResults <- json_file("./indicator.json");
        map<string, unknown> c <- JsonFileResults.contents;
        try{			
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c));		
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now +" Indicator Sucessfully sent to cityIO at iteration:" + cycle ;
		  	
	}
	//HeatMap
	//https://cityio.media.mit.edu/api/table/corktown/access
	
	action updateIndicators {
		list<unknown> update_package;
		ask cityio_indicator {
			write "Updating indicator: " + indicator_name;
			do return_indicator;
			file JsonFileResults <- json_file("./"+indicator_name+".json");
	        map<string, unknown> c <- first(JsonFileResults.contents at "contents");
	        update_package <- update_package+[c];
		}
		write update_package;
		write json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", update_package);
//		save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", update_package));
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
//			do sendIndicator("numeric");
		}
	}
}

species cityio_indicator {
	string indicator_name;
	string indicator_type;
	
	action return_indicator (string viz_type){
		string myIndicator;
		myIndicator<-"[{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+indicator_name+"\",\"value\":"+length(block)+",\"viz_type\":\"bar\"}]";
		save myIndicator to: indicator_name+".json" rewrite: true;
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
