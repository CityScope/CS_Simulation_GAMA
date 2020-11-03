/***
* Name: calibrationModel
* Author: mireia yurrita
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model calibrationModel


global{
	
	string selectedCity <- "CAMBRIDGE";
	
	/////////////////////////////////       SHAPEFILES          /////////////////////////////////////////////////
	

	// check https://github.com/jeffkaufman/apartment_prices/blob/master/query_padmapper.py for the apartment price web scraping process
	
	file<geometry> blockGroup_shapefile <- file<geometry>("./../includesCalibration/City/volpe/tl_2015_25_bg_msa_14460_MAsss_TOWNS_Neighb.shp");
	file<geometry> available_apartments <- file<geometry>("./../includesCalibration/City/volpe/apartments_march_great.shp");
	file<geometry> buildings_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Buildings.shp");
	file<geometry> T_lines_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Tline_cleanedQGIS.shp");
	file<geometry> T_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_NODE_MAss_color.shp");
	file<geometry> bus_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_BUS_MAss.shp");
	file<geometry> road_shapefile <- file<geometry>("./../includesCalibration/City/volpe/simplified_roads.shp");
	
	// GEOID collection of the census block groups belonging to the area of interest
	
	file kendallBlocks_file <- file("./../includesCalibration/City/volpe/KendallBlockGroupstxt.txt");
	
	
	
	////////////////////////////////        CSV FILES         ///////////////////////////////////////////////////////

	
	file criteria_home_file <- file("./../includesCalibration/Criteria/incentivizedCriteria/CriteriaHomeCalibrated.csv"); //home preference parameters f(income profile)
	file activity_file <- file("./../includesCalibration/Criteria/ActivityPerProfile.csv"); //daily activity schedules for each agent f(income profile)
	file mode_file <- file("./../includesCalibration/Criteria/Modes.csv"); //available mobility modes and their characteristics (as for now only walking, biking, metro (T), bus and car are considered
	file profile_file <- file("./../includesCalibration/Criteria/Profiles.csv"); //income profiles and their incidence
	file weather_coeff <- file("../includesCalibration/Criteria/weather_coeff_per_month.csv");
	file criteria_file <- file("../includesCalibration/Criteria/incentivizedCriteria/CriteriaFileCalibrated.csv"); //mobility preference criteria f(income profile, destination)
	file population_file <- file("../includesCalibration/City/censusDataGreaterBoston/censusDataClustered.csv"); //real census data of the area of interest (used to calculate diversity metrics)
	geometry shape<-envelope(T_lines_shapefile);
	
	
	////////////////////////////////        VARIABLES         ///////////////////////////////////////////////////
	
	
	int nb_people <- 11585; //number of people working in the area of interest (and thus looking for accommodation)
	int nb_agents <- int(11585/2); //make sure [nb_agent*max(possible_agents_per_point_list) > nb_people] Number of "dots" or agents used to represent nb_people
	float maxRent; 
	float minRent;
	float maxDiversity;
	float minDiversity;
	int realTotalPeople <- 0; //current amount of people being represented (may slightly differ from nb_people because of rounding effects)
	int realTotalAgents <- 0;
	bool weatherImpact<-false; //weather coefficients (and the difficulty that this implies when using certain mobility modes) will be considered if this boolean is true
	float weather_of_day min: 0.0 max: 1.0;	
	int reference_rent <- 1500; //commuting costs will be calculated as a percentage of this reference rent price
	int days_per_month <- 20; //labour days per month
	int movingPeople; //number of people moving after each iteration. Objective: make this parameter assymptotically approach zero
	int peopleInSelectedCity <- 0; //number of people living and working in the area of interest
	float propInSelectedCity; // percentage of the total amount of people (nb_people) that work and live in the area of interest
	float meanRentPeople;
	float meanDiver <- 0.0;
	float meanDiverNorm <- 0.0; //normalised diversity
	float angle <- atan((899.235 - 862.12)/(1083.42 - 1062.038)); //inclination of the grid
	point startingPoint <- {13844, 8318}; //starting point of the grid
	float brickSize <- 21.3; //CityScope LEGO size
	int boolGrid <- 1; //boolean to indicate whether to include a grid or not
	int init;
	float percForResidentialGrid <- 0.5; //variable for batch experiment (percentage of built area for residential purposes)
	int nbFloorsGrid <- 30; //variable for batch experiment (number of floors of the newly built grid buildings)
	float gridPriceMarketPerc <- 1.0; //percentage of the market price that grid buildings will offer (regardless of income profile for now). Vble for batch experiment
	
	
	map<string,int> density_map<-["S"::15,"M"::55, "L"::89, "microUnit" :: 40]; //area for each dwelling unit f(size)
	list<blockGroup> kendallBlockList; //list of block group agents within the area of interest (in CAMBRIDGE, Kendall)
	list<rentApartment> kendallApartmentList; //list of apartment agents within the area of interest (in CAMBRIDGE, Kendall)
	map<string,map<string,list<float>>> weights_map <- map([]);
	list<string> type_people; //list of considered income profiles
	map<string,float> priceImp_list; //map connecting each income profile to the importance given to rent price
	map<string,float> divacc_list; //idem  but with diversity acceptance
	map<string,list<string>> pattern_list; //idem with zone preference
	map<string,float> patternWeight_list; //idem with importance given to the housing unit being within this preferred zone
	map<string,list<float>> charact_per_mobility;  //characteristics of each mobility mode (fixed price, waiting time etc)
	map<string,rgb> color_per_mobility; 
	map<string,float> speed_per_mobility;
	map<string,float> weather_coeff_per_mobility;
	map<string,graph> graph_per_mobility; //road / metro line topology for each mobility mode
	map<string,rgb> color_per_type;	
	map<string, float> proba_bike_per_type; //probability of owning a bike f(income profile)
	map<string, float> proba_car_per_type; //idem with car
	map<string, float> proportion_per_type; //proportion of people working in the area of interest that belongs to a certain income profile group
	map<string,int> total_number_agents_per_type; 
	map<string,int> reduced_number_agents_per_type; //number of dots used to represent the amount of people of a certain income group (a dot might represent more than one people agent)
	list<int> actual_agents_per_point_list <- [0,0,0,0,0,0,0,0,0,0,0,0,0];
	list<int> possible_agents_per_point_list <- [1,2,5,10,20,30,40,50,60,70,80,90,100]; //possible amount of people agents that a dot might represent
	map<int,int> agent_per_point_map;  //map of how many dots of each type (representing 1,2,5, ... , 100 people agents) there are 
	map<string,int> actual_number_people_per_type; 
	map<string,int> actual_agents_people_per_type; //taking into account rounding effects
	map<string,map<int,int>> agent_per_point_type_map;
	map<string,string> main_activity_map; //which is the main activity of each income profile based on their daily activities (this determines the activity place of type building that these agents will head to)
	map<string,float> time_importance_per_type; //importance given to commuting time by each people agent f(income profile)
	list<list<float>> weather_of_month;
	map<road,float> congestion_map; 
	map<string,int> nPeople_perProfile;
	map<string,map<string,float>> peoplePerNeighbourhoodMap <- map([]); //amount of people that live in neighbourhood i and belongs to income profile j
	map<string,float> peopleProportionInSelectedCity;  //proportion of people (of the total nb_people) that live within the area of interest f(income profile)
	list<string> list_cities <- [];
	map<string,float> meanRent_perProfile; //mean paying rent f(income profile)
	float happyNeighbourhoodPeople; //proportion of people that are happy with their neighbourhood
	map<string,float> happyNeighbourhood_perProfile; //idem but f(income profile)
	map<string,map<string,float>> propPeople_per_mobility_type <- map([]); //proportion of people of type j that are using mobility mode i <mobility_type<people_type, prop>>
	list<string> allPossibleMobilityModes;
	map<string,float> people_per_Mobility_now; //prop of people regardless of their income profile that are using mobility mode i
	float meanTimeToMainActivity;
	map<string,float> meanTimeToMainActivity_perProfile;
	float meanDistanceToMainActivity;
	map<string,float> meanDistanceToMainActivity_perProfile;
	float meanCommutingCostGlobal;
	map<string,float> meanCommutingCost_perProfile;
	int totalAreaBuilt;
	int totalVacantSpacesInVolpe <- 0; //vacant dwelling units within the grid (Volpe if the selected city is CAMBRIDGE)
	float occupancyInVolpe <- 0.0; //percentage of area dedicated for residential purposes in the grid that is currently being used (important to calculate the stabilization points of each what-if scenario)
	
	
	
	
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
		do countNeighbourhoods; //Kendall + surroundings
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
			if(closestBusStop != nil){ //two distance calculated: from the geometrical centre of the block group to the closest bus stop location and from a random point within the block group to this same closes bus stop location
				float distancia <- distance_to(self.location, closestBusStop.location);
				float distancia2 <- distance_to(any_location_in(self), closestBusStop.location);
				if(distancia < 700 or distancia2 < 700){ //if either these distances <700 meters --> the block group offers bus service
					hasBus <- true;
				}
			}
			list<busStop> busesInsideMe <- [];
			busesInsideMe <- busStop inside(self); //double check if there are other bus stops within the boundaries of the census block group --> if so, block group offers bus service
			if(empty(busesInsideMe) = false){
				hasBus <- true;
			}
			else{
				hasBus <- false;
			}
			Tstop closestTStop <- Tstop closest_to(self); //idem with metro service
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
			associatedBlockGroup <- one_of(blockGroup where(each.GEOID = GEOIDAp)); //GEOIDAp is the GEOID of the block group where the apartment is located
			if(empty(associatedBlockGroup) = true){
			}
			if (associatedBlockGroup.city = 'DUXBURY'){
				do die; //outliers. Normalisation affected
			}
			else{
				associatedBlockGroup.apartmentsInMe << self; //if apartmentA's associatedBlockGroup is blockGroupB, apartmentA is within the list apartmentsInMe of associatedBlockGroupB
			}
		}
	}
	
	action calculateAverageFeatureBlockGroups{
		//if vacantBedrooms = 0 in a certain blockGroup but vacantSpaces != 0 that means they are all studios
		// we are interested in price per vacantSpace
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
		
		do calculateMaxMinRents; //important to calculate max and min rent prices as we are always working with normalised values of rent 
		
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
			asscBlock.initDiversityNorm <- blockPopulationMatrix[17,i]; //initial dicersity of the block group based on current census data
			asscBlock.initTotalPeople <- blockPopulationMatrix[7,i];
			asscBlock.totalPeople <- asscBlock.initTotalPeople;
			
			loop j from: 0 to: length(type_people) - 1 {
				asscBlock.initialPopulation[type_people[j]] <- blockPopulationMatrix[j + 8,i];
			}
			asscBlock.populationBlockGroup <- asscBlock.initialPopulation;
			
			ask asscBlock{
				do calculateDiversity; //diversity calculation using the Shanon-Weaver formula
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
			int vacantSpacesFromGrid <- 0;
			loop i from: 0 to: length(gen_apartment_list) - 1{
				int availableBedrooms <- gen_apartment_list[i].numberBedrooms;
				int availableSpaces;
				if(gen_apartment_list[i].numberBedrooms != 0){
					availableSpaces <- gen_apartment_list[i].numberBedrooms;
				}
				else{
					availableSpaces <- 1; //studios still have an availableSpace
				}
				float pricePerVacancy <- gen_apartment_list[i].rentAbs / availableSpaces;
				accummulated_rent <- accummulated_rent + gen_apartment_list[i].rentAbs;
				vacantSpaces_gen <- vacantSpaces_gen + availableSpaces; //total number of available spaces in the block group
				vacantBedrooms_gen <- vacantBedrooms_gen + availableBedrooms;
				if (gen_apartment_list[i].associatedBuilding != nil and empty(gen_apartment_list[i].associatedBuilding) != true){ //apartments that are not created from grid have no associatedBuilding yet
					if (gen_apartment_list[i].associatedBuilding.fromGrid = true){
						vacantSpacesFromGrid <- vacantSpacesFromGrid + gen_apartment_list[i].numberBedrooms;
					}
				}
			}
			if (vacantSpaces_gen - vacantSpacesFromGrid != 0){ //calculation of mean rent price per vacant space in a certain block group
				rentAbsVacancy_gen <- accummulated_rent / (vacantSpaces_gen - vacantSpacesFromGrid); //the ones in the grid do not have a price yet. They will be assigned the price of the closest block group (market price)
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
		if(maxRent != minRent ){ //avoid division by zero
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
		list<string> kendallBlockListString;
		
		loop i from: 0 to: kendall_blocks.columns - 1{
			string name_block <- kendall_blocks[i,0];
			if (i = 0){ //first element of the list includes an "a" that needs to be eliminated (included to avoid "int" error: numbers higher than the highest int value supported)
				name_block <- copy_between(name_block, 1, length(name_block));
			}
			kendallBlockListString << name_block;
			ask blockGroup{
				if(GEOID = kendallBlockListString[i]){
					inKendall <- true; //for block groups within the area of interest (in CAMBRIDGE, Kendall) boolean attribute inKendall = true
					kendallBlockList << self;
				}
			}
		}
		loop i from: 0 to: length(kendallBlockList) - 1{
			if(empty(kendallBlockList[i].apartmentsInMe) = false){
				loop j from: 0 to: length(kendallBlockList[i].apartmentsInMe) - 1{
					kendallApartmentList << kendallBlockList[i].apartmentsInMe[j]; //list gathering the apartment offer within the area of interest
				}
			}			
		}
		
		list<blockGroup> allBlockGroupsNotKendall;
		ask blockGroup where (each.inKendall = false){
			allBlockGroupsNotKendall << self;
			create building{ //fictious buildings (ABSTRACTION) will be associated to each of the census block groups that are not within the area of interest (in the iterative process it is necessary that option off housing A and B are the same type of agent)
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
				
				satellite <- true; //for buildings that represent an abstraction of census block groups (satellite buildings), boolean attribute satellite is true
				associatedBlockGroup.buildingsInMe << self;
				apartmentsInMe <- associatedBlockGroup.apartmentsInMe;
				
			}
			if(empty(apartmentsInMe) = false){
				loop i from:0 to: length(apartmentsInMe) - 1{
					apartmentsInMe[i].associatedBuilding <- self.buildingsInMe[0]; //if apartmentA's associatedBuilding is buildingB, apartmentA belongs to buildingB's apartmentsInMe list
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
				supported_people <- int(area/density_map[scale])*nbFloors;	//will not be used in the end. We ended up using the number of available spaces to consider a certain building as a housing option
			}
			else{
				supported_people<-0;
			}	
		}
				
		ask blockGroup where(each.inKendall = true){
			blockGroup blockGroupNow <- self;
			ask building where(each.GEOIDBuild = GEOID and each.satellite = false){
				blockGroupNow.buildingsInMe << self; //identify the physical building polygons that are located within the geographical boundaries of a certain census block group
			}
			if (empty(buildingsInMe) = false){
				loop i from: 0 to: length(buildingsInMe) - 1 {
					buildingsInMe[i].associatedBlockGroup <- self;
				}
			}
			else{ //census block group that is located in the area of interest (Kendall) but that has no physical building in it --> it turns out to be the same as a satellite census block group (with its corresponding satellite building)
				create building{ //satellite building as an abstraction of this (Kendall) census block group that has no physical building in it
					associatedBlockGroup <- blockGroupNow;
					neighbourhood <- associatedBlockGroup.neighbourhood;
					vacantSpaces <- associatedBlockGroup.vacantSpaces;
					rentAbsVacancy <- associatedBlockGroup.rentAbsVacancy;
					rentNormVacancy <- associatedBlockGroup.rentNormVacancy;
					satellite <- true;
					associatedBlockGroup.buildingsInMe << self;
				}
			}
		}
		ask building where(each.usage = "R" and each.satellite = false){ //physical buildings for residential purposes
			apartmentsInMe <- rentApartment inside(self);
			if(empty(apartmentsInMe) = false){
				loop j from:0 to: length(apartmentsInMe) - 1{
					apartmentsInMe[j].associatedBuilding <- self;
					remove apartmentsInMe[j] from: kendallApartmentList; //each apartment within the area of interest (Kendall) is now located within a physical building (and added to the apartmentsInMe attribute of this building)
				}
			}
		}
		if(empty(kendallApartmentList) = false){ //not every geolocated apartment for rent has been identified as part of a physical building 
			loop while: (empty(kendallApartmentList) = false) {
				kendallApartmentList[0].associatedBuilding <- one_of(building where(each.satellite = false and each.associatedBlockGroup = kendallApartmentList[0].associatedBlockGroup)); //it will be associated to a near physical building (that is located within the same census block group)
				if((kendallApartmentList[0].associatedBuilding) is building != true){
					kendallApartmentList[0].associatedBuilding <- building where(each.satellite = false and each.usage = "R") closest_to (self); //to the closest one indeed
					if(kendallApartmentList[0].associatedBlockGroup != nil and empty(kendallApartmentList[0].associatedBlockGroup) != true){
						kendallApartmentList[0].associatedBlockGroup.apartmentsInMe >- kendallApartmentList[0]; 
						kendallApartmentList[0].associatedBlockGroup  <- kendallApartmentList[0].associatedBuilding.associatedBlockGroup; //the building could be in another block group (when talking about the boundaries between two block groups) --> associatedBlockGroup of the apartment changed
						if (kendallApartmentList[0].associatedBlockGroup = nil){
							
						}
						else{
							kendallApartmentList[0].associatedBlockGroup.apartmentsInMe << kendallApartmentList[0];
						}
						kendallApartmentList[0].associatedBuilding.apartmentsInMe << kendallApartmentList[0];
					}
					else{
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
					list bedSpaceRentList <- calculate_Features(listApartmentsInMe[i]); //calculation of the total vacant Spaces and mean rent per vacancy WITHIN the building (previously this calculation has been held for each census block group)
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
				if (associatedBuilding.fromGrid = true){ //for the buildings created in the grid
					rentAbs <- associatedBlockGroup.rentAbsVacancy*gridPriceMarketPerc; //closest census block group mean rent market price multiplied by the potential subsidy
					associatedBuilding.rentNormVacancy <- associatedBlockGroup.rentNormVacancy*gridPriceMarketPerc;
					associatedBuilding.rentAbsVacancy <- associatedBlockGroup.rentAbsVacancy*gridPriceMarketPerc; //same for all the apartments within the newly built building
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
					associatedBuilding <- associatedBlockGroup.buildingsInMe[0]; //rent apartments that are outside the area of interest (Kendall) have the same associatedBuilding (satellite abstraction building) as the census block group they belong to
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
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
	}
	
	action read_criteriaHome{
		matrix criteriaHome_matrix <- matrix(criteria_home_file);
		loop i from: 0 to: criteriaHome_matrix.rows-1{
			type_people << criteriaHome_matrix[0,i];
			priceImp_list << (type_people[i]::criteriaHome_matrix[1,i]);
			divacc_list << (type_people[i]::criteriaHome_matrix[2,i]);
			
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
		startingPoint <- {startingPoint.x - brickSize / 2, startingPoint.y - brickSize / 2};	
		int cont <- 0;			
		totalAreaBuilt <- 0;
		totalVacantSpacesInVolpe <- 0;
		bool noBuild;
		loop i from: 0 to: 12{ //this is NOT GENERIC. It is adapted for Volpe layout
			loop j from: 0 to: 15{
				noBuild <- false;
				if(i = 12 and j > 11){
					noBuild <- true; //grid elements that cannot have a building in it 
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
				
				if(noBuild != true){ //except for the ones that cannot host a building in them, the rest of the grid elements
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
						scale <- "microUnit"; //following the CityScience vision, all the dwelling units will be comprised of micro units
						category <-  "mixed"; //mixed use buildings (offices, amenities, residential spaces...)
						nbFloors <- nbFloorsGrid; //variable batch experiment
						totalAreaBuilt <- totalAreaBuilt + area*nbFloors*percForResidentialGrid;
						type <- "BLDG";
						FAR <- 4.0; //current air right(not used in the free what-if scenarios)
						max_height <- 120.0; //current air right (not used in the free what-if scenarios)
						satellite <- false;
						if (density_map[scale]!=0){
							supported_people <- int(area/density_map[scale])*nbFloors*percForResidentialGrid;
						}
						else{
							supported_people<-0;
						}
						vacantSpaces <- supported_people;
						totalVacantSpacesInVolpe <- totalVacantSpacesInVolpe + vacantSpaces;
						
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
							numberBedrooms <- associatedBuilding.vacantSpaces;	//although it being considered an only apartment, the amount of vacant spaces is what makes it eligible for the housing search iterative process
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
				add m_temp at: people_type to: weights_map; //weights map (mobility type preference) for each people type and each destination
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
		
		//avoid "nil" elements
		color_per_type [] >>- "nil";
		proba_car_per_type [] >>- "nil";
		proba_bike_per_type [] >>- "nil";
		proportion_per_type [] >>- "nil";
		total_number_agents_per_type [] >>- "nil";
		reduced_number_agents_per_type [] >>- "nil";
	}
	
	action compute_graph{
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode]<- as_edge_graph (road where (mobility_mode in each.mobility_allowed)) use_cache false; //topology of roads
		}
		graph_per_mobility[] >>- "T"; //except for metro
		graph_per_mobility["T"] <- as_edge_graph(Tline) use_cache false; //topology of Tlines for T (metro)
	}
	
	//calculation to know how many people is represented by a dot
	action agent_calc{
		loop i from: 0 to: length(proportion_per_type) -1 {
			int itshere <- 0;
			actual_agents_per_point_list <- [0,0,0,0,0,0,0,0,0,0,0,0,0];
			
			//logic: if we want to represent 27 agents with 4 dots: mean_value_point = 6.75. We need at least 1 of the dots to be of value > 6.75 (ex.:10)
			float mean_value_point <- total_number_agents_per_type[type_people[i]] / reduced_number_agents_per_type[type_people[i]];
			
			loop j from: 0 to: length(possible_agents_per_point_list) - 1 {
				float diff <- possible_agents_per_point_list[j] - mean_value_point;
				if (diff >= 0){ //when the difference gets >0, we have the first element of value greater than the mean (10)
					itshere <- j; //breaking point (from here to the left)
					break;
				}
			}
			
			float howmany <- total_number_agents_per_type[type_people[i]]/possible_agents_per_point_list[itshere]; //calculation of how many of these dots of value 10 we need
			int howmany_round <- round(howmany); //inferior round of the amount of dots of value 10
			if (howmany_round >  howmany){
				howmany_round <- howmany_round - 1; //if round gives us 3 dots of value 10 (upper round), we extract 1--> 2 dots of value 10 
			}
			actual_agents_per_point_list[itshere] <- howmany_round;
			int remaining_people <- total_number_agents_per_type[type_people[i]] - howmany_round*possible_agents_per_point_list[itshere]; //remaining agents for representing with lower dot values (in example 37-2*10 = 7)
			int remaining_points <- reduced_number_agents_per_type[type_people[i]] - howmany_round; //remaining usable dots (maximum amount of dots/agents is fixed. In example: 4 - 2 = 2)
			
			if(itshere > 0){ //if we have not represented everything with unity value dots
				loop m from:0 to:itshere - 1{
					if(possible_agents_per_point_list[m]*remaining_points > remaining_people){ //they need to be enough to end up representing the total amount of people (we can use 2 dots for seven people, then unity or 2 valued dots are not possible)
						actual_agents_per_point_list[m] <- int(remaining_people/possible_agents_per_point_list[m]); //round how many dots we would use for the representation of remaining people (7 / 5 = 1.4 int 1)
						remaining_points <- remaining_points - actual_agents_per_point_list[m]; //2 - 1 = 1 available usable dot still
						remaining_people <- remaining_people - actual_agents_per_point_list[m]*possible_agents_per_point_list[m]; //7 - 5*1 = 2 people to still represent with 1 dot
						if(m != 1 and m!= 0){
							loop n from: m - 1 to: 0 step: -1{ //cover all the remaining dot values below the one selected (in example below 5 valued dots, there are 2,1 valued dots, m = 2 in our example))
								if(possible_agents_per_point_list[n]*remaining_points > remaining_people){ //with the available amount of dots  (1) we need to be able to reprent the remaining amount of people (2)
									actual_agents_per_point_list[n] <- int(remaining_people/possible_agents_per_point_list[n]); //the dot has to be then double valued  (2*1 = 2 remaining_people= 0 remaining_dots = 0)
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
				realnumber_PeopleType <- realnumber_PeopleType + actual_agents_per_point_list[k]*possible_agents_per_point_list[k]; //calculation of real amount of people represneted because of rounding effects
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
					main_activity <- list_form[j]; //main activity for each profile type according to their daily schedule (main activity will be the one that is most repeated)
					max_value <- repetition_list[j];
				}	
			}
			main_activity_map[type_people[i - 1]] <- main_activity;  //associate main activity to each income profile
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
			time_importance_per_type[type_i] <- crits_main_activity[1]; //identify time importance for income profile i for their main activity
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
			type <- proportion_per_type_now.keys[rnd_choice(proportion_per_type.values)]; //random choice of people type depending on their incidence (real data)
			map<int,int> extract_map <- agent_per_point_type_map[type];
			agent_per_point <- extract_map.keys[0];
			extract_map[agent_per_point] <- extract_map[agent_per_point] - 1;
			extract_map >>- 0; //remove from the map the pairs where the value (number of instances) is 0			
			agent_per_point_type_map[type] <- extract_map;
			
			if (empty(extract_map) = true){
				proportion_per_type_now[] >- type; //if every agent of type i has already been represented, delete that type of people from the available ones
			}
			
			
			living_place <- one_of(building where (each.vacantSpaces >= 1*agent_per_point and each.outskirts = false));
			
			if (living_place != nil){ 
				actualCity <- living_place.associatedBlockGroup.city;
				payingRent <- living_place.rentNormVacancy;
				payingRentAbs <- living_place.rentAbsVacancy;
				actualNeighbourhood <- living_place.neighbourhood;
									
			}
			else{//if there is no building with vacant spaces, they will live on the outskirts (supposing this has infinite capacity)
				living_place <- one_of(building where(each.outskirts = true));
				living_place.peopleWhoJustCame <- living_place.peopleWhoJustCame + 1*agent_per_point; //monitoring of outskirts occupancy just for control
				actualNeighbourhood <- living_place.associatedBlockGroup.neighbourhood;
				actualCity <- living_place.associatedBlockGroup.city;
			}
			
			if(living_place.satellite = false){
				location <- any_location_in(living_place);
			}
			else{
				location <- any_location_in(living_place.associatedBlockGroup); //as the satellite building location is just a point, we want people to scatter within the census block group represented by this abstraction
			}
			//update building and census block group metrics (amount of people living there, amount of vacant spaces...)
			living_place.vacantSpaces <- living_place.vacantSpaces - 1*agent_per_point;
			living_place.associatedBlockGroup.vacantSpaces <- living_place.associatedBlockGroup.vacantSpaces - 1*agent_per_point;
			living_place.associatedBlockGroup.totalPeople <- living_place.associatedBlockGroup.totalPeople + 1*agent_per_point;
			living_place.associatedBlockGroup.populationBlockGroup[type] <- living_place.associatedBlockGroup.populationBlockGroup[type] + 1 * agent_per_point;
			living_place.associatedBlockGroup.peopleInMe << self;
			
			//weight given to actual neighbourhood depending whether it is located within the preferred zone of each income profile
			actualPatternWeight <- calculate_patternWeight(actualNeighbourhood);
			list<string> extract_list <- pattern_list[type];
			if (living_place.neighbourhood = extract_list[0]){
				happyNeighbourhood<-1; //boolean attribute for each people agent to notify whether they are happy in their neighbourhood or not
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
				principal_activity <- one_of(list_pa); //if there are more than one activity for same incidence for a certain income profile --> select one of them as their main activity
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
			else if(principal_activity = "A"){ //if amenity is main activity: main activity place will be any place except offices and residential
				activity_place<-one_of(building where(each.category != "R" and each.category != "O" and each.satellite = false));
			}
			else{
				activity_place<-one_of(building where (each.category = principal_activity and each.satellite = false));
			}
			
			do calculate_possibleMobModes;
			
			bool possibilityToTakeT <- false;
			bool possibilityToTakeBus <- false;
			if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
				possibilityToTakeT <- true; //the possibility of taking the metro (T) or the bus only apply if both the housing area and the activity place area offer these services
			}
			if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
				possibilityToTakeBus <- true;
			}
			
			bool hasCar <- false;
			bool hasBike <- false;
			if(possibleMobModes contains "car" = true){
				hasCar <- true;
			}
			if(possibleMobModes contains "bike" = true){
				hasBike <- true;
			}
			
			map<string,list<float>> mobilityAndTime<- evaluate_main_trip(location,activity_place, hasCar, hasBike, possibilityToTakeT, possibilityToTakeBus);
			list<float> extract_list_here <- mobilityAndTime[mobilityAndTime.keys[0]];
			time_main_activity <- extract_list_here[3]/60;
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
		int peopleInVolpe;
		ask people where(each.living_place.fromGrid = true){
			peopleInVolpe <- peopleInVolpe + agent_per_point;
		}
		if(totalVacantSpacesInVolpe != 0){
			occupancyInVolpe <- peopleInVolpe / totalVacantSpacesInVolpe; //occupancy in Volpe will be an important metric to calculate the stabilization point of the incentives
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
					peoplePerNeighbourhoodPartialMap[list_cities[j]] <- number_peopleProfile_here / nPeople_perProfile[type_people[i]]; //proportion of people type i living in city j
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
		meanRentPeople <- 0.0; //general mean rent
		meanRent_perProfile <- []; //mean rent f(income profile)
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
		happyNeighbourhoodPeople <- 0.0; //general metric for the amount of people that are happy with the neighbourhood they are living in
		happyNeighbourhood_perProfile <- []; //idem but f(income profile)
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
		propPeople_per_mobility_type <- map([]); //proportion of people of type j using mobility mode i
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
		meanTimeToMainActivity <- 0.0; //mean commuting time regardless of income profile
		meanDistanceToMainActivity <- 0.0; //idem but for commuting distance
		ask people{
			meanTimeToMainActivity <- meanTimeToMainActivity + time_main_activity_min*agent_per_point;
			meanDistanceToMainActivity <- meanDistanceToMainActivity + distance_main_activity*agent_per_point;
		}
		meanTimeToMainActivity <- meanTimeToMainActivity / nb_people;
		meanDistanceToMainActivity <- meanDistanceToMainActivity / nb_people;
		
		meanTimeToMainActivity_perProfile <- []; //mean commuting time f(income profile)
		meanDistanceToMainActivity_perProfile <- []; //idem for commuting distance
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
		meanCommutingCostGlobal <- 0.0; //general metric for commuting cost
		ask people{
			meanCommutingCostGlobal <- meanCommutingCostGlobal + CommutingCost*agent_per_point;
		}
		meanCommutingCostGlobal <- meanCommutingCostGlobal / nb_people;
		
		meanCommutingCost_perProfile <- []; //mean commuting cost f(income profile)
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
	
}

species blockGroup{
	string GEOID; //unique geographical ID number for each census block group
	float lat; //geolocation latitude, longitude
	float long;
	int vacantSpaces; //we will use this one to allocate people.
	int initVacantSpaces; //initial vacant spaces (infor collected to monitor the evolution throughout the iterations)
	//int vacantBedrooms;
	float rentAbsVacancy; //absolute rent per vacancy
	float rentNormVacancy; //normalized rent per vacancy
	list<rentApartment> apartmentsInMe; //available rentals within the census block group
	list<building> buildingsInMe; //if (<1) abstraction of census block group through satellite building, if (>1) list of physical buildings within the census block group
	bool inKendall <- false; //boolean to indicate if the census block group belongs to the area of interest (in CAMBRIDGE, Kendall)
	string city;
	string neighbourhood;
	map<string,int> initialPopulation; //initial population f(income profile). Info collected to monitor evolution through iterations
	map<string,int> populationBlockGroup;
	int initTotalPeople;
	int totalPeople;
	float initDiversityNorm; //initial normalized diversity. Will be compared to the normalized diversity throughout the iterations to monitor the evolution
	float diversity;
	float diversityNorm;
	bool hasT;
	bool hasBus;
	bool sthHasChanged; //boolean to indicate if someone new has moved to the census block group and thus to recalculate the diversity in iteration i
	list<people> peopleInMe;  //list of people agents that currently live within the census block group

	action calculateDiversity{	 //Shanon-Weaver formula for diversity calculation
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
	
	aspect default{ //various aspects are presented to differ census block groups with or without a certain attribute (Ex hasBus). By default, no difference between the census block groups is made when it comes to aspect
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
	blockGroup associatedBlockGroup; //block group within which the apartment is located
	building associatedBuilding; //idem but for building if the building is physical (satellite = false). If the building is the abstraction of a census block group this associatedBuilding = associatedBlockGroup.buildingsInMe[0]
	int rentAbs;
	int numberBedrooms;
	
	aspect default{
		draw circle(20) color: #purple;
	}
}

species building{
	blockGroup associatedBlockGroup; //block group within which the building is located if satellite = 0 or census block group that the building represents if satellite = 1
	string usage; //office, amenity, mixed use etc
	string scale; //S, M, L, microUnit
	string category; 
	string type;
	float FAR; //based on current policies. Not taken into account when grid buildings are evaluated and free what-if scearios are being evaluated
	float max_height; //same as FAR but translated into maximum meters
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
	bool satellite <- false; //default values. This will change when creating specific buildings that DO meet theses criteria
	bool outskirts <- false;
	bool fromGrid <- false;
	
	aspect default{
		if(fromGrid = true){
			draw shape rotated_by angle color: rgb(50,50,50, 125);
		}
		else{
			draw shape color: rgb(50,50,50, 125);	
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
	int agent_per_point; //amount of people that a dot is representing
	building living_place;
	string actualCity;
	float payingRent; //normalized rent
	float payingRentAbs;
	string actualNeighbourhood;
	float actualPatternWeight;
	int happyNeighbourhood;
	string principal_activity;
	building activity_place;
	list<string> possibleMobModes; //these will vary from people agent to people agent depending on whether they own a car, a bike etc
	float time_main_activity; //normalized commuting time
	float time_main_activity_min; //in minutes
	float CommutingCost;
	float distance_main_activity;
	string mobility_mode_main_activity; //selected most convenient mobility mode among the ones in possibleMobModes list
	
	float calculate_patternWeight(string possibleNeighbourhood){
		float possible_patternWeight;
		list<string> extract_list <- pattern_list[type]; //list of preferred zones based on the income profile
		int donde <- 1000;
		loop i from: 0 to: length(extract_list) - 1 {
			if (possibleNeighbourhood = extract_list[i]){
				donde <- i; //if possibleNeighbourhood is within the preferred zone list, "donde" indicates the element position within the list
			}
		}
		
		possible_patternWeight <- 1.0 - donde*0.3; //depending on the position of preferrence the possible patternWeight will vary (+1.0 for the favourite one, 0.7 for the second choice etc)
		if (possible_patternWeight < - 1.0){
			possible_patternWeight <- -1.0; //minimimum value of possible_patternWeight
		}
		return possible_patternWeight;
	}
	
	action calculate_possibleMobModes{
		possibleMobModes <- ["walking"]; //always possibility to walk. For veeeery long distances, it will be punished through the commuting time, so that the people agent will not choose this option
		if (flip(proba_car_per_type[type]) = true){
			possibleMobModes << "car"; //car and bike will be possible mobility modes depending on the priability of owning one according to their income profile
		}
		if (flip(proba_bike_per_type[type]) = true){
			possibleMobModes << "bike";
		}
	}
	
	
	map<string,list<float>> evaluate_main_trip(point origin_location, building destination, bool hasCar, bool hasBike, bool isthereT <- false, bool isthereBus <- false){
	
		list<list> candidates;
		list<float> commuting_cost_list;
		list<float> distance_list;
		list<float> time_list;
		list<string> possibleMobModesNow <- ["walking"];
		
		if(hasCar = true){
			possibleMobModesNow << "car";
		}
		if(hasBike = true){
			possibleMobModesNow << "bike";
		}
		if (isthereBus = true){
			possibleMobModesNow << "bus"; //bus and T are only available if the origin and the destination offer these services, this possibleMobModes is not always necessarily equal to possibleMobModesNow
		}
		if(isthereT = true){
			possibleMobModesNow << "T";
		}
		
		
		loop mode over:possibleMobModesNow{
			list<float> characteristic<- charact_per_mobility[mode];
			list<float> cand;	
			float distance <- 0.0;	
				
				if(mode = 'T'){ //for T and bus the distance and time from the origin and destination stations are calculated (we are ignoring the time and distance that it takes to get from the origin location to the origin station and the same for destination)
					Tstop nearestTstopHome <-  Tstop closest_to living_place;
					Tstop nearestTstopWork <- Tstop closest_to activity_place;
					using topology(graph_per_mobility[mode]){
						distance <- distance_to(nearestTstopHome.location, nearestTstopWork.location); //nearly straight lines, because of the Tline topology
					}
					if (distance > 100000){ //error with the map because of possible dangling ends etc. Then euclidean distance is calculated and increased by 25%
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
		//normalisation within the available mobility modes
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
			if(obj=destination.category or (destination.category in ["OS","OM","OL"]) and (obj = "O") or (destination.category="Restaurant" and (obj="restaurant"))){ //take into account the spelling differences!!
				vals <- crits[obj];
				break;
			}
		}
		list<map> criteria_WM;
		loop i from: 0 to: length(vals)-1{
			criteria_WM<< ["name"::"crit"+i, "weight"::vals[i]];
		}
		int choice <- weighted_means_DM(candidates, criteria_WM); //GAMA function that indicates the position of the possible mobility mode that maximizes the selection formula (linear combination btw criteria and the corresponding values)
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
		
		
		if(nbFloorsGrid > 0 and boolGrid = 1){ //if there is anythin built in the grid
			float a <- rnd(1.0);
			if(a > 0.75){ //make Volpe exploration easier. Avoid having to run many iterations to at least explore the possibility of moving to the grid
				possibleMoveBuilding <- one_of(building where(each.vacantSpaces >= agent_per_point and (each != living_place) and each.fromGrid = true)); //first explore the grid buildings
				if (possibleMoveBuilding = nil){ //if there is no availability within the grid, explore any building to move
					possibleMoveBuilding <- one_of(building where(each.vacantSpaces >= 1*agent_per_point and (each != living_place) and each.outskirts = false));
				}
			}
			else{ //in the 25% of the cases, just explore any building
				possibleMoveBuilding <- one_of(building where(each.vacantSpaces >= 1*agent_per_point and (each != living_place) and each.outskirts = false));
			}
		}
		
		
		if(possibleMoveBuilding != nil){//it is a building in Kendall or satellite blockGroup
			if(possibleMoveBuilding.satellite = false){
				locationPossibleMoveBuilding <- possibleMoveBuilding.location;
				
			}
			else{
				locationPossibleMoveBuilding <- any_location_in(possibleMoveBuilding.associatedBlockGroup); //the satellite building is represented by a point, and we want the people to scatter throughout the census block group that this building represents
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
		possiblePatternWeight <- calculate_patternWeight(possibleNeighbourhood); //is the housing option located within the preferred zone? If so or if not, a weight is given to it
			
		bool possibilityToTakeT <- false;
		bool possibilityToTakeBus <- false;
		if(possibleMoveBuilding.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
			possibilityToTakeT <- true;
		}
		if(possibleMoveBuilding.associatedBlockGroup.hasBus = true and activity_place.associatedBlockGroup.hasBus = true){
			possibilityToTakeBus <- true;
		}
		bool hasCar <- false;
		bool hasBike <- false;
		if(possibleMobModes contains "car" = true){
			hasCar <- true;
		}
		if(possibleMobModes contains "bike" = true){
			hasBike <- true;
		}
		map<string,list<float>> possibleTimeAndMob <- evaluate_main_trip(locationPossibleMoveBuilding,activity_place, hasCar, hasBike, possibilityToTakeT, possibilityToTakeBus); //list<float> is time and commuting_cost with respect to a reference_rent
		//evaluation of the most favourable means of transportation to commute from and to the housing option that is being offered as an alternative to the current one
		list<float> possible_extract_list <- possibleTimeAndMob[possibleTimeAndMob.keys[0]];
		possibleTime <- possible_extract_list[3]/60;
		possibleTimeMin <- possible_extract_list[3];
		possibleCommutingCost <- possible_extract_list[1];
		possibleMobility <- possibleTimeAndMob.keys[0];
		possibleDistance <- possible_extract_list[2];
		
		cands <- [[possibleLivingCost + possibleCommutingCost,possibleDiversity,possiblePatternWeight, possibleTime],[living_cost + CommutingCost,living_place.associatedBlockGroup.diversityNorm,actualPatternWeight, time_main_activity]];
		//candidateA(alternative to the current one) and its correponding costs (rent+commute), diversity, zone pattern, and commuting time
		//candidateB(current housing option)
		
		list<float> crit<- [priceImp_list[type],divacc_list[type],patternWeight_list[type],time_importance_per_type[type]]; //importance given to housing price, diversity acceptance, zone and commuting time f(income profile)
		
		list<map> criteria_WM<-[];
		loop i from:0 to: length(crit)-1{
			criteria_WM<<["name"::"crit"+i, "weight"::crit[i]];
		}		
		int choice <- weighted_means_DM(cands,criteria_WM); //does candidateA or candidateB maximize the weighted mean sum?
		
		if (choice = 0){ //if candidateA maximimzes it --> people agent MOVES
			//update metrics (available spaces, total people living within the census block group, building etc) both in the current housing (-) and in the future housing option (+)
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
			living_place <- possibleMoveBuilding; //the possibleMoveBuilding (candidateA) turns out to be the current housing option
			
			
			
			if(living_place.satellite = true){
				location <- any_location_in(living_place.associatedBlockGroup);
			}
			else{
				location <- any_location_in(living_place);
			}
			
			movingPeople <- movingPeople + 1*agent_per_point;		
			//possible turns out to be current as a consequence of moving. Update people agent attributes
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
	
			 
		display MovingDiversity { //monitoring of the amount of people moving as well as the mean diversity throughout the iterations
			chart "MovingPeople" type: series background: #white position:{0,0} size:{1.0,0.5}{
				data "Moving people in myCity" value:movingPeople color:#blue;
			}
			chart "Mean diversity evolution" type: series background:#white position:{0,0.5} size:{1.0,0.5}{
				data "Mean diversity in myCity" value: meanDiver color: #green;
				data "Mean normalised diversity in myCity" value: meanDiverNorm color: #orange;
			}
		}
		
		display RentCommutingCosts{ //monitoring of the rent, commuting costs and people happy within their neighbourhood in general and f(income profile) throughout the iterations
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
		display MobilityPie{ //monitoring of general usage of each mobility mode and also f(income profile) as well as mean commuting time and distance throughout the iterations
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
		display MobilityChartsCarsBikes{	 //car and bike usage monitoring throughout the iterations (in general and f(income profile))

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
		display MobilityChartsBusWalking{ //people walking and bus usage monitoring throughout the iterations (in general and f(income profile))
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
		display MobilityChartsT{ //metro (T) usage monitoring throughout the iterations (in general and f(income profile))
			chart "Proportion of people using T" type: series background: #white position:{0,0.0} size: {1.0,0.5}{
				if (propPeople_per_mobility_type['T'] != nil){
					loop i from: 0 to:length(type_people) - 1{
						data type_people[i] value: propPeople_per_mobility_type['T'].values[i] color: color_per_type[type_people[i]];
					}				
				}
			}
		}
		display PeoplePerNeighbourhood{		//distribution of people of each income profile along the different cities in current iteration i	
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
		
		monitor "Number of people moving" value:movingPeople; //number of people moving. This will asymptotically approach zero throughout the iterations
		monitor "Mean diversity" value: meanDiver;
		monitor "Number of people represented" value: nb_people;
		monitor "Number of agents used" value: nb_agents;
		monitor "Volpe Occupancy " value: occupancyInVolpe;		
		
	}
	
}

experiment batch_save type: batch keep_seed: true until: cycle > 4 { //batch experiment to test different what-if scenarios. Parameters to be manipulated: percentage of market price offered for this units (1-subsidy) and number of floors built (in the end it is translated int m2 available for residential use and then into available additional dwelling units)
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
			list_prop_prof << peopleProportionInSelectedCity.values[i]; //proportion of people of within each income profile that ends up living and working within the area of interest ( in CAMBRIDGE, Kendall)
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
			save[totalAreaBuilt, gridPriceMarketPerc, totalPropInSelectedCity, propProfile1, propProfile2, propProfile2, propProfile3, propProfile4, propProfile5, propProfile6, propProfile7, propMob0, propMob1, propMob2, propMob3, propMob4, meanTimeToMainActivity, meanDistanceToMainActivity] type: csv to: "../results/incentivizedScenarios/DiversityIncentive.csv" rewrite: false header: false;
		}
	}
}


	
