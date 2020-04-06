/***
* Name: showpos
* Author: mirei
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model showpos

global{
	string case_study<-"volpe";
	list<string> list_neighbourhoods <- [];
	string cityGISFolder<-"./../includes/City/"+case_study;
	file<geometry> blockGroup_shapefile <- file<geometry>("./../includesCalibration/City/volpe/tl_2015_25_bg_msa_14460_MAsss_TOWNS_Neighb.shp");
	file<geometry> buildings_shapefile <- file<geometry>("./../includesCalibration/City/volpe/BuildingsLatLongBlock.shp");
	file<geometry> roads_shapefile <- file<geometry>("./../includesCalibration/City/volpe/simplified_roads.shp");
	file<geometry> T_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_NODE_MAss_color.shp");
	file resuls_false <- file("../results/calibrateData/hillClimbing/resultingPeopleChoice 023.csv");
	file<geometry> T_lines_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Tline_cleanedQGIS.shp");
	list<string> type_people <- ["<$30000", "$30000 - $44999", "$45000 - $59999", "$60000 - $99999","$100000 - $124999","$125000 - $149999","$150000 - $199999", ">$200000"];
	map<string,rgb> color_per_type <- ["<$30000"::#cyan, "$30000 - $44999"::#blue, "$45000 - $59999"::rgb(0,128,128), "$60000 - $99999"::#green, "$100000 - $124999"::#pink, "$125000 - $149999"::#purple,"$150000 - $199999"::rgb(182, 102, 210), ">$200000"::#magenta];
	geometry shape<-envelope(T_lines_shapefile);
	int it <- 0;
	int initNow <- 1;
	
	init{
		do createBuildings;
		do createRoads;
		do createBlockGroups;
		do createTlines;
		do createTstops;
		do import_resuls;
	}
	
	action createBuildings{
		create building from: buildings_shapefile with:[ID::int(read("BUILDING_I"))]{
			area <- shape.area;
			perimeter <- shape.area;
		}
	}
	
	action createRoads{
		create road from: roads_shapefile{
			
		}
	}
	
	action createBlockGroups{
		create blockGroup from: blockGroup_shapefile with: [GEOID::string(read("GEOID")), lat::float(read("INTPTLAT")), long::float(read("INTPTLON"))]{
			area <- shape.area;
			perimeter <- shape.perimeter;
		}
	}
	
	action createTlines{
		create Tline from: T_lines_shapefile with: [line:: string(read("colorLine"))]{
			color <- rgb(line);	
		}
	}
	
	action createTstops{
		create Tstop from: T_stops_shapefile with:[station::string(read("STATION")), line::string(read("colorLine"))]{
			list<string> color_list <- [];
			loop cat over: line split_with "/"{
				color_list << cat; 
			}
			color <- first(rgb(color_list));
		}
		
	}
	
	action import_resuls{
		matrix resuls_matrix <- matrix(resuls_false);
		loop i from: 0 to: resuls_matrix.rows - 1{
			float location_x <- resuls_matrix[1,i];
			float location_y <- resuls_matrix[2,i];
			string people_type <- resuls_matrix[0,i];
			int agent_per_point <- resuls_matrix[resuls_matrix.columns - 1,i];
			//int iteracion <- resuls_matrix[1,i];
			int iteracion <- 0;
			//float living_placeBlock_lat <- resuls_matrix[3,i];
			//float living_placeBlock_long <- resuls_matrix[5,i];
			string GEOIDblock <- resuls_matrix[3,i];
			int init <- resuls_matrix[0,i];
			
			if (iteracion = it){
				create people number:1{
					loc_x <- location_x;
					loc_y <- location_y;
					type <- people_type;
					ag_per_point <- agent_per_point;
					color <- color_per_type[people_type];
					
					//living_place <- one_of(blockGroup where(each.lat = living_placeBlock_lat and each.long = living_placeBlock_long));
					living_place <- one_of(blockGroup where(each.GEOID = GEOIDblock));
					location <- any_location_in(living_place);	
					//location <- {loc_x, loc_y};		
					
				}				
			}
		}		
	}
	
	reflex renew when: (cycle mod 100 = 0){
		it <- it + 1;
		if (initNow = 1){
			initNow <- initNow - 1;
		}
		
		
		if (it <= 29){
			ask people{
				do die;
			}
			do import_resuls;
		}
	
	}
	
	
}

species Tline{
	string line;
	rgb color;
	
	aspect default{
		draw shape color: color;
	}
}

species Tstop{
	string station;
	string line;
	rgb color;
	
	aspect default{
		draw circle(100) color: color;
	}
}

species building{
	float area;
	float perimeter;
	int ID;
	
	aspect default{
		draw shape color: rgb(50,50,50,125);
	}
	
}

species blockGroup{
	float area;
	float perimeter;
	string GEOID;
	float lat;
	float long;
	
	aspect default{
		draw shape color: rgb(50,50,50,125);
	}
}

species people{
	float loc_x;
	float loc_y;
	string type;
	int ag_per_point;
	int iteracion;
	rgb color;
	blockGroup living_place;
	
	aspect default{
		draw circle(70) color:color;
	}
}

species road{
	aspect default{
		draw shape color: #grey;
	}
}

experiment visual type:gui{
	
	output{
		display map type: opengl draw_env: false fullscreen: 1 autosave: true background:#black {
			species building aspect: default;
			species road aspect: default;
			species blockGroup aspect: default;
			//species Tline aspect: default;
			//species Tstop aspect: default;
			species people aspect: default;
					
			overlay position: { 5, 5 } size: { 240 #px, 340 #px } background: # black transparency: 0.5 border: #black 
            {            	
                rgb text_color<-#white;
                float y <- 30#px;
                y <- y + 30 #px;     
                draw "Icons" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
                y <- y + 30 #px;
                
                loop i from: 0 to: length(type_people) - 1 {
                	draw square(10#px) at: {20#px, y} color:color_per_type[type_people[i]] border: #white;
                	draw string(type_people[i]) at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
                	y <- y + 25#px;
                	
                	
                }      
            }              
        }
	}
}
		

            


		

