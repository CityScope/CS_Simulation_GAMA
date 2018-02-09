/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Andorra
*/

model CityScope_Andorra_Demo

import "./../CityScope_main.gaml"

global {

}

experiment CityScopeAndorraDemo type: gui parent:CityScopeMainVirtual{
	//parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"andorra";	
	float minimum_cycle_duration <- 0.02;

	action _init_ {
		create CityScope_Andorra_Demo_model with: [cityScopeCity::"Andorra", cityMatrix::false,angle :: 3.0,center ::{2550,895}, brickSize :: 37.5];	
	}
	
	output {				
		display CityScope type:opengl parent:CityScopeVirtual{}	
			
		display CityScopeTable  type:opengl background:#black fullscreen:0 rotate:180
		camera_pos: {4463.6173,3032.9552,4033.5415} camera_look_pos: {4464.7186,3026.0023,0.1795} camera_up_vector: {0.1564,0.9877,0.0017}{
			species amenity aspect: onTable ;
			species people aspect: scaleTable;
            graphics "edges" {
				if (interaction_graph != nil  and (drawInteraction = true or toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
						geometry edge_geom <- geometry(eg);
						float val <- 255 * edge_geom.perimeter / distance; 
						draw line(edge_geom.points)  color:rgb(0,125,0,75);
					}
				}
				 draw rectangle(900,700) rotated_by 9.74 color:#black at: { 2500, 2150};	
			}		
		}
	}
}