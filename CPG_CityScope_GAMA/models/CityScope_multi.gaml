/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform. Actually used on 2 different cities.
*/

model CityScope

import "CityScope_main.gaml"

global {

}


experiment CityScopeMulti type: gui {
	init {
	  create simulation with: [cityScopeCity:: "andorra", minimum_cycle_duration::0.02];	
	  //create simulation with: [cityScopeCity:: "san_Francisco", minimum_cycle_duration::0.02];
	  //create simulation with: [cityScopeCity:: "Taipei_MainStation", minimum_cycle_duration::0.02];
	  //create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02];	
	}
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"volpe" among:["volpe", "andorra"];
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species building aspect:base position:{0,0,-0.002};
			species table aspect:base;
			species road aspect: base refresh:false;
			species amenity aspect: base position:{0,0,-0.001};
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
	}
}



