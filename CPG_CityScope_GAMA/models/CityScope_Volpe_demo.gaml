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
               draw "day" +  string(current_day) + " - " + string(current_hour) + "h"  color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.8,world.shape.height*0.975};
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
            graphics "interaction_graph" {
				if (interaction_graph != nil  and (drawInteraction = true or toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:(src.scale = target.scale) ? color_map[src.scale] : #green;
					}
				} 	
			}
			graphics "interaction plot"{
            	if(drawInteraction){
	            	point ppos<-{world.shape.width*1.1,world.shape.height*0.2};
	             	point proi<-{2500,1000};
	             	draw "interactions" color: # white font: font("Helvetica", 25, #plain) at: {ppos.x+proi.x*0.35,ppos.y+150};
	             	draw string(length(interaction_graph.edges)) color: # white font: font("Helvetica", 20, #plain) at: {ppos.x-proi.x*0.125,ppos.y-proi.y/2};
	             	draw line([ppos,{ppos.x,ppos.y-proi.y}]) color:#white width:1 end_arrow:50;
	             	draw line([ppos,{ppos.x+proi.x,ppos.y}]) color:#white width:1 end_arrow:50;
	             	nbInteraction[current_day-1]<+{ppos.x+(cycle mod 8640/8640)*proi.x,ppos.y-(length(interaction_graph.edges))/5};
	             	draw line(nbInteraction[current_day-1]) color:rgb(255,255,255) width:2;
	             	loop i from:1 to:current_day-1{
	             	 draw line(nbInteraction[current_day-1-i]) color:rgb(255-50*i,255-50*i,255-50*i) width:1;	
	             	}	
            	}      	
            }	
		}
			
		display CityScopeTable  type:opengl background:#black fullscreen:1 rotate:180
		//camera_pos: {4463.6173,3032.9552,4033.5415} camera_look_pos: {4464.7186,3026.0023,0.1795} camera_up_vector: {0.1564,0.9877,0.0017}{
		
		
		camera_pos: {4440.366,3088.467,4853.809} camera_look_pos: {4441.693,3080.1,0.075} camera_up_vector: {0.157,0.988,0.002}{
			//species building aspect:demoTable;
			species amenity aspect: onTable;
			species people aspect: scaleTable;
			graphics "interaction_graph" {
				if (interaction_graph != nil  and ( toggle1=7) ) {	
					loop eg over: interaction_graph.edges {
                        people src <- interaction_graph source_of eg;
                        people target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:rgb(0,125,0,75);//(src.scale = target.scale) ? color_map[src.scale] : #green;
					}
				} 
				draw rectangle(900,700) rotated_by 9.74 color:#black at: {2500, 2150,10} ;	
			}	
		}
	}
}