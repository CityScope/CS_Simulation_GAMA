model GAMABrix
// Set of tools to connect to cityio


global {
	string city_io_table;

	bool post_on <- false;
	int update_frequency<-100; // Frequency (in cycles) by which to update local grid by checking for changes in gridhash
	float idle_update_frequency<-5.0; // Time in seconds (real seconds) between two grid updated when idle
	
	int cycle_first_batch<-100; // Cycle in which to send the first batch of data
	bool send_first_batch<-true;
	
	float step <- 60 #sec;
	float saveLocationInterval<-10*step; // In seconds
	
	int totalTimeInSec<-86400; //24hx60minx60sec 1step is 10#sec
//	int totalTimeInSec<-10800; //3hx60minx60sec 1step is 10#sec

	
	// Variables used for debugging
	bool block_post<-false; // set to true to prevent GAMABrix from posting the indicators (useful for debugging)
	
	// Internal variables (non editable)
	bool idle_mode<-false;
	float start_day_time<-0.0;
	int start_day_cycle<-0;
	float end_day_time  <- start_day_time+totalTimeInSec;
	bool first_batch_sent<-false;
	file geogrid;
	string grid_hash_id;
	string hash_id<-"GEOGRIDDATA"; // Some models might want to listen to changes in other hashes (e.g, indicators)
	map<string,unknown> static_type;
	map<string,map<string, float>> lbcs_type;
	map<string,map<string, float>> naics_type;
		
		
	geometry setup_cityio_world {
		geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
		return envelope(geogrid);
	}
	
	
	action setup_static_type{
		static_type <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID/properties/types").contents;
		map<string,list> temp_map;
		loop k over: static_type.keys {
			temp_map <- static_type[k];			
			map<string, float> parsed_lbcs_entry;
			loop mm over: temp_map["LBCS"]  {
				map<string, unknown> entry <- mm;
				float proportion <- float(entry["proportion"]);
				map<string, float> entry_use <- entry["use"]; 
				loop lbcs_code over: entry_use.keys {
					parsed_lbcs_entry[lbcs_code] <- parsed_lbcs_entry[lbcs_code] + entry_use[lbcs_code]*proportion;
				}
			}
			lbcs_type <+ k::parsed_lbcs_entry;
			
			map<string, float> parsed_naics_entry;
			loop mm over: temp_map["NAICS"]  {
				map<string, unknown> entry <- mm;
				float proportion <- float(entry["proportion"]);
				map<string, float> entry_use <- entry["use"]; 
				loop naics_code over: entry_use.keys {
					parsed_naics_entry[naics_code] <- parsed_naics_entry[naics_code] + entry_use[naics_code]*proportion;
				}
			}
			naics_type <+ k::parsed_naics_entry;
		}
		write lbcs_type;
		write naics_type;
    }
			
	init {
		create block from:geogrid;
		do setup_static_type;
		do udpateGrid;
		do sendIndicators;
	}
	
	list<agent> get_all_instances(species<agent> spec) {
        return spec.population +  spec.subspecies accumulate (get_all_instances(each));
    }
	
	string get_grid_hash {
		write "Checking hash";
		file grid_hashes <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/meta/hashes");
		string grid_hash <- first(grid_hashes at hash_id);
		return grid_hash;
	
	}
	action udpateGrid {
	    write "Performing local grid update";
		file geogrid_data <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRIDDATA");
		loop b over: geogrid_data {
			loop l over: list(b) {
				map m <- map(l);
				
				ask block(int(m["id"])) {
					self.type<-m["name"];
					self.color <- m["color"];
					self.block_lbcs <- lbcs_type[type];
					self.block_naics <- naics_type[type];
				}
			}
		}
	}
	
	action sendStringToCityIo(string cityIOString, string type){
		save cityIOString to: "./../results/"+type+".json" rewrite: true;
		file JsonFileResults <- json_file("./../results/"+type+".json");
	    map<string, unknown> m <- JsonFileResults.contents;
	    if (!block_post){
			try{			
			  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/"+type, m)); // This still updates a dictionary with 'contents' as a key
			}catch{
			  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
			}
			write #now + " " + type + " sucessfully sent to cityIO at iteration:" + cycle ;
	    }else{
	    	write #now + " " + type + " would have been sent to cityIO at iteration:" + cycle ;
	    }
		
	}
	
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
		do sendStringToCityIo(numerical_indicator_string,"indicators");
		//Heatmap Indicator
		list<agent> heatmap_indicators <- get_all_instances(cityio_heatmap_indicator);
		string heatmap_indicator_string<-"{\"features\":[";
		ask heatmap_indicators as: cityio_heatmap_indicator{
			if length(listOfPoint)>0 {
				loop i from:0 to:length(listOfPoint)-1{
					string hIndicator<-"{\"geometry\":{\"coordinates\":["+CRS_transform(listOfPoint[i].location).location.x+","+CRS_transform(listOfPoint[i].location).location.y+"],\"type\":\"Point\"},\"properties\":["+listOfPoint[i].att1+","+listOfPoint[i].att2+"],\"type\":\"Feature\"}";
					if length(heatmap_indicator_string)=0 {
					  heatmap_indicator_string<-heatmap_indicator_string+hIndicator;
				    }else{
				      heatmap_indicator_string<-heatmap_indicator_string+","+hIndicator;	
				    }
				}
								
			}
		}
		heatmap_indicator_string<-heatmap_indicator_string+"]";
		heatmap_indicator_string<-heatmap_indicator_string+"\"properties\":[\"att1\",\"att2\"],\"type\":\"FeatureCollection\"}";
		do sendStringToCityIo(heatmap_indicator_string,"access");
		//ABM Indicator
		list<agent> agent_indicators <- get_all_instances(cityio_agent);
		string abm_indicator_string <- "{";
		abm_indicator_string <- abm_indicator_string+"\"attr\": {";
		abm_indicator_string <- abm_indicator_string+"\"mode\": {\"0\": {\"name\": \"home\", \"color\": \"#4daf4a\"}, \"1\": {\"name\": \"work\", \"color\": \"#ffff33\"}}";
		abm_indicator_string <- abm_indicator_string+",\n\"profile\": {\"0\": {\"name\": \"home\", \"color\": \"#4daf4a\"}, \"1\": {\"name\": \"work\", \"color\": \"#ffff33\"}}";
		abm_indicator_string <- abm_indicator_string+"},\n\"trips\": [";
		ask agent_indicators as: cityio_agent {
			if length(locs)>0 {
				string abmIndicator <- "{";
				abmIndicator <- abmIndicator + "\"mode\": "+mode+",\n";
				abmIndicator <- abmIndicator + "\"profile\": "+profile+",\n";
				
				abmIndicator <- abmIndicator+ "\"path\": [";
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
				abmIndicator <- abmIndicator + "]\n}";
				if (length(abm_indicator_string)=124){
				  abm_indicator_string<-abm_indicator_string+abmIndicator;
				}else{
				  abm_indicator_string<-abm_indicator_string+","+abmIndicator;	
				}
			}
        }
        abm_indicator_string<-abm_indicator_string+"]}";
		do sendStringToCityIo(abm_indicator_string,"ABM2");
	}
	
	action restart_day {
		start_day_time<-time;
		end_day_time  <-start_day_time+totalTimeInSec;
		start_day_cycle<-cycle;
		first_batch_sent<-false;
		
		
		list<agent> agent_indicators <- get_all_instances(cityio_agent);
		ask agent_indicators as: cityio_agent {
			do reset_location;
		}
	}
	
	float time_of_day {
		if (time<=end_day_time) {
			return time-start_day_time;
		}else{
			return -1;
		}
	}
	
	float cycle_of_day {
		return cycle-start_day_cycle;
	}
	
	
	reflex update when: ((cycle mod update_frequency = 0)) {
		string new_grid_hash_id <- get_grid_hash();
		float idle_step_start;
		if ((new_grid_hash_id != grid_hash_id))  {
			grid_hash_id <- new_grid_hash_id;
			do restart_day;
			do udpateGrid;
		}
		if ((cycle_of_day()>cycle_first_batch) and !first_batch_sent) {
			first_batch_sent<-true;
			if (post_on and send_first_batch) {
				do sendIndicators;				
			}
		}
		
		if (time_of_day()=-1){
			write "ENTERING IDLE MODE";
			idle_mode<-true;
			if (post_on) {
				do sendIndicators;
			}
			do pause;
			idle_step_start<-machine_time/1000;
			loop while: (idle_mode) {
				if (machine_time/1000>=idle_step_start+idle_update_frequency) {
					string new_grid_hash_id <- get_grid_hash();
					if ((new_grid_hash_id != grid_hash_id))  {
						idle_mode<-false;
					}
					idle_step_start<-machine_time/1000;
				}
			}
			do resume;
		}	
		write "TIME OF DAY:"+time_of_day();
		
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
	list<cityio_agent> listOfPoint;
	list<cityio_agent> return_indicator {
		return listOfPoint; // Not sure about this yet, but we might want this return function just to help users organize their code. 
	}
}

species block{
	string type;
	float height update:rnd(100.0);
	rgb color;
	map<unknown, unknown> block_lbcs;
	map<unknown, unknown> block_naics;
	
	aspect base {
		  draw shape color:color border:color-50 depth:height;	
	}
}


species cityio_agent parent: cityio_indicator {
	list<point> locs;
	
	int att1;
	int att2;
	
	int profile<-0;
	int mode<-0;
	
	string type;
	
	action reset_location {
		locs<-[];
	}
	
	reflex save_location {
		float tod;
		ask world {
			tod<-time_of_day();
		}
		if((tod>0) and (tod mod saveLocationInterval = 0)){
			locs << {location.x,location.y,tod mod totalTimeInSec};
		}
	}
	
	aspect base{
		draw circle(10) color:#blue;
	}
}

experiment CityScopeHeadless autorun:true until: false { }