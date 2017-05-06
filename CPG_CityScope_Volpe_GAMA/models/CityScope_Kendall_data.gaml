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
	int global_start_date;
	int global_end_date;
	float lenghtMax <-0.0;
	file my_csv_file <- csv_file("../includes/mobility/pp.csv",",");
	matrix data <- matrix(my_csv_file);
	
	init {
	  create road from:roads_shapefile;
	  loop i from: 1 to: data.rows -1{
	     create mobileData{
	  	   location <- point(to_GAMA_CRS({ float(data[6,i]), float(data[7,i]) }, "EPSG:4326"));
		   duration<-float(data[4,i]);
		   init_date<-int(data[10,i]);
		 }	
	   }
	   global_start_date<-min(mobileData collect int(each["init_date"]));
	   global_end_date<-max(mobileData collect int(each["init_date"]));		   
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}

species mobileData {
	rgb color <- #red;
	float duration;
	int init_date;
	bool visible <-false;
	
	reflex update{
		if(global_start_date + (cycle*1000) > init_date and global_start_date + (cycle*1000) < init_date + duration){
			visible <-true;
		}else{
			visible <-false;
		}
	}
	
	aspect base {
		draw cone3D(5,duration/100) color:#white depth:duration/100;//rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
	
	aspect timelapse{
		if (visible){
		  draw circle(20) color:#white;	
		}
	}
}


experiment CityScopeDev type: gui {	
	output {		
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:timelapse;
			
		}
		
		display Displaychart{
			chart "Number of call" type: series  {
				data "number_of_call" value: length(mobileData where (each.visible=true)) color: #blue ;
		    }
		}
		
	}
}



