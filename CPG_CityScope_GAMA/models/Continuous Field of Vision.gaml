/**
* Name: fieldofvision
* Author: Patrick Taillandier
* Description: This model illustrate how to use the masked_by operator to compute the field of vision of an agent (with obtsacles)
* Tags: perception, spatial_computation, masked_by
*/

model fieldofvision

import "CityScope_main.gaml"

global {
	
	file obstacle_shapefile <- file("../includes/MIT/Buildings.shp");
	
	//number of obstacles
	int nb_obstacles <- 10 parameter: true;
	
	//perception distance
	float perception_distance <- 40.0 parameter: true;
	
	//precision used for the masked_by operator (default value: 120): the higher the most accurate the perception will be, but it will require more computation
	int precision <- 120 parameter: true;
	
	geometry shape <- envelope(obstacle_shapefile);
	
	//space where the agent can move.
	geometry free_space <- copy(shape);
	init {
		create obstacle from: obstacle_shapefile{//number:10{//
			//shape <- rectangle(2+rnd(20), 2+rnd(20));
			//free_space <- free_space - (shape);
			//shape<- rectangle(100, 100);
			free_space <- free_space - (shape + 2);
		}
		
		create pev  number:10 {
			location <- any_location_in(free_space);
		}
	}
}

species obstacle {
	aspect default {
		draw shape color: #gray border: #gray depth:50;
		draw shape*0.9 color: #gray border: #gray depth:50 at:{location.x,location.y,-10};
		draw shape*0.9 color: #gray border: #gray depth:50 at:{location.x,location.y,10};
	}
}
species pev skills: [moving]{
	//zone of perception
	geometry perceived_area;
	
	//the target it wants to reach
	point target ;
	
	reflex move {
		if (target = nil ) {
			if (perceived_area = nil) {
				//if the agent has no target and if the perceived area is empty, it moves randomly inside the free_space
				do wander bounds: free_space;
			} else {
				//otherwise, it computes a new target inside the perceived_area (we intersect with the free_space to limit its proximity to obstacles).
				target <- any_location_in(perceived_area inter free_space);
			}
		} else {
			//if it has a target, it moves towards this target
			do goto target: target;
			
			//if it reaches its target, it sets it to nil (to choose a new target)
			if (location = target) {
				target <- nil;
			}
		}
	}
	//computation of the perceived area
	reflex update_perception {
		//the agent perceived a cone (with an amplitude of 60°) at a distance of  perception_distance (the intersection with the world shape is just to limit the perception to the world)
		perceived_area <- (cone(heading-30,heading+30) intersection world.shape) intersection circle(perception_distance); 
		
		//if the perceived area is not nil, we use the masked_by operator to compute the visible area from the perceived area according to the obstacles
		if (perceived_area != nil) {
			perceived_area <- perceived_area masked_by (obstacle,precision);
		}
	}
	
	aspect body {
		draw triangle(10) rotate:90 + heading color: #black;
	}
	aspect perception {
		if (perceived_area != nil) {
			draw perceived_area color: #gray;
			draw circle(1) at: target color: #darkgray;
		}
	}
}

experiment fieldofvision type: gui {
	float minimum_cycle_duration <- 0.05;
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"kendall" among:["kendall", "Andorra"];	
	output {
		display view type:opengl{
			species obstacle;
			species pev aspect: perception transparency: 0.5;
			species pev aspect: body;
		}
	}
}
