/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Kendall
*/

model CityScope_Kendall

import "./../CityScope/CityScope_main.gaml"

global {

	reflex createAnimPeople when:cycle=1{
		 create peopleAnim number: 1 {
			    scale<-"S"; 
		  		living_place <- one_of(building  where (each.usage="R" and each.scale=scale and each.area >10000));
				location <- any_location_in (living_place);	
				speed <- min_speed + rnd (max_speed - min_speed) ;
				initialSpeed <-speed;
				time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
				time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
				time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
				time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
				time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
				working_place <- one_of(building  where (each.usage="O" and each.scale=scale and each.area >10000)) ;
				eating_place <- one_of(amenity where (each.scale=scale )) ;
				dining_place <- one_of(amenity where (each.scale=scale )) ;
				objective <- "resting";
				fromTheGrid<-false;  
			}
		
	}

}


species peopleAnim parent:people{
    bool showMyPlaces;
	
	aspect myPlaces{	  
	      if(cycle>1){
	      	draw living_place  color:color_map[living_place.scale];
	      	//draw living_place  color:rgb(245,135,51);
	      }
	      if(cycle >2){
	      	draw working_place   color:color_map[working_place.scale];
	      	//draw working_place   color:rgb(39,62,78);
	      }
	      if (cycle>3){
	      	draw eating_place  color:color_map[eating_place.scale];
	        //draw eating_place  color:rgb(4,158,189);	
	      }
	      if (cycle >4){
	      	draw dining_place  color:color_map[dining_place.scale];
	        //draw dining_place  color:rgb(232,13,33);
	      }
	      draw circle(30) color:color_map[scale] at:{location.x,location.y,0.01};	
		
		
	}
}



experiment CityScopeVolpe type: gui {
	action _init_ {
		create CityScope_Kendall_model with: [cityScopeCity::"volpe",angle :: -9.74,center ::{3305,2075}, brickSize :: 70.0, coeffPop::1.0, coeffSize::1];	
	}	
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			//species table aspect:base;
			species road aspect: base refresh:false;
			species building aspect:base position:{0,0,-0.01};
		    species amenity aspect: white;
			species peopleAnim aspect: myPlaces position:{0,0,0.01};
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: { 5700, 6200};
               draw imageRaster size:40#px at: { 7000, 6000};
            }
		}		
	}
}