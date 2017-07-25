/**
* Name: CityScope volpe - Mobility Data Visualization
* Author: Arnaud Grignard
* Description: Visualization of Modbile Data in volpe
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

	init {
	  create road from:roads_shapefile;
	  create building from:buildings_shapefile with:[energy:: int(read('Kwh/m2'))];
	}

}

species building{
	int energy;
	aspect base {
		draw shape color: rgb(255 - (255 * ((4000-energy)/4000 )),255 * ((4000-energy)/4000 ),0)/*rgb(energy/100,energy/100,energy/100)*/ depth:energy/4000*100;
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}




experiment CityScopeEnergy type: gui {	
	output {		
		display CityScope  type:opengl background:#white {
			species road aspect: base refresh:false;
			species building aspect:base;	
		}
	}
}






