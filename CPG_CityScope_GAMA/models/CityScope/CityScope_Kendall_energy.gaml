/**
* Name: CityScope volpe - Energy Data Visualization
* Author: Arnaud Grignard
* Description: Visualization of Energy Data on Volpe Site
*/

model CityScope_volpe



global {
	// GIS FILE //	
	file bound_shapefile <- file("../includes/volpe/Bounds.shp");
	file roads_shapefile <- file("../includes/volpe/Roads.shp");
	file buildings_shapefile <- file("../includes/energy/volpe.shp");
	file imageRaster <- file('../includes/images/gama_black.png') ;
	geometry shape <- envelope(buildings_shapefile);
	float angle <--9.74;
	graph<geometry, geometry> smart_grid_graph;

	init {
	  create road from:roads_shapefile;
	  create building from:buildings_shapefile with:[energy:: int(read('Kwh/m2'))]{
	  	color<-rgb(255 - (255 * ((4000-energy)/4000 )),255 * ((4000-energy)/4000 ),0);
	  }
	  create people number:500{
	  	location<-any_location_in(one_of(building));
	  }
	}
	
	
	reflex updateGraph when:time=100{
		ask powerSupply{
			do die;
		}
		ask building{
			create powerSupply{
	  		  location<-myself.location;
	  		  color<-myself.color;
	  		  energy<-myself.energy;
			}
	  	    
	  	    smart_grid_graph <- as_distance_graph(powerSupply, 100);
	  	  		
	    }	
	}

}

species building{
	int energy;
	rgb color;
	aspect base {
		draw shape color: color depth:(time>100) ? energy/4000*100 :(time/100)*energy/4000*100;
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}

species powerSupply{
	rgb color;
	int energy;
	aspect base{
		if(time>100){
			draw cube(10 +abs(cos(time)*energy/250)) color:color;
		}
	  
	}
}

species people skills:[moving]{	 
	reflex move {
	   do wander;
	}
	aspect base{
		draw circle(5) color:#black;
	}
}

experiment CityScopeEnergy type: gui {	
	output {		
		display CityScope  type:opengl background:#white {
			species people aspect:base;
			species road aspect: base refresh:false;
			species building aspect:base;
			species powerSupply aspect:base position:{0,0,0.25};
			graphics "the graph" position:{0,0,0.25}{
				if(time>100){
					loop edge over: smart_grid_graph.edges {
				    draw edge color: #green;
				}
			}	
			}	
		}
	}
}






