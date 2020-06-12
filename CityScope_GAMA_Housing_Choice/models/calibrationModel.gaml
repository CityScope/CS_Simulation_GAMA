/***
* Name: calibrationModel
* Author: mireia yurrita
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model calibrationModel


global{
	
	string selectedCity <- "CAMBRIDGE";
	
	file<geometry> blockGroup_shapefile <- file<geometry>("./../includesCalibration/City/volpe/tl_2015_25_bg_msa_14460_MAsss_TOWNS_Neighb.shp");
	file<geometry> available_apartments <- file<geometry>("./../includesCalibration/City/volpe/apartments_march_great.shp");
	file<geometry> buildings_shapefile <- file<geometry>("./../includesCalibration/City/volpe/BuildingsLatLongBlock.shp");
	file<geometry> T_lines_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Tline_cleanedQGIS.shp");
	file<geometry> T_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_NODE_MAss_color.shp");
	file<geometry> bus_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_BUS_MAss.shp");
	file<geometry> road_shapefile <- file<geometry>("./../includesCalibration/City/volpe/simplified_roads.shp");
	file kendallBlocks_file <- file("./../includesCalibration/City/volpe/KendallBlockGroupstxt.txt");
	file criteria_home_file <- file("./../includesCalibration/Criteria/incentivizedCriteria/CriteriaHomeDiversity.csv");
	file activity_file <- file("./../includesCalibration/Criteria/ActivityPerProfile.csv");
	file mode_file <- file("./../includesCalibration/Criteria/Modes.csv");
	file profile_file <- file("./../includesCalibration/Criteria/Profiles.csv");
	file weather_coeff <- file("../includesCalibration/Criteria/weather_coeff_per_month.csv");
	file criteria_file <- file("../includesCalibration/Criteria/incentivizedCriteria/CriteriaFileDiversity.csv");
	file population_file <- file("../includesCalibration/City/censusDataGreaterBoston/censusDataClustered.csv");
	geometry shape<-envelope(T_lines_shapefile);
	
	int nb_people <- 11585; //for example. Nearly x2 of vacant spaces in Kendall
	int nb_agents <- int(11585/2); //make sure [nb_agent*max(possible_agents_per_point_list) > nb_people]
	float maxRent;
	float minRent;
	float maxDiversity;
	float minDiversity;
	int realTotalPeople <- 0;
	int realTotalAgents <- 0;
	bool weatherImpact<-false;
	float weather_of_day min: 0.0 max: 1.0;	
	int reference_rent <- 1500;
	int days_per_month <- 20; //labour days per month
	int movingPeople;
	int peopleInSelectedCity <- 0;
	float propInSelectedCity;
	float meanRentPeople;
	float meanDiver <- 0.0;
	float meanDiverNorm <- 0.0;
	float angle <- atan((899.235 - 862.12)/(1083.42 - 1062.038));
	point startingPoint <- {13844, 8318};
	float brickSize <- 21.3;
	int boolGrid <- 1;
	int init;
	float percForResidentialGrid <- 0.5; //variable for batch experiment
	int nbFloorsGrid <- 30; //variable for batch experiment
	float gridPriceMarketPerc <- 1.0; //percentage of the market price that grid buildings will offer (to everyone or specific profiles??) Vble for batch experiment
	
	
	map<string,int> density_map<-["S"::15,"M"::55, "L"::89, "microUnit" :: 40]; //provisional. Ask Suleiman
	list<blockGroup> kendallBlockList;
	list<rentApartment> kendallApartmentList;
	map<string,map<string,list<float>>> weights_map <- map([]);
	list<string> type_people;
	map<string,float> priceImp_list;
	map<string,float> divacc_list;
	map<string,string> vacancyPerPerson_list;
	map<string,float> vacancyPerPersonWeight_list;
	map<string,list<string>> pattern_list;
	map<string,float> patternWeight_list;
	map<string,list<float>> charact_per_mobility;
	map<string,rgb> color_per_mobility;
	map<string,float> width_per_mobility;
	map<string,float> speed_per_mobility;
	map<string,float> weather_coeff_per_mobility;
	map<string,graph> graph_per_mobility;
	map<string,rgb> color_per_type;	
	map<string, float> proba_bike_per_type;
	map<string, float> proba_car_per_type;
	map<string, float> proportion_per_type;
	map<string,int> total_number_agents_per_type;
	map<string,int> reduced_number_agents_per_type;
	list<int> actual_agents_per_point_list <- [0,0,0,0,0,0,0,0,0,0,0,0,0];
	list<int> possible_agents_per_point_list <- [1,2,5,10,20,30,40,50,60,70,80,90,100];
	map<int,int> agent_per_point_map;
	map<string,int> actual_number_people_per_type;
	map<string,int> actual_agents_people_per_type;
	map<string,map<int,int>> agent_per_point_type_map;
	map<string,string> main_activity_map;
	map<string,float> time_importance_per_type;
	list<list<float>> weather_of_month;
	map<road,float> congestion_map; 
	map<string,int> nPeople_perProfile;
	map<string,map<string,float>> peoplePerNeighbourhoodMap <- map([]);
	map<string,float> peopleProportionInSelectedCity;
	list<string> list_cities <- [];
	map<string,float> meanRent_perProfile;
	float happyNeighbourhoodPeople;
	map<string,float> happyNeighbourhood_perProfile;
	map<string,map<string,float>> propPeople_per_mobility_type <- map([]);
	list<string> allPossibleMobilityModes;
	map<string,float> people_per_Mobility_now;
	float meanTimeToMainActivity;
	map<string,float> meanTimeToMainActivity_perProfile;
	float meanDistanceToMainActivity;
	map<string,float> meanDistanceToMainActivity_perProfile;
	float meanCommutingCostGlobal;
	map<string,float> meanCommutingCost_perProfile;
	map<string, unknown> cityMatrixData;
	list<map<string, unknown>> cityMatrixCell;
	int totalAreaBuilt;
	
	
	
	
	init{
		do createTlines;
		write "T lines created";
		do createTstops;
		write "T stops created";
		do createBusStops;
		write "bus stops created";
		do createBlockGroups;
		write "block groups created";
		do createApartments;
		write "apartments created";
		do read_criteriaHome;
		write "criteriaHome read";
		if(boolGrid = 1){
			do createGridBuildings;
			write "grid buildings created";
		}		
		do calculateAverageFeatureBlockGroups;
		write "average Features per block group calculated";
		do identifyKendallBlocks;
		write "Kendall blocks identified";
		do createBuildings;
		write "buildings created";
		do createRoads;
		write "roads created";
		do criteria_file_import;
		write "criteria file imported";
		do characteristic_file_import;
		write "characteristic file imported";
		do profils_data_import;
		write "profils data imported";
		do compute_graph;
		write "graph computed";
		do agent_calc;
		write "agent calculated";
		do activityDataImport;
		write "activity data imported";
		do calc_time_criteria_per_type;
		write "time criteria per type calculated";
		do import_weather_data;
		write "weather data imported";
		if (weatherImpact=true){
			do calculate_weather;
		}
		write "weather calculated";
		do createPopulation;
		write "population created";
		do countPopulation;
		do countPopMainCity;
		do countNeighbourhoods; //Kendall + planetary
		do countRent;
		do countHappyPeople;
		do countMobility;
		do updateMeanDiver;
		init <- 1;
		
	}
	
	action createBlockGroups{
		create blockGroup from: blockGroup_shapefile with:[GEOID::string(read("GEOID")), lat::float(read("INTPTLAT")), long::float(read("INTPTLON")), city::string(read("TOWN")), neighbourhood::string(read("Neighbourh"))]{
		}
		ask blockGroup{		
			busStop closestBusStop <- busStop closest_to(self);
			if(closestBusStop != nil){
				float distancia <- distance_to(self.location, closestBusStop.location);
				float distancia2 <- distance_to(any_location_in(self), closestBusStop.location);
				if(distancia < 700 or distancia2 < 700){
					hasBus <- true;
				}
			}
			list<busStop> busesInsideMe <- [];
			busesInsideMe <- busStop inside(self);
			if(empty(busesInsideMe) = false){
				hasBus <- true;
			}
			else{
				hasBus <- false;
			}
			Tstop closestTStop <- Tstop closest_to(self);
			if(closestTStop != nil){
				float distancia <- distance_to(self.location, closestTStop.location);
				float distancia2 <- distance_to(any_location_in(self), closestTStop.location);
				if(distancia < 700 or distancia2 < 700){
					hasT <- true;
				}
			}
			else{
				hasT <- false;
			}
			list<Tstop> TstopsInsideMe <- [];
			TstopsInsideMe <- Tstop inside(self);
			if(empty(TstopsInsideMe) = false){
				hasT <- true;
			}
			
		}
	}
	
	action createApartments{
		create rentApartment from: available_apartments with: [rentAbs::int(read("Rent")), numberBedrooms::int(read("NBedrooms")), GEOIDAp::string(read("GEOID"))]{
			associatedBlockGroup <- one_of(blockGroup where(each.GEOID = GEOIDAp));
			if(empty(associatedBlockGroup) = true){
				//write "estoy vacio" + self;
			}
			if (associatedBlockGroup.city = 'DUXBURY'){
				do die; //outliers. Normalisation affected
			}
			else{
				associatedBlockGroup.apartmentsInMe << self;
			}
		}
	}
	
	action calculateAverageFeatureBlockGroups{
		//if vacantBedrooms = 0 in a certain blockGroup but vacantSpaces != 0 that means they are all studios
		// we are interested in price per vacantSpace
		//¿? should we consider that a studio can allocate 2 people. Bedrooms = 0 BUT vacantSpaces = 2
		list<list<rentApartment>> listApartmentsInMe;
		ask blockGroup where(empty(each.apartmentsInMe) = false and each.apartmentsInMe != [nil]){
			listApartmentsInMe << apartmentsInMe;
		}
		if (empty(listApartmentsInMe) = false){
			loop i from: 0 to: length(listApartmentsInMe) - 1{
				list bedSpaceRentList <- calculate_Features(listApartmentsInMe[i]);
				list<rentApartment> extract_apartmentList <- listApartmentsInMe[i];
				//extract_apartmentList[0].associatedBlockGroup.vacantBedrooms <- bedSpaceRentList[0];
				extract_apartmentList[0].associatedBlockGroup.initVacantSpaces <- bedSpaceRentList[1];
				extract_apartmentList[0].associatedBlockGroup.vacantSpaces <- bedSpaceRentList[1];
				extract_apartmentList[0].associatedBlockGroup.rentAbsVacancy <- bedSpaceRentList[2];
			}
		}
		
		do calculateMaxMinRents;
		
		loop i from: 0 to: length(listApartmentsInMe) - 1{
			list<rentApartment> extract_apartmentList <- listApartmentsInMe[i];
			extract_apartmentList[0].associatedBlockGroup.rentNormVacancy <- normalise_rents(extract_apartmentList[0].associatedBlockGroup.rentAbsVacancy);
		}	
		
		matrix blockPopulationMatrix <- matrix(population_file);
		
		loop i from: 0 to: blockPopulationMatrix.rows - 1{
			blockGroup asscBlock <- one_of(blockGroup where (each.GEOID = blockPopulationMatrix[1,i]));
			if(list_cities contains asscBlock.city != true){
				list_cities << asscBlock.city;
			}
			//write "list_cities " + list_cities;
			asscBlock.initDiversityNorm <- blockPopulationMatrix[17,i];
			asscBlock.initTotalPeople <- blockPopulationMatrix[7,i];
			asscBlock.totalPeople <- asscBlock.initTotalPeople;
			
			loop j from: 0 to: length(type_people) - 1 {
				asscBlock.initialPopulation[type_people[j]] <- blockPopulationMatrix[j + 8,i];
			}
			asscBlock.populationBlockGroup <- asscBlock.initialPopulation;
			
			ask asscBlock{
				do calculateDiversity;
			}
		}	
		
	}
	
	list calculate_Features(list<rentApartment> gen_apartment_list){
		int vacantSpaces_gen;
		int vacantBedrooms_gen;
		float rentAbsVacancy_gen;
		
		gen_apartment_list >>- [nil];
		if(gen_apartment_list != []){		
			float accummulated_rent <- 0.0;		
			int numberApartmentsFromGrid <- 0;
			loop i from: 0 to: length(gen_apartment_list) - 1{
				int availableBedrooms <- gen_apartment_list[i].numberBedrooms;
				int availableSpaces;
				if(gen_apartment_list[i].numberBedrooms != 0){
					availableSpaces <- gen_apartment_list[i].numberBedrooms;
				}
				else{
					availableSpaces <- 1;
				}
				float pricePerVacancy <- gen_apartment_list[i].rentAbs / availableSpaces;
				accummulated_rent <- accummulated_rent + pricePerVacancy;
				vacantSpaces_gen <- vacantSpaces_gen + availableSpaces;
				vacantBedrooms_gen <- vacantBedrooms_gen + availableBedrooms;
				if (gen_apartment_list[i].associatedBuilding != nil and empty(gen_apartment_list[i].associatedBuilding) != true){ //apartments that are not created from grid have no associatedBuilding yet
					if (gen_apartment_list[i].associatedBuilding.fromGrid = true){
						numberApartmentsFromGrid <- numberApartmentsFromGrid + 1;
					}
				}
			}
			if ((length(gen_apartment_list) - numberApartmentsFromGrid) != 0){
				rentAbsVacancy_gen <- accummulated_rent / (length(gen_apartment_list) - numberApartmentsFromGrid); //these ones do not have a price yet
			}
			else{
				blockGroup closestBlockGroup;
				closestBlockGroup <- blockGroup where(each.rentAbsVacancy != 0) closest_to (gen_apartment_list[0].associatedBlockGroup);
				rentAbsVacancy_gen <- closestBlockGroup.rentAbsVacancy;
			}
			 
		}
		else{
			vacantBedrooms_gen <- 0;
			vacantSpaces_gen <- 0;
			rentAbsVacancy_gen <- 0.0;
		}
		list return_list <- [vacantBedrooms_gen, vacantSpaces_gen, rentAbsVacancy_gen];
		return return_list;
	}
	
	float normalise_rents(float rentAbsVacancy_gen){
		float rentNormVacancy_gen;		
		if(maxRent != minRent ){
			rentNormVacancy_gen <- (rentAbsVacancy_gen - minRent) / (maxRent - minRent);
		}		
		return rentNormVacancy_gen;		
	}
		
	action calculateMaxMinRents{
		maxRent <- max(blockGroup collect each.rentAbsVacancy);
		minRent <- min(blockGroup where(each.rentAbsVacancy != 0.0) collect each.rentAbsVacancy);
	}
	
	action calculateMaxMinDiversity{
		maxDiversity <- max(blockGroup collect each.diversity);
		minDiversity <- min(blockGroup where(each.totalPeople != 0) collect each.diversity);
	}
	
	action identifyKendallBlocks{
		matrix kendall_blocks <- matrix(kendallBlocks_file);
		//write "matrix kendall blocks " + kendall_blocks;
		list<string> kendallBlockListString;
		
		loop i from: 0 to: kendall_blocks.columns - 1{
			//string name <- kendall_blocks[0,i];
			string name_block <- kendall_blocks[i,0];
			//write "name blockGroup kendall " + name_block;
			if (i = 0){
				name_block <- copy_between(name_block, 1, length(name_block));
			}
			kendallBlockListString << name_block;
			ask blockGroup{
				if(GEOID = kendallBlockListString[i]){
					inKendall <- true;
					kendallBlockList << self;
					//write "im kendall block " + self;
				}
			}
		}
		loop i from: 0 to: length(kendallBlockList) - 1{
			if(empty(kendallBlockList[i].apartmentsInMe) = false){
				loop j from: 0 to: length(kendallBlockList[i].apartmentsInMe) - 1{
					kendallApartmentList << kendallBlockList[i].apartmentsInMe[j];
				}
			}			
		}
		
		list<blockGroup> allBlockGroupsNotKendall;
		ask blockGroup where (each.inKendall = false){
			allBlockGroupsNotKendall << self;
			create building{
				associatedBlockGroup <- allBlockGroupsNotKendall[length(allBlockGroupsNotKendall) - 1];
				if (associatedBlockGroup.GEOID = '250173661003'){
					vacantSpaces <- #infinity;
					outskirts <- true;
					rentNormVacancy <- 1.0;
					neighbourhood <-  "outskirts";
					associatedBlockGroup.city <- "outskirts";
					associatedBlockGroup.neighbourhood <- "outskirts";
				}
				else{
					neighbourhood <- associatedBlockGroup.neighbourhood;
					vacantSpaces <- associatedBlockGroup.vacantSpaces;
					rentNormVacancy <- associatedBlockGroup.rentNormVacancy;
					rentAbsVacancy <- associatedBlockGroup.rentAbsVacancy;
				}
				
				satellite <- true;
				associatedBlockGroup.buildingsInMe << self;
				apartmentsInMe <- associatedBlockGroup.apartmentsInMe;
				
			}
			if(empty(apartmentsInMe) = false){
				loop i from:0 to: length(apartmentsInMe) - 1{
					apartmentsInMe[i].associatedBuilding <- self.buildingsInMe[0];
				}
			}
		}
	}
	
	action createBuildings{
		create building from: buildings_shapefile with:[usage::string(read("Usage")),scale::string(read("Scale")),category::string(read("Category")), FAR::float(read("FAR")), max_height::float(read("Max_Height")), type::string(read("TYPE")), neighbourhood::string(read("NAME")), ID::int(read("BUILDING_I")),lat::float(read("Latitude")), long::float(read("Longitude")), GEOIDBuild::string(read("GEOID"))]{
			area <- shape.area;
			perimeter <- shape.perimeter;	
			nbFloors <- int(max_height/10);
			if (density_map[scale]!=0 and usage="R"){
				supported_people <- int(area/density_map[scale])*nbFloors;	
			}
			else{
				supported_people<-0;
			}	
		}
				
		ask blockGroup where(each.inKendall = true){
			blockGroup blockGroupNow <- self;
			ask building where(each.GEOIDBuild = GEOID and each.satellite = false){
				blockGroupNow.buildingsInMe << self;
			}
			if (empty(buildingsInMe) = false){
				loop i from: 0 to: length(buildingsInMe) - 1 {
					buildingsInMe[i].associatedBlockGroup <- self;
				}
			}
			else{
				create building{
					associatedBlockGroup <- blockGroupNow;
					neighbourhood <- associatedBlockGroup.neighbourhood;
					vacantSpaces <- associatedBlockGroup.vacantSpaces;
					rentNormVacancy <- associatedBlockGroup.rentNormVacancy;
					satellite <- true;
					associatedBlockGroup.buildingsInMe << self;
				}
			}
		}
		ask building where(each.usage = "R" and each.satellite = false){
			apartmentsInMe <- rentApartment inside(self);
			if(empty(apartmentsInMe) = false){
				loop j from:0 to: length(apartmentsInMe) - 1{
					apartmentsInMe[j].associatedBuilding <- self;
					remove apartmentsInMe[j] from: kendallApartmentList;
				}
			}
		}
		if(empty(kendallApartmentList) = false){
			loop while: empty(kendallApartmentList) = false {
				kendallApartmentList[0].associatedBuilding <- one_of(building where(each.satellite = false and each.associatedBlockGroup = kendallApartmentList[0].associatedBlockGroup));
				if((kendallApartmentList[0].associatedBuilding) is building != true){
					kendallApartmentList[0].associatedBuilding <- building where(each.satellite = false) closest_to (self);
					if(kendallApartmentList[0].associatedBlockGroup != nil and empty(kendallApartmentList[0].associatedBlockGroup) != true){
						kendallApartmentList[0].associatedBlockGroup.apartmentsInMe >- kendallApartmentList[0];
						kendallApartmentList[0].associatedBlockGroup  <- kendallApartmentList[0].associatedBuilding.associatedBlockGroup;
						kendallApartmentList[0].associatedBlockGroup.apartmentsInMe << kendallApartmentList[0];
						kendallApartmentList[0].associatedBuilding.apartmentsInMe << kendallApartmentList[0];
					}
				}
				
				if(empty(kendallApartmentList[0].associatedBuilding) = false and empty(kendallApartmentList) = false){				
					remove kendallApartmentList[0] from: kendallApartmentList;	
				}
			}  			
		}
		
		list<list<rentApartment>> listApartmentsInMe <- [];
		ask building where(each.usage = "R" and (each.apartmentsInMe != []) and (each.apartmentsInMe !=[nil]) and each.satellite = false){
			listApartmentsInMe << apartmentsInMe;
		}

		if(empty(listApartmentsInMe) != true){
			loop i from: 0 to: length(listApartmentsInMe) - 1{
				if (empty(listApartmentsInMe[i]) != true){
					list bedSpaceRentList <- calculate_Features(listApartmentsInMe[i]);
					list<rentApartment> extract_apartmentList <- listApartmentsInMe[i];
					//extract_apartmentList[0].associatedBuilding.vacantBedrooms <- bedSpaceRentList[0];
					extract_apartmentList[0].associatedBuilding.vacantSpaces <- bedSpaceRentList[1];
					extract_apartmentList[0].associatedBuilding.rentAbsVacancy <- bedSpaceRentList[2];
					extract_apartmentList[0].associatedBuilding.rentNormVacancy <- normalise_rents(extract_apartmentList[0].associatedBuilding.rentAbsVacancy);
				}
			}
		}	
		
		
		ask rentApartment{
			if(associatedBuilding != nil and empty(associatedBuilding) = false){
				if (associatedBuilding.fromGrid = true){
					rentAbs <- associatedBlockGroup.rentAbsVacancy*gridPriceMarketPerc;
					associatedBuilding.rentNormVacancy <- associatedBlockGroup.rentNormVacancy*gridPriceMarketPerc;
					associatedBuilding.rentAbsVacancy <- associatedBlockGroup.rentAbsVacancy*gridPriceMarketPerc;
					//write "rentApartment" + rentApartment;
					//write "associatedBuilding" + associatedBuilding;
					//write "associatedBlockGroup" + associatedBlockGroup;
					//write "associatedBlockGroup.rentAbsVacancy" + associatedBlockGroup.rentAbsVacancy;
					//write "associatedBuilding.rentAbsVacancy " + associatedBuilding.rentAbsVacancy ;
				}
			}
		}
		
		ask building where(each.satellite = false){
			if (associatedBlockGroup = nil){
				do die;
			}
		}
		
		ask rentApartment {
			if(associatedBlockGroup != nil and empty(associatedBlockGroup) != true){
				if(associatedBlockGroup.inKendall = false and (associatedBuilding) = nil){
					associatedBuilding <- associatedBlockGroup.buildingsInMe[0];
				}
			}
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
	
	action createBusStops{
		create busStop from: bus_stops_shapefile;
	}
	
	action createRoads{
		create road from: road_shapefile{
			mobility_allowed <- ["walking","bike","car","bus"];
			capacity <- shape.perimeter / 10.0; //¿?¿?
			congestion_map [self] <- shape.perimeter;
		}
	}
	
	action read_criteriaHome{
		matrix criteriaHome_matrix <- matrix(criteria_home_file);
		loop i from: 0 to: criteriaHome_matrix.rows-1{
			type_people << criteriaHome_matrix[0,i];
			priceImp_list << (type_people[i]::criteriaHome_matrix[1,i]);
			divacc_list << (type_people[i]::criteriaHome_matrix[2,i]);
			vacancyPerPerson_list << (type_people[i]::criteriaHome_matrix[3,i]);
			vacancyPerPersonWeight_list << (type_people[i]::criteriaHome_matrix[4,i]);
			
			string cat_name <- criteriaHome_matrix[5,i];
			list<string> name_list;
			loop cat over: cat_name split_with "|"{
				name_list << cat;
			}
			add name_list at: type_people[i] to: pattern_list;
			patternWeight_list << (type_people[i]::criteriaHome_matrix[6,i]);		
			 
		}
	}
	
	action createGridBuildings{
		angle <- angle / 2;
		float acum_area <- 0.0;
		//write startingPoint;
		startingPoint <- {startingPoint.x - brickSize / 2, startingPoint.y - brickSize / 2};
		//write startingPoint;	
		int cont <- 0;			
		totalAreaBuilt <- 0;
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
					//write "building i "+ i + " j " + j;
					building imTheBuilding;
					blockGroup imTheAssociatedBlockGroup;
					create building{
						fromGrid <- true;
						ID <- cont;
						int x <- j;
						int y <- i;
						point location_local_axes <- {x * brickSize + 15, y * brickSize};
						location <- {startingPoint.x + location_local_axes.x*sin(angle) - location_local_axes.y*cos(angle), startingPoint.y - location_local_axes.y*sin(angle) - location_local_axes.x*cos(angle)};
						shape <- square(brickSize * 0.9) at_location location;
						area <- shape.area;
						perimeter <- shape.perimeter;
						usage <- "R";
						scale <- "microUnit";
						category <-  "mixed";
						nbFloors <- nbFloorsGrid; //variable batch experiment
						totalAreaBuilt <- totalAreaBuilt + area*nbFloors*percForResidentialGrid;
						type <- "BLDG";
						FAR <- 4.0;
						max_height <- 120.0;
						satellite <- false;
						if (density_map[scale]!=0){
							supported_people <- int(area/density_map[scale])*nbFloors*percForResidentialGrid;	 //change from density_map to area per micro-unit
						}
						else{
							supported_people<-0;
						}
						vacantSpaces <- supported_people;
						
						imTheBuilding <- self;
						ask blockGroup{
							if(self overlaps imTheBuilding = true){
								imTheAssociatedBlockGroup <- self;
							}
						}
						
						associatedBlockGroup <- imTheAssociatedBlockGroup;
						neighbourhood <- associatedBlockGroup.neighbourhood;
						associatedBlockGroup.buildingsInMe << self;
						create rentApartment number: 1{ //we are considering the whole building an apartment so that we dont change the way the average features are calculated in a block group
							GEOIDAp <- imTheAssociatedBlockGroup.GEOID;
							associatedBlockGroup <- imTheAssociatedBlockGroup;
							associatedBuilding <- imTheBuilding;
							associatedBlockGroup.apartmentsInMe << self; 
							associatedBuilding.apartmentsInMe << self;
							numberBedrooms <- associatedBuilding.vacantSpaces;	
							location <- associatedBuilding.location;				
						}
						cont <- cont + 1;
					}				
				}
			}	
		}
	}
	
	
	action  criteria_file_import{
		matrix criteria_matrix <- matrix (criteria_file);
		int nbCriteria <- criteria_matrix[1,0] as int;
		int nbTO <- criteria_matrix[1,1] as int ;
		int lignCategory <- 2;
		int lignCriteria <- 3;
		
		loop i from: 5 to:  criteria_matrix.rows - 1 {
			string people_type <- criteria_matrix[0,i];
			int index <- 1;
			map<string, list<float>> m_temp <- map([]);
			if(people_type != "") {
				list<float> l <- [];
				loop times: nbTO {
					list<float> l2 <- [];
					loop times: nbCriteria {
						add float(criteria_matrix[index,i]) to: l2;
						index <- index + 1;
					}
					string cat_name <-  criteria_matrix[index-nbTO,lignCategory];
					loop cat over: cat_name split_with "|" {
						add l2 at: cat to: m_temp;
					}
				}
				add m_temp at: people_type to: weights_map;
			}
		}
	}
	
	action characteristic_file_import{
		matrix mode_matrix<- matrix(mode_file);
		loop i from:0 to: mode_matrix.rows - 1 {
			string mobility_type <- mode_matrix[0,i];
			if(mobility_type!=""){
				list<float> vals<- [];
				loop j from: 1 to: mode_matrix.columns - 2 {
					vals<<float(mode_matrix[j,i]);
				}
				allPossibleMobilityModes << mobility_type;
				charact_per_mobility[mobility_type] <- vals;
				color_per_mobility[mobility_type]<- rgb(mode_matrix[7,i]);
				width_per_mobility[mobility_type]<- float(mode_matrix[8,i]);
				speed_per_mobility[mobility_type]<- float(mode_matrix[9,i]);
				weather_coeff_per_mobility[mobility_type]<- float(mode_matrix[10,i]);
			}
		}		
	}
	
	action profils_data_import{
		matrix profile_matrix<- matrix(profile_file);
		if (nb_agents > nb_people){
			nb_agents <- nb_people;
		}
		loop i from:0 to: profile_matrix.rows-1{
			string profil_type <- profile_matrix[0,i];
			if(profil_type!=""){
				color_per_type[profil_type] <- rgb(profile_matrix[1,i]);
				proba_car_per_type[profil_type]<-float(profile_matrix[2,i]);
				proba_bike_per_type[profil_type]<-float(profile_matrix[3,i]);
				proportion_per_type[profil_type]<-float(profile_matrix[4,i]);
				total_number_agents_per_type[profil_type] <- proportion_per_type[profil_type]*nb_people;
				reduced_number_agents_per_type[profil_type] <- proportion_per_type[profil_type]*nb_agents;
			}
		}	
		
		color_per_type [] >>- "nil";
		proba_car_per_type [] >>- "nil";
		proba_bike_per_type [] >>- "nil";
		proportion_per_type [] >>- "nil";
		total_number_agents_per_type [] >>- "nil";
		reduced_number_agents_per_type [] >>- "nil";
	}
	
	action compute_graph{
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode]<- as_edge_graph (road where (mobility_mode in each.mobility_allowed)) use_cache false;
		}
		graph_per_mobility[] >>- "T";
		graph_per_mobility["T"] <- as_edge_graph(Tline) use_cache false;
	}
	
	//calculation to know how many people is represented by a dot
	action agent_calc{
		loop i from: 0 to: length(proportion_per_type) -1 {
			int itshere <- 0;
			actual_agents_per_point_list <- [0,0,0,0,0,0,0,0,0,0,0,0,0];
			
			float mean_value_point <- total_number_agents_per_type[type_people[i]] / reduced_number_agents_per_type[type_people[i]];
			
			loop j from: 0 to: length(possible_agents_per_point_list) - 1 {
				float diff <- possible_agents_per_point_list[j] - mean_value_point;
				if (diff >= 0){  //if condition at line 13 is met, at a point we will get diff > 0
					itshere <- j;
					break;
				}
			}
			
			float howmany <- total_number_agents_per_type[type_people[i]]/possible_agents_per_point_list[itshere];
			int howmany_round <- round(howmany);
			if (howmany_round >  howmany){
				howmany_round <- howmany_round - 1;
			}
			actual_agents_per_point_list[itshere] <- howmany_round;
			int remaining_people <- total_number_agents_per_type[type_people[i]] - howmany_round*possible_agents_per_point_list[itshere];
			int remaining_points <- reduced_number_agents_per_type[type_people[i]] - howmany_round;
			
			if(itshere > 0){
				loop m from:0 to:itshere - 1{
					if(possible_agents_per_point_list[m]*remaining_points > remaining_people){
						actual_agents_per_point_list[m] <- int(remaining_people/possible_agents_per_point_list[m]);
						remaining_points <- remaining_points - actual_agents_per_point_list[m];
						remaining_people <- remaining_people - actual_agents_per_point_list[m]*possible_agents_per_point_list[m];
						if(m != 1 and m!= 0){
							loop n from: m - 1 to: 0 step: -1{
								if(possible_agents_per_point_list[n]*remaining_points > remaining_people){
									actual_agents_per_point_list[n] <- int(remaining_people/possible_agents_per_point_list[n]);
									remaining_points <- remaining_points - actual_agents_per_point_list[n];
									remaining_people <- remaining_people - actual_agents_per_point_list[n]*possible_agents_per_point_list[n];
								}
							}	
						}
						else{
							actual_agents_per_point_list[0] <- actual_agents_per_point_list[0] + remaining_people;
						}
						break;
					}
				}			
			}
			
			int realnumber_PeopleType <- 0;
			int realagents_PeopleType <- 0;
			loop k from: 0 to: length(possible_agents_per_point_list) - 1{
				agent_per_point_map << (possible_agents_per_point_list[k]::actual_agents_per_point_list[k]);
				realnumber_PeopleType <- realnumber_PeopleType + actual_agents_per_point_list[k]*possible_agents_per_point_list[k];
				realagents_PeopleType <- realagents_PeopleType + actual_agents_per_point_list[k];
			}
			add agent_per_point_map at: type_people[i] to: agent_per_point_type_map;
			agent_per_point_map <- map([]);
			actual_number_people_per_type[type_people[i]] <- realnumber_PeopleType;
			actual_agents_people_per_type[type_people[i]] <- realagents_PeopleType;
			realTotalAgents <- realTotalAgents + realagents_PeopleType;
			realTotalPeople <- realTotalPeople + realnumber_PeopleType;
			nb_people <- realTotalPeople;
			nb_agents <- realTotalAgents;
		}
	}
	
	action activityDataImport{
		matrix activity_matrix <- matrix(activity_file);
		loop i from: 1 to: activity_matrix.rows -1{
			map<string,int> activities;
			string current_activity<-"";
			list<string> act_all_day<-[];
			int posts<-0;
			list<string> list_form;
			loop j from: 1 to: activity_matrix.columns -1 {
				act_all_day << activity_matrix[j,i];
				string act<- activity_matrix[j,i];
				if(act != current_activity){
					activities[act] <- j;
					current_activity <- act;
					posts <- posts + 1;
					list_form << act;
				}
			}
			list<int> repetition_list <- [];
			loop j from: 0 to: posts-1{
				repetition_list << count(act_all_day,each = list_form[j]);
			}
			string main_activity <- "";
			int max_value <- 0;
			loop j from: 0 to: length(list_form) - 1{
				if (repetition_list[j]>max_value and first(list_form[j])!="R"){
					main_activity <- list_form[j];
					max_value <- repetition_list[j];
				}	
			}
			main_activity_map[type_people[i - 1]] <- main_activity;
		}
	}
	
	action calc_time_criteria_per_type{
		map<string,list<float>> crits;
		list<float> crits_main_activity <- [];
		string main_activity_code;
		bool wasItSplit <- false;
		string main_activity;
		loop type_i over:type_people {
			if (main_activity_map[type_i] contains "|" = true){
				list<string> name_list;
				loop cat over: main_activity_map[type_i] split_with "|"{
					name_list << cat;
				}
				main_activity <- one_of(name_list);
				wasItSplit <- true;
			}
			crits <- weights_map[type_i];
			if(wasItSplit = true){
			}
			else{
				main_activity <- main_activity_map[type_i];
			}
			if (main_activity in ["OS","OM","OL"]){
				main_activity_code <- first(main_activity);
			}
			else{
				main_activity_code <- main_activity;
			}
			crits_main_activity <- crits[main_activity_code];
			time_importance_per_type[type_i] <- crits_main_activity[1];
		}
	}
	
	action import_weather_data{
		matrix weather_matrix<-matrix(weather_coeff);
		loop i from:0 to: weather_matrix.rows -1 {
			weather_of_month<<[float(weather_matrix[1,i]),float(weather_matrix[2,i])];
		}
	}
	
	action calculate_weather{
		list<float> weather_m<-weather_of_month[current_date.month-1];
		weather_of_day<- gauss(weather_m[0],weather_m[1]);
	}
	
	action createPopulation{
		loop i from: 0 to: length(type_people) - 1 {
			map<int,int> extract_map <- agent_per_point_type_map[type_people[i]];
			extract_map >>- 0;
		}
		
		map<string,float> proportion_per_type_now <- proportion_per_type;
		
		int nPeople_created <- 0;
		create people number: nb_agents{
			nPeople_created <- nPeople_created + 1;
			//write "nPeople_created " + nPeople_created;
			type <- proportion_per_type_now.keys[rnd_choice(proportion_per_type.values)];
			map<int,int> extract_map <- agent_per_point_type_map[type];
			agent_per_point <- extract_map.keys[0];
			extract_map[agent_per_point] <- extract_map[agent_per_point] - 1;
			extract_map >>- 0; //remove from the map the pairs where the value (number of instances) is 0			
			agent_per_point_type_map[type] <- extract_map;
			
			if (empty(extract_map) = true){
				proportion_per_type_now[] >- type;
			}
			
			
			living_place <- one_of(building where (each.vacantSpaces >= 1*agent_per_point and each.outskirts = false));
			
			if (living_place != nil){
				actualCity <- living_place.associatedBlockGroup.city;
				payingRent <- living_place.rentNormVacancy;
				payingRentAbs <- living_place.rentAbsVacancy;
				actualNeighbourhood <- living_place.neighbourhood;
									
			}
			else{
				living_place <- one_of(building where(each.outskirts = true));
				living_place.peopleWhoJustCame <- living_place.peopleWhoJustCame + 1*agent_per_point;
				actualNeighbourhood <- living_place.associatedBlockGroup.neighbourhood;
				actualCity <- living_place.associatedBlockGroup.city;
			}
			
			if(living_place.satellite = false){
				location <- any_location_in(living_place);
			}
			else{
				location <- any_location_in(living_place.associatedBlockGroup);
			}
			living_place.vacantSpaces <- living_place.vacantSpaces - 1*agent_per_point;
			living_place.associatedBlockGroup.vacantSpaces <- living_place.associatedBlockGroup.vacantSpaces - 1*agent_per_point;
			living_place.associatedBlockGroup.totalPeople <- living_place.associatedBlockGroup.totalPeople + 1*agent_per_point;
			living_place.associatedBlockGroup.populationBlockGroup[type] <- living_place.associatedBlockGroup.populationBlockGroup[type] + 1 * agent_per_point;
			living_place.associatedBlockGroup.peopleInMe << self;
			
			actualPatternWeight <- calculate_patternWeight(actualNeighbourhood);
			list<string> extract_list <- pattern_list[type];
			if (living_place.neighbourhood = extract_list[0]){
				happyNeighbourhood<-1;
			}
			else{
				happyNeighbourhood<-0;
			}
			
			string various_principal_activity <- main_activity_map[type];
			if(various_principal_activity contains "|" = true){
				list<string> list_pa <- [];
				loop pa over: various_principal_activity split_with "|"{
					list_pa << pa;
				}
				principal_activity <- one_of(list_pa);
			}
			else{
				principal_activity <- various_principal_activity;
			}
			
			if (first(principal_activity) = "O"){
				activity_place<-one_of(building where (each.category = 'O' and each.satellite = false));
			}
			else if(principal_activity = "restaurant"){//spelling difference with respect to "R" to have different first letter
				activity_place<-one_of(building where(each.category = "Restaurant" and each.satellite = false));
			}
			else if(principal_activity = "A"){
				activity_place<-one_of(building where(each.category != "R" and each.category != "O" and each.satellite = false));
			}
			else{
				activity_place<-one_of(building where (each.category = principal_activity and each.satellite = false));
			}
			
			//write "principal_activity " + principal_activity;
			//write "activity_place " + activity_place;
			
			do calculate_possibleMobModes;
			
			bool possibilityToTakeT <- false;
			bool possibilityToTakeBus <- false;
			if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
				possibilityToTakeT <- true;
			}
			if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
				possibilityToTakeBus <- true;
			}
			
			map<string,list<float>> mobilityAndTime<- evaluate_main_trip(location,activity_place, possibilityToTakeT, possibilityToTakeBus);
			list<float> extract_list_here <- mobilityAndTime[mobilityAndTime.keys[0]];
			time_main_activity <- extract_list_here[0];
			time_main_activity_min <- extract_list_here[3];
			CommutingCost <- extract_list_here[1];
			distance_main_activity <- extract_list_here[2];
			mobility_mode_main_activity <- mobilityAndTime.keys[0];
			
			
		}
	}
	
	action countPopulation{
		nPeople_perProfile <- actual_number_people_per_type;
	}
	
	action countPopMainCity{		
		ask people where(each.actualCity = selectedCity){
			peopleInSelectedCity <- peopleInSelectedCity + agent_per_point;
		}
	}
	
	action countNeighbourhoods{
		loop i from: 0 to: length(type_people) - 1{
			map<string,float> peoplePerNeighbourhoodPartialMap <- map([]);
			float propInSelectedCity <- 0.0;
			loop j from: 0 to: length(list_cities) - 1{
				int number_peopleProfile_here <- 0;
				ask people where(each.type = type_people[i]){
					if(actualCity = list_cities[j]){
						number_peopleProfile_here <- number_peopleProfile_here + 1*agent_per_point;
					}
				}
				if(nPeople_perProfile[type_people[i]] != 0){
					peoplePerNeighbourhoodPartialMap[list_cities[j]] <- number_peopleProfile_here / nPeople_perProfile[type_people[i]];
				}
				else{
					peoplePerNeighbourhoodPartialMap[list_cities[j]] <- 0.0;
				}
				
				if (list_cities[j] = selectedCity and peopleInSelectedCity != 0){
					peopleProportionInSelectedCity[type_people[i]] <- number_peopleProfile_here / nb_people;
					
				}
				else if (j = 0 and peopleInSelectedCity = 0){
					peopleProportionInSelectedCity[type_people[i]] <- 0.0;
				}
			}
			add peoplePerNeighbourhoodPartialMap at: type_people[i] to: peoplePerNeighbourhoodMap;
		}
	}
	
	action countRent{
		meanRentPeople <- 0.0;
		meanRent_perProfile <- [];
		ask people{
			meanRentPeople <- meanRentPeople + payingRentAbs*agent_per_point;
		}
		meanRentPeople <- meanRentPeople / nb_people;
		loop i from: 0 to: length(type_people) -1 {
			ask people where(each.type = type_people[i]){
				meanRent_perProfile[type_people[i]] <- meanRent_perProfile[type_people[i]] + payingRentAbs*agent_per_point;
			}
			if(nPeople_perProfile[type_people[i]] != 0){
				meanRent_perProfile[type_people[i]] <- meanRent_perProfile[type_people[i]] / nPeople_perProfile[type_people[i]];
			}
			else{
				meanRent_perProfile[type_people[i]] <- 0.0;
			}
			
		}
		
	}
	
	action countHappyPeople{
		happyNeighbourhoodPeople <- 0.0;
		happyNeighbourhood_perProfile <- [];
		ask people{
			if (happyNeighbourhood = 1){
				happyNeighbourhoodPeople <- happyNeighbourhoodPeople + agent_per_point;
			}
		}
		happyNeighbourhoodPeople <- happyNeighbourhoodPeople / nb_people;
		
		loop i from: 0 to: length(type_people) -1 {
			ask people where(each.type = type_people[i]){
				if(happyNeighbourhood = 1){
					happyNeighbourhood_perProfile[type_people[i]] <- happyNeighbourhood_perProfile[type_people[i]] + agent_per_point;
				}
			}
			if(nPeople_perProfile[type_people[i]] != 0){
				happyNeighbourhood_perProfile[type_people[i]] <- happyNeighbourhood_perProfile[type_people[i]] / nPeople_perProfile[type_people[i]];
			}
			else{
				happyNeighbourhood_perProfile[type_people[i]] <- 0;
			}
			
		}
	}
	
	action countMobility{
		propPeople_per_mobility_type <- map([]);	
		loop i from: 0 to: length(allPossibleMobilityModes) - 1{
			map<string,float> propPeople_per_mobility_indiv <- [];
			loop j from:0 to: length(type_people) - 1{
				int nPeople <- 0;
				ask people where(each.mobility_mode_main_activity = allPossibleMobilityModes[i]){
					nPeople <- nPeople + agent_per_point;
				}
				
				people_per_Mobility_now[allPossibleMobilityModes[i]] <- nPeople/nb_people;
				int nPeopleEach <- 0;
				ask people where(each.type = type_people[j] and each.mobility_mode_main_activity = allPossibleMobilityModes[i]){
					nPeopleEach <- nPeopleEach + agent_per_point;				}
				if(nPeople_perProfile[type_people[j]] != 0){
					propPeople_per_mobility_indiv[type_people[j]] <- nPeopleEach / nPeople_perProfile[type_people[j]];
				}
				else{
					propPeople_per_mobility_indiv[type_people[j]] <- 0.0;
				}
				add propPeople_per_mobility_indiv at: allPossibleMobilityModes[i] to: propPeople_per_mobility_type;				
			}
		}
		meanTimeToMainActivity <- 0.0;
		meanDistanceToMainActivity <- 0.0;
		ask people{
			meanTimeToMainActivity <- meanTimeToMainActivity + time_main_activity_min*agent_per_point;
			meanDistanceToMainActivity <- meanDistanceToMainActivity + distance_main_activity*agent_per_point;
		}
		meanTimeToMainActivity <- meanTimeToMainActivity / nb_people;
		meanDistanceToMainActivity <- meanDistanceToMainActivity / nb_people;
		
		meanTimeToMainActivity_perProfile <- [];
		meanDistanceToMainActivity_perProfile <- [];
		loop k from:0 to: length(type_people) -1 {
			ask people where(each.type = type_people[k]){
				meanTimeToMainActivity_perProfile[type_people[k]] <- meanTimeToMainActivity_perProfile[type_people[k]] + time_main_activity_min*agent_per_point;
				meanDistanceToMainActivity_perProfile[type_people[k]] <- meanDistanceToMainActivity_perProfile[type_people[k]] + distance_main_activity*agent_per_point;
			}
			if(nPeople_perProfile[type_people[k]] != 0){
				meanTimeToMainActivity_perProfile[type_people[k]] <- meanTimeToMainActivity_perProfile[type_people[k]] / nPeople_perProfile[type_people[k]];
				meanDistanceToMainActivity_perProfile[type_people[k]] <- meanDistanceToMainActivity_perProfile[type_people[k]] / nPeople_perProfile[type_people[k]];
			}
			else{
				meanTimeToMainActivity_perProfile[type_people[k]] <- 0.0;
				meanTimeToMainActivity_perProfile[type_people[k]] <- 0.0;
			}
			
		}
		
		do updateCommutingCosts;
	}
	
	action updateCommutingCosts{
		meanCommutingCostGlobal <- 0.0;
		ask people{
			meanCommutingCostGlobal <- meanCommutingCostGlobal + CommutingCost*agent_per_point;
		}
		meanCommutingCostGlobal <- meanCommutingCostGlobal / nb_people;
		
		meanCommutingCost_perProfile <- [];
		loop i from: 0 to: length(type_people) - 1 {
			ask people where(each.type = type_people[i]){
				meanCommutingCost_perProfile[type_people[i]] <- meanCommutingCost_perProfile[type_people[i]] + CommutingCost*agent_per_point;
			}
			if(nPeople_perProfile[type_people[i]] != 0){
				meanCommutingCost_perProfile[type_people[i]] <- meanCommutingCost_perProfile[type_people[i]] / nPeople_perProfile[type_people[i]];
			}			
			else{
				meanCommutingCost_perProfile[type_people[i]] <- 0.0;
			}
		}
	}
	
	action updateMeanDiver{
		meanDiverNorm <- mean(blockGroup where(each.totalPeople != 0) collect each.diversityNorm);
		meanDiver <- mean(blockGroup where(each.totalPeople != 0) collect each.diversity);
	}
	
	reflex peopleMove{
		movingPeople <- 0;
		ask blockGroup{
			sthHasChanged <- false;
		}
		ask people{
			do changeHouse;
		}
		
		ask blockGroup where(each.sthHasChanged = true){
			do calculateDiversity;
		}
		do calculateMaxMinDiversity;
		ask blockGroup{
			do normaliseDiversity;
		}
		do countRent;
		do countPopMainCity;
		do countNeighbourhoods;
		do countHappyPeople;
		do countMobility;
		do updateMeanDiver;
	}
	
	/***reflex save_info{
		init <- 0;
		do save_info_cycle;
	}***/
	
}

species blockGroup{
	string GEOID;
	float lat;
	float long;
	int vacantSpaces; //we will use this one to allocate people
	int initVacantSpaces;
	//int vacantBedrooms;
	float rentAbsVacancy;
	float rentNormVacancy;
	list<rentApartment> apartmentsInMe;
	list<building> buildingsInMe;
	bool inKendall <- false;
	string city;
	string neighbourhood;
	map<string,int> initialPopulation;
	map<string,int> populationBlockGroup;
	int initTotalPeople;
	int totalPeople;
	float initDiversityNorm;
	float diversity;
	float diversityNorm;
	bool hasT;
	bool hasBus;
	bool sthHasChanged;
	list<people> peopleInMe; 

	action calculateDiversity{	
		float prop_i <- 0.0;
		diversity <- 0.0;	
		if(totalPeople != 0){
			loop i from: 0 to: length(populationBlockGroup) - 1{
				prop_i <- populationBlockGroup[type_people[i]] / totalPeople;
				if(prop_i != 0){
					diversity <- diversity + prop_i*ln(prop_i);
				}
				else{
					diversity <- diversity + 0.0;
				}
			}
			diversity <- - diversity;
		}		
	}
	
	action normaliseDiversity{
		if(maxDiversity != minDiversity){
			diversityNorm <- (diversity - minDiversity) / (maxDiversity - minDiversity);
		}
		else{
			diversityNorm <- 0.0;
		}
		
	}
	
	aspect default{
		draw shape color: rgb(50,50,50,125);	
		//draw shape color: rgb(50,255*rentNormVacancy,50,125);
		/***if(hasBus = true and hasT = true){
			color <- #green;
		}
		else if (hasBus = true and hasT = false){
			color <- #yellow;
		}
		else if (hasBus = false and hasT = true){
			color <- #orange;
		}
		else{
			color <- #red;
		}
		draw shape color: color;
		/***if(vacantSpaces = 0){
			color <- #red;
		}
		else{
			color <- #green;
		}
		draw shape color: color;***/
	}
}

species rentApartment{
	string GEOIDAp;
	blockGroup associatedBlockGroup;
	building associatedBuilding;
	int rentAbs;
	int numberBedrooms;
	
	aspect default{
		draw circle(20) color: #purple;
	}
}

species building{
	blockGroup associatedBlockGroup;
	string usage;
	string scale;
	string category;
	string type;
	float FAR;
	float max_height;
	int nbFloors;
	float area;
	float perimeter;
	int supported_people;
	int peopleWhoJustCame; //we will use it just for outskirts
	string neighbourhood;
	int ID;
	float lat;
	float long;	
	//int vacantBedrooms;
	int vacantSpaces;
	float rentAbsVacancy;
	float rentNormVacancy;
	list<rentApartment> apartmentsInMe;
	string GEOIDBuild;
	bool satellite <- false;
	bool outskirts <- false;
	bool fromGrid <- false;
	
	aspect default{
		if(fromGrid = true){
			draw shape rotated_by angle color: rgb(50,50,50, 125);
		}
		else{
			draw shape color: rgb(50,50,50, 125);	
		}
		//draw shape color: #red;
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

species busStop{
	aspect default{
		draw circle(30) color: #yellow;
	}
}

species road{
	list<string> mobility_allowed;
	float capacity;
	float max_speed <- 30 #km/#h;
	float current_concentration;
	float speed_coeff<-1.0;
	
	aspect default{
		draw shape color: #grey;
	}
}

species people{
	string type;
	int agent_per_point;
	building living_place;
	string actualCity;
	float payingRent;
	float payingRentAbs;
	string actualNeighbourhood;
	float actualPatternWeight;
	int happyNeighbourhood;
	string principal_activity;
	building activity_place;
	list<string> possibleMobModes;
	float time_main_activity;
	float time_main_activity_min;
	float CommutingCost;
	float distance_main_activity;
	string mobility_mode_main_activity;
	
	float calculate_patternWeight(string possibleNeighbourhood){
		float possible_patternWeight;
		list<string> extract_list <- pattern_list[type];
		int donde <- 1000;
		loop i from: 0 to: length(extract_list) - 1 {
			if (possibleNeighbourhood = extract_list[i]){
				donde <- i;
			}
		}
		
		possible_patternWeight <- 1.0 - donde*0.3;
		if (possible_patternWeight < - 1.0){
			possible_patternWeight <- -1.0;
		}
		return possible_patternWeight;
	}
	
	action calculate_possibleMobModes{
		possibleMobModes <- ["walking"];
		if (flip(proba_car_per_type[type]) = true){
			possibleMobModes << "car";
		}
		if (flip(proba_bike_per_type[type]) = true){
			possibleMobModes << "bike";
		}
	}
	
	
	map<string,list<float>> evaluate_main_trip(point origin_location, building destination, bool isthereT <- false, bool isthereBus <- false){
	
		list<list> candidates;
		list<float> commuting_cost_list;
		list<float> distance_list;
		list<float> time_list;
		list<string> possibleMobModesNow <- [];
		/***possibleMobModesNow <- possibleMobModes + 'fin'; //to avoid coupling
		possibleMobModesNow >- 'fin';***/
		possibleMobModesNow <- possibleMobModes;
		
		if (isthereBus = true){
			possibleMobModesNow << "bus";
		}
		else{
			possibleMobModesNow >- "bus";
		}
		if(isthereT = true){
			possibleMobModesNow << "T";
		}
		else{
			possibleMobModesNow >- "T";
		}
		
		loop mode over:possibleMobModesNow{
			list<float> characteristic<- charact_per_mobility[mode];
			list<float> cand;	
			float distance <- 0.0;	
				
				if(mode = 'T'){
					Tstop nearestTstopHome <-  Tstop closest_to living_place;
					Tstop nearestTstopWork <- Tstop closest_to activity_place;
					using topology(graph_per_mobility[mode]){
						distance <- distance_to(nearestTstopHome.location, nearestTstopWork.location); //nearly straight lines
					}
					if (distance > 100000){ //error with the map
						distance <- distance_to(nearestTstopHome.location, nearestTstopWork.location) * 1.25;
					}
				}			
				if(mode = 'bus'){
					busStop nearestBusStopHome <- busStop closest_to living_place;
					busStop nearestBusStopWork <- busStop closest_to activity_place;
					using topology(graph_per_mobility[mode]){						
						distance <- distance_to(nearestBusStopHome.location, nearestBusStopWork.location); //far from straight lines
					}
					if (distance > 100000){ //error with the map
						distance <- distance_to(nearestBusStopHome.location, nearestBusStopWork.location) * 1.25;
					}
				}
				if(mode != 'T' and mode!= 'bus'){
					using topology(graph_per_mobility[mode]){
						distance <- distance_to(origin_location,destination.location);
					}
					if (distance > 100000){ //error with the map
						distance <- distance_to(origin_location, destination.location) * 1.25;
					}
				}
		
			cand<<characteristic[0] + characteristic[1]*distance;  //length unit meters
			commuting_cost_list << (characteristic[0] + characteristic[1]*distance/1000)/reference_rent*days_per_month*2; //price with respect to a reference rent (*2 because it is a roundtrip)
			distance_list << distance;
			cand<<characteristic[2] + distance/1000/speed_per_mobility[mode]*60;
			time_list << characteristic[2] + distance/1000/speed_per_mobility[mode]*60;
			cand<<characteristic[4];
			
			cand<<characteristic[5]*(weatherImpact?(1.0 + weather_of_day*weather_coeff_per_mobility[mode]):1.0);
			add cand to: candidates;
		}
		//normalisation
		list<float> max_values;
		loop i from:0 to: length(candidates[0])-1{
			max_values<<max(candidates collect abs(float(each[i])));
		}
		
		loop cand over:candidates{
			loop i from:0 to: length(cand)-1{
				if (max_values[i]!=0.0){
					cand[i] <- float(cand[i])/max_values[i];
				}
			}
		}
		
		map<string,list<float>> crits<-weights_map[type];
		list<float> vals;
		loop obj over:crits.keys{
			if(obj=destination.category or (destination.category in ["OS","OM","OL"]) and (obj = "O") or (destination.category="Restaurant" and (obj="restaurant"))){
				vals <- crits[obj];
				break;
			}
		}
		list<map> criteria_WM;
		//write "destination category " + destination.category; 
		loop i from: 0 to: length(vals)-1{
			criteria_WM<< ["name"::"crit"+i, "weight"::vals[i]];
		}
		int choice <- weighted_means_DM(candidates, criteria_WM);
		string poss_mobility_mode_main_activity;
		if (choice>=0){
			poss_mobility_mode_main_activity <- possibleMobModesNow[choice];
		}
		else{
			poss_mobility_mode_main_activity <- one_of(possibleMobModesNow);
		}
		list<float> choice_vector <- candidates[choice];
		float commuting_cost <- commuting_cost_list[choice];
		float dist <- distance_list[choice];
		float timem <- choice_vector[1];
		float timemin <- time_list[choice];
		map<string,list<float>> mobAndTime<-(poss_mobility_mode_main_activity::[timem,commuting_cost,dist, timemin]);
		return mobAndTime;
	}
	
	action changeHouse{
		building possibleMoveBuilding;
		list<list> cands <- [];
		float living_cost;
		living_cost <- payingRent;
		//float living_cost <- living_place.rentPriceNorm;
		float possibleLivingCost;
		float possibleLivingCostAbs;
		float possibleDiversity;
		string possibleNeighbourhood;
		float possiblePatternWeight;
		float possibleTime;
		float possibleTimeMin;
		float possibleCommutingCost;
		float possibleDistance;
		string possibleMobility;
		point locationPossibleMoveBuilding;
		
		possibleMoveBuilding <- one_of(building where(each.vacantSpaces >= 1*agent_per_point and (each != living_place) and each.outskirts = false));
		
		if(possibleMoveBuilding != nil){//it is a building in Kendall or satellite blockGroup
			if(possibleMoveBuilding.satellite = false){
				locationPossibleMoveBuilding <- possibleMoveBuilding.location;
				
			}
			else{
				locationPossibleMoveBuilding <- any_location_in(possibleMoveBuilding.associatedBlockGroup);
			}	
			possibleDiversity <- possibleMoveBuilding.associatedBlockGroup.diversityNorm;
			possibleNeighbourhood <- possibleMoveBuilding.neighbourhood;		
		}
		else{ //it is a location on the outskirts
			possibleMoveBuilding <- one_of(building where(each.outskirts = true)); //we are supposing that outskirts DO have infinite capacity
			locationPossibleMoveBuilding <- any_location_in(possibleMoveBuilding.associatedBlockGroup);
			possibleDiversity <- 0.5; //we suppose diversity cte
			possibleNeighbourhood <- possibleMoveBuilding.associatedBlockGroup.neighbourhood;
			
		}		
		possibleLivingCost <- possibleMoveBuilding.rentNormVacancy;
		possibleLivingCostAbs <- possibleMoveBuilding.rentAbsVacancy;
		possiblePatternWeight <- calculate_patternWeight(possibleNeighbourhood);
			
		bool possibilityToTakeT <- false;
		bool possibilityToTakeBus <- false;
		if(possibleMoveBuilding.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
			possibilityToTakeT <- true;
		}
		if(possibleMoveBuilding.associatedBlockGroup.hasBus = true and activity_place.associatedBlockGroup.hasBus = true){
			possibilityToTakeBus <- true;
		}
		map<string,list<float>> possibleTimeAndMob <- evaluate_main_trip(locationPossibleMoveBuilding,activity_place, possibilityToTakeT, possibilityToTakeBus); //list<float> is time and commuting_cost with respect to a reference_rent
		list<float> possible_extract_list <- possibleTimeAndMob[possibleTimeAndMob.keys[0]];
		possibleTime <- possible_extract_list[0];
		possibleTimeMin <- possible_extract_list[3];
		possibleCommutingCost <- possible_extract_list[1];
		possibleMobility <- possibleTimeAndMob.keys[0];
		possibleDistance <- possible_extract_list[2];
		
		cands <- [[possibleLivingCost + possibleCommutingCost,possibleDiversity,possiblePatternWeight, possibleTime],[living_cost + CommutingCost,living_place.associatedBlockGroup.diversityNorm,actualPatternWeight, time_main_activity]];
		
		list<float> crit<- [priceImp_list[type],divacc_list[type],patternWeight_list[type],time_importance_per_type[type]];
		
		list<map> criteria_WM<-[];
		loop i from:0 to: length(crit)-1{
			criteria_WM<<["name"::"crit"+i, "weight"::crit[i]];
		}		
		int choice <- weighted_means_DM(cands,criteria_WM);
		
		if (choice = 0){
			living_place.vacantSpaces <- living_place.vacantSpaces + 1*agent_per_point;
			living_place.associatedBlockGroup.vacantSpaces <- living_place.associatedBlockGroup.vacantSpaces + 1*agent_per_point;
			living_place.associatedBlockGroup.totalPeople <- living_place.associatedBlockGroup.totalPeople - 1*agent_per_point;
			living_place.associatedBlockGroup.populationBlockGroup[type] <- living_place.associatedBlockGroup.populationBlockGroup[type] - 1 * agent_per_point;
			living_place.associatedBlockGroup.peopleInMe >- self;
			living_place.associatedBlockGroup.sthHasChanged <- true;
			possibleMoveBuilding.vacantSpaces <- possibleMoveBuilding.vacantSpaces - 1*agent_per_point;	
			possibleMoveBuilding.associatedBlockGroup.vacantSpaces <- possibleMoveBuilding.associatedBlockGroup.vacantSpaces - 1*agent_per_point;
			possibleMoveBuilding.associatedBlockGroup.totalPeople <- possibleMoveBuilding.associatedBlockGroup.totalPeople + 1*agent_per_point;
			
			possibleMoveBuilding.associatedBlockGroup.populationBlockGroup[type] <- possibleMoveBuilding.associatedBlockGroup.populationBlockGroup[type] + 1 * agent_per_point;
			possibleMoveBuilding.associatedBlockGroup.sthHasChanged <- true;
			possibleMoveBuilding.associatedBlockGroup.peopleInMe << self;
			living_place <- possibleMoveBuilding;
			
			
			
			if(living_place.satellite = true){
				location <- any_location_in(living_place.associatedBlockGroup);
			}
			else{
				location <- any_location_in(living_place);
			}
			
			movingPeople <- movingPeople + 1*agent_per_point;		
			actualPatternWeight <- possiblePatternWeight;
			actualNeighbourhood <- living_place.associatedBlockGroup.neighbourhood;
			actualCity <- living_place.associatedBlockGroup.city;
			time_main_activity <- possibleTime;
			time_main_activity_min <- possibleTimeMin;
			distance_main_activity <- possibleDistance;
			mobility_mode_main_activity <- possibleMobility;
			CommutingCost <- possibleCommutingCost;
			payingRent <- possibleLivingCost;
			payingRentAbs <- possibleLivingCostAbs;
			
			list<string> extract_list <- pattern_list[type];
			if(living_place.neighbourhood = extract_list[0]){
				happyNeighbourhood <- 1;
			}
			else{
				happyNeighbourhood <- 0;
			}
		}
	
	}
	
	aspect default{
		if (living_place != one_of(building where(each.outskirts))){
			draw circle(70) color: color_per_type[type];
		}
	}
}

experiment show type: gui{
	parameter "createGrid " var: boolGrid init: 1 category: "Grid / No Grid difference ";
	output{
		display map type: opengl draw_env: false background: #black{
			species blockGroup aspect: default;
			species building aspect: default;
			//species rentApartment aspect: default;
			species road aspect: default;
			species Tstop aspect:default;
			species Tline aspect: default;
			//species busStop aspect: default;
			species people aspect: default;		
					
		
		overlay position: { 5, 5 } size: { 240 #px, 340 #px } background: rgb(50,50,50,125) transparency: 0.5 border: #black 
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
	
			
		display MovingDiversity {			
			chart "MovingPeople" type: series background: #white position:{0,0} size:{1.0,0.5}{
				data "Moving people in myCity" value:movingPeople color:#blue;
			}
			chart "Mean diversity evolution" type: series background:#white position:{0,0.5} size:{1.0,0.5}{
				data "Mean diversity in myCity" value: meanDiver color: #green;
				data "Mean normalised diversity in myCity" value: meanDiverNorm color: #orange;
			}
		}
		
		display RentCommutingCosts{
			chart "Mean rent" type:series background: #white position:{0,0} size:{1.0, 0.3}{
				data "Mean normalised rent in myCity" value: meanRentPeople color: #black;
				loop i from: 0 to: length(type_people) -1 {
					data type_people[i] value: meanRent_perProfile[type_people[i]] color: color_per_type[type_people[i]];
				}
 			}
			chart "Mean CommutingCost" type:series background: #white position:{0,0.3} size:{1.0,0.3}{
				data "Mean CommutingCost" value: meanCommutingCostGlobal color: #black;
				loop i from: 0 to: length(type_people) - 1 {
					data type_people[i] value: meanCommutingCost_perProfile[type_people[i]] color: color_per_type[type_people[i]];
				}
			}
			chart "Proportion of people happy with their Neighbourhood" type: series background:#white position: {0,0.6} size:{1.0,0.3}{
				data "Happy Neighbourhood" value: happyNeighbourhoodPeople color: #black;
				loop i from: 0 to: length(type_people) -1 {
					data type_people[i] value: happyNeighbourhood_perProfile[type_people[i]] color: color_per_type[type_people[i]];
				}
			}
		}
		display MobilityPie{
			chart "Proportion of people per Mobility Mode" background:#white type: pie style:ring size: {0.25,0.25} position: {0.0,0.0} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(people_per_Mobility_now.keys)-1	{
				  data people_per_Mobility_now.keys[i] value: people_per_Mobility_now.values[i] color:color_per_mobility[people_per_Mobility_now.keys[i]];
				}
			}
			chart "Mean time to main activity" type: series background: #white position:{0,0.25} size:{1.0,0.35}{
				data "Mean time to main activity" value:meanTimeToMainActivity color:#black;
				loop i from:0 to: length(type_people) -1 {
					data type_people[i] value: meanTimeToMainActivity_perProfile[type_people[i]] color: color_per_type[type_people[i]];
				}
			}
			chart "Mean distance to main activity" type: series background:#white position: {0,0.6} size:{1.0,0.35}{
				data "Mean distance to main activity" value:meanDistanceToMainActivity color: #black;
				loop i from: 0 to: length(type_people) - 1 {
					data type_people[i] value: meanDistanceToMainActivity_perProfile[type_people[i]] color: color_per_type[type_people[i]];
				}
			}
		}
		display MobilityChartsCarsBikes{	

			chart "Proportion of people using cars" type: series background: #white position:{0,0.0} size: {1.0,0.5}{
				
				if (propPeople_per_mobility_type['car'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['car'].values[i] color: color_per_type[type_people[i]];
					}	
				}
			}
			chart "Proportion of people using bikes" type: series background: #white position:{0,0.5} size: {1.0,0.5}{
				if (propPeople_per_mobility_type['bike'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['bike'].values[i] color: color_per_type[type_people[i]];
					}				
				}
			}	
		}
		display MobilityChartsBusWalking{
			chart "Proportion of people using bus" type: series background: #white position:{0,0.0} size: {1.0,0.5}{		
				if (propPeople_per_mobility_type['bus'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['bus'].values[i] color: color_per_type[type_people[i]];
					}
				}
			}
			
			chart "Proportion of people walking" type: series background: #white position:{0,0.5} size: {1.0,0.5}{
				if (propPeople_per_mobility_type['walking'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['walking'].values[i] color: color_per_type[type_people[i]];
					}
				}
			}			
		}
		display MobilityChartsT{
			chart "Proportion of people using T" type: series background: #white position:{0,0.0} size: {1.0,0.5}{
				if (propPeople_per_mobility_type['T'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['T'].values[i] color: color_per_type[type_people[i]];
					}				
				}
			}
		}
		display PeoplePerNeighbourhood{			
			chart "Proportion of people per neighbourhood [profile 0]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.0,0.0} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[0]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[0]].keys[i] value:peoplePerNeighbourhoodMap[type_people[0]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 1]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.3,0.0} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[1]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[1]].keys[i] value:peoplePerNeighbourhoodMap[type_people[1]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 2]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.6,0.0} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[2]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[2]].keys[i] value:peoplePerNeighbourhoodMap[type_people[2]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 3]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.0,0.3} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[3]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[3]].keys[i] value:peoplePerNeighbourhoodMap[type_people[3]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 4]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.3,0.3} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[4]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[4]].keys[i] value:peoplePerNeighbourhoodMap[type_people[4]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 5]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.6,0.3} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[5]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[5]].keys[i] value:peoplePerNeighbourhoodMap[type_people[5]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 6]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.0,0.6} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[6]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[6]].keys[i] value:peoplePerNeighbourhoodMap[type_people[6]].values[i];
					}
			}
			chart "Proportion of people per neighbourhood [profile 7]" background:#white type: pie style:ring size: {0.3,0.3} position: {0.3,0.6} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peoplePerNeighbourhoodMap[type_people[7]].keys)-1	{
					  data peoplePerNeighbourhoodMap[type_people[7]].keys[i] value:peoplePerNeighbourhoodMap[type_people[7]].values[i];
					}
			}
			chart "People distribution in Main City" background:#white type: pie style:ring size: {0.3,0.3} position: {0.6,0.6} color: #black axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
			tick_font: 'Monospaced' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Arial' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{					
					loop i from: 0 to: length(peopleProportionInSelectedCity.keys)-1	{
					  data peopleProportionInSelectedCity.keys[i] value:peopleProportionInSelectedCity.values[i] color: color_per_type[type_people[i]];
					}
			}
		}
		
		monitor "Number of people moving" value:movingPeople;
		monitor "Mean diversity" value: meanDiver;
		monitor "Number of people represented" value: nb_people;
		monitor "Number of agents used" value: nb_agents;
		
		
	}
	
}

experiment batch_save type: batch keep_seed: true until: cycle > 4 {
	parameter "percentage of market price for grid housing" var: gridPriceMarketPerc init: 0.0 min: 0.0 max: 1.0 step: 0.1 category: "Grid vables";
	parameter "number of floors for grid buildings" var: nbFloorsGrid init: 10 min: 10 max: 50 step: 5 category: "Grid vbles";
	
	reflex save_results{
		float propProfile0;
		float propProfile1;
		float propProfile2;
		float propProfile3;
		float propProfile4;
		float propProfile5;
		float propProfile6;
		float propProfile7;
		float totalPropInSelectedCity;
		
		list<float> list_prop_prof <- [];
		loop i from: 0 to: length(type_people) - 1{
			list_prop_prof << peopleProportionInSelectedCity.values[i];
		}
		//NOT GENERAL. COULD NOT WRITE AS A LIST WITH ONLY "," SEPARATORS
		//MODIFY THIS DEPENDING ON THE NUMBER OF PROFILES AND MOBILITY MODES THAT ARE BEING CONSIDERED
		
		propProfile0 <- list_prop_prof[0];
		propProfile1 <- list_prop_prof[1];
		propProfile2 <- list_prop_prof[2];
		propProfile3 <- list_prop_prof[3];
		propProfile4 <- list_prop_prof[4];
		propProfile5 <- list_prop_prof[5];
		propProfile6 <- list_prop_prof[6];
		propProfile7 <- list_prop_prof[7];
		totalPropInSelectedCity <- propProfile0 + propProfile1 +propProfile2 + propProfile3 + propProfile4 + propProfile5 + propProfile6 + propProfile7;
		
		
		float propMob0 <- people_per_Mobility_now['car'];
		float propMob1 <- people_per_Mobility_now['bus'];
		float propMob2 <- people_per_Mobility_now['T'];
		float propMob3 <- people_per_Mobility_now['bike'];
		float propMob4 <- people_per_Mobility_now['walking'];
			
		ask simulations{
			save[totalAreaBuilt, gridPriceMarketPerc, totalPropInSelectedCity, propProfile1, propProfile2, propProfile2, propProfile3, propProfile4, propProfile5, propProfile6, propProfile7, propMob0, propMob1, propMob2, propMob3, propMob4, meanTimeToMainActivity, meanDistanceToMainActivity] type: csv to: "../results/incentivizedScenarios/DiversityIncentive.csv" rewrite: false;
		}
	}
}


	
