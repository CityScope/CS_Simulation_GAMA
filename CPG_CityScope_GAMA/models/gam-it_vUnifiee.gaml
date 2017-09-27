/**
* Name: gamit
* Author: Arnaud, Tri, Patrick, Benoit
* Description: Describe here the model and its experiments
* Tags: Tag1, Tag2, TagN
*/

model gamit

global {
	string case_study <- "volpe" among: ["Rouen", "volpe"];
	bool is_osm_data <- case_study = "Rouen";
	file<geometry> buildings_shapefile <- file<geometry>("../includes/"+case_study+"/Buildings.shp");
	file<geometry> amenities_shapefile <- file_exists("../includes/"+case_study+"/amenities.shp") ? file<geometry>("../includes/"+case_study+"/amenities.shp") : nil;
	file<geometry> roads_shapefile <- file<geometry>("../includes/"+case_study+"/Roads.shp");
	file activity_file <- file("../includes/Activity Table.csv");
	file criteria_file <- file("../includes/CriteriaFile.csv");
	file modeCharacteristics_file <- file("../includes/ModeCharacteristics.csv");
	
	file clock_normal     const: true <- image_file("../images/clock.png");
	file clock_big_hand   const: true <- image_file("../images/big_hand.png");
	file clock_small_hand const: true <- image_file("../images/small_hand.png");
	
	float luminosity update: 1.0 - abs(12 - current_date.hour)/12;
	
	map<string,rgb> color_per_usage <- ["R"::#lightgray, "O"::#dimgray, "Shopping"::#violet, "Restaurant"::#cyan, "Night"::#blue,"GP"::#magenta, "Park"::#green, "HS"::#orange, "Uni"::#red, "Cultural"::#brown];
	geometry shape <- envelope(roads_shapefile);
	
	map<string,map<string,int>> activity_data;
	float step <- 1 #mn;
	date starting_date <- date([2017,9,25,0,0]);
	
	list<building> residential_buildings;
	list<building> office_buildings;
	map<string, rgb> color_per_type <- ["High School Student"::#lightblue, "College student"::#blue, "Young professional"::#darkblue,"Home maker"::#orange, "Mid-career workers"::#yellow, "Executives"::#red, "Retirees"::#darkorange];
	map<string,rgb> color_per_mobility <- ["walking"::#green, "bike"::#orange,"car"::#red,"car"::#blue];
	map<string,float> width_per_mobility <- ["walking"::2.0, "bike"::3.0, "car"::4.0,"bus"::4.0];
	map<string,float> speed_per_mobility <- ["walking"::3#km/#h, "bike"::5#km/#h,"car"::20#km/#h,"bus"::20#km/#h];
	map<string,graph> graph_per_mobility;
	map<string,list<float>> charact_per_mobility;
	
	map<road,float> congestion_map;  
	
	map<string,map<string,list<float>>> weights_map <- map([]);
	
	// outputs
	map<string,int> transport_type_cumulative_usage <- ["walking"::0, "bike"::0,"car"::0,"bus"::0];
	
	
	init {
		gama.pref_display_flat_charts <- true;
		do activity_data_import;
		do criteria_file_import;
		do characteristic_file_import;
		if is_osm_data {
			do import_osm_files;	
		} else {
			do import_shapefiles;	
		}
		
		do compute_graph;
		ask building {
			color <- color_per_usage[usage]; 
		}
		
		create bus_stop number: 6 {
			location <- one_of(building).location;
		}
		
		create bus {
			stops <- list(bus_stop);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
		}		
		
		create people number: 1000 {
			living_place <- one_of(residential_buildings);
			current_place <- living_place;
			location <- any_location_in(living_place);
			type <- one_of(color_per_type.keys);
			color <- color_per_type[type];
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
			do create_trip_objectives;
		}
	}
	
	action import_shapefiles {
		create road from: roads_shapefile {
			mobility_allowed << "walking";
			mobility_allowed << "bike";
			mobility_allowed << "car";
			mobility_allowed << "bus";
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale"))] ;
		
		if (amenities_shapefile != nil) {
			loop am over: amenities_shapefile {
				ask (building closest_to am) {
					usage <- "Restaurant";
					scale <- am get "Scale";
					name <- am get "name";
				} 
			}
		}
		office_buildings <- building where (each.usage = "O");
		residential_buildings <- building where (each.usage = "R");
		
		do random_init;	
	}
	
	action import_osm_files {
		create road from: roads_shapefile {
			string type <- shape get "type";
			switch type {
				match "cycleway" {
					mobility_allowed << "bike";
				}
				match "footway" {
					mobility_allowed << "walking";
					mobility_allowed << "bike";
				}
				match "pedestrian" {
					mobility_allowed << "walking";
					mobility_allowed << "bike";
				}
				match "trunk" {
					mobility_allowed << "car";
				}
				default {
					mobility_allowed << "walking";
					mobility_allowed << "bike";
					mobility_allowed << "car";
				}
			} 
			
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
		
		create building from: buildings_shapefile {
			string type <- shape get "type";
			switch type {
				match "public_building" {
					usage <- "O";
					scale <- one_of (["L", "M","S"]);
				}
				match "college" {
					if (not empty(building where (each.usage = "Uni"))) {
						usage <- "Uni";
					}else {
						usage <- "HS";
					}
				} match "church" {
					
				}
				
				default {
					usage <- "R";
					scale <- one_of (["L", "M","S"]);
				}
			} 
		}
		office_buildings <- building where (each.usage = "O");
		residential_buildings <- building where (each.usage = "R");	
	}
	
	user_command "add bus_stop" {
		create bus_stop returns: new_bus_stop {
			location <- #user_location;
		}
		// recompute bus line
		bus_stop closest_bus_stop <- (bus_stop - first(new_bus_stop)) with_min_of(each distance_to(#user_location));
		ask bus {
			int i <- (stops index_of(closest_bus_stop));
			bus_stop bb <- first(new_bus_stop);
			add bb at: i to: stops ;
		}
		
	}	
	
	action characteristic_file_import {
		matrix criteria_matrix <- matrix (modeCharacteristics_file);
		loop i from: 0 to:  criteria_matrix.rows - 1 {
			string mobility_type <- criteria_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to:  criteria_matrix.columns - 1 {
					vals << float(criteria_matrix[j,i]);	
				}
				charact_per_mobility[mobility_type] <- vals;
			}
		}
	}
	action criteria_file_import {
		matrix criteria_matrix <- matrix (criteria_file);
		int nbCriteria <- criteria_matrix[1,0] as int;
		int nbTO <- criteria_matrix[1,1] as int ;
		int lignCategory <- 2;
		int lignCriteria <- 3;
		
		loop i from: 5 to:  criteria_matrix.rows - 1 {
			string people_type <- criteria_matrix[0,i];
			int index <- 1;
			map<string, list<float>> m_temp <- map([]);
			if(people_type != "") {
				list<float> l <- [];
				loop times: nbTO {
					list<float> l2 <- [];
					loop times: nbCriteria {
						add float(criteria_matrix[index,i]) to: l2;
						index <- index + 1;
					}
					string cat_name <-  criteria_matrix[index-nbTO,lignCategory];
					loop cat over: cat_name split_with "|" {
						add l2 at: cat to: m_temp;
					}
				}
				add m_temp at: people_type to: weights_map;
			}
		}
	}

	 
	
	action random_init {
		ask one_of (office_buildings) {
			usage <- "Uni";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Shopping";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Restaurant";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Night";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Park";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "HS";
			office_buildings >> self;
		}
		ask one_of (office_buildings) {
			usage <- "Cultural";
			office_buildings >> self;
		}
		
	}
	
	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;	
		}
	}
	
	action activity_data_import {
		matrix activity_matrix <- matrix (activity_file);
		loop i from: 1 to:  activity_matrix.rows - 1 {
			string people_type <- activity_matrix[0,i];
			map<string, int> activities;
			string current_activity <- "";
			loop j from: 1 to:  activity_matrix.columns - 1 {
				string act <- activity_matrix[j,i];
				if (act != current_activity) {
					activities[act] <-j;
					 current_activity <- act;
				}
			}
			activity_data[people_type] <- activities;
		}
	}
	
	
	reflex update_road_weights {
		ask road {
			do update_speed_coeff;	
			congestion_map [self] <- speed_coeff;
		}
	}
}

species trip_objective {
	building place; 
	int starting_hour;
	int starting_minute;
}

species bus_stop {
	list<people> waiting_people;
	
	aspect c {
		draw circle(30) color: empty(waiting_people)?#pink:#blue border: #black;
	}
}

species bus skills: [moving] {
	list<bus_stop> stops; 
	map<bus_stop,list<people>> stop_passengers ;
	list<people> passengers;
	bus_stop my_target;
	
	reflex new_target when: my_target = nil{
		bus_stop firstStop <- first(stops);
		remove firstStop from: stops;
		add firstStop to: stops; 
		my_target <- firstStop;
	}
	
	reflex r {
		do goto target: my_target.location on: graph_per_mobility["car"];
		if(location = my_target.location) {
			////////      release some people
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				bus_status <- 2;
			}
			stop_passengers[my_target] <- [];
			
			/////////     get some people
			loop p over: my_target.waiting_people {
				bus_stop b <- bus_stop with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b] ;
			}
			my_target.waiting_people <- [];
						
			add my_target.waiting_people to: passengers all: true;
			my_target.waiting_people <- [];
			my_target <- nil;			
		}
		
	}
	
	aspect bu {
		draw rectangle(40,20) color: empty(passengers)?#yellow:#red border: #black;
	}
	
}

species people skills: [moving]{
	string type;
	rgb color ;
	building living_place;
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	building current_place;
	string mobility_mode;
	list<string> possible_mobility_modes;
	bool has_car <- flip(1.0);
	bool has_bike <- flip(1.0);

	//
	bus_stop closest_bus_stop;	
	int bus_status <- 0;
	
	action create_trip_objectives {
		map<string,int> activities <- activity_data[type];
		//if (activities = nil ) or (empty(activities)) {write "my type: " + type;}
		loop act over: activities.keys {
			if (act != "") {
				list<string> parse_act <- act split_with "|";
				string act_real <- one_of(parse_act);
				list<building> possible_bds;
				if (length(act_real) = 2) and (first(act_real) = "R") {
					possible_bds <- building where ((each.usage = "R") and (each.scale = last(act_real)));
				} 
				else if (length(act_real) = 2) and (first(act_real) = "O") {
					possible_bds <- building where ((each.usage = "O") and (each.scale = last(act_real)));
				} 
				else {
					possible_bds <- building where (each.usage = act_real);
				}
				building act_build <- one_of(possible_bds);
				if (act_build= nil) {write "problem with act_real: " + act_real;}
				do create_activity(act_real,act_build,activities[act]);
			}
		}
	}
	
	action create_activity(string act_name, building act_place, int act_time) {
		create trip_objective {
			name <- act_name;
			place <- act_place;
			starting_hour <- act_time;
			starting_minute <- rnd(60);
			myself.objectives << self;
		}
	} 
	
	action choose_mobility_mode {
		list<list> cands <- mobility_mode_eval();
		map<string,list<float>> crits <-  weights_map[type];
		list<float> vals ;
		loop obj over:crits.keys {
			if (obj = my_current_objective.name) or
			 ((my_current_objective.name in ["RS", "RM", "RL"]) and (obj = "R"))or
			 ((my_current_objective.name in ["OS", "OM", "OL"]) and (obj = "O")){
				vals <- crits[obj];
				break;
			} 
		}
		list<map> criteria_WM;
		loop i from: 0 to: length(vals) - 1 {
			criteria_WM << ["name"::"crit"+i, "weight" :: vals[i]];
		}
		int choice <- weighted_means_DM(cands, criteria_WM);
		if (choice >= 0) {
			mobility_mode <- possible_mobility_modes [choice];
		} else {
			mobility_mode <- one_of(possible_mobility_modes);
		}
		transport_type_cumulative_usage[mobility_mode] <- transport_type_cumulative_usage[mobility_mode] + 1;
		speed <- speed_per_mobility[mobility_mode];
	}
	
	list<list> mobility_mode_eval {
		list<list> candidates;
		loop mode over: possible_mobility_modes {
			list<float> characteristic <- charact_per_mobility[mode];
			list<float> cand;
			float distance <-  0.0;
			using topology(graph_per_mobility[mode]){
				distance <-  distance_to (location,my_current_objective.place.location);
			}
			cand << characteristic[0] + characteristic[1]*distance;
			cand << characteristic[2] #mn +  distance / speed_per_mobility[mode];
			cand << characteristic[3];
			cand << characteristic[4];
			add cand to: candidates;
		}
		return candidates;
	}
	
	
	reflex choose_objective when: my_current_objective = nil {
		location <- any_location_in(current_place);
		my_current_objective <- objectives first_with ((each.starting_hour = current_date.hour) and (current_date.minute >= each.starting_minute) and (current_place != each.place) );
		if (my_current_objective != nil) {
			current_place <- nil;
			possible_mobility_modes <- ["walking"];
			if (has_car) {possible_mobility_modes << "car";}
			if (has_bike) {possible_mobility_modes << "bike";}
			possible_mobility_modes << "bus";				
			do choose_mobility_mode;
		}
	}
	reflex move when: (my_current_objective != nil) and (mobility_mode != "bus") {
		if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- max([0,road(current_edge).current_concentration - 1]); }
		if (mobility_mode in ["car"]) {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode] move_weights: congestion_map ;
		}else {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode]  ;
		}
		
		if (location = my_current_objective.place.location) {
			current_place <- my_current_objective.place;
			location <- any_location_in(current_place);
			my_current_objective <- nil;	
			mobility_mode <- nil;
		} else {
			if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- road(current_edge).current_concentration + 1; }
		}
	}
	
	reflex move_bus when: (my_current_objective != nil) and (mobility_mode = "bus") {

		if (bus_status = 0){
			do goto target: closest_bus_stop.location on: graph_per_mobility["walking"];
			
			if(location = closest_bus_stop.location) {
				add self to: closest_bus_stop.waiting_people;
				bus_status <- 1;
			}
		} else if (bus_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility["walking"];		
		
			if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
				location <- any_location_in(current_place);
				my_current_objective <- nil;	
				mobility_mode <- nil;
				bus_status <- 0;
			}
		}
	}	
	
	aspect default {
		if (mobility_mode = nil) {
			draw sphere(8) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4}  color: color ;
		} else {
			if (mobility_mode = "walking") {
				draw sphere(8) color: color  ;
			}else if (mobility_mode = "bike") {
				draw triangle(10) rotate: heading +90  color: color depth: 8 ;
			} else if (mobility_mode = "car") {
				draw cube(10)  color: color ;
			}
		}
	}
}

species road  {
	list<string> mobility_allowed;
	float capacity;
	float max_speed <- 30 #km/#h;
	float current_concentration;
	float speed_coeff <- 1.0;
	
	action update_speed_coeff {
		speed_coeff <- shape.perimeter / max([0.01,exp(-current_concentration/capacity)]);
	}
	aspect default {
		string max_mobility <- mobility_allowed with_max_of (width_per_mobility[each]);
		
		draw shape width: width_per_mobility[max_mobility] color:color_per_mobility[max_mobility] ;
	}
	
	user_command to_pedestrian_road {
		mobility_allowed <- ["walking", "bike"];
		ask world {do compute_graph;}
	}
}

species building {
	string usage;
	string scale;
	rgb color <- #grey;
	float height <- 10.0 + rnd(10);
	aspect default {
		draw shape color: color border: #black depth: height;
	}
}
experiment gamit type: gui {
	output {
		display map type: opengl draw_env: false background: rgb(255 *luminosity,255*luminosity, 255*luminosity ){
			species building refresh: false;
			species road ;
			species people;
			
			graphics "time" {
				point loc <- {-100,-100};
				draw clock_normal size: 400 at:loc ;
				draw clock_big_hand rotate: current_date.minute*(360/60)  + 90  size: {400,400/14} at:loc + {0,0,0.1}; 
				draw clock_small_hand rotate: current_date.hour*(360/12)  + 90  size: {240,240/10} at:loc + {0,0,0.1}; 
			}
			
			 overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 0.5 border: #black rounded: true
            {
            	//for each possible type, we draw a square with the corresponding color and we write the name of the type
 
                float y <- 30#px;
  				draw "Building Usage" at: { 40#px, y } color: # white font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                loop type over: color_per_usage.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_per_usage[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }
                 y <- y + 30 #px;
                draw "People Type" at: { 40#px, y } color: # white font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                loop type over: color_per_type.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_per_type[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }
				 y <- y + 30 #px;
                draw "Mobility Mode" at: { 40#px, y } color: # white font: font("SansSerif", 20, #bold);
                y <- y + 30 #px;
                draw circle(10#px) at: { 20#px, y } color:#white border: #black;
                draw "Walking" at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                 y <- y + 25#px;
                draw triangle(15#px) at: { 20#px, y } color:#white  border: #black;
                draw "Bike" at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                y <- y + 25#px;
                 draw square(20#px) at: { 20#px, y } color:#white border: #black;
                draw "Car" at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                   
            }
		}
		display map_simple{
			species building refresh: false;
			species road ;
			species bus_stop aspect: c;
			species bus aspect: bu; 			
			species people;
		}
		display histogram type:java2D {
			chart "Transport type" type:histogram 
			series_label_position: onchart
			{
				datalist legend: transport_type_cumulative_usage.keys 
					style: bar
					value: transport_type_cumulative_usage.values
					color:[#green,#blue,#red,#yellow];
			}
		}
		
		
	}
}
