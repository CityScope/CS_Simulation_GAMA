/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/

model CityScope_ABM_Aalto

import "CityScope_main.gaml"

global{
	//GIS folder of the CITY	
	string cityGISFolder <- "./../includes/City/Testing_parking_choice";	
	
	// Variables used to initialize the table's grid position.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24.0;
	float cityIOVersion<-2.1;
	
	//	city_io
	string CITY_IO_URL <- "https://cityio.media.mit.edu/api/table/cs_aalto_2";
	// Offline backup data to use when server data unavailable.
	string BACKUP_DATA <- "../includes/City/otaniemi/cityIO_Aalto.json";
	
    //Sliders that dont exisit in Aalto table and are only used in version 1.0 
	int	toggle1 <- 2;
	int	slider1 <-2;
	// TODO: Hard-coding density because the Aalto table doesnt have it.
	list<float> density_array<-[1.0,1.0,1.0,1.0,1.0,1.0];
	
	// TODO: mapping needs to be fixed for Aalto inputs
	map<int, list> citymatrix_map_settings <- [-1::["Green", "Green"], 0::["R", "L"], 1::["R", "M"], 2::["R", "S"], 3::["O", "L"], 4::["O", "M"], 5::["O", "S"], 6::["A", "Road"], 7::["A", "Plaza"], 
		8::["Pa", "Park"], 9::["P", "Parking"], 20::["Green", "Green"], 21::["Green", "Green"]
	]; 
	

	// Babak dev:
	int max_walking_distance <- 300 	min:0 max:3000	parameter: "maximum walking distance form parking:" category: "people settings";
	int number_of_people <- 1 min:0 max: 2000 parameter:"number of people in the simulation" category: "people settings";
	int min_work_start <- 4;
	int max_work_start <- 10;
	int min_work_end <- 17;
	int max_work_end <- 18;
	
	graph car_road_graph;
	graph pedestrian_road_graph;
	
	file parking_footprint_shapefile <- file(cityGISFolder + "/Parkings.shp");
	//file roads_shapefile <- file(cityGISFolder + "/car_network.shp");
	file Origin_shapefile <- file(cityGISFolder + "/Origin.shp");
	file Destination_shapefile <- file(cityGISFolder + "/destination.shp");
	
	float step <- 2 #mn;
	int current_hour update: 6 + (time / #hour) mod 24;
	
	// reflex clock_ when:0=0 {write(current_hour);}
	geometry shape <- envelope(bound_shapefile);
	
	
	init {
		create parking from: parking_footprint_shapefile with: [capacity::int(read("Capacity")),total_capacity::int(read("Capacity")), excess_time::int(read("excess"))];
		create origin from: Origin_shapefile;
		create destination from: Destination_shapefile;
		create aalto_people number: number_of_people {
			working_place <- one_of(destination);
			living_place_ <- one_of(origin);
			location <- any_location_in(living_place);
			time_to_work <-8 ; //min_work_start + rnd(max_work_start - min_work_start);
			time_to_sleep <-16; // min_work_end + rnd(max_work_end - min_work_end);
			objective <- "resting";
			}
		
		
		
	}
	
}


species origin  parent:building{
	aspect base{
		draw circle(10) color: #blue;
	}
}
species destination  parent:building{
	aspect base {
		draw circle(10) color: #orange;
	}
}
species parking schedules:[] {
	int capacity;
	int total_capacity;
	int excess_time;
	//float vacancy <-(capacity/total_capacity) update: (capacity/total_capacity);
	//rgb color <- rgb(240 , 240*vacancy ,  240*vacancy ,255) update: rgb(240 , 240*vacancy ,  240*vacancy ,255);
	aspect base {
		draw shape color: #yellow ;
	}
	
}

species aalto_people parent:people skills: [moving] {
	origin living_place_ ;
	bool driving_car <- true;
	bool mode_of_transportation_is_car <- true;
	
	int time_to_work;
	int time_to_sleep;
	
	list<parking> list_of_available_parking -> sort_by(parking where (distance_to(each.location, working_place) < max_walking_distance  ),distance_to(each.location, working_place));

	point the_target_parking;
	parking chosen_parking;
	string objective;
	point the_target <- nil;
	
	rgb color <- #red ;
	
	// ----- ACTIONS
	
	action park_the_car(parking target_parking) {
		target_parking.capacity <- target_parking.capacity -1;
	}
	
	action take_the_car(parking target_parking) {
		target_parking.capacity <- target_parking.capacity +1;
	}
	
	
	// ----- REFLEXES 


	
	reflex time_to_go_to_work when: current_hour = time_to_work and objective = "resting" {
		
		if (mode_of_transportation_is_car = true) {
			chosen_parking <- one_of(list_of_available_parking where (each.capacity > 0));
			the_target_parking <- any_location_in(chosen_parking);
			the_target <- any_location_in(working_place);
			objective <- "working";
		}	
		
		else {
			the_target <- any_location_in(working_place);
			objective <- "working";
		}
	}
	
	
	
	reflex time_to_go_home when: current_hour = time_to_sleep and objective = "working" {
		objective <- "resting";
		the_target <- any_location_in(living_place);
	}
	
	reflex change_mode_of_transportation when: location = the_target_parking {
		if (driving_car = true){
			driving_car <- false;
			do park_the_car(chosen_parking);
		}
		else {
			driving_car <- true;
			do take_the_car(chosen_parking);
		}
	}

	reflex move when: the_target != nil {
		if (driving_car = true){
			if (objective = "working"){
				do goto target: the_target_parking speed: (1.0 + rnd(0,5));
			}
			else {
				do goto target: the_target speed: (0.1 + rnd(0,5));
			}
		}
		else {
			if (objective = "working"){
				do goto target: the_target speed: (1.0 + rnd(0,5));
			}
			else {
				do goto target: the_target_parking speed: (0.1 + rnd(0,5));
			}
		}
		
      	if the_target = location {
        	the_target <- nil ;
		}
	}
	
	aspect base {
		draw circle(5) color:#red;
	}
}



// ----------------- EXPREIMENTS -----------------
experiment test type: gui {
	output {
		display test type:opengl{
			species parking aspect: base ;
			species aalto_people aspect:base;
			species origin aspect:base;
			species destination aspect:base;
			}
			
		}

}
