/***
* Name: cityScopableHousingChoice 
* Author: mireia yurrita + GameIt
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model cityScopableHousingChoice

global{
	
	file<geometry>buildings_shapefile<-file<geometry>("./../includesCalibration/City/volpe/Buildings.shp");
	file<geometry> roads_shapefile<-file<geometry>("./../includesCalibration/City/volpe/Roads_big.shp");
	file<geometry> busStops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/kendall_busStop.shp");
	file<geometry> TStops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/kendall_TStops.shp");
	file<geometry> entry_point_shapefile <- file<geometry>("./../includesCalibration/City/volpe/kendall_entry_points.shp");
	file<geometry> Tline_shapefile <- file<geometry>("./../includesCalibration/City/volpe/kendall_Tline.shp");
	file<geometry> roads_kendall_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Roads.shp");
	//geometry shape<-envelope(roads_kendall_shapefile);
	geometry shape<-envelope(roads_shapefile);
	
	
	
	/***file calibratedCase <- file("../results/incentivizedScenarios/MLResultsCalibratedData.csv");
	file diversityIncentive <- file("../results/incentivizedScenarios/MLResultsDiversityIncentive.csv");
	file kendallFancyIncentive <- file("../results/incentivizedScenarios/MLResultsKendallFancyIncentive.csv");
	file envFriendlyIncentive <- file("../results/incentivizedScenarios/MLResultsEnvFriendlyIncentive.csv");
	file diversityKendallFancyIncentive <- file("../results/incentivizedScenarios/MLResultsDiversityKendallFancyIncentive.csv");
	file diversityEnvFriendlyIncentive <- file("../results/incentivizedScenarios/MLResultsDiversityEnvFriendlyIncentive.csv");
	file kendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenarios/MLResultsEnvFriendlyKendallFancyIncentive.csv");
	file diversityKendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenarios/MLResultsEnvFriendlyKendallFancyDiversityIncentive.csv");***/
	file calibratedCase <- file("../results/incentivizedScenarios/CalibratedData.csv");
	file diversityIncentive <- file("../results/incentivizedScenarios/DiversityIncentive.csv");
	file kendallFancyIncentive <- file("../results/incentivizedScenarios/KendallFancyIncentive.csv");
	file envFriendlyIncentive <- file("../results/incentivizedScenarios/EnvFriendlyIncentive.csv");
	file diversityKendallFancyIncentive <- file("../results/incentivizedScenarios/DiversityKendallFancyIncentive.csv");
	file diversityEnvFriendlyIncentive <- file("../results/incentivizedScenarios/DiversityEnvFriendlyIncentive.csv");
	file kendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenarios/EnvFriendlyKendallFancyIncentive.csv");
	file diversityKendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenarios/EnvFriendlyKendallFancyDiversityIncentive.csv");
	file activity_file <- file("../includesCalibration/Criteria/ActivityPerProfile.csv");
	file originalProfiles <- file("../includesCalibration/Criteria/Profiles.csv");
	file mode_file <- file("../includesCalibration/Criteria/Modes.csv");
	
	//PARAMETERS
	int builtFloors <- 10 parameter: "Built Floors: " category: "Area" min: 0 max: 50 step: 5;
	float devotedResidential <- 0.5 parameter: "Percentage of area for residential use: " category: "Area" min: 0.4 max: 1.0 step: 0.1; //slider
	float subsidyPerc <- 0.0 parameter: "Percentage of subsidy: " category: "Financial incentives " min: 0.0 max: 1.0 step: 0.05; //slider
	bool kendallFancy <- false parameter: "Kendall fanciness incentive " category: "Behavioural incentives ";
	bool diversityAcceptance <- false parameter: "Diversity acceptance incentive " category: "Behavioural incentives ";
	bool environmentallyFriendly <- false parameter: "Environmentally friendly transport promotion " category: "Behavioural incentives ";
	int initPopulation <- 11585 max: 50000 parameter: "Population: " category: "Population";
	
	date starting_date <- date([2020,7,1,8,0,0]);
	
	float proportion_apart_reduction <- 0.05;
	int nbPeopleKendall;
	float builtArea<- 0.0; //if Volpe grid, different floors for each building possible. builtArea is the one to search
	float untilNowInKendall <- 0.0;
	float propInKendall <- 0.0;
	int agent_per_point <- 4;
	list<int> listBusRoutes;
	float meanCommTime;
	float meanCommDist;
	float propVolpe;
	int minRentPrice;
	int maxRentPrice;
	float angle <- atan((899.235 - 862.12)/(1083.42 - 1062.038));
	//point startingPoint <- {1025, 1160}; //kendall_roads
	point startingPoint <- {2165, 2120}; //roads_big
	//point startingPoint <- {4205,3830};
	float brickSize <- 21.3;
	list<string> prof_list;
	list<rgb> list_T_lines;
	map<string,int> listAreasApartment <- ["S"::15,"M"::55,"L"::89];
	int microUnitArea <- 40;
	list<string> mobility_list <- ['car', 'bus', 'T', 'bike', 'walking'];
	map<string,rgb> mobilityColorMap <- ['car'::#red, 'bus'::#yellow, 'T'::#orange, 'bike'::#blue, 'walking'::#green];
	map<string,float> mobilityMap;
	map<string,float> profileMap;
	map<string,float> originalProportions;
	map<string,float> outKendallProportions;
	map<string,rgb> colorMap;
	map<string,map<string,int>> activity_data;
	map<string,graph> graph_per_mobility_road;
	map<rgb,graph> graph_per_mobility_T;
	map<string,rgb> color_per_mobility;
	map<string,float> speed_per_mobility;
	map<int,rgb> bus_route_colors <- [701::#yellow, 747::#red,69::#blue, 68::#green];
	list<apartment> gridApartments <- [];
	
	init{
		do createBuildings;
		do createRoads;
		do createMinorRoads;
		do createTlines;
		do characteristic_file_import;
		do compute_graph;
		do createBusStops;
		do createBus;
		do createTStops;
		do createT;
		do createEntryPoints;
		if (builtFloors != 0){
			do createGrid;
		}
		do normaliseRents;
		do importOriginalValues;
		do importData;
		do activity_data_import;
		do createPopulation;	
		
	}
	
	action createBuildings{
		create building from: buildings_shapefile with:[usage::string(read("Usage")), rentPrice::read("PRICE"), category::read("Category"), scale::string(read("Scale")), heightValue::float(read("Max_Height"))]{
			if(usage != "R"){
				rentPrice <- 0.0;
			}
			//heightValue <- 15;
			float rentPriceBuilding <- rentPrice;
			float areaBuilding <- shape.area;
			float areaApartment <- listAreasApartment[scale];
			building ImTheBuilding <- self;
			int nbFloors <- heightValue/5;
			
			if(usage = "R"){
				create apartment number: int(areaBuilding / areaApartment*nbFloors *proportion_apart_reduction){
					int numberApartment <- int(areaBuilding / areaApartment*nbFloors *proportion_apart_reduction);
					rent <- rentPriceBuilding;
					associatedBuilding <- ImTheBuilding;
					location <- associatedBuilding.location;
				}
			}
			
		}
	}
	
	action normaliseRents{
		maxRentPrice <- max(building collect each.rentPrice);
		minRentPrice <- min(building where(each.usage="R") collect each.rentPrice);
		float geometricMean <- geometric_mean(building collect(each.rentPrice));
		ask building where(each.usage="R"){
			do normaliseRentPrice;
		}
	}
	
	action importOriginalValues{
		matrix data_matrix <- matrix(originalProfiles);
		
		loop i from: 0 to: data_matrix.rows - 1{
			prof_list << data_matrix[0,i];
			colorMap[data_matrix[0,i]] <- data_matrix[1,i];
			originalProportions[data_matrix[0,i]] <- data_matrix[4,i];
		} 
	}
	
	action createRoads{
		create road from:roads_shapefile{
			mobility_allowed <-["walking","bike","car","bus"];
		}
	}
	
	
	action createMinorRoads{
		create minor_road from:roads_kendall_shapefile{
			mobility_allowed <-["walking","bike","car","bus"];
		}
	}
	
	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			if(mobility_mode != "T"){
				graph_per_mobility_road[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;
			}
			else{
				loop i from: 0 to: length(list_T_lines) - 1{
					graph_per_mobility_T[list_T_lines[i]] <- as_edge_graph(T_line where(each.line = list_T_lines[i])) use_cache false;
				}
				write "graph_per_mobility_T " + graph_per_mobility_T;
			}
				
		}
	}
	
	action characteristic_file_import {
		matrix mode_matrix <- matrix (mode_file);
		loop i from: 0 to:  mode_matrix.rows - 1 {
			string mobility_type <- mode_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to:  mode_matrix.columns - 2 {
					vals << float(mode_matrix[j,i]);	
				}
				color_per_mobility[mobility_type] <- rgb(mode_matrix[7,i]);
				speed_per_mobility[mobility_type] <- float(mode_matrix[9,i]);
			}
		}
	}
	
	action createBusStops{
		create bus_stop from: busStops_shapefile with: [route::int(read("ROUTE")), station_num::int(read("STOP_NUM"))]{
			if (listBusRoutes contains route = false){
				listBusRoutes << route;
			}
		}
	}
	
	action createBus {
		int cont <- 0;
		create bus number: length(listBusRoutes){
			route  <- listBusRoutes[cont];
			list<bus_stop> stops_list <- list(bus_stop where (each.route = route));
			stops <- stops_list sort_by (each.station_num);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
			cont_station_num <- 0;
			ascending <- true;
			cont <- cont + 1;
		}
	}
	
	action createTStops{
		create T_stop from: TStops_shapefile with: [line::rgb(read("LINE")), station::string(read("STATION")), station_num::int(read("STOP_NUM"))]{
		}
	}
	
	action createT{
		list<T_stop> T_stops_list <- list(T_stop);
		map<rgb, list<T_stop>> T_stops_per_color;
		list<rgb> already_color;
		loop indiv_stop over: T_stops_list{
			rgb indiv_color <- indiv_stop.line;
			if (already_color contains indiv_color = false){
				already_color << indiv_color;
				list<T_stop> equal_color_list <- [];
				loop equal_color over: T_stops_list{
					if (equal_color != self and equal_color.line = indiv_color){
						equal_color_list << equal_color;
					}
				}
				T_stops_per_color[indiv_color] <- equal_color_list;
			}
		}
		
		loop color_stops over: T_stops_per_color.keys{
			create T{
				line <- color_stops;
				list<T_stop> stops_list <- list(T_stop where (each.line = line));
				stops <- stops_list sort_by (each.station_num);
				location <- first(stops).location;
				stop_passengers <- map<T_stop, list<people>>(stops collect(each::[]));
				cont_station_num <- 0;
				ascending <- true;
				
			}
		}
		
	}
	
	action createTlines{
		create T_line from: Tline_shapefile with: [line::rgb(read("LINE"))]{
			mobility_allowed <- ["T"];
			if(list_T_lines contains line = false){
				list_T_lines << line;
			}
		
			changeIntensity1 <- rnd(0.3,1.0);
			changeIntensity2 <- rnd(0.3,1.0);
			changeIntensity3 <- rnd(0.3,1.0);
			changeIntensity4 <- rnd(0.3,1.0);
			changeIntensity5 <- rnd(0.3,1.0);
			changeIntensity6 <- rnd(0.3,1.0);
		
		}
		
	}
	
	action createEntryPoints{
		create entry_point from: entry_point_shapefile with: [type_entry::string(read("mobility"))]{
			entry_point ImTheEntry <- self;
			create building{
				ImTheEntry.associatedBuilding <- self;
				location <- ImTheEntry.location;
				isEntryPoint <- true;
			}
		}
	}
	
	float interpValues(float x1,float x2,float x3,float y1,float y3){
		float y2;
		if(x3 != x1){
			y2 <- (x2 - x1)*(y3 - y1) / (x3 - x1) + y1;
		}
		else{
			y2 <- y1; //and equal to y3
		}
		
		
		return y2;		
	}
	
	action importData{
		matrix data_matrix;
		if(kendallFancy = false and diversityAcceptance = false and environmentallyFriendly = false){
			data_matrix <- matrix(calibratedCase);
		}
		if (kendallFancy = true and diversityAcceptance = false and environmentallyFriendly = false){
			 data_matrix<-matrix(kendallFancyIncentive);
		}
		if(kendallFancy = false and diversityAcceptance = true and environmentallyFriendly = false){
			data_matrix <- matrix(diversityIncentive);	
		}
		if(kendallFancy = false and diversityAcceptance = false and environmentallyFriendly = true) {
			data_matrix <- matrix(envFriendlyIncentive);
		}
		if(kendallFancy = true and diversityAcceptance = true and environmentallyFriendly = false){
			data_matrix <- matrix(diversityKendallFancyIncentive);
		}
		if(kendallFancy = true and diversityAcceptance = true and environmentallyFriendly = true){
			data_matrix <- matrix(diversityKendallFancyEnvFriendlyIncentive);
		}
		if(kendallFancy = false and diversityAcceptance = true and environmentallyFriendly = true){
			data_matrix <- matrix(diversityEnvFriendlyIncentive);	
		}
		if(kendallFancy = true and diversityAcceptance = false and environmentallyFriendly = true){
			data_matrix <- matrix(kendallFancyEnvFriendlyIncentive);
		}
		
		float minDifferenceUntilNow <- 10000000000.0;
		float minDifferenceNow <- 0.0;
		int location <- 0;
		int interpLocation <- 1;
		
		if(builtArea != 0){
				loop i from:0 to: data_matrix.rows - 1{ //provisional. Increase granularity with ML
				float areaValue <- data_matrix[0,i];
				float perMarketPrice <- data_matrix[1,i];
				if ((1 - subsidyPerc) = perMarketPrice){
					minDifferenceNow <- abs(builtArea - areaValue);
					if(minDifferenceNow < minDifferenceUntilNow){
						minDifferenceUntilNow <- minDifferenceNow;
						location <- i;
						if(location != data_matrix.rows - 1 and data_matrix[1,location] = data_matrix[1,location + 1]){
							if((builtArea - areaValue) < 0){
							interpLocation <- location - 1;
							}
							else{
								interpLocation <- location + 1;
							}
						}
						else{
							interpLocation <- location;
						}
						
					}
				}
			}
		}
		else{
			location <- 0;
			interpLocation <- 0;
		}

		untilNowInKendall <- propInKendall;
		float areaValueLocation <- data_matrix[0,location];
		float areaValueInterpLocation <- data_matrix[0,interpLocation];
		float propInKendallLocation <- data_matrix[2,location];
		float propInKendallInterpLocation <- data_matrix[2,interpLocation];
		propInKendall <- interpValues(areaValueLocation, builtArea, areaValueInterpLocation, propInKendallLocation, propInKendallInterpLocation);
		nbPeopleKendall <- int(propInKendall*initPopulation);
		
		loop i from:3 to:10{
			string profi <- prof_list[i -3];
			float propProfLocationi <- data_matrix[i,location];
			float propProfInterpLocationi <- data_matrix[i,interpLocation];
			float propProfi <- interpValues(areaValueLocation,builtArea,areaValueInterpLocation,propProfLocationi,propProfInterpLocationi);
			profileMap[profi] <- propProfi;
			outKendallProportions[profi] <- abs(originalProportions[profi] - propProfi);
		}
		
		loop i from: 11 to:15{
			float mobPropLocationi <- data_matrix[i,location];
			float mobPropInterpLocationi <- data_matrix[i,interpLocation];
			float mobPropi <- interpValues(areaValueLocation, builtArea, areaValueInterpLocation, mobPropLocationi, mobPropInterpLocationi);
			string mobi <- mobility_list[i - 11];
			mobilityMap[mobi] <- mobPropi;
		}
		
		float meanCommTimeLocation <- data_matrix[16,location];
		float meanCommTimeInterpLocation <- data_matrix[16,interpLocation];
		meanCommTime <- interpValues(areaValueLocation, builtArea, areaValueInterpLocation, meanCommTimeLocation, meanCommTimeInterpLocation);
		float meanCommDistLocation <- data_matrix[17,location];
		float meanCommDistInterpLocation <- data_matrix[17,interpLocation];
		meanCommDist <- interpValues(areaValueLocation, builtArea, areaValueInterpLocation, meanCommDistLocation, meanCommDistInterpLocation);
		float propVolpeLocation <- data_matrix[18,location];
		float propVolpeInterpLocation <- data_matrix[18,interpLocation];
		propVolpe <- interpValues(areaValueLocation, builtArea, areaValueInterpLocation, propVolpeLocation, propVolpeInterpLocation);
	}
	
	action createPopulation{
		int numberApartmentsVolpe <- count(apartment, each.associatedBuilding.fromGrid = true);				
		int peopleInVolpe <- int(numberApartmentsVolpe*propVolpe);
		int countRemaining <- peopleInVolpe;
		create people number: int(nbPeopleKendall/agent_per_point){
			liveInKendall <- true;	
			type <- profileMap.keys[rnd_choice(profileMap.values)];
			color <- colorMap[type];
			if (devotedResidential != 0){
				if(countRemaining > 0){
					countRemaining <- countRemaining - agent_per_point;
					//livingPlace <- apartment where each.associatedBuilding.fromGrid = true;
					livingPlace <- one_of(gridApartments);
					if(livingPlace = nil){
						livingPlace <- one_of(apartment);
					}
				}
				else{
					livingPlace <- one_of(apartment);
				}
			}
			else{
				livingPlace <- one_of(apartment where each.associatedBuilding.fromGrid = false);
			}
			location <- any_location_in(livingPlace.associatedBuilding);
			mobilityMode <- mobilityMap.keys[rnd_choice(mobilityMap.values)];
			loop while: (mobilityMode = "T"){
				mobilityMode <- mobilityMap.keys[rnd_choice(mobilityMap.values)];
			}
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));	
			closest_T_stop <- T_stop with_min_of(each distance_to(self));
			current_place <- livingPlace.associatedBuilding;				
			do create_trip_objectives;
		}
		
		create people number: int((initPopulation - nbPeopleKendall)/agent_per_point){
			liveInKendall <- false;
			type <- outKendallProportions.keys[rnd_choice(outKendallProportions.values)];
			color <- colorMap[type];
			mobilityMode <- mobilityMap.keys[rnd_choice(mobilityMap.values)];
			if(mobilityMode = "T"){
				livingPlace <- one_of(entry_point where (each.type_entry = "T"));
			}
			else{
				livingPlace <- one_of(entry_point where (each.type_entry = "road"));
			}
			location <- livingPlace.associatedBuilding.location;
			current_place <- livingPlace.associatedBuilding;
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));	
			closest_T_stop <- T_stop with_min_of(each distance_to(self));
			do create_trip_objectives;
		}
	}
		
	action createGrid{
		angle <- angle / 2;
		float acum_area <- 0.0;
		startingPoint <- {startingPoint.x - brickSize / 2, startingPoint.y - brickSize / 2};				
		bool noBuild;
		loop i from: 0 to: 12{
			loop j from: 0 to: 15{
				noBuild <- false;
				if(i = 12 and j > 11){
					noBuild <- true;
				}
				if(i = 11 and j > 11){
					noBuild <- true;
				}
				if(i = 10 and j > 12){
					noBuild <- true;
				}
				if(i = 9 and j > 12){
					noBuild <- true;
				}
				if([8,7] contains i = true and j > 13){
					noBuild <- true;
				}
				if(i = 6 and [9,10,11,14,15] contains j = true){
					noBuild <- true;
				}
				if(i = 5 and [8,9,10,11,15] contains j = true){
					noBuild <- true;
				}
				if(i = 4 and [7,8,9,10,11,15] contains j = true){
					noBuild <- true;
				}
				if(i = 3 and [7,8,9,10,11,12,15] contains j = true){
					noBuild <- true;
				}
				if([1,2] contains i = true and [7,8,9,10,11,12] contains j = true){
					noBuild <- true;
				}
				if(i = 0 and [7,8,9,10,11,12,13,14,15] contains j = true){
					noBuild <- true;
				}
				
				if(noBuild != true){
					create building{
						fromGrid <- true;
						int x <- j;
						int y <- i;
						point location_local_axes <- {x * brickSize + 15, y * brickSize};
						location <- {startingPoint.x + location_local_axes.x*sin(angle) - location_local_axes.y*cos(angle), startingPoint.y - location_local_axes.y*sin(angle) - location_local_axes.x*cos(angle)};
						shape <- square(brickSize * 0.9) at_location location;
						usage <- "mixed";
						category <- "mixed";
						//scale <- "microUnit";
						nbFloors <- builtFloors; //variable batch experiment
						heightValue <- builtFloors*5;
						builtArea <- builtArea + shape.area*nbFloors*devotedResidential;
						rentPrice <- (1-subsidyPerc)*3400;
						
						float areaBuilding <- shape.area;
						float rentBuilding <- rentPrice;
						building ImTheBuilding <- self;
						int numberApartment <- int(areaBuilding/microUnitArea*devotedResidential*builtFloors * proportion_apart_reduction);
						create apartment number: int(areaBuilding/microUnitArea*devotedResidential*builtFloors * proportion_apart_reduction){
							rent <- rentBuilding;
							associatedBuilding <- ImTheBuilding;
							location <- associatedBuilding.location;
							gridApartments << self;
						}
					}				
				}
			}	
		}
	}
	
	action activity_data_import {
		matrix activity_matrix <- matrix (activity_file);
		loop i from: 1 to:  activity_matrix.rows - 1 {
			string people_type <- activity_matrix[0,i];
			map<string, int> activities;
			string current_activity <- "";
			loop j from: 1 to:  activity_matrix.columns - 1 {
				string act <- activity_matrix[j,i];
				if (act != current_activity) {
					activities[act] <-j;
					 current_activity <- act;
				}
			}
			activity_data[people_type] <- activities;
		}
	}
	
	

}
	
species entry_point parent: apartment{
	string type_entry;
	
	aspect default{
		draw square(50) color: #white;
	}
}

species apartment{
	int rent;
	building associatedBuilding;
}

species building{
	int nbFloors;
	string usage;
	string category;
	int rentPrice;
	float normalisedRentPrice;
	bool fromGrid <- false;
	float heightValue;
	string scale;
	bool isEntryPoint <- false;
	
	action normaliseRentPrice{
		normalisedRentPrice <- (rentPrice - minRentPrice)/(maxRentPrice - minRentPrice);
	}
	
	aspect default{
		if(fromGrid = true){
			draw shape rotated_by angle color: rgb(50,50,50);
		}
		else{	
			draw shape color: rgb(50,50,50);
		}
	}
}


species road{
	list<string> mobility_allowed;
	float max_speed <- 30 #km/#h;
	
	aspect default{
		draw shape color: #grey;
	}
}

species minor_road parent: road{
	
}

species T_line parent:road{
	rgb line;
	float changeIntensity1;
	float changeIntensity2;
	float changeIntensity3;
	float changeIntensity4;
	float changeIntensity5;
	float changeIntensity6;
	
	aspect default{
		draw shape color: line;
	}
	
	aspect color_per_segment{
	
		if(line = #red){
			draw shape color: rgb(255*changeIntensity1,0,255*changeIntensity2);
			
		}
		else if(line = #green){
			draw shape color: rgb(0,255*changeIntensity3,255*changeIntensity4);
		}
		else{
			draw shape color: rgb(255*changeIntensity5,255*changeIntensity6,0);
		}
		//draw text: color: #white size: 5;
		//draw " " + self at: location + {-3,3} color: #white font: font('Default', 16, #bold) ;
		
	}
}

species bus_stop{
	list<people> waiting_people;
	int route;
	int station_num;
	
	aspect default{
		draw square(10) color: #yellow;
	}
	
	aspect debugging{
		draw square(30) color: bus_route_colors[route];
		draw " " + self at: location + {-3,-3} color: #white font: font('Default', 16, #bold) ;
		//draw " " + route at: location + {6,6} color: #white font: font('Default', 16, #bold) ;
	}
}

species bus skills: [moving] {
	list<bus_stop> stops; 
	map<bus_stop,list<people>> stop_passengers ;
	bus_stop my_target;
	int route;
	int cont_station_num;
	bool ascending;
	int stop_time;
	
	reflex new_target when: my_target = nil{
		bus_stop StopNow <- stops[cont_station_num];
		
		
		
		if(cont_station_num = length(stops)-1 and ascending = true){
			cont_station_num <- cont_station_num - 1;
			ascending <- false;
		}
		else if(cont_station_num = 0 and ascending = false){
			cont_station_num <- cont_station_num + 1;
			ascending <- true;
		}
		else {
			if(ascending = true){
				cont_station_num <- cont_station_num + 1;
			}
			else{
				cont_station_num <- cont_station_num - 1;
			}
		}
		
		my_target <- StopNow;
	}
	
	reflex r {
		if(stop_time = 0){
			do goto target: my_target.location on: graph_per_mobility_road["car"] speed:speed_per_mobility["bus"]*0.5;
			int nb_passengers <- stop_passengers.values sum_of (length(each));	
		}
		else{
			stop_time <- stop_time - 1;
		}
		
		if(location = my_target.location) {
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				bus_status <- 2;
			}
			stop_passengers[my_target] <- [];
			loop p over: my_target.waiting_people {
				bus_stop b <- bus_stop where (each.route = route) with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b] ;
			}
			my_target.waiting_people <- [];						
			my_target <- nil;		
			stop_time <- 30;	
		}
	}
	
	aspect default {
		draw rectangle(60,20) color: #orange border: #black;
	}
	
	aspect debugging {
		draw rectangle(60,20) color: bus_route_colors[route] border: #black;
		//draw "current_edge " + current_edge at: location + {-3,-100} color: #white font: font('Default', 50, #bold);
		draw "" + my_target at: location + {-3,100} color: #white font: font('Default', 50, #bold);
	}
}

species T_stop{
	string station;
	rgb line;
	list<people> waiting_people;
	int station_num;
	
	aspect default{
		if (station != "boundary"){
			draw square(40) color: line;
		}
		
	}
	
	aspect debugging{
		if (station != "boundary"){
			draw square(10) color: line;
		}
		draw " " + self at: location + {-3,-3} color: #white font: font('Default', 16, #bold) ;
	}
}

species T skills: [moving] {
	list<T_stop> stops; 
	map<T_stop,list<people>> stop_passengers ;
	T_stop my_target;
	rgb line;
	int cont_station_num;
	bool ascending;
	int stop_time;
	
	reflex new_target when: my_target = nil{
		
		T_stop StopNow <- stops[cont_station_num];
		
		if(cont_station_num = length(stops)-1 and ascending = true){
			cont_station_num <- cont_station_num - 1;
			ascending <- false;
		}
		else if(cont_station_num = 0 and ascending = false){
			cont_station_num <- cont_station_num + 1;
			ascending <- true;
		}
		else {
			if(ascending = true){
				cont_station_num <- cont_station_num + 1;
			}
			else{
				cont_station_num <- cont_station_num - 1;
			}
		}
		
		my_target <- StopNow;
	}
	
	reflex r {
		if (stop_time = 0){
			do goto target: my_target.location on: graph_per_mobility_T[line] speed:speed_per_mobility["T"]*0.5;
			int nb_passengers <- stop_passengers.values sum_of (length(each)); 
		}
		else{
			stop_time <- stop_time - 1;
		}
		
			
		if(location = my_target.location) {
			ask stop_passengers[my_target] {
				location <- myself.my_target.location;
				T_status <- 2;
			}
			stop_passengers[my_target] <- [];
			loop p over: my_target.waiting_people {
				T_stop b <- T_stop where(each.line = line) with_min_of(each distance_to(p.my_current_objective.place.location));
				add p to: stop_passengers[b];
			}
			my_target.waiting_people <- [];						
			my_target <- nil;	
			stop_time <- 30;		
		}
	}
	
	aspect default {
		draw rectangle(60,20) color: line border: #black;
	}
	
	aspect T_debugging {
		draw rectangle(60,20) color: line border: #black;
		//draw "current_edge " + current_edge at: location + {-3,-100} color: #white font: font('Default', 50, #bold);
		//draw "my_target " + my_target at: location + {-3,100} color: #white font: font('Default', 50, #bold);
	}
}

species people skills: [moving]{
	string type;
	rgb color;
	string mobilityMode;
	apartment livingPlace;
	building current_place;
	bool liveInKendall; 
	list<trip_objective> objectives;
	trip_objective my_current_objective;
	bus_stop closest_bus_stop;
	T_stop closest_T_stop;
	int bus_status <- 0;
	int T_status <- 0;
	
	action create_trip_objectives {
		map<string,int> activities <- activity_data[type];
		loop act over: activities.keys {
			if (act != "") {
				list<string> parse_act <- act split_with "|";
				string act_real <- one_of(parse_act);
				list<building> possible_bds;
				if (length(act_real) = 2) and (first(act_real) = "R") {
					if(liveInKendall = true){
						if (devotedResidential > 0){
							possible_bds <- building where ((each.usage = "R") or (each.usage = "mixed"));
						}
						else{
							possible_bds <- building where ((each.usage = "R"));	
						}
					}
					else{
						if(mobilityMode = "T"){
							possible_bds <- livingPlace.associatedBuilding;
						}
						else{
							possible_bds <- livingPlace.associatedBuilding;
						}
					}
				} 
				else if (length(act_real) = 2) and (first(act_real) = "O") {
					if(devotedResidential < 1){
						possible_bds <- building where ((each.usage = "O") or (each.usage = "mixed"));
					}
					else{
						possible_bds <- building where ((each.usage = "O"));
					}
				} 
				else {
					if(liveInKendall = true){ //people not living inKendall only commute
						if(devotedResidential < 1){
							if(act_real = "restaurant"){
								possible_bds <- building where(each.category = "Restaurant" or each.category = "mixed");
							}
							else if(act_real = "A"){
								possible_bds <- building where(each.category != "R");
							}
							else{
								possible_bds <- building where (each.category = act_real or each.category = "mixed");
							}
						}
						else{
							if(act_real = "restaurant"){
								possible_bds <- building where(each.category = "Restaurant");
							}
							else if(act_real = "A"){
								possible_bds <- building where(each.category != "R" and each.category != "mixed");
							}
							else{
								possible_bds <- building where (each.category = act_real);
							}
						}			
						
					}
					else{
						if(mobilityMode = "T"){
							possible_bds <- livingPlace.associatedBuilding;
						}
						else{
							possible_bds <- livingPlace.associatedBuilding;
						}
					}
				}
				building act_build <- one_of(possible_bds);
				if (act_build= nil) {write "problem with act_real: " + act_real;}
				do create_activity(act_real,act_build,activities[act]);
			}
		}
	}
	
	action create_activity(string act_name, building act_place, int act_time) {
		create trip_objective {
			name <- act_name;
			place <- act_place;
			starting_hour <- act_time;
			starting_minute <- rnd(60);
			myself.objectives << self;
		}
	} 
	
	reflex choose_objective when: my_current_objective = nil {
		do wander speed:0.01;
		my_current_objective <- objectives first_with ((each.starting_hour = current_date.hour) and (current_date.minute >= each.starting_minute) and (current_place != each.place) );
		if (my_current_objective != nil) {
			current_place <- nil;
		}
	}
	
	reflex move when: (my_current_objective != nil) and (mobilityMode != "bus") and (mobilityMode != "T") {
		if (mobilityMode in ["car"]) {
			//do goto target: my_current_objective.place.location on: graph_per_mobility[mobilityMode] move_weights: congestion_map ;
			do goto target: my_current_objective.place.location on: graph_per_mobility_road[mobilityMode];
		}else {
			do goto target: my_current_objective.place.location on: graph_per_mobility_road[mobilityMode]  ;
		}
		
		if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				location <- any_location_in(current_place);
				my_current_objective <- nil;
		}
	}
	
	reflex move_bus when: (my_current_objective != nil) and (mobilityMode = "bus") {

		if (bus_status = 0){
			do goto target: closest_bus_stop.location on: graph_per_mobility_road["walking"];
			if(location = closest_bus_stop.location) {
				add self to: closest_bus_stop.waiting_people;
				bus_status <- 1;
			}
		} else if (bus_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility_road["walking"];		
			
			if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
				location <- any_location_in(current_place);
				my_current_objective <- nil;	
				bus_status <- 0;
			}
		}		
	}
	
	reflex move_T when: (my_current_objective != nil) and (mobilityMode = "T") {

		if (T_status = 0){
			do goto target: closest_T_stop.location on: graph_per_mobility_road["walking"];
			
			if(location = closest_T_stop.location) {
				add self to: closest_T_stop.waiting_people;
				T_status <- 1;
			}
		} else if (T_status = 2){
			do goto target: my_current_objective.place.location on: graph_per_mobility_road["walking"];		
			
			if (location = my_current_objective.place.location) {
				current_place <- my_current_objective.place;
				closest_T_stop <- T_stop with_min_of(each distance_to(self));						
				location <- any_location_in(current_place);
				my_current_objective <- nil;	
				T_status <- 0;
			}
		}
	}
	
	
	aspect default{
		building ImTheCurrentPlace <- current_place;
		bool ItIsEntryPoint <- false;
		ask entry_point{
			if (associatedBuilding = ImTheCurrentPlace){
				ItIsEntryPoint <- true;
			}
		}
		if(ItIsEntryPoint = false){
			if (mobilityMode = "bike"){
			draw squircle(20,20) at_location {location.x,location.y} color:color ;
			}
			else if(mobilityMode = "car"){
				draw triangle(20) at_location {location.x,location.y} rotate: heading + 90 color:color;
			}
			else{
				draw circle(10) at_location {location.x,location.y} color:color;
			}
		}			
	}
}

species trip_objective{
	building place; 
	int starting_hour;
	int starting_minute;
}


experiment visual type:gui{

	output{
		display map type: opengl draw_env: false  autosave: false background: #black 
			{
			species building aspect: default;
			species road aspect: default;
			species minor_road aspect: default;
			species bus_stop aspect: default;
			species bus aspect: default;
			species T_stop aspect: default;
			species T aspect: default;
			species T_line aspect: default;
			//species entry_point aspect: default;
			//species people aspect: default;
			
			/***graphics "time" {
				draw string(current_date.hour) + "h" + string(current_date.minute) +"m" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.7,world.shape.height*0.55};
			}***/
	
			overlay position: {5,5} size: { 260 #px,750 #px } background: rgb(50,50,50,125) transparency: 1.0 border: #black 
		        {            	
		           rgb text_color<-#white;
		           float y <- 30#px;
		           float y2 <- world.shape.height*0.1;
		           float x <- world.shape.width*0.1;
		           draw "Icons" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
		            y <- y + 30#px;
		            
		            loop i from: 0 to: length(prof_list) - 1 {
		            	draw square(10#px) at: {20#px, y} color:colorMap[prof_list[i]] border: #white;
		            	draw string(prof_list[i]) at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            	y <- y + 25#px;
		            } 
		          //  y <- y + 100#px;
		         	 y <- y + 50#px;
		            draw "Input: " at:{40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		            draw "BuiltArea: " +  string(builtArea with_precision 2) + " m2" at:{40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		           // draw rectangle(builtArea/1000#px,10#px) at: {40#px+builtArea/2/1000#px, y} color:#white border: #white;
		          //  y <- y + 50#px;
		            draw "Subsidy: " + string(int(subsidyPerc*100)) + " %" at:{40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 100#px;
		           // draw rectangle(int(subsidyPerc*250)#px,10#px) at: {40#px+int(subsidyPerc*250/2)#px, y} color:#white border: #white;
		           // y <- y + 100#px;
		            draw "Output: " at:{40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		          //  draw "Percentage of people working "  at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		           // y <- y + 50 #px;    
	              //	draw "and living in Kendall: " + string(int(propInKendall*100) ) + " %" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		           draw "n_Kendall " + string(int(propInKendall*100) ) + " %" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50 #px; 
		            draw "n_Volpe: " + string(int(propVolpe*100)) + " %" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		           // draw rectangle(int(propInKendall*250)#px,10#px) at: {40#px+int(propInKendall*250/2)#px, y} color:#white border: #white;
		          //  y <- y + 50#px;
		          //  draw "Mean Commuting Distance: " + string(meanCommDist with_precision 2) + " m" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		           draw "d_comm: " + string(meanCommDist with_precision 2) + " m" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		                       
		          
		           // draw "Mean Commuting Time: " + string(meanCommTime with_precision 2) + " min" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		           draw "t_comm: " + string(meanCommTime with_precision 2) + " min" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            y <- y + 50#px;
		            
		           
		            
		            
		    	}
		    	
		    	chart "Mobility Modes" background:#black  type: pie size: {0.4,0.4} position: {world.shape.width*0.88,2#px} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
				tick_font: 'Helvetica' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Helvetica' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
				{
					loop i from: 0 to: length(mobilityMap.keys)-1	{
					  data mobilityMap.keys[i] value: mobilityMap.values[i] color:mobilityColorMap[mobilityMap.keys[i]];
					}
				}	
		    	
	    	}
	    	
		}    
}

experiment debug_T type:gui{

	output{
		display map type: opengl draw_env: false  autosave: false background: #black 
			{
			species T_stop aspect: debugging;
			species T aspect: T_debugging;
			species T_line aspect: color_per_segment;
			//species people aspect: default;
			
			}
	}
}

experiment debug_BUS type:gui{

	output{
		display map type: opengl draw_env: false  autosave: false background: #black 
			{
			species bus_stop aspect: debugging;
			species bus aspect: debugging;
			species road aspect: default;
			species minor_road aspect: default;
			//species people aspect: default;
			
			}
	}
}

