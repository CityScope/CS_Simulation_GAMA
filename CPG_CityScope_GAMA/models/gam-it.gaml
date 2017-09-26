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
	graph road_network;
	list<building> residential_buildings;
	list<building> office_buildings;
	map<string, rgb> color_per_type <- ["High School Student"::#lightblue, "College student"::#blue, "Young professional"::#darkblue,"Home maker"::#orange, "Mid-career workers"::#yellow, "Executives"::#red, "Retirees"::#darkorange];
			
	init {
		do activity_data_import;
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road) with_optimizer_type "Floyd Warshall";
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale"))] ;
		loop am over: amenities_shapefile {
			ask (building closest_to am) {
				usage <- "Restaurant";
				scale <- am get "Scale";
				name <- am get "name";
			} 
		}
		office_buildings <- building where (each.usage = "O");
		residential_buildings <- building where (each.usage = "R");
		ask one_of (office_buildings) {
			usage <- "Uni";
		}
		ask one_of (office_buildings) {
			usage <- "Shopping";
		}
		ask one_of (office_buildings) {
			usage <- "Restaurant";
		}
		ask one_of (office_buildings) {
			usage <- "Night";
		}
		ask one_of (office_buildings) {
			usage <- "Park";
		}
		ask one_of (office_buildings) {
			usage <- "HS";
		}
		ask one_of (office_buildings) {
			usage <- "Cultural";
		}
		ask building {
			color <- color_per_usage[usage]; 
		}
		create people number: 1000 {
			living_place <- one_of(residential_buildings);
			current_place <- living_place;
			location <- any_location_in(living_place);
			type <- one_of(color_per_type.keys);
			color <- color_per_type[type];
			do create_trip_objectives;
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
	float speed <- 3 #km/#h;
	building current_place;
	
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
	reflex choose_objective when: my_current_objective = nil {
		my_current_objective <- objectives first_with (each.starting_time = current_date.hour);
		location <- any_location_in(current_place);
		if (my_current_objective != nil) {
			current_place <- nil;
		}
	}
	reflex move when: my_current_objective != nil{
		do goto target: my_current_objective.place.location on: road_network;
		if (location = my_current_objective.place.location) {
			current_place <- my_current_objective.place;
			location <- any_location_in(current_place);
			my_current_objective <- nil;	
		}
	}
	aspect default {
		draw sphere(8) at: (current_place = nil ? location: (location + {0,0,current_place.height + 4}))  color: color ;
	}
}

species road {
	aspect default {
		draw shape width: 3 color: #red;
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
			species road refresh: false;
			species people;
			
			graphics "time" {
				point loc <- {-100,-100};
				draw clock_normal size: 400 at:loc ;
				draw clock_big_hand rotate: current_date.minute*(360/60)  + 90  size: {400,400/14} at:loc + {0,0,0.1}; 
				draw clock_small_hand rotate: current_date.hour*(360/12)  + 90  size: {240,240/10} at:loc + {0,0,0.1}; 
			}
			
			 overlay position: { 5, 5 } size: { 240 #px, 550 #px } background: # black transparency: 0.5 border: #black rounded: true
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

            }
		}
	}
}
