model GAMABrix
// Set of tools to connect to cityio


global {
	string city_io_table;
	map<string, unknown> cityScopeGrid;

	bool post_on <- false;
	int update_frequency<-100; // Frequency (in cycles) by which to update local grid by checking for changes in gridhash
	float idle_update_frequency<-5.0; // Time in seconds (real seconds) between two grid updated when idle
	
	int cycle_first_batch<-100; // Cycle in which to send the first batch of data
	bool send_first_batch<-true;
	
	float step <- 60 #sec;
	float saveLocationInterval<-10*step; // In seconds
	
	bool pull_only<-false; // If true, the model will only pull the grid and not handle any of the posting or time of day controlling
	
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
	
	bool inverse_xy <- true; //parameter for issue #157
	
	
	list<string> road_types <- ["Road", "LRT street"];	
	bool use_neigbors4 <- true;
	list<brix> roads;
	
	geometry setup_cityio_world {
		geogrid <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID","EPSG:4326");
		cityScopeGrid<-json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/GEOGRID/properties/header").contents;
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
    }
			
	init {
		do initialize_brix;
		do setup_static_type;
		do udpateGrid;
		do sendIndicators;
	}
	
	action initialize_brix {
		create brix from:geogrid with: (name:nil);
		if (inverse_xy) {
			ask brix {
				list<point> pts;
				loop i from: 0 to: length(shape.points) - 1 {
					point pt <- shape.points[i];
					pts << {world.shape.width - pt.x, world.shape.height - pt.y };
				}
				shape <- polygon(pts);
			}
		}
		float dist_tol <- first(brix).shape.width/ 100.0;
		float perimeter_diag <- 0.99 * (first(brix).shape.points[0] distance_to  first(brix).shape.points[2]);
		ask brix {
			neighbors8 <- brix at_distance dist_tol; 
			neighbors4 <- neighbors8 where ((each.location distance_to location) <= perimeter_diag);
		}
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
				ask brix(int(m["id"])) {
					self.type<-m["name"];
					self.color <- m["color"];
					self.block_lbcs <- lbcs_type[type];
					self.block_naics <- naics_type[type];
				}
			}
		}
		roads <- brix where (each.type in road_types);
		
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
		list<agent> numeric_indicators <- get_all_instances(cityio_agent);
		string numerical_indicator_string<-"[";
		ask numeric_indicators as: cityio_agent {
			if is_numeric {
				string myIndicator;
				loop k over: numeric_values.keys {
					myIndicator<-"{\"indicator_type\":\"" + indicator_type+"\",\"name\":\""+k+"\",\"value\":"+numeric_values[k]+",\"viz_type\":\"" + viz_type + "\"}";
				}
				if length(numerical_indicator_string)=1 {
					numerical_indicator_string <- numerical_indicator_string+myIndicator;				
				}else{
					numerical_indicator_string <- numerical_indicator_string+","+myIndicator;
				}
			}
		}
		numerical_indicator_string <- numerical_indicator_string+"]";
		do sendStringToCityIo(numerical_indicator_string,"indicators");
		//Heatmap Indicator
		list<agent> heatmap_indicators <- get_all_instances(cityio_agent);
		list<string> all_keys<-[];
		ask heatmap_indicators as: cityio_agent{
			if is_heatmap {
				loop k over: heatmap_values.keys {
					all_keys<-remove_duplicates(all_keys+[k]);
				}
			}
		}
		string heatmap_indicator_string<-"{\"features\":[";
		ask heatmap_indicators as: cityio_agent{
			if is_heatmap {
				string hIndicator<-"{\"geometry\":{\"coordinates\":["+CRS_transform(self).location.x+","+CRS_transform(self).location.y+"],\"type\":\"Point\"},"; // Do we need CRS_transform here?
				hIndicator<-hIndicator+"\"properties\":[";
				bool first_key<-true;
				loop k over: all_keys {
					if first_key {
						hIndicator<-hIndicator+heatmap_values[k];
						first_key<-false;						
					}else{
						hIndicator<-hIndicator+","+heatmap_values[k];
					}
				}
				hIndicator<-hIndicator+"],\"type\":\"Feature\"}";
				if length(heatmap_indicator_string)=length("{\"features\":[") {
					heatmap_indicator_string<-heatmap_indicator_string+hIndicator;
			    }else{
					heatmap_indicator_string<-heatmap_indicator_string+","+hIndicator;	
			    }
			}
			
		}
		heatmap_indicator_string<-heatmap_indicator_string+"]";
		heatmap_indicator_string<-heatmap_indicator_string+"\"properties\":[";
		bool first_key<-true;
		loop k over: all_keys {
			if first_key {
				heatmap_indicator_string<-heatmap_indicator_string+"\""+k+"\"";
				first_key<-false;						
			}else{
				heatmap_indicator_string<-heatmap_indicator_string+","+"\""+k+"\"";
			}
		}
		heatmap_indicator_string<-heatmap_indicator_string+"],\"type\":\"FeatureCollection\"}";
		do sendStringToCityIo(heatmap_indicator_string,"access");
		//ABM Indicator
		list<agent> agent_indicators <- get_all_instances(cityio_agent);
		string abm_indicator_string <- "{";
		abm_indicator_string <- abm_indicator_string+"\"attr\": {";
		abm_indicator_string <- abm_indicator_string+"\"mode\": {\"0\": {\"name\": \"home\", \"color\": \"#4daf4a\"}, \"1\": {\"name\": \"work\", \"color\": \"#ffff33\"}}";
		abm_indicator_string <- abm_indicator_string+",\n\"profile\": {\"0\": {\"name\": \"home\", \"color\": \"#4daf4a\"}, \"1\": {\"name\": \"work\", \"color\": \"#ffff33\"}}";
		abm_indicator_string <- abm_indicator_string+"},\n\"trips\": [";
		ask agent_indicators as: cityio_agent {
			if (is_visible) {
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
	
	reflex pull_grid when: ((cycle mod update_frequency = 0) and (pull_only)) {
		string new_grid_hash_id <- get_grid_hash();
		if ((new_grid_hash_id != grid_hash_id))  {
			grid_hash_id <- new_grid_hash_id;
			do udpateGrid;
		}
	}
	
	
	reflex update when: ((cycle mod update_frequency = 0) and (not pull_only)) {
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
	
	path path_between_brix(point origin, point destination, list<brix> on, bool neigbors4) {
		brix startAg <- on closest_to origin;
		brix endAg <- on closest_to destination;
		if (startAg = endAg) {
			return path([line([origin, destination])]);
		}
		list<bool> open;
		loop times: length(brix) {open << false;}
		loop b over: on {
			open[int(b)] <- true;
		}
		map<brix,brix> cameFrom;
		map<brix, float> frontier;
		map<brix,float> costSoFar;
		costSoFar[startAg] <- 0.0;
		frontier[startAg] <- 0.0;
		loop while: not empty(frontier) {
			brix current <- frontier.keys with_min_of (frontier[each]);
			remove key: current from: frontier;
			if (current = endAg) {
				list<point> nodesPt ;
				nodesPt << destination.location;
				loop while: (current != startAg) {
					current <- cameFrom[current];
					if (current != startAg) {
						nodesPt << current.location;
					}
				}
				nodesPt << origin.location;
				nodesPt <- reverse(nodesPt);
				return path(nodesPt);
			}
			float cost <- costSoFar[current];
			loop next over: neigbors4 ? current.neighbors4 : current.neighbors8{
				if (open[int(next)]) {
					float dist <- current.location distance_to next.location;
					float nextCost <- cost +  dist;
					frontier[next] <-nextCost;
					open[int(next)] <- false;
					if (not (next in costSoFar.keys)) or (nextCost < costSoFar[next]) {
						costSoFar[next] <- nextCost;
						cameFrom[next] <- current;
					}
				}
			}
		}
		return nil;
	}
	
	
}

species cityio_indicator { // This is the master indicator species. We will use this to force indicators to define certain features.
	string indicator_name;
	string indicator_type;
}


species brix{
	string type;
	list<brix> neighbors4;
	list<brix> neighbors8;
	float height init:rnd(100.0);
	rgb color;
	map<string, float> block_lbcs;
	map<string, float> block_naics;
	
	aspect base {
		  draw shape color:color border:color-50 depth:height;	
	}
	
}


species cityio_agent parent: cityio_indicator {
	list<point> locs;
	
	map<string,float> heatmap_values;
	map<string,float> numeric_values;
	string viz_type <- "bar";
	
	bool is_heatmap<-false;
	bool is_visible<-false;
	bool is_numeric<-false;
	
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
			locs << {location.x,location.y,tod};
		}
	}
	
	reflex update_heatmap {
		
	}
	
	reflex update_numeric {
		
	}
	
	aspect base {
		draw circle(10) color:#blue;
	}
}

species moving_agent parent: cityio_agent skills: [moving] {
	path my_path;
	point random_target;
	
	action goto_on_roads (point a_target){
		if (a_target != nil) and (location != a_target){
			if (my_path = nil or my_path.target != a_target) {
				my_path <- world.path_between_brix(location, a_target,roads, use_neigbors4 );
			}
			do follow path: my_path;
		}
	}
	
	action wander_on_roads {
		if (random_target = nil){
			random_target <- any_location_in(one_of(roads));
			my_path <- world.path_between_brix(location, random_target,roads, use_neigbors4 );
		}
		do follow path: my_path;
		if (location = random_target) {
			random_target <- nil;
		}
		
	}	
}
species cityio_numeric_indicator parent: cityio_agent {
	string indicator_value;
	string viz_type <- "bar";	
	string indicator_type<-"numeric";
	bool is_numeric<-true;
	bool is_heatmap<-false;
	bool is_visible<-false;
	
	reflex update_numeric {
		numeric_values<-[];
		numeric_values<+indicator_name::float(eval_gaml(indicator_value));
	}
}

/*grid gamaGrid width:int(cityScopeGrid["ncols"]) height:int(cityScopeGrid["nrows"]){
	int size;
	int type;
	int depth;
    aspect base{
	  draw shape color:#white border:#black;	
	}
}*/


experiment CityScopeHeadless autorun:true until: false { }