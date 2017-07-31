/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform. Actually used on 2 different cities.
*/

model CityScope

import "CityScope_main.gaml"

global {

}

experiment CityScopeAndorra type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"andorra" among:["volpe", "andorra"];
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species table aspect:base refresh:false;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
		}			
	}
}


experiment CityScopeSF type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"San_Francisco";
	parameter 'CityMatrix:' var: cityMatrix category: 'GIS' <-false;
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species building aspect:usage;
			species table aspect:base refresh:false;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
		}			
	}
}

experiment CityScopeTaipeiMain type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"Taipei_MainStation";
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species table aspect:base refresh:false;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
		}			
	}
}

experiment CityScopeTongji type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"Shanghai";
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species table aspect:base refresh:false;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
		}			
	}
}

experiment CityScopeMulti type: gui {
	init {
	  //we create a second simulation (the first simulation is always created by default) with the given parameters
	  create simulation with: [cityScopeCity:: "andorra", minimum_cycle_duration::0.02];
	  create simulation with: [cityScopeCity:: "san_Francisco", minimum_cycle_duration::0.02];
	  //create simulation with: [cityScopeCity:: "andorra", minimum_cycle_duration::0.02];
		
	}
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"volpe" among:["volpe", "andorra"];
	float minimum_cycle_duration <- 0.02;
	output {	
		display CityScope  type:opengl background:#black {
			species building aspect:usage;
			species table aspect:base refresh:false;
			species road aspect: base refresh:false;
			species amenity aspect: onScreen ;
			species people aspect: scale;
			graphics "text" 
			{
               draw string(current_hour) + "h" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.85,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
                
            }
		}			
	}
}



