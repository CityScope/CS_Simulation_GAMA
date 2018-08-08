/***
* Name: CustomableCityScope
* Author: Arnaud Grignard
* Description: This is a custom template to create any species on top of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/



model CityScope_Custom_Template


import "CityScope_main.gaml"

/* Insert your model definition here */

global{
	
	init{
		create CustomSpecies number:10;
	}
}

species CustomSpecies skills:[moving]{
	reflex move{
		do wander;
	}
	aspect base{
		draw circle(10#m) color:#red;
	}
}

experiment customizedExperiment type:gui parent:CityScopeMain{
	output{
		display CityScopeAndCustomSpecies type:opengl parent:CityScopeVirtual{
			species CustomSpecies aspect:base;
			
		}
		display CustomSpeciesOnly type:opengl{
			species CustomSpecies aspect:base;
		}
	}
}

