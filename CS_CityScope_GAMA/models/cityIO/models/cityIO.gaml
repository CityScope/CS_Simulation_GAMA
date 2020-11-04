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
		create people with:(att1:rnd(10),att2:rnd(10)) number:10;
		create cityio_indicator with: (viz_type:"bar",indicator_name: "Mean Height", indicator_type: "numeric", indicator_value: "mean(block collect each.height)");
		create cityio_indicator with: (viz_type:"bar",indicator_name: "Min Height", indicator_type: "numeric", indicator_value: "min(block collect each.height)");
		create cityio_indicator with: (viz_type:"bar",indicator_name: "Max Height", indicator_type: "numeric", indicator_value: "max(block collect each.height)");
		create cityio_heatmap_indicator with: (listOfPoint:list<people>(people));
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
		//Numeric Indicator
		list<cityio_indicator> numeric_indicators <- (cityio_indicator where (each.indicator_type="numeric")); // This should also select indicator agents that are subspecies of the cityio_indicator species
		string numerical_indicator_string<-"[";
		ask numeric_indicators {
			string myIndicator;
			myIndicator<-"{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+indicator_name+"\",\"value\":"+return_numeric_indicator()+",\"viz_type\":\"" + viz_type + "\"}";
			if length(numerical_indicator_string)=1 {
				numerical_indicator_string <- numerical_indicator_string+myIndicator;				
			}else{
				numerical_indicator_string <- numerical_indicator_string+","+myIndicator;
			}
		}
		numerical_indicator_string <- numerical_indicator_string+"]";
		write numerical_indicator_string;
		save numerical_indicator_string to: "numeric_indicator.json" rewrite: true;
		file JsonFileResults <- json_file("./numeric_indicator.json");
	    map<string, unknown> c <- JsonFileResults.contents;
		try{			
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c)); // This still updates a dictionary with 'contents' as a key
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now + "  " + length(numeric_indicators) + " indicators sucessfully sent to cityIO at iteration:" + cycle ;
		//Heatmap Indicator
		string heatmap_indicator_string<-"{\"features\":[";
		ask cityio_heatmap_indicator{
			loop i from:0 to:length(listOfPoint)-1{
				string hIndicator<-"{\"geometry\":{\"coordinates\":["+CRS_transform(listOfPoint[i].location).location.y+","+CRS_transform(listOfPoint[i].location).location.x+"],\"type\":\"Point\"},\"properties\":["+listOfPoint[i].att1+","+listOfPoint[i].att2+"],\"type\":\"Feature\"}";
				if length(heatmap_indicator_string)=0 {
				  heatmap_indicator_string<-heatmap_indicator_string+hIndicator;
			    }else{
			      heatmap_indicator_string<-heatmap_indicator_string+","+hIndicator;	
			    }
			}
			heatmap_indicator_string<-heatmap_indicator_string+"]";
			heatmap_indicator_string<-heatmap_indicator_string+"\"properties\":[\"att1\",\"att2\"],\"type\":\"FeatureCollection\"}";
			write heatmap_indicator_string;
			save heatmap_indicator_string to: "heatmap_indicator.json" rewrite: true;
			file JsonFileResultsH <- json_file("./heatmap_indicator.json");
		    map<string, unknown> h <- JsonFileResultsH.contents;
			try{			
			  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/access", h)); // This still updates a dictionary with 'contents' as a key
			}catch{
			  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
			}
			write #now + "  " + length(cityio_heatmap_indicator) + " heatmap sucessfully sent to cityIO at iteration:" + cycle ;
			}
		
		
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
	string indicator_type;
	string indicator_value;
	string viz_type;
	float return_numeric_indicator {
		return float(eval_gaml(indicator_value));
	}
}

species cityio_heatmap_indicator{
	list<people> listOfPoint;
}

species block{
	string type;
	float height update:rnd(100.0);
	rgb color;
	aspect base {
		  draw shape color:color border:color-50 depth:height;	
	}
}

species people skills:[moving]{
	string type;
	int att1;
	int att2;
	aspect base{
		draw circle(10) color:#blue;
	}
}

experiment CityScope type: gui autorun:false{
	output {
		display map_mode type:opengl background:#black{	

			species block aspect:base;
			species people aspect:base position:{0,0,0.1};

		}
	}
}
