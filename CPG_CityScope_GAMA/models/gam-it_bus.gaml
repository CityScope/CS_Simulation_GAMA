/**
* Name: gamit
* Author: Arno
* Description: Describe here the model and its experiments
* Tags: Tag1, Tag2, TagN
*/

model gamit

global {
	file buildings_shapefile <- file("../includes/volpe/Buildings.shp");
	file amenities_shapefile <- file("../includes/volpe/amenities.shp");
	file roads_shapefile <- file("../includes/volpe/Roads.shp");
	file activity_file <- file("../includes/Activity Table.csv");
	
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
	map<string,rgb> color_per_mobility <- ["walking"::#green, "bike"::#orange,"car"::#red];
	map<string,float> width_per_mobility <- ["walking"::2.0, "bike"::3.0, "car"::4.0];
	map<string,float> speed_per_mobility <- ["walking"::3#km/#h, "bike"::5#km/#h,"car"::10#km/#h];
	map<string,graph> graph_per_mobility;
	init {
		do activity_data_import;
		create road from: roads_shapefile {
			mobility_allowed << "walking";
			mobility_allowed << "bike";
			mobility_allowed << "car";
		}
		
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale"))] ;
		loop am over: amenities_shapefile {
			ask (building closest_to am) {
				usage <- "Restaurant";
				scale <- am get "Scale";
				name <- am get "name";
			} 
		}
		do compute_graph;
		office_buildings <- building where (each.usage = "O");
		residential_buildings <- building where (each.usage = "R");
		do random_init;
		
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
		
		create people number: 100 {
			living_place <- one_of(residential_buildings);
			current_place <- living_place;
			location <- any_location_in(living_place);
			// type <- one_of(color_per_type.keys);
			type <- "College student";
			color <- color_per_type[type];
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));			
			do create_trip_objectives;
		}		
				
	}
	
	user_command "add bus_stop" {
		create bus_stop returns: new_bus_stop {
			location <- #user_location;
		}
		// recompute bus line
		bus_stop closest_bus_stop <- (bus_stop - first(new_bus_stop)) with_min_of(each distance_to(#user_location));
		ask bus {
			
			write closest_bus_stop;
			write stops;
			int i <- (stops index_of(closest_bus_stop));
			write i;
			bus_stop bb <- first(new_bus_stop);
			add bb at: i to: stops ;
			write stops;
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
			graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) with_optimizer_type "Floyd Warshall" use_cache false;	
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


species trip_objective {
	building place; 
	int starting_time;
}


species people skills: [moving]{
	string type;
	rgb color ;
	building living_place;
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	building current_place;
	string mobility_mode;
	bool has_car <- flip(1.0);
	bool has_bike <- flip(1.0);
	
	//
	bus_stop closest_bus_stop;	
	int bus_status <- 0;
	bool in_bus_station <- false;
	
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
				do create_activity(act,act_build,activities[act]);
			}
		}
	}
	
	action create_activity(string act_name, building act_place, int act_time) {
		create trip_objective {
			name <- act_name;
			place <- act_place;
			starting_time <- act_time;
			myself.objectives << self;
		}
	}
	
	action choose_mobility_mode{
		if (has_car) {
			mobility_mode <- flip(1.0) ? "car" : "walking";
		} else {
			mobility_mode <-"walking";
		}
		speed <- speed_per_mobility[mobility_mode];

		speed <- 3#km/#h;		
		mobility_mode <- "bus";
		bus_status <- 0;
	}
	
	reflex choose_objective when: my_current_objective = nil {
		my_current_objective <- objectives first_with (each.starting_time = current_date.hour);
		location <- any_location_in(current_place);
		if (my_current_objective != nil) {
			current_place <- nil;
			do choose_mobility_mode;
		}
	}
	
	reflex move when: my_current_objective != nil and mobility_mode != "bus" {
		do goto target: my_current_objective.place.location on: graph_per_mobility[mobility_mode];
		if (location = my_current_objective.place.location) {
			current_place <- my_current_objective.place;
			location <- any_location_in(current_place);
			my_current_objective <- nil;	
			mobility_mode <- nil;
		}
	}
	
	reflex move_on_bus0 when: (my_current_objective != nil) and (mobility_mode = "bus") and (bus_status = 0){
		do goto target: closest_bus_stop.location on: graph_per_mobility["walking"];
		
		if(location = closest_bus_stop.location) {
			add self to: closest_bus_stop.waiting_people;
			bus_status <- 1;
		}
	}	
	
	reflex move_on_bus2 when: (my_current_objective != nil) and (mobility_mode = "bus") and (bus_status = 2){
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
			} else if (mobility_mode = "bus") {
				if(bus_status != 1) {
					draw cube(10)  color: color ;				
				}
			}
			
		}
	}
}

species road {
	list<string> mobility_allowed;
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
		display map2{
			species building refresh: false;
			species road ;
			species bus_stop aspect: c;
			species bus aspect: bu; 
			species people;
			
		}
	}
}
