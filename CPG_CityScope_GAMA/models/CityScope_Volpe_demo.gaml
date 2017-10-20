 /**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall_Volpe_Demo

import "CityScope_main.gaml"

global {

}
experiment CityScopeVolpeDemo type: gui parent:CityScopeMainVirtual{
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"volpe" among:["volpe", "Andorra"];	
	float minimum_cycle_duration <- 0.02;
	output {		
		
        display CityScope type:opengl parent:CityScopeVirtual{}	
        	
		display CityScopeTable  type:opengl background:#black fullscreen:1 rotate:180 synchronized:true
		//camera_pos: {4440.366,3088.467,4853.809} camera_look_pos: {4441.693,3080.1,0.075} camera_up_vector: {0.157,0.988,0.002}{
		//camera_pos: {4412.441,3178.202,4508.246} camera_look_pos: {4413.674,3170.43,-0.084} camera_up_vector: {0.157,0.988,0.002}{	
		camera_pos: {4414.559,3164.843,4508.27} camera_look_pos: {4415.792,3157.071,-0.06} camera_up_vector: {0.157,0.988,0.002}{	
			/*species table aspect:base refresh:false;
				species road aspect: base ;
				species amenity aspect: onScreen ;*/
		
			
			species amenity aspect: onTable;
			species people aspect: scale;
			graphics "interaction_graph" {
				if (interaction_graph != nil  and ( toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:rgb(0,125,0,75);//(src.scale = target.scale) ? color_map[src.scale] : #green;
					}
				} 
				draw rectangle(900,700) rotated_by 9.74 color:#black	 at: {2500, 2000,10} ;	
			}	
		}
	}
}