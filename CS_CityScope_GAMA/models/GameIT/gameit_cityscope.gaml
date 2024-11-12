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
	bool CityIO <- true parameter: "CityIO connection:" category: "Simulation";

	//ENVIRONMENT
	float step <- 1 #mn;
	date starting_date <-date([2017,9,25,0,0]);
	string case_study <- "volpe";
	int nb_people <- 500;

	string cityGISFolder <- "./../../includes/City/"+case_study;
	file<geometry> buildings_shapefile <- file<geometry>(cityGISFolder+"/Buildings.shp");
	file<geometry> roads_shapefile <- file<geometry>(cityGISFolder+"/Roads.shp");
	geometry shape <- envelope(roads_shapefile);

	// MOBILITY DATA
	list<string> mobility_list <- ["walking", "bike","car","bus"];
	file activity_file <- file("./../../includes/Game_IT/ActivityPerProfile.csv");
	file criteria_file <- file("./../../includes/Game_IT/CriteriaFile.csv");
	file profile_file <- file("./../../includes/Game_IT/Profiles.csv");
	file mode_file <- file("./../../includes/Game_IT/Modes.csv");
	file weather_coeff <- file("./../../includes/Game_IT/weather_coeff_per_month.csv");

	map<string,rgb> color_per_category <- [ "Restaurant"::rgb("#2B6A89"), "Night"::rgb("#1B2D36"),"GP"::rgb("#244251"), "Cultural"::rgb("#2A7EA6"), "Shopping"::rgb("#1D223A"), "HS"::rgb("#FFFC2F"), "Uni"::rgb("#807F30"), "O"::rgb("#545425"), "R"::rgb("#222222"), "Park"::rgb("#24461F")];
	map<string,rgb> color_per_type <- [ "High School Student"::rgb("#FFFFB2"), "College student"::rgb("#FECC5C"),"Young professional"::rgb("#FD8D3C"), "Mid-career workers"::rgb("#F03B20"), "Executives"::rgb("#BD0026"), "Home maker"::rgb("#0B5038"), "Retirees"::rgb("#8CAB13")];

	map<string,map<string,int>> activity_data;
	map<string, float> proportion_per_type;
	map<string, float> proba_bike_per_type;
	map<string, float> proba_car_per_type;
	map<string,rgb> color_per_mobility;
	map<string,float> width_per_mobility;
	map<string,float> speed_per_mobility;
	map<string,graph> graph_per_mobility;
	map<string,float> weather_coeff_per_mobility;
	map<string,list<float>> charact_per_mobility;
	map<road,float> congestion_map;
	map<string,map<string,list<float>>> weights_map <- map([]);
	list<list<float>> weather_of_month;

	// INDICATOR
	map<string,int> transport_type_cumulative_usage <- map(mobility_list collect (each::0));
	map<string,int> transport_type_usage <- map(mobility_list collect (each::0));
	map<string,float> transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
	map<string, int> buildings_distribution <- map(color_per_category.keys collect (each::0));

	float weather_of_day min: 0.0 max: 1.0;

	init {
		gama.pref_display_flat_charts <- true;
		do import_shapefiles;
		do profils_data_import;
		do activity_data_import;
		do criteria_file_import;
		do characteristic_file_import;
		do import_weather_data;
		do compute_graph;

		create bus_stop number: 6 {
			location <- one_of(building).location;
		}

		create bus {
			stops <- list(bus_stop);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
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
			do create_trip_objectives;
		}
		save "cycle,walking,bike,car,bus,average_speed,walk_distance,bike_distance,car_distance,bus_distance, bus_people_distance" to: "../results/mobility.csv";

		if CityIO {
			create Networking_Client {
				do connect to: "localhost" protocol: "websocket_client" port: 8080 with_name: "Client" raw: true;

//				string buildings <- to_geojson(buildings_shapefile.contents(),"EPSG:4326",[]);
//				save buildings to: "geojson.txt" rewrite: (cycle = 0);
//
//				buildings <- '[{"id": "geojson", "type": "geojsonbase", "data": ' + buildings + ', "properties": {"filled": false}}]';
//				do send to: "ws://localhost:8080" contents: buildings;
			}
		}
	}

	reflex save_simu_attribute when: (cycle mod 100 = 0){
		save [cycle,transport_type_usage.values[0] ,transport_type_usage.values[1], transport_type_usage.values[2], transport_type_usage.values[3], mean (people collect (each.speed)), transport_type_distance.values[0],transport_type_distance.values[1],transport_type_distance.values[2],transport_type_distance.values[3],transport_type_distance.values[4]] rewrite:false to: "../results/mobility.csv" type:"csv";
		// Reset value
		transport_type_usage <- map(mobility_list collect (each::0));
		transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
		if(cycle = 5000){
			do pause;
		}
	}


	action import_weather_data {
		matrix weather_matrix <- matrix(weather_coeff);
		loop i from: 0 to: weather_matrix.rows - 1 {
			weather_of_month << [float(weather_matrix[1,i]), float(weather_matrix[2,i])];
		}
	}
	action profils_data_import {
		matrix profile_matrix <- matrix(profile_file);
		loop i from: 0 to: profile_matrix.rows - 1 {
			string profil_type <- profile_matrix[0,i];
			if(profil_type != "") {
				proba_car_per_type[profil_type] <- float(profile_matrix[2,i]);
				proba_bike_per_type[profil_type] <- float(profile_matrix[3,i]);
				proportion_per_type[profil_type] <- float(profile_matrix[4,i]);
			}
		}
	}



	action activity_data_import {
		matrix activity_matrix <- matrix (activity_file);
		loop i from: 1 to: activity_matrix.rows - 1 {
			string people_type <- activity_matrix[0,i];
			map<string, int> activities;
			string current_activity <- "";
			loop j from: 1 to: activity_matrix.columns - 1 {
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
		int nbTO <- criteria_matrix[1,1] as int;
		int lignCategory <- 2;
		int lignCriteria <- 3;

		loop i from: 5 to: criteria_matrix.rows - 1 {
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
					string cat_name <- criteria_matrix[index-nbTO,lignCategory];
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
		loop i from: 0 to: mode_matrix.rows - 1 {
			string mobility_type <- mode_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to: mode_matrix.columns - 2 {
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


	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;
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

species Networking_Client skills: [network] {
	reflex statistics when: CityIO and (cycle mod 2 = 0) {
		int ind <- 0;

		float total <- 10^(-9);
		loop i from: 0 to: length(transport_type_cumulative_usage.keys)-1 {
			total <- total + float(transport_type_cumulative_usage.values[i]);
		}

		string layers <- '{"type": "bar", "data": {';
		loop i from: 0 to: length(transport_type_cumulative_usage.keys)-2 {
			layers <- layers + '"' + transport_type_cumulative_usage.keys[i] + '": {"value": ' +
			transport_type_cumulative_usage.values[i]/total + ', "description": "An example ' + (i+1) + '"}, ';
			ind <- i;
		}
		layers <- layers + '"' + transport_type_cumulative_usage.keys[ind+1] + '": {"value": ' +
		transport_type_cumulative_usage.values[ind+1]/total + ', "description": "An example ' + (ind+2) + '"}}, "properties":{}},';

		layers <- layers + '{"type": "radar", "data": {';
		loop i from: 0 to: length(transport_type_cumulative_usage.keys)-2 {
			layers <- layers + '"' + transport_type_cumulative_usage.keys[i] + '": {"value": ' +
			transport_type_cumulative_usage.values[i]/total + ', "description": "An example ' + (i+1) + '"}, ';
			ind <- i;
		}
		layers <- layers + '"' + transport_type_cumulative_usage.keys[ind+1] + '": {"value": ' +
		transport_type_cumulative_usage.values[ind+1]/total + ', "description": "An example ' + (ind+2) + '"}}, "properties":{}},';

		list people_list <- list(people);

		layers <- layers + '{"id": "simpleMesh", "type": "simpleMesh", "data": [';
		loop i from: 0 to: length(people_list)-2 {
			ask (people_list at i) {
				geometry geom_pos <- CRS_transform(({location.x, location.y}),'EPSG:4326');
				layers <- layers + '{"position": [' + geom_pos.location.x + ', ' +
				geom_pos.location.y + '], "angle": 0, "color": ' + rgba_to_rgb(color) + '},';
				ind <- i;
			}
		}

		ask (people_list at (ind+1)) {
			geometry geom_pos <- CRS_transform(({location.x, location.y}),'EPSG:4326');
			layers <- layers + '{"position": [' + geom_pos.location.x + ', ' +
			geom_pos.location.y + '], "angle": 0, "color": ' + rgba_to_rgb(color) + '}],' +
			'"properties": {"mesh": "https://raw.githubusercontent.com/visgl/deck.gl-data/master/website/humanoid_quad.obj"}}';
		}

		do send to: "ws://localhost:8080" contents: "[" + layers + "]";
	}
}

species trip_objective{
	building place;
	int starting_hour;
	int starting_minute;
}

species bus_stop {
	list<people> waiting_people;

	aspect c {
		draw circle(30) color: empty(waiting_people)?#black:#blue border: #black depth:1;
	}
}

species bus skills: [moving] {
	list<bus_stop> stops;
	map<bus_stop,list<people>> stop_passengers;
	bus_stop my_target;

	reflex new_target when: my_target = nil{
		bus_stop firstStop <- first(stops);
		remove firstStop from: stops;
		add firstStop to: stops;
		my_target <- firstStop;
	}

	reflex r {
		do goto target: my_target.location on: graph_per_mobility["car"] speed:speed_per_mobility["bus"];
		int nb_passengers <- stop_passengers.values sum_of (length(each));
		if (nb_passengers > 0) {
				transport_type_distance["bus"] <- transport_type_distance["bus"] + speed/step;
				transport_type_distance["bus_people"] <- transport_type_distance["bus_people"] + speed/step * nb_passengers;
		}

		if(location = my_target.location) {
			//////// release some people
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				bus_status <- 2;
			}
			stop_passengers[my_target] <- [];
			///////// get some people
			loop p over: my_target.waiting_people {
				bus_stop b <- bus_stop with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b];
			}
			my_target.waiting_people <- [];
			my_target <- nil;
		}
	}

	aspect bu {
		draw rectangle(40,20) color: empty(stop_passengers.values accumulate(each))?#yellow:#red border: #black;
	}
}

grid gridHeatmaps height: 50 width: 50 {
	int pollution_level <- 0;
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
	rgb color;
	float size<-5#m;
	building living_place;
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	building current_place;
	string mobility_mode;
	list<string> possible_mobility_modes;
	bool has_car;
	bool has_bike;

	bus_stop closest_bus_stop;
	int bus_status <- 0;

	string rgba_to_rgb(rgb rgba) {
		int r <- rgba.red();
		int g <- rgba.green();
		int b <- rgba.blue();
		int a <- rgba.alpha();

		float alpha_normalized <- a/255.0;

		float r_final <- r * alpha_normalized + 255 * (1 - alpha_normalized);
		float g_final <- g * alpha_normalized + 255 * (1 - alpha_normalized);
		float b_final <- b * alpha_normalized + 255 * (1 - alpha_normalized);

		return '[' + r_final + ', ' + g_final + ', ' + b_final + ']';
	}

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
		map<string,list<float>> crits <- weights_map[type];
		list<float> vals;
		loop obj over:crits.keys {
			if (obj = my_current_objective.name) or
			   ((my_current_objective.name in ["RS", "RM", "RL"]) and (obj = "R")) or
			   ((my_current_objective.name in ["OS", "OM", "OL"]) and (obj = "O")) {
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
		transport_type_usage[mobility_mode] <-transport_type_usage[mobility_mode]+1;
		speed <- speed_per_mobility[mobility_mode];
	}

	list<list> mobility_mode_eval {
		list<list> candidates;
		loop mode over: possible_mobility_modes {
			list<float> characteristic <- charact_per_mobility[mode];
			list<float> cand;
			float distance <- 0.0;
			using topology(graph_per_mobility[mode]){
				distance <- distance_to (location,my_current_objective.place.location);
			}
			cand << characteristic[0] + characteristic[1]*distance;
			cand << characteristic[2] #mn + distance / speed_per_mobility[mode];
			cand << characteristic[4];

			cand << characteristic[5] * (weatherImpact ?(1.0 + weather_of_day * weather_coeff_per_mobility[mode]) : 1.0);
			add cand to: candidates;
		}

		//normalisation
		list<float> max_values;
		loop i from: 0 to: length(candidates[0]) - 1 {
			max_values << max(candidates collect abs(float(each[i])));
		}
		loop cand over: candidates {
			loop i from: 0 to: length(cand) - 1 {
				if ( max_values[i] != 0.0) {cand[i] <- float(cand[i]) / max_values[i];}

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
			do choose_mobility_mode;
		}
	}
	reflex move when: (my_current_objective != nil) and (mobility_mode != "bus") {
		transport_type_distance[mobility_mode] <- transport_type_distance[mobility_mode] + speed/step;
		if ((current_edge != nil) and (mobility_mode in ["car"])) {road(current_edge).current_concentration <- max([0,road(current_edge).current_concentration - 1]); }
		if (mobility_mode in ["car"]) {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode] move_weights: congestion_map;
		}else {
			do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode];
		}

		if (location = my_current_objective.place.location) {
			if(mobility_mode = "car" and updatePollution = true) {do updatePollutionMap;}
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
			transport_type_distance["walking"] <- transport_type_distance["walking"] + speed/step;

			if(location = closest_bus_stop.location) {
				add self to: closest_bus_stop.waiting_people;
				bus_status <- 1;
			}
		} else if (bus_status = 2){
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

	aspect default {
		if (mobility_mode = nil) {
			draw circle(size) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4} color: color;
		} else {
			if (mobility_mode = "walking") {
				draw circle(size) color: color;
			}else if (mobility_mode = "bike") {
				draw triangle(size) rotate: heading +90 color: color depth: 8;
			} else if (mobility_mode = "car") {
				draw square(size*2) color: color;
			}
		}
	}


	aspect base{
		draw circle(size) at: location + {0,0,(current_place != nil ?current_place.height : 0.0) + 4} color: color;
	}
	aspect layer {
		if(cycle mod 180 = 0){
			draw sphere(size) at: {location.x,location.y,cycle*2} color: color;
		}
	}
}

species road {
	list<string> mobility_allowed;
	float capacity;
	float max_speed <- 30 #km/#h;
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
		draw shape width: width_per_mobility[max_mobility] color:color_per_mobility[max_mobility];
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
	float height <- 0.0;//50.0 + rnd(50);
	aspect default {
		draw shape color: color;
	}
	aspect depth {
		draw shape color: color depth: height;
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
			species building aspect:depth refresh: false;
			species road;
			species people aspect:base;
			species externalCities aspect:base;

			graphics "time" {
				draw string(current_date.hour) + "h" + string(current_date.minute) +"m" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.9,world.shape.height*0.55};
			}

			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 1.0 border: #black
			{

				rgb text_color<-#white;
				float y <- 30#px;
				draw "Building Usage" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
				y <- y + 30 #px;
				loop type over: color_per_category.keys
				{
					draw square(10#px) at: { 20#px, y } color: color_per_category[type] border: #white;
					draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 16, #plain) perspective:false;
					y <- y + 25#px;
				}
				 y <- y + 30 #px;
				draw "People Type" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
				y <- y + 30 #px;
				loop type over: color_per_type.keys
				{
					draw square(10#px) at: { 20#px, y } color: color_per_type[type] border: #white;
					draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 16, #plain) perspective:false;
					y <- y + 25#px;
				}
				y <- y + 30 #px;
				draw "Mobility Mode" at: { 40#px, 600#px } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
				map<string,rgb> list_of_existing_mobility <- map<string,rgb>(["Walking"::#green,"Bike"::#yellow,"Car"::#red,"Bus"::#blue]);
				y <- y + 30 #px;

				loop i from: 0 to: length(list_of_existing_mobility) -1 {
					// draw circle(10#px) at: { 20#px, 600#px + (i+1)*25#px } color: list_of_existing_mobility.values[i] border: #white;
					draw list_of_existing_mobility.keys[i] at: { 40#px, 610#px + (i+1)*20#px } color: list_of_existing_mobility.values[i] font: font("Helvetica", 18, #plain) perspective:false;
				}
			}

			chart "Cumulative Trip" background:#black type: pie style:ring size: {0.5,0.5} position: {world.shape.width*1.1,world.shape.height*0} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(transport_type_cumulative_usage.keys)-1 {
					data transport_type_cumulative_usage.keys[i] value: transport_type_cumulative_usage.values[i] color:color_per_mobility[transport_type_cumulative_usage.keys[i]];
				}
			}
			chart "People Distribution" background:#black type: pie size: {0.5,0.5} position: {world.shape.width*1.1,world.shape.height*0.5} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0
			tick_font: 'Helvetica' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Helvetica' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(proportion_per_type.keys)-1 {
					data proportion_per_type.keys[i] value: proportion_per_type.values[i] color:color_per_type[proportion_per_type.keys[i]];
				}
			}
		}
	}
}
