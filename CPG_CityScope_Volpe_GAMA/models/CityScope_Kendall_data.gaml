/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Visualization of Modbile Data in Kendall
*/

model CityScope_Kendall

global {
	// GIS FILE //	
	file bound_shapefile <- file("../includes/Bounds.shp");
	file roads_shapefile <- file("../includes/Roads.shp");
	file imageRaster <- file('../includes/images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	float angle <--9.74;
	
	// MOBILE DATA //
	int start_date;
	int end_date;
	float lenghtMax <-0.0;
	file my_csv_file <- csv_file("../includes/mobility/pp.csv",",");
	matrix data <- matrix(my_csv_file);
	
	init {
	  create road from:roads_shapefile;
	  loop i from: 1 to: data.rows -1{
	     create mobileData{
	  	   location <- point(to_GAMA_CRS({ float(data[6,i]), float(data[7,i]) }, "EPSG:4326"));
		   lenght<-float(data[4,i]);
		   init_date<-int(data[10,i]);
		 }	
	   }
	   start_date<-min(mobileData collect int(each["init_date"]));
	   end_date<-max(mobileData collect int(each["init_date"]));	   
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}

species mobileData schedules:[]{
	rgb color <- #red;
	float lenght;
	int init_date;
	
	aspect base {
		draw cone3D(5,lenght/100) color:#white depth:lenght/100;//rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
}


experiment CityScopeDev type: gui {	
	output {		
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:base;
		}
	}
}



