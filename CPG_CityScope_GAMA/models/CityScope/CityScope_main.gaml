/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform. 
*/

model CityScope

global {
	string cityScopeCity;
	// GIS FILE //	
	file bound_shapefile <- file("./../../includes/City/"+cityScopeCity+"/Bounds.shp");
	file buildings_shapefile <- file("./../../includes/City/"+cityScopeCity+"/Buildings.shp");
	file roads_shapefile <- file("./../../includes/City/"+cityScopeCity+"/Roads.shp");
	file amenities_shapefile <- file("./../../includes/City/"+cityScopeCity+"/Amenities.shp");
	file table_bound_shapefile <- file("./../../includes/City/"+cityScopeCity+"/table_bounds.shp");
	file imageRaster <- file('./../../images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	graph road_graph;
	graph<people, people> interaction_graph;
	
	//PARAMETERS
	bool moveOnRoadNetworkGlobal <- true parameter: "Move on road network:" category: "Simulation";
	int distance parameter: 'distance ' category: "Visualization" min: 1 max:200 <- 100;	
	bool drawInteraction <- false parameter: "Draw Interaction:" category: "Visualization";
	bool cityMatrix <-true parameter: "CityMatrix:" category: "Environment";
	bool onlineGrid <-true parameter: "Online Grid:" category: "Environment";
	bool localHost <-false parameter: "Local Host:" category: "Environment";
	bool dynamicGrid <-false parameter: "Update Grid:" category: "Environment";
	bool realAmenity <-true parameter: "Real Amenities:" category: "Environment";
	bool dynamicPop <-false parameter: "Dynamic Population:" category: "Environment";
	int refresh <- 50 min: 1 max:1000 parameter: "Refresh rate (cycle):" category: "Environment";
	int refreshPop <- 100 min: 1 max:1000 parameter: "Pop Refresh rate (cycle):" category: "Environment";
	float minimum_cycle_duration <- 0.02;
	
	/////////// CITYMATRIX   //////////////
	map<string, unknown> cityMatrixData;
	list<map<string, int>> cityMatrixCell;
	list<float> density_array;
	list<float> current_density_array;
	int toggle1;
	map<int,list> citymatrix_map_settings<- [-1::["Green","Green"],0::["R","L"],1::["R","M"],2::["R","S"],3::["O","L"],4::["O","M"],5::["O","S"],6::["A","Road"],7::["A","Plaza"],8::["Pa","Park"],9::["P","Parking"]];	
	map<string,rgb> color_map<- ["R"::#white, "O"::#gray,"S"::#gamablue, "M"::#gamaorange, "L"::#gamared, "Green"::#green, "Plaza"::#white, "Road"::#black,"Park"::#black,"Parking"::rgb(50,50,50)]; 
	list scale_string<- ["S", "M", "L"];
	list usage_string<- ["R", "O"]; 
	list density_map<- [89,55,15,30,18,5]; //Use for Volpe Site (Could be change for each city)
	
	float step <- 10 #sec;
	int current_hour update: (time / #hour) mod 24  ;
	int current_day<-0;
	int min_work_start <-4 ;
	int max_work_start <- 10;
	int min_lunch_start <- 11;
	int max_lunch_start <- 13;
	int min_rework_start <- 14;
	int max_rework_start <- 16;
	int min_dinner_start <- 18;
	int max_dinner_start <- 20;
	int min_work_end <- 21; 
	int max_work_end <- 22; 
	float min_speed <- 4 #km / #h;
	float max_speed <- 6 #km / #h; 
	float angle;
	point center;
	float brickSize;
	float coeffPop<-1.0;
	int coeffSize<-20;
	string cityIOUrl;
	//Global indicator
	list<list<point>> nbInteraction <-[{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}];
	list<list<point>> entropySeries <-[{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}];
	float averageEntropy;
	float averageClusterSize <-1;
	list<list<people>> clusters <- [];
	
	
	init {
		create table from: table_bound_shapefile;
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale")),nbFloors::1+float(read ("Floors"))]{
			area <-shape.area;
			perimeter<-shape.perimeter;
			depth<-50+rnd(50);
		}
		create road from: roads_shapefile ;
		road_graph <- as_edge_graph(road);
		
		if(realAmenity = true){
          create amenity from: amenities_shapefile{
		    scale <- scale_string[rnd(2)];	
		    fromGrid<-false;
		    size<-10+rnd(20);
		  }		
        }
        
        if(cityScopeCity= "volpe"){        	
        	if(false){// last realease with feet
        	angle <- -9.74;
			center <-{1007,632};
			brickSize <- 21.3;
			coeffPop<-1.0;
			coeffSize<-3;
        		
        	}else{
        		angle <- -9.74;
			center <-{3305,2075};
			brickSize <-  70.0;
			coeffPop<-1.0;
			coeffSize<-1;
        	}
        	
			
		}
		if(cityScopeCity= "andorra"){
			angle <-3.0;
			center <-{2550,895};
			brickSize <- 37.5;
			coeffPop<-2.0;
			coeffSize<-1;
		}
		
		if(cityScopeCity= "Lyon"){
			angle <-3.0;
			center <-{2550,895};
			brickSize <- 37.5;
			coeffPop<-2.0;
			coeffSize<-1;
		}
		
		if(cityScopeCity= "San_Francisco"){
			angle <-3.0;
			center <-{2550,895};
			brickSize <- 37.5;
			coeffPop<-10.0;
			coeffSize<-1;
		}
		
		if(cityScopeCity= "Taipei"){
			angle <-3.0;
			center <-{2550,895};
			brickSize <- 37.5;
			coeffPop<-20.0;
			coeffSize<-1;
		}
		
		if(cityScopeCity= "Shanghai"){
			angle <-3.0;
			center <-{2550,895};
			brickSize <- 37.5;
			coeffPop<-10.0;
			coeffSize<-1;
		}
		      
        cityIOUrl <- (cityMatrix = true and !localHost) ? "https://cityio.media.mit.edu/api/table/citymatrix_"+cityScopeCity : "http://localhost:8080/table/citymatrix_"+cityScopeCity;	

	    if(cityMatrix = true){
	    	do initGrid;
	    }	
	    write cityScopeCity + " width: " + world.shape.width + " height: " + world.shape.height;
	}
	
		action initPop{
		  ask people {do die;}
		  int nbPeopleToCreatePerBuilding;
		  ask building where  (each.usage="R"){  	
		    nbPeopleToCreatePerBuilding <- int((self.scale="S") ? (area/density_map[2])*nbFloors: ((self.scale="M") ? (area/density_map[1])*nbFloors:(area/density_map[0])*nbFloors));
		  	create people number: (nbPeopleToCreatePerBuilding/100)*coeffPop { 
		  		living_place <- myself;
				location <- any_location_in (living_place);
				scale <- myself.scale;	
				speed <- min_speed + rnd (max_speed - min_speed) ;
				initialSpeed <-speed;
				time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
				time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
				time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
				time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
				time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
				working_place <- one_of(building  where (each.usage="O" and each.scale=scale)) ;
				eating_place <- one_of(amenity where (each.scale=scale )) ;
				dining_place <- one_of(amenity where (each.scale=scale )) ;
				objective <- "resting";
				fromTheGrid<-false;  
			}				
		  }
		  if(length(density_array)>0){
			  ask amenity where  (each.usage="R"){
	
				  	float nb <- (self.scale ="L") ? density_array[0] : ((self.scale ="M") ? density_array[1] :density_array[2]);
				  	create people number: 1+nb/3 { 
						living_place <- myself;
						location <- any_location_in (living_place);
						scale <- myself.scale;	
						speed <- min_speed + rnd (max_speed - min_speed) ;
						initialSpeed <-speed;
						time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
						time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
						time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
						time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
						time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
						working_place <- one_of(building  where (each.usage="O" and each.scale=scale)) ;
						eating_place <- one_of(amenity where (each.scale=scale )) ;
						dining_place <- one_of(amenity where (each.scale=scale )) ;
						objective <- "resting";
						fromTheGrid<-true; 
					}
			  }
			  write "initPop from density array" + density_array + " nb people: " + length(people); 
		  }
		  else{
		  	write "density array is empty";
		  }
		  
		 }
	
	action initGrid{
  		ask amenity where (each.fromGrid=true){
  			do die;
  		}
		if(onlineGrid = true){
		  cityMatrixData <- json_file(cityIOUrl).contents;
		  if (length(list(cityMatrixData["grid"])) = nil){
		  	cityMatrixData <- json_file("https://cityio.media.mit.edu/api/table/citymatrix_volpe").contents;
		  }
	    }
	    else{
	      cityMatrixData <- json_file("../includes/cityIO_Kendall.json").contents;
	    }	
		cityMatrixCell <- cityMatrixData["grid"];
		density_array <- cityMatrixData["objects"]["density"];
		toggle1 <- int(cityMatrixData["objects"]["toggle1"]);	
		loop l over: cityMatrixCell { 
		      create amenity {
		      	  id <-int(l["type"]);
		      	  x<-l["x"];
		      	  y<-l["y"];
				  location <- {	center.x + (13-l["x"])*brickSize,	center.y+ l["y"]*brickSize};  
				  location<- {(location.x * cos(angle) + location.y * sin(angle)),-location.x * sin(angle) + location.y * cos(angle)};
				  shape <- square(brickSize*0.9) at_location location;	
				  size<-10+rnd(10);
				  fromGrid<-true;  
				  scale <- citymatrix_map_settings[id][1];
				  usage<-citymatrix_map_settings[id][0];
				  color<-color_map[scale];
				  if(id!=-1 and id!=-2 and id!=7){
				  	density<-density_array[id];
				  }
              }	        
        }
        ask amenity{
          if ((x = 0 and y = 0) and fromGrid = true){
            do die;
          }
          if(cityScopeCity= "andorra"){
          	if((y<3 or y>11) or x>14){
          		do die;
          	}
          }
        }
		cityMatrixData <- json_file(cityIOUrl).contents;
		density_array <- cityMatrixData["objects"]["density"];
		
		if(cycle>10 and dynamicPop =true){
		if(current_density_array[0] < density_array[0]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[0]/current_density_array[0] -1);
			do generateSquarePop(tmp,"L");			
		}
		if(current_density_array[0] > density_array[0]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[0]/current_density_array[0]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="L")){
				do die;
			}
		}
		if(current_density_array[1] < density_array[1]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[1]/current_density_array[1] -1);
			do generateSquarePop(tmp,"M");	
		}
		if(current_density_array[1] > density_array[1]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[1]/current_density_array[1]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="M")){
				do die;
			}
		}
		if(current_density_array[2] < density_array[2]){
			float tmp<-length(people where each.fromTheGrid) * (density_array[2]/current_density_array[2] -1);
			do generateSquarePop(tmp,"S");
		}
		if(current_density_array[2] > density_array[2]){
			float tmp<-length(people where (each.fromTheGrid))*(1-density_array[2]/current_density_array[2]);
			ask tmp  among (people where (each.fromTheGrid and each.scale="S")){
				do die;
			}
		}
		}
        current_density_array<-density_array;		
	}
	

		
	reflex updateGrid when: ((cycle mod refresh) = 0) and (dynamicGrid = true) and (cityMatrix=true){		
		do initGrid;
	}
	
	reflex updateGraph when:(drawInteraction = true or toggle1 = 7){
		interaction_graph <- graph<people, people>(people as_distance_graph(distance));
	}
	
	reflex updateEntropy when: (length(interaction_graph) != 0 and false){
		clusters <- connected_components_of(interaction_graph);
		averageClusterSize <- clusters sum_of (length(each))/length(clusters);
	//	write "average cluster size: "+averageClusterSize;
			
		averageEntropy <- 0.0;
		loop c over: clusters{
			list<float> categoriesDistribution <- [];
			int cLength <- length(c);
			loop category over: scale_string{
				categoriesDistribution <+ (c count (each.scale = category))/cLength;
			}
			averageEntropy <- averageEntropy - cLength * ((categoriesDistribution where (each != 0)) sum_of (each * log(each))) ;
		}
		
		averageEntropy <- averageEntropy / length(people);
		//write "Average Entropy: "+averageEntropy;	
	}
	
	reflex initSim when: ((cycle mod 8640) = 0){
		do initPop;
		current_day<-current_day mod 6 +1;
		nbInteraction[current_day-1]<-[];
		entropySeries[current_day-1]<-[];
		
	}
		
	action generateSquarePop(int nb, string _scale){
		create people number:nb	{
				living_place <- one_of(amenity where (each.scale=_scale and each.fromGrid));
				location <- any_location_in (living_place);
				scale <- _scale;	
				speed <- min_speed + rnd (max_speed - min_speed) ;
				initialSpeed <-speed;
				time_to_work <- min_work_start + rnd (max_work_start - min_work_start) ;
				time_to_lunch <- min_lunch_start + rnd (max_lunch_start - min_lunch_start) ;
				time_to_rework <- min_rework_start + rnd (max_rework_start - min_rework_start) ;
				time_to_dinner <- min_dinner_start + rnd (max_dinner_start - min_dinner_start) ;
				time_to_sleep <- min_work_end + rnd (max_work_end - min_work_end) ;
				working_place <- one_of(building  where (each.usage="O" and each.scale=scale)) ;
				eating_place <- one_of(amenity where (each.scale=scale )) ;
				dining_place <- one_of(amenity where (each.scale=scale )) ;
				objective <- "resting";
				fromTheGrid<-true; 
			}
	}
}

species building schedules: []{
	string usage;
	string scale;
	float nbFloors<-1.0;//1 by default if no value is set.
	int depth;	
	float area;
	float perimeter;
	aspect base {	
     	draw shape color: rgb(50,50,50,125);
	}
	aspect realistic {	
     	draw shape color: rgb(75,75,75) depth:depth;
	}
	aspect usage{
		draw shape color: color_map[usage];
	}
	aspect scale{
		draw shape color: color_map[scale];
	}
	aspect scaleRes{
		if(usage = "R"){
		  draw shape color: color_map[scale];
		}
		
	}
	aspect usageRes{
		if(usage = "R"){
		  draw shape color: color_map[usage];
		}
		
	}
	
	aspect demoScreen{
		if(toggle1=1){
			draw shape color: color_map[usage];
		}
		if(toggle1=2){
			if(usage="O"){
			  draw shape color: color_map[scale];
			}
			
		}
		if(toggle1=3){
			if(usage="R"){
			  draw shape color: color_map[scale];
			}
		}
	}
	aspect demoTable{
		if(toggle1=2){
			draw shape color: color_map[usage];
		}
		if(toggle1=3){
			draw shape color: color_map[scale];
		}
	}
}

species road  schedules: []{
	rgb color <- #red ;
	aspect base {
		draw shape color: rgb(125,125,125);
	}
	
	aspect white {
		draw shape color: #white ;
	} 
}

species people skills:[moving]{
	rgb color <- #yellow ; 
	float initialSpeed;
	building living_place <- nil ;
	building working_place <- nil ;
	amenity eating_place<-nil;
	amenity dining_place<-nil;
	int time_to_work ;
	int time_to_lunch;
	int time_to_rework;
	int time_to_dinner;
	int time_to_sleep;
	string objective ;
	string curMovingMode<-"wandering";	
	string scale;
	string usage; 
	point the_target <- nil ;
	int degree;
	float radius;
	bool moveOnRoad<-true;
	bool fromTheGrid<-false;
	
	action travellingMode{
		curMovingMode <- "travelling";
		speed <-initialSpeed;	
	}
	
    reflex updateTargetAndObjective {
		
		if(current_hour > time_to_work and current_hour < time_to_lunch  and objective = "resting"){
			objective <- "working" ;
			the_target <- any_location_in (working_place);
			do travellingMode;			
	    }
	
	    if(current_hour > time_to_lunch and current_hour < time_to_rework and objective = "working"){
			objective <- "eating" ;
			the_target <- any_location_in (eating_place); 
			do travellingMode;
	    } 
	
	    if (current_hour > time_to_rework and current_hour < time_to_dinner  and objective = "eating"){
			objective <- "reworking" ;
			the_target <- any_location_in (working_place);
			do travellingMode;
	    } 
	    if(current_hour > time_to_dinner and current_hour < time_to_sleep  and objective = "reworking"){
			objective <- "dinning" ;
			the_target <- any_location_in (dining_place);
			do travellingMode;
	    } 
	
	    if(current_hour > time_to_sleep and (current_hour < 24) and objective = "dinning"){
			objective <- "resting" ;
			the_target <- any_location_in (living_place);
			do travellingMode;
	    } 
		
	} 
	 
	reflex move {
	    if(moveOnRoad = true and the_target !=nil){
	      do goto target: the_target on: road_graph  ; 
	    }else{
	      do goto target: the_target;
	    }
		
		if (the_target = location) {
			the_target <- nil ;
			curMovingMode <- "wandering";
		}
		if(curMovingMode = "wandering"){
			do wander speed:(0.5/coeffSize) #km / #h;
		}
	}
		
	
	aspect scale{
	if(toggle1 !=1){
      if(!fromTheGrid){	
		  draw circle(10#m*coeffSize) color: color_map[scale];
		   
	  }else{
		  draw square(10#m*2*coeffSize) color: color_map[scale];  
	  }
	 } 
	}
	
	aspect scaleTable{
		if(toggle1 >4)
		{
		  draw circle(coeffSize*4) color: color_map[scale];	
		}
      
	}
}

species amenity parent:building schedules:[]{
	int id;
	bool fromGrid;
	float density <-0.0;
	rgb color;
	int x;
	int y;
	float size;
	
	aspect white{
		if(fromGrid and id!=-2	){
			draw shape rotated_by -angle color: #white;
		}
	}
	
	aspect scaleGrid{
		if(fromGrid and id!=-2	){
			draw shape rotated_by -angle color: rgb(color.red, color.green, color.blue);
		}
	}
	
	aspect base{
		if(fromGrid){
			if(color!=nil){
			draw shape rotated_by -angle color: rgb(color.red, color.green, color.blue,75);
			}
		}
		else{
			  draw circle(size/coeffSize) empty:true border:#white color: #white;
		      draw circle(size/coeffSize) color: rgb(255,255,255,125);	
		}	
	}
	
	aspect realistic {	
     	if(fromGrid and id!=-2){
			draw shape rotated_by -angle color: #gray depth:density*10;//rgb(color.red, color.green, color.blue) depth:density*10;
		}
	}

	aspect onScreen {
		if(fromGrid){
			if(color!=nil){
			  draw shape rotated_by -angle color: rgb(color.red, color.green, color.blue,75);	
			}
		}
		else{
			if (toggle1 =  6){
			  draw circle(size) empty:true border:#white color: #white;
		      draw circle(size) color: rgb(255,255,255,125);	
			}
		}
	}
	
    aspect onTable {
		if(!fromGrid){
			if (toggle1 =  6){
			  draw circle(size) empty:true border:#white color: #white;
		      draw circle(size) color: rgb(255,255,255,125);	
			}
		}
	}
}

species table{
	aspect base {
		draw shape empty:true border:rgb(75,75,75) color: rgb(75,75,75) ;
	}	
}



experiment CityScopeMainVirtual type: gui {
	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <-"volpe" among:["volpe", "andorra","San_Francisco","Taipei_MainStation","Shanghai"];
	
	output {	
		display CityScopeVirtual  type:opengl background:#black virtual:true toolbar:false{
			species table aspect:base refresh:false;
			species building aspect:base position:{0,0,-0.0015};	
			species road aspect: base refresh:false;
			species people aspect:scale;
			species amenity aspect: onScreen ;
			
		    graphics "text" 
			{
               draw "day" +  string(current_day) + " - " + string(current_hour) + "h"  color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.8,world.shape.height*0.975};
               draw imageRaster size:40#px at:{world.shape.width*0.95, world.shape.height*0.95};
            }
            graphics "density"{
             	point hpos<-{world.shape.width*0.85,world.shape.height*0.675};
             	int barW<-20;
             	int factor<-10;
             	loop i from: 0 to: length(density_array) -1{
             		draw rectangle(barW,density_array[i]*factor) color: (i=0 or i=3) ? #gamared : ((i=1 or i=4) ? #gamaorange: #gamablue) at: {hpos.x+barW*1.1*i,hpos.y-density_array[i]*factor/2};
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
			
			graphics "Entropy plot"{
            	if(drawInteraction){
	            	point ppos<-{world.shape.width*1.1,world.shape.height*0.5};
	             	point proi<-{2500,1000};
	             	draw "Average Entropy" color: # white font: font("Helvetica", 25, #plain) at: {ppos.x+proi.x*0.35,ppos.y+150};
	             	draw string(averageEntropy/log(3)) color: # white font: font("Helvetica", 20, #plain) at: {ppos.x-proi.x*0.125,ppos.y-proi.y/2};
	             	draw line([ppos,{ppos.x,ppos.y-proi.y}]) color:#white width:1 end_arrow:50;
	             	draw line([ppos,{ppos.x+proi.x,ppos.y}]) color:#white width:1 end_arrow:50;
	             	entropySeries[current_day-1]<+{ppos.x+(cycle mod 8640/8640)*proi.x,ppos.y-averageEntropy/log(3)*proi.y};
	             	draw line(entropySeries[current_day-1]) color:rgb(255,255,255) width:2;
	             	loop i from:1 to:current_day-1{
	             	 draw line(entropySeries[current_day-1-i]) color:rgb(255-50*i,255-50*i,255-50*i) width:1;	
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






