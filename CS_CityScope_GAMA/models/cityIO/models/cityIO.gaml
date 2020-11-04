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
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Mean Height", indicator_type: "numeric", indicator_value: "mean(block collect each.height)");
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Min Height",  indicator_type: "numeric", indicator_value: "min(block collect each.height)");
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Max Height",  indicator_type: "numeric", indicator_value: "max(block collect each.height)");
		create cityio_heatmap_indicator with: (listOfPoint:list<people>(people));
		do sendIndicators;
	}
	
	list<agent> get_all_instances(species<agent> spec) {
        return spec.population +  spec.subspecies accumulate (get_all_instances(each));
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
		list<agent> numeric_indicators <- get_all_instances(cityio_numeric_indicator);
		string numerical_indicator_string<-"[";
		ask numeric_indicators as: cityio_numeric_indicator {
			string myIndicator;
			myIndicator<-"{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+indicator_name+"\",\"value\":"+return_indicator()+",\"viz_type\":\"" + viz_type + "\"}";
			if length(numerical_indicator_string)=1 {
				numerical_indicator_string <- numerical_indicator_string+myIndicator;				
			}else{
				numerical_indicator_string <- numerical_indicator_string+","+myIndicator;
			}
		}
		numerical_indicator_string <- numerical_indicator_string+"]";
		save numerical_indicator_string to: "numeric_indicator.json" rewrite: true;
		file JsonFileResults <- json_file("./numeric_indicator.json");
	    map<string, unknown> c <- JsonFileResults.contents;
		try{
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/indicators", c)); 
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now + "  " + length(numeric_indicators) + " indicators sucessfully sent to cityIO at iteration:" + cycle ;
		
		
		//Heatmap Indicator
		list<agent> heatmap_indicators <- get_all_instances(cityio_heatmap_indicator);
		string heatmap_indicator_string<-"{\"features\":[";
		ask heatmap_indicators as: cityio_heatmap_indicator{
			write return_indicator();
			loop i from:0 to:length(listOfPoint)-1{
				string hIndicator<-"{\"geometry\":{\"coordinates\":["+CRS_transform(listOfPoint[i].location).location.x+","+CRS_transform(listOfPoint[i].location).location.y+"],\"type\":\"Point\"},\"properties\":["+listOfPoint[i].att1+","+listOfPoint[i].att2+"],\"type\":\"Feature\"}";
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
			write #now + "  " + length(heatmap_indicators) + " heatmap sucessfully sent to cityIO at iteration:" + cycle ;
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

species cityio_indicator { // This is the master indicator species. We will use this to force indicators to define certain features.
	string indicator_name;
	string indicator_type;
}


species cityio_numeric_indicator parent: cityio_indicator {
	string indicator_value;
	string viz_type <- "bar";
	float return_indicator {
		return float(eval_gaml(indicator_value));
	}
}

species cityio_heatmap_indicator parent: cityio_indicator {
	list<people> listOfPoint;
	list<unknown> return_indicator {
		return listOfPoint; // Not sure about this yet, but we might want this return function just to help users organize their code. 
	}
}

// Example of how a user would define their own numeric indicator
species my_cool_indicator parent: cityio_numeric_indicator {
	float return_indicator {
		return length(block);
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
