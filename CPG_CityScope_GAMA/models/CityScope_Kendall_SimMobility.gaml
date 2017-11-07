/**
* Name: CityScope Kendall SimMobility
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall

global {
	file buildings_shapefile <- file("../includes/Volpe/Buildings.shp");
	file roads_shapefile <- file("../includes/Volpe/Roads.shp");
	file imageRaster <- file('../includes/images/gama_black.png') ;
	geometry shape <- envelope(buildings_shapefile);
	graph road_graph;
	float step <- 10 #sec;
	int current_hour update: (time / #hour) mod 24 ;

	init {
		create building from: buildings_shapefile;
		create road from: roads_shapefile ;
		road_graph <- as_edge_graph(road);				
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


experiment CityScopeVolpe type: gui {	
	output {	
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species building aspect:base;
		}			
	}
}