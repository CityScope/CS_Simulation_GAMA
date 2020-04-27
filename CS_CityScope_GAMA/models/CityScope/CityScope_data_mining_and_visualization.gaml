/**
* Name: CityScope volpe - Mobility Data Visualization
* Author: Arnaud Grignard
* Description: Visualization and Analysis of Mobile Data
*/

model CityScope_volpe

global {
	// GIS FILE //	
	file bound_shapefile <- file("./../../includes/City/volpe/Bounds.shp");
	file roads_shapefile <- file("./../../includes/City/volpe/Roads.shp");
	//file imageRaster <- file('./../../includes/images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	float angle <--9.74;
	
	// MOBILE DATA //
	int global_start_date;
	int global_end_date;
	float lenghtMax <-0.0;
	//kendall_1_08_10_2017
	//boston_1_08_10_2017
	file my_csv_file <- csv_file("./../../includes/City/volpe/mobility/kendall_1_08_10_2017.csv",",");
	matrix data <- matrix(my_csv_file);
	
	graph<mobileData, mobileData> interaction_graph;
	
	//CLUSTERING
	bool drawInteraction <- false parameter: "Draw Interaction:" category: "Visualization";
	int distance parameter: 'distance ' category: "Visualization" min: 1 max:100 <- 10;
	bool wandering <- false parameter: "Wandering:" category: "Simulation";
	bool clustering <- false parameter: "Clustering:" category: "Simulation";
	int k parameter: 'number of groups to create (kmeans) ' category: "Simulation" min: 1 max:100 <- 10;	
	float eps parameter: 'the maximum radius of the neighborhood (DBscan)' category: "Simulation" min: 10.0 max: 100.0 <- 50.0;	
	int minPoints <- 3; //the minimum number of elements needed for a cluster (DBscan)
	bool whiteBackground <- true parameter: "Black background:" category: "Visualization";
	rgb background_color <- whiteBackground ? #black : #white;
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
	reflex updateGraph when:(drawInteraction = true){
		interaction_graph <- graph<mobileData, mobileData>(mobileData as_distance_graph(distance));
	}
	reflex cluster_building when:(clustering){
		list<list> instances <- mobileData collect ([each.location.x, each.location.y]);
		//DBSCAN
		list<list<int>> clusters_dbscan <- list<list<int>>(dbscan(instances, eps,minPoints));
       	loop cluster over: clusters_dbscan {
       		int r<-rnd(255);
			rgb col <- rgb(r,r,r);//rnd_color(255);
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
		draw shape color: whiteBackground ? #white : #black;
	}
}

species mobileData skills:[moving]{
	rgb color <- #red;
	float duration;
	int init_date;
	bool visible <-false;
	int size<-6;
	
	reflex update{
		if(global_start_date + (cycle*1000) > init_date and global_start_date + (cycle*1000) < init_date + duration){
			visible <-true;
		}else{
			//visible <-false;
		}
		if(wandering){
			do wander;
		}
	}
	
	aspect duration {
		draw cone3D(size,duration/100) color:whiteBackground ? #white : #black;//depth:duration/1000; //rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
	
	
	aspect circle {
		draw circle(size) color:whiteBackground ? #white : #black;//rgb((255 * lenght/50) / 100,(255 * (100 - lenght/50)) / 100 ,0) depth:lenght/100;
	}
	
	aspect timelapse{
		if (visible){
		  draw circle(size) color:whiteBackground ? #white : #black;	
		}
	}
	aspect spacelapse{
	      draw sphere(size) color:whiteBackground ? #white : #black at:{location.x,location.y,(init_date-global_start_date)/300}; 	
	}
	aspect timespace{
		if (visible){
	      draw sphere(size) color:whiteBackground ? #white : #black at:{location.x,location.y,(init_date-global_start_date)/300};
		}	  	
	}
	rgb color_dbscan <- #grey;
	rgb color_kmeans <- #grey;
	aspect dbscan_aspect {
		draw circle(size) color: color_dbscan;
	}
	aspect kmeans_aspect {
		draw circle(size) color: color_kmeans;
	}
}


experiment CityScopeDev type: gui {	
	output {		
		display CityScope  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base;
			species mobileData aspect:circle;
			graphics "interaction_graph" {
				if (interaction_graph != nil  and (drawInteraction = true) ) {	
					loop eg over: interaction_graph.edges {
                        mobileData src <- interaction_graph source_of eg;
                        mobileData target <- interaction_graph target_of eg;
						geometry edge_geom <- geometry(eg);
						draw line(edge_geom.points)  color:#gray;//(src.color = target.color) ? color_map[src.scale] : #green;
					}
				} 	
		    }
		}
		
		display CityScopeDuration  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base refresh:false;
			species mobileData aspect:duration;	
		}
		
		display CityScopeTimeLapse  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base refresh:false;
			species mobileData aspect:timelapse;	
		}
		display CityScopeSpaceLapse  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base refresh:false;
			species mobileData aspect:spacelapse;	
		}
		
		display CityScopeTimeSpace  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base refresh:false;
			species mobileData aspect:timespace;
			
		}
		display CityScopeDBScan  type:opengl background:whiteBackground ? #black : #white{
			species road aspect: base refresh:false;
			species mobileData aspect:dbscan_aspect;
			
		}	
		display CityScopeKMeans  type:opengl background:whiteBackground ? #black : #white {
			species road aspect: base refresh:false;
			species mobileData aspect:kmeans_aspect;	
		}
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



