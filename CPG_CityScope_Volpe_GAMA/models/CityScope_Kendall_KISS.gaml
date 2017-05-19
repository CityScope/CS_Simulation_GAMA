/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall

global {
	file buildings_shapefile <- file("../includes/Buildings.shp");
	file roads_shapefile <- file("../includes/Roads.shp");
	file imageRaster <- file('../includes/images/gama_black.png') ;
	geometry shape <- envelope(buildings_shapefile);
	graph road_graph;
	float step <- 10 #sec;
	int current_hour update: (time / #hour) mod 24 ;

	init {
		create building from: buildings_shapefile;
		create road from: roads_shapefile ;
		road_graph <- as_edge_graph(road);
		create people number: 1000{//shape.area/100000 {
			living_place <- one_of(building);
			working_place <- one_of(building) ;
			objective <- "resting"; 
			location <- any_location_in (living_place);
			speed <- 1 #km / #h + rnd (5 #km / #h) ;
			initialSpeed <-speed;
			time_to_work <- rnd (12) ;
			time_to_sleep <- 12 + rnd (12) ;
		}				
	}
}
	
species building schedules: []{
	aspect base {	
     	draw shape color: rgb(50,50,50,125);
	}
}

species road  schedules: []{
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}

species people skills:[moving]{
	float initialSpeed;
	building living_place <- nil ;
	building working_place <- nil ;
    int time_to_work ;
    int time_to_sleep ;
	string objective ;
	string curMovingMode<-"travelling";	
	point the_target <- nil ;

    reflex updateTarget{	
		if(current_hour > time_to_work and objective = "resting"){
			objective <- "working" ;
			the_target <- any_location_in (working_place);
			curMovingMode <- "travelling";
		    speed <-initialSpeed;			
	    }	    
	    if(current_hour > time_to_sleep and objective = "working"){
			objective <- "resting" ;
			the_target <- any_location_in (living_place);
			curMovingMode <- "travelling";
		    speed <-initialSpeed;			
	    }
	} 
	 
	reflex move {
	    do goto target: the_target on: road_graph ; 
		if (the_target = location) {
			the_target <- nil ;
			curMovingMode <- "wandering";
		}
		if(curMovingMode = "wandering"){
			do wander speed:0.5 #km / #h;
		}
	}
		
	aspect base{
      draw circle(14) color: #white;
	}
}

experiment CityScopeVolpe type: gui {	
	output {	
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species people aspect: base;
			species building aspect:base;
			graphics "text" {
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: { 5700, 6200};
               draw imageRaster size:40#px at: { 7000, 6000};
            }
		}			
	}
}