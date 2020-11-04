model GAMABrix
// Set of tools to connect to cityio

global {
	string city_io_table;
	string grid_hash_id;
	int update_frequency<-10;
	bool forceUpdate<-true;
	file geogrid;
	float step <- 30 #sec;
	float saveLocationInterval<-step;
	int totalTimeInSec<-86400; //24hx60minx60sec 1step is 10#sec
	bool saveABM parameter: 'Save ABM' category: "Parameters" <-true; 
	
	
	init {
		create block from:geogrid with:[type::read("land_use")];
		do udpateGrid;
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
		//ABM Indicator
		if (cycle>1){
		string abm_indicator_string<-"{\"attr\": {\"trip_purpose\": {\"0\": {\"name\": \"home\", \"color\": \"#4daf4a\"}, \"1\": {\"name\": \"work\", \"color\": \"#ffff33\"}}}";
		abm_indicator_string<-abm_indicator_string+",\"trips\": [";
		ask people{
			string abmIndicator <-"{\"path\": [";
			loop i from:0 to:length(locs)-1{
				point loc <- CRS_transform(locs[i]).location;
				if(i<length(locs)-1){
				abmIndicator <- abmIndicator + "[" + loc.x + ", " + loc.y + "],\n";	
				}else{
				abmIndicator <- abmIndicator + "[" + loc.x + ", " + loc.y + "]\n";	
				}
			}
			abmIndicator<-abmIndicator+"]";
			abmIndicator <- abmIndicator+",\n\"timestamps\": [";
			loop i from:0 to:length(locs)-1{
				point loc <- CRS_transform(locs[i]).location;
				if(i<length(locs)-1){
				abmIndicator <- abmIndicator + loc.z + ",\n";	
				}else{
				abmIndicator <- abmIndicator +  loc.z + "\n";	
				}
			}
			abmIndicator <- abmIndicator + "]";
			abmIndicator<-  abmIndicator+ "\n}";
			if (length(abm_indicator_string)=124){
			  abm_indicator_string<-abm_indicator_string+abmIndicator;
			}else{
			  abm_indicator_string<-abm_indicator_string+","+abmIndicator;	
			}
        }
        abm_indicator_string<-abm_indicator_string+"]}";
		save abm_indicator_string to: "abm_indicator.json" rewrite: true;
		file JsonFileResultsABM <- json_file("./abm_indicator.json");
		map<string, unknown> a <- JsonFileResultsABM.contents;
		try{			
		  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/ABM2", a)); // This still updates a dictionary with 'contents' as a key
		}catch{
		  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		}
		write #now + " ABM indicator sucessfully sent to cityIO at iteration:" + cycle ;
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
	string indicator_type<-"numeric";
	float return_indicator {
		return float(eval_gaml(indicator_value));
	}
}

species cityio_heatmap_indicator parent: cityio_indicator {
	// The generic heatmap indicator should not reely on people species.
	string indicator_type<-"heatmap"; 
	list<people> listOfPoint;
	list<people> return_indicator {
		return listOfPoint; // Not sure about this yet, but we might want this return function just to help users organize their code. 
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


species people skills:[moving]{ // This is here only because the current version of cityio_heatmap_indicator needs it. This should live in the model file.
	string type;
	int att1;
	int att2;
	list<point> locs;
	
	reflex move{
		do wander;
		locs << {location.x,location.y,time mod totalTimeInSec};
		if(saveABM){
			if((time mod saveLocationInterval = 0) and (time mod totalTimeInSec)>1){
		 		
			}		
		}
	}
	aspect base{
		draw circle(10) color:#blue;
	}
}