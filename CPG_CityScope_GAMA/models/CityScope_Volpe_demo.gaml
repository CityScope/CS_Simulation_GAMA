 /**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall_Volpe_Demo

import "CityScope_main.gaml"

global {

}

experiment CityScopeVolpeDemo type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"volpe" among:["volpe", "Andorra"];	
	float minimum_cycle_duration <- 0.02;
	output {				
		display CityScope  type:opengl background:#black{
			species building aspect:demoScreen;
			species table aspect:base;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
             graphics "density"{
             	point hpos<-{world.shape.width*0.85,world.shape.height*0.675};
             	int barW<-60;
             	int factor<-20;
             	loop i from: 0 to: length(density_array) -1{
             		draw rectangle(barW,density_array[i]*factor) color: (i=0 or i=3) ? #gamablue : ((i=1 or i=4) ? #gamaorange: #gamared) at: {hpos.x+barW*1.1*i,hpos.y-density_array[i]*factor/2};
             	}
            }
            /*graphics "interaction_graph" {
				if (interaction_graph != nil  and (drawInteraction = true or toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:(src.scale = target.scale) ? color_map[src.scale] : #green;
					}
				} 	
			}*/
			species people aspect:scale;
			
		}
			
		/*display CityScopeTable  type:opengl background:#black fullscreen:1 rotate:180
		camera_pos: {4463.6173,3032.9552,4033.5415} camera_look_pos: {4464.7186,3026.0023,0.1795} camera_up_vector: {0.1564,0.9877,0.0017}{
			//species building aspect:demoTable;
			species amenity aspect: onTable ;
			species people aspect: scaleTable;
			graphics "interaction_graph" {
				if (interaction_graph != nil  and (drawInteraction = true or toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:rgb(0,125,0,75);//(src.scale = target.scale) ? color_map[src.scale] : #green;
					}
				} 
				draw rectangle(900,700) rotated_by 9.74 color:#black at: {2500, 2150};	
			}	
		}*/
	}
}