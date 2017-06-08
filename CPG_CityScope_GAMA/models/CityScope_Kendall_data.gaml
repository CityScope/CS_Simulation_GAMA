/**
* Name: CityScope Kendall - Mobility Data Visualization
* Author: Arnaud Grignard
* Description: Visualization of Modbile Data in Kendall
*/

model CityScope_Kendall

global {
	// GIS FILE //	
	file bound_shapefile <- file("../includes/Kendall/Bounds.shp");
	file roads_shapefile <- file("../includes/Kendall/Roads.shp");
	file imageRaster <- file('../includes/images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	float angle <--9.74;
	
	// MOBILE DATA //
	int global_start_date;
	int global_end_date;
	float lenghtMax <-0.0;
	//kendall_1_08_10_2017
	//boston_1_08_10_2017
	file my_csv_file <- csv_file("../includes/Kendall/mobility/kendall_1_08_10_2017.csv",",");
	matrix data <- matrix(my_csv_file);
	
	//CLUSTERING
	bool clustering<-false;
	int k parameter: 'number of groups to create (kmeans) ' category: "Visualization" min: 1 <- 10;	
	float eps parameter: 'the maximum radius of the neighborhood (DBscan)' category: "Visualization" min: 10.0 <- 150.0;	
	int minPoints <- 3; //the minimum number of elements needed for a cluster (DBscan)
	
	init {
	  create road from:roads_shapefile;
	  loop i from: 1 to: data.rows -1{
	     create mobileData{
	  	   location <- point(to_GAMA_CRS({ float(data[4,i]), float(data[3,i]) }, "EPSG:4326"));
		   duration<-float(data[1,i]);
		   init_date<-int(data[0,i]);
		 }	
	   }
	   global_start_date<-min(mobileData collect int(each["init_date"]));
	   global_end_date<-max(mobileData collect int(each["init_date"]));	
	}
	reflex cluster_building when:(cycle=0 and clustering=true){
		eps <-cycle*10;
		list<list> instances <- mobileData collect ([each.location.x, each.location.y]);
		//DBSCAN
		list<list<int>> clusters_dbscan <- list<list<int>>(dbscan(instances, eps,minPoints));
       	loop cluster over: clusters_dbscan {
			rgb col <- rnd_color(255);
			loop i over: cluster {
				ask mobileData[i] {color_dbscan <- col;}
			}
		}
		//KMEANS
		list<list<int>> clusters_kmeans <- list<list<int>>(kmeans(instances, k));
		loop cluster over: clusters_kmeans {
			rgb col <- rnd_color(255);
			loop i over: cluster {
				ask mobileData[i] {color_kmeans <- col;}
			}
		}
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125,75) ;
	}
}

species mobileData skills:[moving]{
	rgb color <- #red;
	float duration;
	int init_date;
	bool visible <-false;
	
	reflex update{
		if(global_start_date + (cycle*1000) > init_date and global_start_date + (cycle*1000) < init_date + duration){
			visible <-true;
		}else{
			//visible <-false;
		}
		if(cycle>100){
			do wander;
		}
	}
	
	aspect base {
		draw cone3D(5,duration/100) color:#white depth:duration/100;//rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
	
	
	aspect circle {
		draw circle(8) color:#white;//rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
	
	aspect timelapse{
		if (visible){
		  draw circle(4) color:#white;	
		}
	}
	aspect timespace{
		if (visible){
	      draw sphere(10) color:#white at:{location.x,location.y,(init_date-global_start_date)/100};
		}
		  	
	}
	rgb color_dbscan <- #grey;
	rgb color_kmeans <- #grey;
	aspect dbscan_aspect {
		draw circle(10) color: color_dbscan;
	}
	aspect kmeans_aspect {
		draw circle(10) color: color_kmeans;
	}
}


experiment CityScopeDev type: gui {	
	output {		
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:circle;
			
		}
		
		/*display CityScopeTimeLapse  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:timelapse;
			
		}
		
		display CityScopeTimeSpace  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:timespace;
			
		}*/
		/*display CityScopeDBScan  type:opengl background:#black autosave:true{
			species road aspect: base refresh:false;
			species mobileData aspect:dbscan_aspect;
			
		}	
		display CityScopeKMeans  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:kmeans_aspect;
			
		}*/
	}
}


experiment CityScopeVolpeDemo type: gui {	
	float minimum_cycle_duration <- 0.02;
	output {				
		display CityScope  type:opengl background:#black {
			species road aspect: base refresh:false;
			species mobileData aspect:circle;
		}
			
		display CityScopeTable  type:opengl background:#black fullscreen:1 rotate:180
		camera_pos: {4463.6173,3032.9552,4033.5415} camera_look_pos: {4464.7186,3026.0023,0.1795} camera_up_vector: {0.1564,0.9877,0.0017}{
			species road aspect: base refresh:false;
			species mobileData aspect:timelapse;		
		}
	}
}



