/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/



model CityScope_ABM_Aalto


import "CityScope_main.gaml"

/* Insert your model definition here */

global{
	
	string cityGISFolder <- "./../includes/City/otaniemi";
	// GIS FILES
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp");
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp");
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp");
	file amenities_shapefile <- file(cityGISFolder + "/Amenities.shp");
	file table_bound_shapefile <- file(cityGISFolder + "/table_bounds.shp");
	file imageRaster <- file('./../images/gama_black.png');
	geometry shape <- envelope(bound_shapefile);
	
	
	// Variables used to initialize the table's grid.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24;
}

//species CustomSpecies skills:[moving]{
//	reflex move{
//		do wander;
//	}
//	aspect base{
//		draw circle(10#m) color:#red;
//	}
//}

//experiment CustomizedExperiment type:gui parent:CityScopeMain{
//	output{
//		display CityScopeAndCustomSpecies type:opengl parent:CityScopeVirtual{
//			species CustomSpecies aspect:base;
//			
//		}
//		display CustomSpeciesOnly type:opengl{
//			species CustomSpecies aspect:base;
//		}
//	}
//}

