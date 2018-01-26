 /**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall_Volpe_Demo

import "./../CityScope_main.gaml"

global {

}
experiment CityScopeVolpeDemo type: gui parent:CityScopeMainVirtual{
	action _init_ {
		create CityScope_Kendall_Volpe_Demo_model with: [cityScopeCity::"volpe",angle :: -9.74,center ::{3305,2075}, brickSize :: 70.0, coeffPop::1.0];	
	}
	float minimum_cycle_duration <- 0.02;
	output {		
		
        display CityScope type:opengl parent:CityScopeVirtual{}	
        	
		/*display CityScopeTable   type:opengl background:#black fullscreen:1 rotate:180 synchronized:true
		camera_pos: {4414.559,3164.843,4508.27} camera_look_pos: {4415.792,3157.071,-0.06} camera_up_vector: {0.157,0.988,0.002}{	
			species amenity aspect: onTable;
			species people aspect: scale;
			graphics "interaction_graph" {
				if (interaction_graph != nil  and ( toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:rgb(0,125,0,75);
					}
				} 
				draw rectangle(900,700) rotated_by 9.74 color:#black	 at: {2500, 2000,10} ;	
			}	
		}*/
	}


}