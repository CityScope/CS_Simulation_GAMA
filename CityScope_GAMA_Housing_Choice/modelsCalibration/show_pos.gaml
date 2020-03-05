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
	file resuls_30000 <- file("../results/blockGroups/results_segreg_2_11582.csv");
	list<string> type_people <- ["<$30000", "$30000 - $44999", "$45000 - $59999", "$60000 - $99999","$100000 - $124999","$125000 - $149999","$150000 - $199999", ">$200000"];
	map<string,rgb> color_per_type <- ["<$30000"::rgb(6,10,147), "$30000 - $44999"::#orange, "$45000 - $59999"::#red, "$60000 - $99999"::rgb(13,192,156), "$100000 - $124999"::#green, "$125000 - $149999"::#olive,"$150000 - $199999"::#purple, ">$200000"::#pink];
	geometry shape<-envelope(roads_shapefile);
	int it <- 0;
	
	init{
		do createBuildings;
		do createRoads;
		do createBlockGroups;
		do import_resuls_30000;
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
		create blockGroup from: blockGroup_shapefile with: [GEOID::string(read("GEOID"))]{
			area <- shape.area;
			perimeter <- shape.perimeter;
		}
	}
	
	action import_resuls_30000{
		matrix resuls_matrix <- matrix(resuls_30000);
		loop i from: 0 to: resuls_matrix.rows - 1{
			float location_x <- resuls_matrix[4,i];
			float location_y <- resuls_matrix[5,i];
			string people_type <- resuls_matrix[2,i];
			int agent_per_point <- resuls_matrix[resuls_matrix.columns - 1,i];
			int iteracion <- resuls_matrix[1,i];
			string living_place_ID <- resuls_matrix[3,i];
			
			if (iteracion = it){
				create people number:1{
					loc_x <- location_x;
					loc_y <- location_y;
					type <- people_type;
					ag_per_point <- agent_per_point;
					color <- color_per_type[people_type];
					if (living_place_ID != 0){
						living_place <- one_of(blockGroup where(each.GEOID = living_place_ID));
						location <- any_location_in(living_place);
					}
					else {
						//float rnd_value_x <- rnd(-100,100);
						//float rnd_value_y <- rnd(-100,100);
						float rnd_R <- rnd(0,100);
						float rnd_alpha <- rnd(0,360);
						location <- {loc_x + rnd_R * cos(rnd_alpha), loc_y + rnd_R * sin(rnd_alpha)};
						//location <- {loc_x + rnd_value_x,loc_y + rnd_value_y};
					}
					
				}				
			}
		}		
	}
	
	reflex renew when: (cycle mod 100 = 0){
		it <- it + 1;
		
		if (it <= 9){
			ask people{
				do die;
			}
			do import_resuls_30000;
		}
	
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
		draw circle(50) color:color;
	}
}

species road{
	aspect default{
		draw shape color: #grey;
	}
}

experiment visual type:gui{
	
	output{
		display map type: opengl draw_env: false fullscreen: 1 background: #black {
			species building aspect: default;
			species road;
			species people aspect: default;
			species blockGroup aspect: default;
			
			/***graphics "time" {
				draw string(it) + " iteration " color: #white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.9,world.shape.height*0.55};
			}***/
			
			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 1.0 border: #black 
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
		

            


		

