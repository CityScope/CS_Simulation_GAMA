/**
* Name: gamit
* Author: Arnaud Grignard, Tri Nguyen Huu, Patrick Taillandier, Benoit Gaudou
* Description: Describe here the model and its experiments
* Tags: Tag1, Tag2, TagN
*/

model gamit

global {
	
	//PARAMETERS
	bool updatePollution <-false parameter: "Pollution:" category: "Simulation";
	bool updateDensity <-false parameter: "Density:" category: "Simulation";
	bool weatherImpact <-true parameter: "Weather impact:" category: "Simulation";
		
	//ENVIRONMENT
	float step <- 1 #sec;
	date starting_date <- date([2021,2,4,8,0]);
	string case_study <- "volpe" ;
	int nb_people <- 500;   //11585;
	
    string cityGISFolder <- "./../includes/City/"+case_study;
	file<geometry> buildings_shapefile <- file<geometry>(cityGISFolder+"/Buildings.shp");
	file<geometry> roads_shapefile <- file<geometry>(cityGISFolder+"/Roads.shp");
	
	
	// MOBILITY DATA
	list<string> mobility_list <- ["walking", "bike","car","bus", "T"];
	file activity_file <- file("./../includes/Game_IT/ActivityPerProfile.csv");
	file criteria_file <- file("./../includes/Game_IT/CriteriaFile.csv");
	file profile_file <- file("./../includes/Game_IT/Profiles2.csv");
	file mode_file <- file("./../includes/Game_IT/Modes2.csv");
	file weather_coeff <- file("./../includes/Game_IT/weather_coeff_per_month.csv");
	
	map<string,rgb> color_per_category <- [ "Restaurant"::rgb("#2B6A89"), "Night"::rgb("#1B2D36"),"GP"::rgb("#244251"), "Cultural"::rgb("#2A7EA6"), "Shopping"::rgb("#1D223A"), "HS"::rgb("#FFFC2F"), "Uni"::rgb("#807F30"), "O"::rgb("#545425"), "R"::rgb("#222222"), "Park"::rgb("#24461F")];	
	map<string,rgb> color_per_type <- [ "High School Student"::rgb("#FFFFB2"), "College student"::rgb("#FECC5C"),"Young professional"::rgb("#FD8D3C"),  "Mid-career workers"::rgb("#F03B20"), "Executives"::rgb("#BD0026"), "Home maker"::rgb("#0B5038"), "Retirees"::rgb("#8CAB13")];
	
	map<string,map<string,int>> activity_data;
	map<string, float> proportion_per_type;
	map<string, float> proba_bike_per_type;
	map<string, float> proba_car_per_type;	
	map<string,rgb> color_per_mobility;
	map<string,float> width_per_mobility ;
	map<string,float> speed_per_mobility;
	map<string,graph> graph_per_mobility;
	map<rgb,graph> graph_per_mobility_train;
	map<string,float> weather_coeff_per_mobility;
	map<string,list<float>> charact_per_mobility;
	map<road,float> congestion_map;  
	map<string,map<string,list<float>>> weights_map <- map([]);
	list<list<float>> weather_of_month;
	
	// NEW DATA
	list<int> listBusRoutes;
	list<rgb> listTrainLines;
	map<string, float> proba_bus_per_type;
	map<string, float> proba_train_per_type;
	
	// INDICATOR
	map<string,int> transport_type_cumulative_usage <- map(mobility_list collect (each::0));
	map<string,int> transport_type_usage <- map(mobility_list collect (each::0));
	map<string,float> transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
	map<string, int> buildings_distribution <- map(color_per_category.keys collect (each::0));
	
	float weather_of_day min: 0.0 max: 1.0;	

	// TRANSPORT FILES
	file<geometry> tLines_shapefile <- file<geometry>(cityGISFolder+"/kendall_Tline.shp");
	file<geometry> tStops_shapefile <- file<geometry>(cityGISFolder+"/kendall_TStops.shp");
	file<geometry> bStops_shapefile <- file<geometry>(cityGISFolder+"/kendall_busStop.shp");
	geometry shape <- envelope(tLines_shapefile);
	
	
	init {
		gama.pref_display_flat_charts <- true;
		do import_shapefiles;	
		do profils_data_import;
		do activity_data_import;
		do criteria_file_import;
		do characteristic_file_import;
		do import_weather_data;
		do create_train_lines;
		do compute_graph;
		
		
		create bus_stop from: bStops_shapefile with: [route::int(read("ROUTE")), station_num::int(read("STOP_NUM"))]{
			if (listBusRoutes contains route = false){
				listBusRoutes << route;
			}
		}
		
		int cont <- 0;
		create bus number: length(listBusRoutes) {
			route  <- listBusRoutes[cont];
			list<bus_stop> stops_list <- list(bus_stop where (each.route = route));
			stops <- stops_list sort_by (each.station_num);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
			cont_station <- 0;
			ascending <- true;
			cont <- cont + 1;
		}
		
		create train_stop from: tStops_shapefile with: [line::rgb(read("LINE")), station::string(read("STATION")), station_num::int(read("STOP_NUM"))]{
		}
		
		create train {
			list<train_stop> train_stops_list <- list(train_stop);
			map<rgb, list<train_stop>> train_stops_per_color;
			list<rgb> already_color;
			loop indiv_stop over: train_stops_list{
				rgb indiv_color <- indiv_stop.line;
				if (already_color contains indiv_color = false){
					already_color << indiv_color;
					list<train_stop> equal_color_list <- [];
					loop equal_color over: train_stops_list{
						if (equal_color != self and equal_color.line = indiv_color){
							equal_color_list << equal_color;
						}
					}
					train_stops_per_color[indiv_color] <- equal_color_list;  
				}
			}
			
			loop color_stops over: train_stops_per_color.keys{
				create train {
					line <- color_stops;
					list<train_stop> stops_list <- list(train_stop where (each.line = line)); 
					stops <- stops_list sort_by (each.station_num);
					location <- first(stops).location;
					stop_passengers <- map<train_stop, list<people>>(stops collect(each::[]));
					cont_station <- 0;
					ascending <- true;	 
				}
			}
			if (line=nil) {
					do die;
			}
		}
		
		create people number: nb_people {
			type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
			has_car <- flip(proba_car_per_type[type]);
			has_bike <- flip(proba_bike_per_type[type]);
			living_place <- one_of(building where (each.usage = "R"));
			current_place <- living_place;
			location <- any_location_in(living_place);
			color <- color_per_type[type];
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));
			closest_train_stop <- train_stop with_min_of(each distance_to(self));						
			do create_trip_objectives;
		}	
		save "cycle,walking,bike,car,bus,train,average_speed,walk_distance,bike_distance,car_distance,bus_distance,bus_people_distance,train_distance" to: "../results/mobility.csv";
	}
	
	
    reflex save_simu_attribute when: (cycle mod 100 = 0){
    	save [cycle,transport_type_usage.values[0] ,transport_type_usage.values[1], transport_type_usage.values[2], transport_type_usage.values[3], mean (people collect (each.speed)), transport_type_distance.values[0],transport_type_distance.values[1],transport_type_distance.values[2],transport_type_distance.values[3],transport_type_distance.values[4]] rewrite:false to: "../results/mobility.csv" type:"csv";
	    // Reset value
	    transport_type_usage <- map(mobility_list collect (each::0));
	    transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
	    if(cycle = 10000){
	    	do pause;
	    }
	}
	
	action import_weather_data {
		matrix weather_matrix <- matrix(weather_coeff);
		loop i from: 0 to:  weather_matrix.rows - 1 {
			weather_of_month << [float(weather_matrix[1,i]), float(weather_matrix[2,i])];
		}
	}
	
	action profils_data_import {
		matrix profile_matrix <- matrix(profile_file);
		loop i from: 0 to:  profile_matrix.rows - 1 {
			string profil_type <- profile_matrix[0,i];
			if(profil_type != "") {
				proba_bike_per_type[profil_type] <- float(profile_matrix[2,i]);
				proba_bus_per_type[profil_type] <- float(profile_matrix[3,i]);
				proba_car_per_type[profil_type] <- float(profile_matrix[4,i]);
				proba_train_per_type[profil_type] <- float(profile_matrix[5,i]);
				proportion_per_type[profil_type] <- float(profile_matrix[6,i]);
			}
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
	
	action characteristic_file_import {
		matrix mode_matrix <- matrix (mode_file);
		loop i from: 0 to:  mode_matrix.rows - 1 {
			string mobility_type <- mode_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to:  mode_matrix.columns - 2 {
					vals << float(mode_matrix[j,i]);	
				}
				charact_per_mobility[mobility_type] <- vals;
				color_per_mobility[mobility_type] <- rgb(mode_matrix[7,i]);
				width_per_mobility[mobility_type] <- float(mode_matrix[8,i]);
				speed_per_mobility[mobility_type] <- float(mode_matrix[9,i]);
				weather_coeff_per_mobility[mobility_type] <- float(mode_matrix[10,i]);	
			}			
		}
	}
		
	action import_shapefiles {
		create road from: roads_shapefile {
			mobility_allowed <-["walking","bike","car","bus"];
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale")),category::string(read ("Category"))]{
			color <- color_per_category[category];
		}
	}	
	
	action create_train_lines {
		create train_line from: tLines_shapefile with: [line::rgb(read("colorLine"))] {	
			mobility_allowed <- ["T"];
			if(listTrainLines contains line = false) {
				listTrainLines << line;
			}
		}
	}
		
	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			if(mobility_mode != "T"){
				graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;
			}
			else{
				loop i from: 0 to: length(listTrainLines) - 1{
					graph_per_mobility_train[listTrainLines[i]] <- as_edge_graph(train_line where(each.line = listTrainLines[i])) use_cache false;
				}
			}		
		}
	}
		
	reflex update_road_weights {
		ask road {
			do update_speed_coeff;	
			congestion_map [self] <- speed_coeff;
		}
	}
	
	reflex update_buildings_distribution{
		buildings_distribution <- map(color_per_category.keys collect (each::0));
		ask building{
			buildings_distribution[usage] <- buildings_distribution[usage]+1;
		}
	}
	
	reflex update_weather when: weatherImpact and every(#day){
		list<float> weather_m <- weather_of_month[current_date.month - 1];
		weather_of_day <- gauss(weather_m[0], weather_m[1]);
	}		
}

species trip_objective{
	building place; 
	int starting_hour;
	int starting_minute;
}

species bus_stop {
	list<people> waiting_people;
	int route;
	int station_num;
	
	aspect c {
		draw circle(20) color: empty(waiting_people)?#blue:#blue border: #black depth:1;
	}
}

species bus skills: [moving] {
	list<bus_stop> stops; 
	map<bus_stop,list<people>> stop_passengers ;
	bus_stop my_target;
	int route;
	int cont_station;
	bool ascending;
	int stop_time;
	
	reflex new_target when: my_target = nil{
		bus_stop StopNow <- stops[cont_station];
		if(cont_station = length(stops)-1 and ascending = true){
			cont_station <- cont_station - 1; 
			ascending <- false;
		}
		else if(cont_station = 0 and ascending = false){
			cont_station <- cont_station + 1;
			ascending <- true;
		}
		else {
			if(ascending = true){
				cont_station <- cont_station + 1;
			}
			else{
				cont_station <- cont_station - 1;
			}
		}
		my_target <- StopNow;
	}
	
	reflex r {
		if(stop_time = 0){
			do goto target: my_target.location on: graph_per_mobility["car"] speed:speed_per_mobility["bus"];
			int nb_passengers <- stop_passengers.values sum_of (length(each));
			if (nb_passengers > 0) {
				transport_type_distance["bus"] <- transport_type_distance["bus"] + speed/step;
				transport_type_distance["bus_people"] <- transport_type_distance["bus_people"] + speed/step * nb_passengers;
				}
		}
		else{
			stop_time <- stop_time - 1;
		}
			
		if(location = my_target.location) {
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				bus_status <- 2;
			}
			stop_passengers[my_target] <- [];
			loop p over: my_target.waiting_people {
				bus_stop b <- bus_stop with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b] ;
			}
			my_target.waiting_people <- [];						
			my_target <- nil;
			stop_time <- 30;		
		}
	}
	
	aspect bu {
		draw rectangle(40,20) color: empty(stop_passengers.values accumulate(each))?#yellow:#red border: #black;
	}
}

species train_line parent:road{
	rgb line;
	list<string> mobility_allowed;
	
	aspect default{
		draw shape color: line;
	}
}

species train_stop{
	string station;
	rgb line;
	list<people> waiting_people;
	int station_num;
	
	aspect default{
		if (station != "boundary"){
			draw square(40) color: line;
		}
	}
}

species train skills: [moving] {
	list<train_stop> stops; 
	map<train_stop,list<people>> stop_passengers ;
	train_stop my_target;
	rgb line;
	int cont_station;
	bool ascending;
	int stop_time;

	reflex new_target when: my_target = nil{
		train_stop StopNow <- stops[cont_station];
		if(cont_station = length(stops)-1 and ascending = true){
			cont_station <- cont_station - 1;
			ascending <- false;
		}
		else if(cont_station = 0 and ascending = false){
			cont_station <- cont_station + 1;
			ascending <- true;
		}
		else {
			if(ascending = true){
				cont_station <- cont_station + 1;
			}
			else{
				cont_station <- cont_station - 1;
			}
		}
		my_target <- StopNow;
	}
	
	reflex r {
		if (stop_time = 0){
			do goto target: my_target.location on: graph_per_mobility_train[line] speed:speed_per_mobility["T"]*0.5;
			int nb_passengers <- stop_passengers.values sum_of (length(each));
		}
		else{
			stop_time <- stop_time - 1;
		}
		
		if(location = my_target.location) {
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				train_status <- 2;
			}
			stop_passengers[my_target] <- [];
			loop p over: my_target.waiting_people {
				train_stop b <- train_stop where(each.line = line) with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b];
			}
			my_target.waiting_people <- [];						
			my_target <- nil;	
			stop_time <- 30;		
		}
	}
	
	aspect default {
		draw rectangle(60,20) color: line border: #black;
	}
}

grid gridHeatmaps height: 50 width: 50 {
	int pollution_level <- 0 ;
	int density<-0;
	rgb pollution_color <- rgb(255-pollution_level*10,255-pollution_level*10,255-pollution_level*10) update:rgb(255-pollution_level*10,255-pollution_level*10,255-pollution_level*10);
	rgb density_color <- rgb(255-density*50,255-density*50,255-density*50) update:rgb(255-density*50,255-density*50,255-density*50);
	
	aspect density{
		draw shape color:density_color at:{location.x+current_date.hour*world.shape.width,location.y};
	}
	
	aspect pollution{
		draw shape color:pollution_color;
	}
	
	reflex raz when: every(1#hour) {
		pollution_level <- 0;
	}
}

species people skills: [moving]{
	string type;
	rgb color ;
	float size<-5#m;	
	building living_place;
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	building current_place;
	string mobility_mode;
	list<string> possible_mobility_modes;
	bool has_car ;
	bool has_bike;

	bus_stop closest_bus_stop;	
	int bus_status <- 0;
	train_stop closest_train_stop;
	int train_status <- 0;
	
	action create_trip_objectives {
		map<string,int> activities <- activity_data[type];
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
					possible_bds <- building where (each.category = act_real);
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
		transport_type_usage[mobility_mode] <- transport_type_usage[mobility_mode]+1;
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
			cand << characteristic[4];
		
			cand << characteristic[5] * (weatherImpact ?(1.0 + weather_of_day * weather_coeff_per_mobility[mode]  ) : 1.0);
			add cand to: candidates;
		}
		list<float> max_values;
		loop i from: 0 to: length(candidates[0]) - 1 {
			max_values << max(candidates collect abs(float(each[i])));
		}
		loop cand over: candidates {
			loop i from: 0 to: length(cand) - 1 {
				if ( max_values[i] != 0.0) {
					cand[i] <- float(cand[i]) / max_values[i];
				}	
			}
		}
		return candidates;
	}
	
	action updatePollutionMap{
		ask gridHeatmaps overlapping(current_path.shape) {
			pollution_level <- pollution_level + 1;
		}
	}	
	
	reflex updateDensityMap when: (every(#hour) and updateDensity=true){
		ask gridHeatmaps{
		  density<-length(people overlapping self);	
		}
	}
	
	reflex choose_objective when: my_current_objective = nil {
	    //location <- any_location_in(current_place);
		do wander speed:0.01;
		my_current_objective <- objectives first_with ((each.starting_hour = current_date.hour) and (current_date.minute >= each.starting_minute) and (current_place != each.place) );
		if (my_current_objective != nil) {
			current_place <- nil;
			possible_mobility_modes <- ["walking"];
			if (has_car) {possible_mobility_modes << "car";}
			if (has_bike) {possible_mobility_modes << "bike";}
			possible_mobility_modes << "bus";
			possible_mobility_modes << "T";			
			do choose_mobility_mode;
		}
	}
	
	reflex move when: (my_current_objective != nil) and (mobility_mode != "bus") and (mobility_mode!="T") {
		transport_type_distance[mobility_mode] <- transport_type_distance[mobility_mode] + speed/step;
		if ((current_edge != nil) and (mobility_mode in ["car"])) {
			road(current_edge).current_concentration <- max([0,road(current_edge).current_concentration - 1]);
		}
		if (mobility_mode in ["car"]) {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode] move_weights: congestion_map ;
		}
		else {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode]  ;
		}
		if (location = my_current_objective.place.location) {
			if(mobility_mode = "car" and updatePollution = true) {do updatePollutionMap;}					
			current_place <- my_current_objective.place;
			location <- any_location_in(current_place);
			my_current_objective <- nil;	
			mobility_mode <- nil;
		}
		else {
			if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- road(current_edge).current_concentration + 1; }
		}
	}
	
	reflex move_bus when: (my_current_objective != nil) and (mobility_mode = "bus") {
		if (bus_status = 0){
			do goto target: closest_bus_stop.location on: graph_per_mobility["walking"];
			transport_type_distance["walking"] <- transport_type_distance["walking"] + speed/step;
			if(location = closest_bus_stop.location) {
				add self to: closest_bus_stop.waiting_people;
				bus_status <- 1;
			}
		}
		else if (bus_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility["walking"];		
			transport_type_distance["walking"] <- transport_type_distance["walking"] + speed/step;
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
	
	reflex move_train when: (my_current_objective != nil) and (mobility_mode = "T") {
		if (train_status = 0){
			do goto target: closest_train_stop.location on: graph_per_mobility["walking"];
			if(location = closest_train_stop.location) {
				add self to: closest_train_stop.waiting_people;
				train_status <- 1;
			}
		}
		else if (train_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility["walking"];
			if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				closest_train_stop <- train_stop with_min_of(each distance_to(self));						
				location <- any_location_in(current_place);
				my_current_objective <- nil;	
				train_status <- 0;
			}
		}
	}
	
	aspect default {
		if (mobility_mode = nil) {
			draw circle(size) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4}  color: color ;
		}
		else {
			if (mobility_mode = "walking") {
				draw circle(size) color: color  ;
			}
			else if (mobility_mode = "bike") {
				draw triangle(size) rotate: heading +90  color: color depth: 8 ;
			}
			else if (mobility_mode = "car") {
				draw square(size*2)  color: color ;
			}
			else if (mobility_mode = "T") {
				draw circle(size) color:color;
			}
		}
	}
	
	aspect base{
	  draw circle(size) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4}  color: color ;
	}
	
	aspect layer {
		if(cycle mod 180 = 0){
			draw sphere(size) at: {location.x,location.y,cycle*2} color: color ;
		}
	}
}

species road  {
	list<string> mobility_allowed;
	float capacity;
	float max_speed <- 40 #km/#h;
	float current_concentration;
	float speed_coeff <- 1.0;
	
	action update_speed_coeff {
		speed_coeff <- shape.perimeter / max([0.01,exp(-current_concentration/capacity)]);
	}
	
	aspect default {	
		draw shape color:rgb(125,125,125);
	}
	
	aspect mobility {
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
	string category;
	rgb color <- #grey;
	float height <- 0.0; //50.0 + rnd(50);
	aspect default {
		draw shape color: color;
	}
	aspect depth {
		draw shape color: color  depth: height;
	}
}


species externalCities parent:building{
	string id;
	point real_location;
	point entry_location;
	list<float> people_distribution;
	list<float> building_distribution;
	list<building> external_buildings;
	
	aspect base{
		draw circle(100) color:#yellow at:real_location;
		draw circle(100) color:#red at:entry_location;
	}
}

experiment gameit type: gui {
	output {
		display map type: opengl draw_env: false background: #black refresh:every(10#cycle){
			//species gridHeatmaps aspect:pollution;
			//species pie;
			species bus_stop aspect:c;
			species building aspect:depth refresh: false;
			species road;
			species train_line;
			species train_stop;
			species people aspect:base ;
			species externalCities aspect:base;
			species train aspect:default;
			species bus aspect:bu;
								
			graphics "time" {
				draw string(current_date.hour) + "h" + string(current_date.minute) +"m" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.9,world.shape.height*0.55};
			}
			
			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 1.0 border: #black {
                rgb text_color<-#white;
                float y <- 30#px;
  				draw "Building Usage" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
                y <- y + 30 #px;
                loop type over: color_per_category.keys {
                    draw square(10#px) at: { 20#px, y } color: color_per_category[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 16, #plain) perspective:false;
                    y <- y + 25#px;
                }
                y <- y + 30 #px;     
                draw "People Type" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
                y <- y + 30 #px;
                loop type over: color_per_type.keys {
                    draw square(10#px) at: { 20#px, y } color: color_per_type[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 16, #plain) perspective:false;
                    y <- y + 25#px;
                }
				y <- y + 30 #px;
                draw "Mobility Mode" at: { 40#px, 600#px } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
                map<string,rgb> list_of_existing_mobility <- map<string,rgb>(["Walking"::#green,"Bike"::#yellow,"Car"::#red,"Bus"::#blue, "T"::#orange]);
                y <- y + 30 #px;
                
                loop i from: 0 to: length(list_of_existing_mobility) -1 {    
                  // draw circle(10#px) at: { 20#px, 600#px + (i+1)*25#px } color: list_of_existing_mobility.values[i]  border: #white;
                   draw list_of_existing_mobility.keys[i] at: { 40#px, 610#px + (i+1)*20#px } color: list_of_existing_mobility.values[i] font: font("Helvetica", 18, #plain) perspective:false; 			
		        }     
            }
            
/***        chart "Cumulative Trip" background:#black type: pie style:ring size: {0.5,0.5} position: {world.shape.width*1.1,world.shape.height*0} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(transport_type_cumulative_usage.keys)-1	{
				  data transport_type_cumulative_usage.keys[i] value: transport_type_cumulative_usage.values[i] color:color_per_mobility[transport_type_cumulative_usage.keys[i]];
				}
			}
			chart "People Distribution" background:#black  type: pie size: {0.5,0.5} position: {world.shape.width*1.1,world.shape.height*0.5} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Helvetica' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Helvetica' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(proportion_per_type.keys)-1	{
				  data proportion_per_type.keys[i] value: proportion_per_type.values[i] color:color_per_type[proportion_per_type.keys[i]];
				}
			}
***/		
		} 				
	}
}
