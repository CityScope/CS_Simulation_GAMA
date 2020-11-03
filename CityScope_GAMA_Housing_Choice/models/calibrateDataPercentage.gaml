/***
* Name: calibrateDataPercentage
* Author: mireia yurrita
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model calibrateDataPercentage



global{
	
	//note that the dynamics of this model are very similar to the main model. The difference is: in the main model people use some criteria f(income profile) to choose their housing and mobility options
	//in this case we have info about the outcome (data of which census block group people working in Kendall live as well as transportation statistics). Two types of errors (housing and mobility) are 
	// defined so that a criteria exploration process can be held and the combination of criteria leading to the minimum amount of error is identified
	
	//comments of parts of code that are similar or even identical to that in the main model are, thus, omited
	
	
	/////////////////////////////////       SHAPEFILES          /////////////////////////////////////////////////
	
	file<geometry> blockGroup_shapefile <- file<geometry>("./../includesCalibration/City/volpe/tl_2015_25_bg_msa_14460_MAsss_TOWNS_Neighb.shp");
	file<geometry> available_apartments <- file<geometry>("./../includesCalibration/City/volpe/apartments_march_great.shp");
	file<geometry> buildings_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Buildings.shp");
	file<geometry> T_lines_shapefile <- file<geometry>("./../includesCalibration/City/volpe/Tline_cleanedQGIS.shp");
	file<geometry> T_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_NODE_MAss_color.shp");
	file<geometry> bus_stops_shapefile <- file<geometry>("./../includesCalibration/City/volpe/MBTA_BUS_MAss.shp");
	file<geometry> road_shapefile <- file<geometry>("./../includesCalibration/City/volpe/simplified_roads.shp");
	
	// GEOID collection of the census block groups belonging to the area of interest (this could have been done directly in QGIS)
	
	file kendallBlocks_file <- file("./../includesCalibration/City/volpe/KendallBlockGroupstxt.txt");
	
	
	
	////////////////////////////////        CSV FILES         ///////////////////////////////////////////////////////
	
	file criteria_home_file <- file("./../includesCalibration/Criteria/CriteriaHome.csv"); //home preference parameters f(income profile). Starting points will be taken from here
	file activity_file <- file("./../includesCalibration/Criteria/ActivityPerProfile.csv"); //daily activity schedules for each agent f(income profile)
	file mode_file <- file("./../includesCalibration/Criteria/Modes.csv"); //available mobility modes and their characteristics (as for now only walking, biking, metro (T), bus and car are considered
	file profile_file <- file("./../includesCalibration/Criteria/Profiles.csv"); //income profiles and their incidence
	file weather_coeff <- file("../includesCalibration/Criteria/weather_coeff_per_month.csv");
	file criteria_file <- file("../includesCalibration/Criteria/CriteriaFile.csv"); //synthetic criteria file for mobility preferences
	file population_file <- file("../includesCalibration/City/censusDataGreaterBoston/censusDataClustered.csv"); //real census data of the area of interest (used to calculate diversity metrics)
	file real_Kendall_data_file <- file("../includesCalibration/City/censusDataGreaterBoston/kendallWorkersCleaned.csv"); //census block groups where people working in the area of interest live (this data is only available for a small propotion of them, it will be extrapolated to the whoel amount of workers, once their preference criteria is identified)
	file real_mobility_data_file <- file("../includesCalibration/Criteria/realKendallMobility.csv"); //transportation data 
	geometry shape<-envelope(T_lines_shapefile);
	
	
	
	////////////////////////////////        VARIABLES         ///////////////////////////////////////////////////////
	
	
	//list of neighbourhoods needs to be changed for each calibration scenario (Cambridge, Boston, Hamburg etc)
	list<string> list_neighbourhoods <- ["Area 2/MIT",'The Port','Neighborhood Nine','East Cambridge','Cambridgeport','Riverside','Mid-Cambridge','Wellington-Harrington','Cambridge Highlands','Strawberry Hill','West Cambridge','North Cambridge','BOSTON','ARLINGTON','SOMERVILLE','WEYMOUTH','MARBLEHEAD','DANVERS','SALEM','BEVERLY','LYNN','NORTH ANDOVER','BOXFORD','IPSWICH','MIDDLETON','TOPSFIELD','LAWRENCE','ESSEX','WENHAM','HAMILTON','MANCHESTER','PEABODY','NORTH READING','LYNNFIELD','ANDOVER','GEORGETOWN','ROWLEY','METHUEN','HAVERHILL','NEWBURY','GROVELAND','WEST NEWBURY','MERRIMAC','NEWBURYPORT','ROCKPORT','GLOUCESTER','READING','WAKEFIELD','SAUGUS','AMESBURY','FOXBOROUGH','SHARON','QUINCY','WELLESLEY','NEEDHAM','DOVER','CANTON','WESTWOOD','NORWOOD','HULL','COHASSET','HINGHAM','SCITUATE','MEDFIELD','MILTON','SHERBORN','NATICK','FRAMINGHAM','GROTON','LITTLETON','AYER','TEWKSBURY','WILMINGTON','RANDOLPH','AVON','HOLBROOK','NORFOLK','WRENTHAM','WALPOLE','MILLIS','MEDWAY','HOLLISTON','BURLINGTON','MEDFORD','BROOKLINE','DEDHAM','BRAINTREE','BELLINGHAM','FRANKLIN','TYNGSBOROUGH','WESTFORD','CHELSEA','REVERE','EVERETT','NEWTON','WATERTOWN','MALDEN','STOUGHTON','WINTHROP','ABINGTON','ROCKLAND','CONCORD','CARLISLE','BILLERICA','BEDFORD','STONEHAM','MELROSE','LOWELL','WALTHAM','STOW','ACTON','CHELMSFORD','LINCOLN','SUDBURY','WESTON','MAYNARD','MARLBOROUGH','HUDSON','NORWELL','HANOVER','PEMBROKE','HANSON','BROCKTON','WEST BRIDGEWATER','DRACUT','BELMONT','ASHLAND','HOPKINTON','PEPPERELL','TOWNSEND','MARSHFIELD','WHITMAN','WOBURN','WINCHESTER','EAST BRIDGEWATER','MIDDLEBOROUGH','PLYMPTON','BRIDGEWATER','LAKEVILLE','KINGSTON','WAREHAM','PLYMOUTH','LEXINGTON','DUXBURY','CARVER','MARION','MATTAPOISETT','SWAMPSCOTT','SALISBURY','NAHANT','OUTSKIRTS'];
	map<string, map<string,float>> neighbourhoods_real <- map([]); //map of all the neighbourhoods availble. Within each element there is a map that represents the percentage of people of type j that live there according to real data
	map<string, map<string,int>> neighbourhoods_real_int <- map([]); //same but in number of people of type j that live there
	map<string, map<string,float>> neighbourhoods_now <- map([]); //same as neighbourhoods_real but instead of based on real data, based on simulation results
	map<string, map<string,int>> neighbourhoods_now_int <- map([]); //same as neighbourhoods_real_int but instead of based on real data, based on simulation results
	
	
	int it;
	int nb_people <- 996; //number of people for whom there is data regarding their census block group
	float maxRent;
	float minRent;
	float maxDiversity;
	float minDiversity;
	bool weatherImpact<-false;
	float weather_of_day min: 0.0 max: 1.0;	
	int reference_rent <- 1500; //commuting costs will be calculated as a percentage of this reference rent price
	int days_per_month <- 20; //labour days per month
	int movingPeople;
	float meanDiver <- 0.0;
	float meanDiverNorm <- 0.0;
	float propCar; //percentage of people using cars
	int intCar; //number (int) of people using cars
	float propBike;
	int intBike;
	float propTransit; //T + bus
	int intTransit;
	float propWalking;
	int intWalking;
	float mobilityError; //mean square root error of percentage of mobility choice usage
	float mobilityErrorInt; //RMSE of number of people using a mobility choice that differs what data says
	float housingErrorTotal; //idem for housing error
	float housingErrorTotalInt;
	matrix kendall_real_pop; //real population in the area of interest
	map<string,int> density_map<-["S"::15,"M"::55, "L"::89];
	list<blockGroup> kendallBlockList; //list of census block groups within the area of interest
	list<rentApartment> kendallApartmentList; //available apartments within the area of interest (Padmapper, March 2020)
	map<string,map<string,list<float>>> weights_map <- map([]); //imporance of each mobility mode criteria f(income profile, destination)
	list<string> type_people;
	map<string,float> priceImp_map; //housing price importance f(income profile)
	map<string,float> divacc_map; // diversity acceptance f(income profile)
	map<string,string> pattern_map; //preferred zone map f(income profile)
	map<string,float> patternWeight_map; //weight given to this preferred zone f(income profile)
	map<string,list<float>> charact_per_mobility;  ////characteristics of each mobility mode (fixed price, waiting time etc)
	map<string,rgb> color_per_mobility;
	map<string,float> speed_per_mobility;
	map<string,float> weather_coeff_per_mobility;
	map<string,graph> graph_per_mobility; //road / metro line topology for each mobility mode
	map<string,rgb> color_per_type;	
	map<string, float> proba_bike_per_type; //probability of owning a bike f(income profile)
	map<string, float> proba_car_per_type; //idem for cars
	map<string,string> main_activity_map;
	map<string,float> time_importance_per_type; //importance given to commuting time f(income profile)
	list<list<float>> weather_of_month;
	map<road,float> congestion_map; 
	list<string> allPossibleMobilityModes;
	map<string,float> people_per_Mobility_now; //percentage of people using mobility mode i
	map<string,int> people_per_Mobility_now_int; //number (int) of people using mobility mode i
	
	
	
	////////////////////////////////        PARAMETERS TO EXPLORE         ///////////////////////////////////////////////////////
	
	
	float price_main_trip_30000 <- -0.95; //starting value for importance given to commuting cost for income profile <$30,000 
	float price_main_trip_30000_44999 <- -0.9; //idem for income profile 30,000-44,999
	float price_main_trip_45000_59999 <- -0.8;
	float price_main_trip_60000_99999 <- -0.7;
	float price_main_trip_100000_124999 <- -0.6;
	float price_main_trip_125000_149999 <- -0.4;
	float price_main_trip_150000_199999 <- -0.3;
	float price_main_trip_200000 <- 0.0;
	
	list<float> price_main_trip_list <- [price_main_trip_30000, price_main_trip_30000_44999, price_main_trip_45000_59999, price_main_trip_60000_99999, price_main_trip_100000_124999, price_main_trip_125000_149999, price_main_trip_150000_199999, price_main_trip_200000];
	
	float time_main_trip_30000 <- -0.7; //stating value for commuting time for income profile <$30,000
	float time_main_trip_30000_44999 <- -0.75;
	float time_main_trip_45000_59999 <- -0.8;
	float time_main_trip_60000_99999 <- -0.85;
	float time_main_trip_100000_124999 <- -0.9;
	float time_main_trip_125000_149999 <- -0.95;
	float time_main_trip_150000_199999 <- -0.95;
	float time_main_trip_200000 <- -1.0;
	
	list<float> time_main_trip_list <- [time_main_trip_30000, time_main_trip_30000_44999, time_main_trip_45000_59999, time_main_trip_60000_99999, time_main_trip_100000_124999, time_main_trip_125000_149999, time_main_trip_150000_199999, time_main_trip_200000];
	
	float pattern_main_trip_30000 <- 1.0; //starting value for social pattern imprtance of mobility mode for income profile <$30,000
	float pattern_main_trip_30000_44999 <- 1.0;
	float pattern_main_trip_45000_59999 <- 0.95;
	float pattern_main_trip_60000_99999 <- 0.8;
	float pattern_main_trip_100000_124999 <- 0.7;
	float pattern_main_trip_125000_149999 <- 0.5;
	float pattern_main_trip_150000_199999 <- 0.32;
	float pattern_main_trip_200000 <- 0.2;
	
	list<float> pattern_main_trip_list <- [pattern_main_trip_30000, pattern_main_trip_30000_44999, pattern_main_trip_45000_59999, pattern_main_trip_60000_99999, pattern_main_trip_100000_124999, pattern_main_trip_125000_149999, pattern_main_trip_150000_199999, pattern_main_trip_200000];
	
	float difficulty_main_trip_30000 <- -0.65; //starting value for difficulty importance when commuting for income profile <$30,000
	float difficulty_main_trip_30000_44999 <- -0.65;
	float difficulty_main_trip_45000_59999 <- -0.7;
	float difficulty_main_trip_60000_99999 <- -0.75;
	float difficulty_main_trip_100000_124999 <- -0.8;
	float difficulty_main_trip_125000_149999 <- -0.85;
	float difficulty_main_trip_150000_199999 <- -0.9;
	float difficulty_main_trip_200000 <- -1.0;
	
	list<float> difficulty_main_trip_list <- [difficulty_main_trip_30000, difficulty_main_trip_30000_44999, difficulty_main_trip_45000_59999, difficulty_main_trip_60000_99999, difficulty_main_trip_100000_124999, difficulty_main_trip_125000_149999, difficulty_main_trip_150000_199999, difficulty_main_trip_200000];
	
	matrix criteriaHome_matrix <- matrix(criteria_home_file); //starting values for housing preferences are taken from the synthetic Criteria file (price importance, diversity acceptance, prefered zone and importance of this zone)
		
	float price_home_30000 <- criteriaHome_matrix[1,0];
	float price_home_30000_44999 <- criteriaHome_matrix[1,1];
	float price_home_45000_59999 <- criteriaHome_matrix[1,2];
	float price_home_60000_99999 <- criteriaHome_matrix[1,3];
	float price_home_100000_124999 <- criteriaHome_matrix[1,4];
	float price_home_125000_149999 <- criteriaHome_matrix[1,5];
	float price_home_150000_199999 <- criteriaHome_matrix[1,6];
	float price_home_200000 <- criteriaHome_matrix[1,7];		
	
	list<float> priceImp_list <- [price_home_30000, price_home_30000_44999, price_home_45000_59999, price_home_60000_99999, price_home_100000_124999, price_home_125000_149999, price_home_150000_199999, price_home_200000];
	
	
	float diver_home_30000 <- criteriaHome_matrix[2,0];
	float diver_home_30000_44999 <- criteriaHome_matrix[2,1];
	float diver_home_45000_59999 <- criteriaHome_matrix[2,2];
	float diver_home_60000_99999 <- criteriaHome_matrix[2,3];
	float diver_home_100000_124999 <- criteriaHome_matrix[2,4];
	float diver_home_125000_149999 <- criteriaHome_matrix[2,5];
	float diver_home_150000_199999 <- criteriaHome_matrix[2,6];
	float diver_home_200000 <- criteriaHome_matrix[2,7];
	
	list<float> divacc_list <- [diver_home_30000, diver_home_30000_44999, diver_home_45000_59999, diver_home_60000_99999, diver_home_100000_124999, diver_home_125000_149999, diver_home_150000_199999, diver_home_200000];
	
	int zone_home_30000 <- 0; //position of the prefered zone within the complete list of neighbourhoods
	int zone_home_30000_44999 <- 0;
	int zone_home_45000_59999 <- 7;
	int zone_home_60000_99999 <- 7;
	int zone_home_100000_124999 <- 3;
	int zone_home_125000_149999 <- 3;
	int zone_home_150000_199999 <- 3;
	int zone_home_200000 <- 3;
	
	list<string> pattern_list <- [list_neighbourhoods[zone_home_30000], list_neighbourhoods[zone_home_30000_44999], list_neighbourhoods[zone_home_45000_59999], list_neighbourhoods[zone_home_60000_99999], list_neighbourhoods[zone_home_100000_124999], list_neighbourhoods[zone_home_125000_149999], list_neighbourhoods[zone_home_150000_199999], list_neighbourhoods[zone_home_200000]];
	
	float pattern_home_30000 <- criteriaHome_matrix[6,0];
	float pattern_home_30000_44999 <- criteriaHome_matrix[6,1];
	float pattern_home_45000_59999 <- criteriaHome_matrix[6,2];
	float pattern_home_60000_99999 <- criteriaHome_matrix[6,3];
	float pattern_home_100000_124999 <- criteriaHome_matrix[6,4];
	float pattern_home_125000_149999 <- criteriaHome_matrix[6,5];
	float pattern_home_150000_199999 <- criteriaHome_matrix[6,6];
	float pattern_home_200000 <- criteriaHome_matrix[6,7];
	
	list<float> patternWeight_list <- [pattern_home_30000, pattern_home_30000_44999, pattern_home_45000_59999, pattern_home_60000_99999, pattern_home_100000_124999, pattern_home_125000_149999, pattern_home_150000_199999, pattern_home_200000];
	
	
	

		
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
		do import_mobility_data;
		write "mobility data imported";
		do countMobility;
		do updateMeanDiver;
		do calculateRealPercentages;
		do computeErrorHousing;

	}
	
	action createBlockGroups{
		create blockGroup from: blockGroup_shapefile with:[GEOID::string(read("GEOID")), lat::float(read("INTPTLAT")), long::float(read("INTPTLON")), city::string(read("TOWN")), neighbourhood::string(read("Neighbourh"))]{
		}
		ask blockGroup{ //discussed in main model
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
	
	action createApartments{ //discussed in main model
		create rentApartment from: available_apartments with: [rentAbs::int(read("Rent")), numberBedrooms::int(read("NBedrooms")), GEOIDAp::string(read("GEOID"))]{
			associatedBlockGroup <- one_of(blockGroup where(each.GEOID = GEOIDAp));
			if (associatedBlockGroup = nil){
				write "rentApartment with no associatedBlockGroup " + self + "my GEOID " + GEOIDAp;
			}
			if(empty(associatedBlockGroup) = true){
				write "estoy vacio" + self;
			}
			associatedBlockGroup.apartmentsInMe << self;
		}
	}
	
	action calculateAverageFeatureBlockGroups{ //discussed in main model
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
			if(list_neighbourhoods contains asscBlock.neighbourhood != true){
				list_neighbourhoods << asscBlock.neighbourhood;
			}
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
	
	list calculate_Features(list<rentApartment> gen_apartment_list){ //discussed in main model
		int vacantSpaces_gen;
		int vacantBedrooms_gen;
		float rentAbsVacancy_gen;
		
		gen_apartment_list >>- [nil];
		if(gen_apartment_list != []){		
			float accummulated_rent <- 0.0;		
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
				accummulated_rent <- accummulated_rent + gen_apartment_list[i].rentAbs;
				vacantSpaces_gen <- vacantSpaces_gen + availableSpaces;
				vacantBedrooms_gen <- vacantBedrooms_gen + availableBedrooms;
			}
			rentAbsVacancy_gen <- accummulated_rent / vacantSpaces_gen;
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
		float rentNormVacancy_gen <- (rentAbsVacancy_gen - minRent) / (maxRent - minRent);		
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
	
	action identifyKendallBlocks{ //discussed in main model
		matrix kendall_blocks <- matrix(kendallBlocks_file);
		list<string> kendallBlockListString;
		
		loop i from: 0 to: kendall_blocks.columns - 1{
			string name_block <- kendall_blocks[i,0];
			if (i = 0){
				name_block <- copy_between(name_block, 1, length(name_block));
			}			
			kendallBlockListString << name_block;
			ask blockGroup{
				if(GEOID = kendallBlockListString[i]){
					inKendall <- true;
					kendallBlockList << self;
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
	
	action createBuildings{ //discussed in main model
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
					rentAbsVacancy <- associatedBlockGroup.rentAbsVacancy;
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
					kendallApartmentList[0].associatedBuilding <- building where(each.satellite = false and each.usage = "R") closest_to (self);
					kendallApartmentList[0].associatedBlockGroup.apartmentsInMe >- kendallApartmentList[0];
					kendallApartmentList[0].associatedBlockGroup  <- kendallApartmentList[0].associatedBuilding.associatedBlockGroup;
					if(kendallApartmentList[0].associatedBlockGroup = nil){
						
					}
					else{
						kendallApartmentList[0].associatedBlockGroup.apartmentsInMe << kendallApartmentList[0];
					}
					kendallApartmentList[0].associatedBuilding.apartmentsInMe << kendallApartmentList[0];
				}
				else{
					kendallApartmentList[0].associatedBuilding.apartmentsInMe << kendallApartmentList[0];
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
					extract_apartmentList[0].associatedBuilding.vacantSpaces <- bedSpaceRentList[1];
					extract_apartmentList[0].associatedBuilding.rentAbsVacancy <- bedSpaceRentList[2];
					extract_apartmentList[0].associatedBuilding.rentNormVacancy <- normalise_rents(extract_apartmentList[0].associatedBuilding.rentAbsVacancy);
				}
			}
		}	
		
		ask building where(each.satellite = false){
			if (associatedBlockGroup = nil){
				do die;
			}
		}
		
		ask rentApartment{
			if (associatedBlockGroup = nil or empty(associatedBlockGroup) = true){
				write "rentApartment with no associatedBlockGroup " + self + "my GEOID " + GEOIDAp;
			}
		}
		
		ask rentApartment {
			if(associatedBlockGroup != nil){
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
	
		loop i from: 0 to: criteriaHome_matrix.rows-1{
			type_people << criteriaHome_matrix[0,i];
			priceImp_map << (type_people[i]::priceImp_list[i]);						
			divacc_map << (type_people[i]:: divacc_list[i]);
			pattern_map << (type_people[i]::pattern_list[i]);
			patternWeight_map << (type_people[i]::patternWeight_list[i]);		
			 
		}
	}
	
	action  criteria_file_import{ //discussed in main model
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
						if(index>4){
							add float(criteria_matrix[index,i]) to: l2;
						}
						if(index = 1){ //criteria for main activity commuting trip os directly taken from the parameters we are iteraring through
							add price_main_trip_list[i - 5] to: l2;
						}
						if(index = 2){
							add time_main_trip_list[i - 5] to: l2;
						}
						if(index = 3){
							add pattern_main_trip_list[i - 5] to: l2;
						}
						if(index = 4){
							add difficulty_main_trip_list[i - 5] to: l2;
						}
						
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
				speed_per_mobility[mobility_type]<- float(mode_matrix[9,i]);
				weather_coeff_per_mobility[mobility_type]<- float(mode_matrix[10,i]);
			}
		}		
	}
	
	action profils_data_import{
		matrix profile_matrix<- matrix(profile_file);
		loop i from:0 to: profile_matrix.rows-1{
			string profil_type <- profile_matrix[0,i];
			if(profil_type!=""){
				color_per_type[profil_type] <- rgb(profile_matrix[1,i]);
				proba_car_per_type[profil_type]<-float(profile_matrix[2,i]);
				proba_bike_per_type[profil_type]<-float(profile_matrix[3,i]);
			}
		}	
		
		color_per_type [] >>- "nil";
		proba_car_per_type [] >>- "nil";
		proba_bike_per_type [] >>- "nil";
	}
	
	action compute_graph{
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode]<- as_edge_graph (road where (mobility_mode in each.mobility_allowed)) use_cache false;
		}
		graph_per_mobility[] >>- "T";
		graph_per_mobility["T"] <- as_edge_graph(Tline) use_cache false;
	}
	
	
	action activityDataImport{ //discussed in main model
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
	
	action createPopulation{ //creation of a reduced population based on the available data. Criteria will be then extrapolated to the real amount of people working in the area
		
		kendall_real_pop <- matrix(real_Kendall_data_file);
		string name_pop <- kendall_real_pop[0,0];
		kendall_real_pop[0,0] <- copy_between(name_pop, 1, length(name_pop));
		
		loop i from: 0 to: kendall_real_pop.rows - 1{
			create people number: kendall_real_pop[1,i]{
				type <- kendall_real_pop[2,i]; //the income profile has been approximated to the income profile that has the greatest incidence within the census block group where the person lives
				agent_per_point <- 1; //for calibration each point will represent a person (there are not so many people)
				real_GEOID <- kendall_real_pop[0,i]; //GEOID of the actual census block group where this person lives
				realBlockGroup <- one_of(blockGroup where(each.GEOID = real_GEOID));
				
				living_place <- one_of(building where (each.vacantSpaces >= 1*agent_per_point and each.outskirts = false)); //the objective is to get to the point where the simulation ends up inferring (based on the preference criteria) where this person will live and that it matches the real data. But for a first iteration a random living place is assigned to them
				
				if (living_place != nil){
					actualCity <- living_place.associatedBlockGroup.city;
					payingRent <- living_place.rentNormVacancy;
					actualNeighbourhood <- living_place.neighbourhood;
										
				}
				else{
					living_place <- one_of(building where(each.outskirts = true));
					living_place.peopleWhoJustCame <- living_place.peopleWhoJustCame + 1*agent_per_point; //monitoring attribute to check whether it is necessary to update the diversity metric
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
				
				
				//discussed in main model
				actualPatternWeight <- calculate_patternWeight(actualNeighbourhood);
				list<string> extract_list <- pattern_map[type];
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
				
				do calculate_possibleMobModes;
				
				bool possibilityToTakeT <- false;
				bool possibilityToTakeBus <- false;
				if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
					possibilityToTakeT <- true;
				}
				if(living_place.associatedBlockGroup.hasT = true and activity_place.associatedBlockGroup.hasT = true){
					possibilityToTakeBus <- true;
				}
				
				bool hasCar <- false;
				bool hasBike <- false;
				if(possibleMobModes contains "car" = true){
					hasCar <- true;
				}
				if (possibleMobModes contains "bike" = true){
					hasBike <- true;
				}
				map<string,list<float>> mobilityAndTime<- evaluate_main_trip(location,activity_place, hasCar, hasBike, possibilityToTakeT, possibilityToTakeBus);
				list<float> extract_list <- mobilityAndTime[mobilityAndTime.keys[0]];
				time_main_activity <- extract_list[3]/60;
				time_main_activity_min <- extract_list[3];
				CommutingCost <- extract_list[1];
				distance_main_activity <- extract_list[2];
				mobility_mode_main_activity <- mobilityAndTime.keys[0];
				
				
			}
		}
	}
	
	action import_mobility_data{ //import real transportation data
		matrix kendall_real_mobility <- matrix(real_mobility_data_file);
		propCar <- kendall_real_mobility[1,2];
		intCar <- propCar * nb_people;
		propBike <- kendall_real_mobility[1,1];
		intBike <- propBike * nb_people;
		propTransit <- kendall_real_mobility[1,0];
		intTransit <- propTransit * nb_people;
		propWalking <- kendall_real_mobility[1,3];
		intWalking <- propWalking * nb_people;
	}
	
	action countMobility{ //mobility error computation
		mobilityError <- 0.0; //difference in percentage between simulation and real transportation data (in general terms)
		mobilityErrorInt <- 0.0; //difference in number of people btw simulation and real transporation data
		float errorPropCar; //same as mobility error but just for car usage
		float errorIntCar;  //same as mobilityErrorInt but just for car usage
		float errorPropTransit;
		float errorIntTransit;
		float errorPropBike;
		float errorIntBike;
		float errorPropWalking;
		float errorIntWalking;
		float propBus; //transit = T + bus, but in the simulation we will have the breakdown of each of them
		int intBus;
		float propT;
		int intT;
		float propTransitNow;
		int intTransitNow;
	
		loop i from: 0 to: length(allPossibleMobilityModes) - 1{
			loop j from:0 to: length(type_people) - 1{
				int nPeople <- 0;
				ask people where(each.mobility_mode_main_activity = allPossibleMobilityModes[i]){
					nPeople <- nPeople + agent_per_point;
				}
				
				people_per_Mobility_now[allPossibleMobilityModes[i]] <- nPeople/nb_people;	//percentage of people agents that use mobility mode i regardless of their income profile
				people_per_Mobility_now_int[allPossibleMobilityModes[i]] <- nPeople;		
			}
		}
		loop i from: 0 to: length(people_per_Mobility_now) - 1{
			if (people_per_Mobility_now.keys[i] = "walking"){
				errorPropWalking <- (people_per_Mobility_now.values[i] - propWalking)^2; // Squared error in percentage for people walking
 				errorIntWalking <- (people_per_Mobility_now_int.values[i] - intWalking)^2; //Squared error in number of people for people walking	
			}
			else if(people_per_Mobility_now.keys[i] = "car"){
				errorPropCar <- (people_per_Mobility_now.values[i] - propCar)^2;
				errorIntCar <- (people_per_Mobility_now_int.values[i] - intCar)^2;
			}
			else if(people_per_Mobility_now.keys[i] = "bike"){
				errorPropBike <- (people_per_Mobility_now.values[i] - propBike)^2; 
				errorIntBike <- (people_per_Mobility_now_int.values[i] - intBike)^2;
			}
			else if (people_per_Mobility_now.keys[i] = "bus"){
				propBus <- people_per_Mobility_now.values[i];
				intBus <- people_per_Mobility_now_int.values[i];
			}
			else if (people_per_Mobility_now.keys[i] = "T"){
				propT <- people_per_Mobility_now.values[i];
				intT <- people_per_Mobility_now_int.values[i];
			}
		}
		propTransitNow <- propBus + propT;
		intTransitNow <- intBus + intT;
		errorPropTransit <- (propTransitNow - propTransit)^2; //Squared error for transit (once the error for bus and bus have been calculated separately)
		errorIntTransit <- (intTransitNow - intTransit)^2;
		mobilityError <- 1/4*(errorPropWalking + errorPropCar + errorPropBike + errorPropTransit); //MSE for mobility error in percentage
		mobilityErrorInt <- 1/2*(errorIntWalking + errorIntCar + errorIntBike + errorIntTransit); //MSE for mobility error in number of people
		mobilityError <- sqrt(mobilityError); //RMSE for mobility error in percentage
		mobilityErrorInt <- sqrt(mobilityErrorInt); //RMSE for mobility error in number of people

	}
	
	action updateMeanDiver{
		meanDiverNorm <- mean(blockGroup where(each.totalPeople != 0) collect each.diversityNorm);
		meanDiver <- mean(blockGroup where(each.totalPeople != 0) collect each.diversity);
	}
	
	action calculateRealPercentages{ //definition of maps that will gather housing info (based on data and simulations). 
		loop i from: 0 to: length(list_neighbourhoods) - 1{
			map<string, float> local_neighbourhoods_real <- map([]); //according to real data, percentage of people of type j that live in neighbourhood i
			map<string, float> local_neighbourhoods_now <- map([]); //according to the simulation, percentage of people of type j that live in neighbourhood i
			map<string, int> local_neighbourhoods_real_int <- map([]); //same but measured in number of people
			map<string, int> local_neighbourhoods_now_int <- map([]);
			loop j from: 0 to: length(type_people)- 1{
				local_neighbourhoods_real[type_people[j]] <- 0; //initialization in zero in each iteration. Each time we start counting from zero and ask every agent where they are living
				local_neighbourhoods_now[type_people[j]] <- 0;
				local_neighbourhoods_real_int[type_people[j]] <- 0;
				local_neighbourhoods_now_int[type_people[j]] <- 0;
			}
			add local_neighbourhoods_real to: neighbourhoods_real at: list_neighbourhoods[i]; 
			add local_neighbourhoods_now to: neighbourhoods_now at: list_neighbourhoods[i];
			add local_neighbourhoods_real_int to: neighbourhoods_real_int at: list_neighbourhoods[i];
			add local_neighbourhoods_now_int to: neighbourhoods_now_int at: list_neighbourhoods[i];
		}
		
		loop i from:0 to: kendall_real_pop.rows - 1{ //read and write data to the corresponding map
			blockGroup blockGroupNow <- one_of(blockGroup where(each.GEOID = kendall_real_pop[0,i]));
			string blockGroupNeighbourhood <- blockGroupNow.neighbourhood;
			int nPeopleHere <- kendall_real_pop[1,i];
			string typePeopleHere <- kendall_real_pop[2,i];
			
			map<string, int> extract_neighbourhoods_real_int <- map([]);	
			map<string,float> extract_neighbourhoods_real <- map([]); 		
			extract_neighbourhoods_real_int <- neighbourhoods_real_int[blockGroupNeighbourhood];	
			extract_neighbourhoods_real <- neighbourhoods_real[blockGroupNeighbourhood];		
			extract_neighbourhoods_real_int[typePeopleHere] <- extract_neighbourhoods_real_int[typePeopleHere] + nPeopleHere;
			extract_neighbourhoods_real[typePeopleHere] <- extract_neighbourhoods_real_int[typePeopleHere] / nb_people;	
			add extract_neighbourhoods_real_int to: neighbourhoods_real_int at: blockGroupNeighbourhood;
			add extract_neighbourhoods_real  to: neighbourhoods_real at: blockGroupNeighbourhood;
		}
	}
	
	action computeErrorHousing{ //housing error computing
		housingErrorTotal <- 0.0;		
		ask people{
			 map<string, int> extract_map_neighbourhoods_now_int <- map([]);			
			 extract_map_neighbourhoods_now_int <- neighbourhoods_now_int[actualNeighbourhood];
			 extract_map_neighbourhoods_now_int[type] <- extract_map_neighbourhoods_now_int[type] + 1*agent_per_point; //add oneself to according to their income profile to the corresponding population map of the neighbourhood they are living in 
			 add extract_map_neighbourhoods_now_int to: neighbourhoods_now_int at: actualNeighbourhood;
			 
		}
		
		float localHousingError <- 0.0; //error in percentage
		float localHousingErrorInt <- 0.0; //error in number of people
		loop i from:0 to: length(list_neighbourhoods) - 1{
			
			map<string, float> extract_neighbourhoods_now <- map([]);
			map<string, float> extract_neighbourhoods_real <- map([]);
			map<string, int> extract_neighbourhoods_now_int <- map([]);
			map<string, int> extract_neighbourhoods_real_int <- map([]);
			extract_neighbourhoods_now <- neighbourhoods_now[list_neighbourhoods[i]];
			extract_neighbourhoods_real <- neighbourhoods_real[list_neighbourhoods[i]];
			extract_neighbourhoods_now_int <- neighbourhoods_now_int[list_neighbourhoods[i]];
			extract_neighbourhoods_real_int <- neighbourhoods_real_int[list_neighbourhoods[i]];
			
			
			loop j from: 0 to: length(type_people) - 1{
				extract_neighbourhoods_now[type_people[j]] <- extract_neighbourhoods_now_int[type_people[j]] / nb_people;	 //calculation of percentage of people of type j that live in neighbourhood i			
				
				localHousingError <- (extract_neighbourhoods_now[type_people[j]] - extract_neighbourhoods_real[type_people[j]])^2; //Squared error btw simulation and reality in percentage
				localHousingErrorInt <- (extract_neighbourhoods_now_int[type_people[j]] - extract_neighbourhoods_real_int[type_people[j]])^2; //same but in number of people
			}
			add extract_neighbourhoods_now to: neighbourhoods_now at: list_neighbourhoods[i] ;
			housingErrorTotal <- housingErrorTotal + localHousingError;
			housingErrorTotalInt <- housingErrorTotalInt + localHousingErrorInt;
		}
		housingErrorTotal <- sqrt(housingErrorTotal / (length(list_neighbourhoods) - 1)); //RMSE of housing error in percentage
		housingErrorTotalInt <- sqrt(housingErrorTotalInt) / (length(list_neighbourhoods) - 1); //same but in number of people
	}

	reflex peopleMove{ //discussed in main model
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
		do countMobility;
		do updateMeanDiver;
		do computeErrorHousing;
	}
}

species blockGroup{ //discussed in main model
	string GEOID;
	float lat;
	float long;
	int vacantSpaces; //we will use this one to allocate people
	int initVacantSpaces;
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
	int vacantSpaces;
	float rentAbsVacancy;
	float rentNormVacancy;
	list<rentApartment> apartmentsInMe;
	string GEOIDBuild;
	bool satellite <- false;
	bool outskirts <- false;
	
	aspect default{
		draw shape color: rgb(50,50,50);
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

species people{ //discussed in main model
	string type;
	int agent_per_point;
	building living_place;
	string actualCity;
	float payingRent;
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
	string real_GEOID;
	blockGroup realBlockGroup;
	
	float calculate_patternWeight(string possibleNeighbourhood){
		float possible_patternWeight;
		string extract_list <- pattern_map[type];
		int donde <- 1000;
		
		if (possibleNeighbourhood = extract_list){
			donde <- 0;
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
			possibleMobModesNow << "bus";
		}
		if(isthereT = true){
			possibleMobModesNow << "T";
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
		float possibleLivingCost;
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
		possiblePatternWeight <- calculate_patternWeight(possibleNeighbourhood);
			
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
		list<float> possible_extract_list <- possibleTimeAndMob[possibleTimeAndMob.keys[0]];
		possibleTime <- possible_extract_list[3]/60;
		possibleTimeMin <- possible_extract_list[3];
		possibleCommutingCost <- possible_extract_list[1];
		possibleMobility <- possibleTimeAndMob.keys[0];
		possibleDistance <- possible_extract_list[2];
		
		cands <- [[possibleLivingCost + possibleCommutingCost,possibleDiversity,possiblePatternWeight, possibleTime],[living_cost + CommutingCost,living_place.associatedBlockGroup.diversityNorm,actualPatternWeight, time_main_activity]];
		
		list<float> crit<- [priceImp_map[type],divacc_map[type],patternWeight_map[type],time_importance_per_type[type]];
		
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
			
			list<string> extract_list <- pattern_map[type];
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

experiment gui_lets_see type: gui{ //gui created just to see if the code was working correctly
	output{
		display map type: opengl draw_env: false background: #black{
			species blockGroup aspect: default;
			species building aspect: default;
			species rentApartment aspect: default;
			species road aspect: default;
			species Tstop aspect:default;
			species Tline aspect: default;
			//species busStop aspect: default;
			species people aspect: default;	}	
			
			display HousingErrorEvolution{
				chart "Housing Error Total Evolution" type: series background: #white position:{0,0.0} size: {1.0,0.5}{
					data "HousingErrorTotal" value: housingErrorTotal color: #green;
				}
				chart "Housing Error Total Int Evolution" type: series background: #white position: {0,0.5} size: {1.0,0.5}{
					data "HousingErrorTotalInt" value: housingErrorTotalInt color: #red;
				}
			}
			display MobilityErrorEvolution{
				chart "Mobility Error Evolution" type: series background: #white position: {0,0.0} size: {1.0,0.5}{
					data "MobilityError" value: mobilityError color: #green;
				}
				chart "Mobility Error Evolution Int" type:series background: #white position:{0,0.5} size:{1.0,0.5}{
					data "MobilityErrorInt" value: mobilityErrorInt color: #red;
				}
			}
			display MovingPeople{
				chart "Moving People Evolution" type: series background: #white position:{0,0.0} size: {1.0,0.5}{
					data "Moving People Evolution " value: movingPeople color: #blue;
				}		
			}	
			
		monitor "Number of people moving" value: movingPeople;
		monitor "Housing Error Total" value: housingErrorTotal;	
		monitor "Mobility Error" value: mobilityError;
	}
}

experiment exploration type: batch keep_seed: true until: (movingPeople < 0.1*nb_people ) or ( cycle > 4 ) {
	//exploration of all the parameters (4 housing related preference parameters, 4 mobility related preference parameters multiplied by 8 income profiles  ==> 64 parameters to explore
	
	parameter "Price Importance main trip <$30000 " var: price_main_trip_30000 init: -0.6 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $300000 - $44999 " var: price_main_trip_30000_44999 init: -0.5 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $45000 - $59999 " var: price_main_trip_45000_59999 init: -0.1 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $60000 - $99999 " var: price_main_trip_60000_99999 init: -0.1 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $100000- $124999 " var: price_main_trip_100000_124999 init: -0.2 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $125000 - $149999 " var: price_main_trip_125000_149999 init: -0.1 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip $150000 - $199999 " var: price_main_trip_150000_199999 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance main trip >$200000 " var: price_main_trip_200000 init: -0.9  min: -1.0 max: 0.0 step: 0.1;
	
	parameter "Time Importance main trip <$30000 " var: time_main_trip_30000 init: -0.3 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $300000 - $44999 " var: time_main_trip_30000_44999 init: 0.0 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $45000 - $59999 " var: time_main_trip_45000_59999 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $60000 - $99999 " var: time_main_trip_60000_99999 init: -0.3 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $100000- $124999 " var: time_main_trip_100000_124999 init: -0.4 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $125000 - $149999 " var: time_main_trip_125000_149999 init: -0.9 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip $150000 - $199999 " var: time_main_trip_150000_199999 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	parameter "Time Importance main trip >$200000 " var: time_main_trip_200000 init: -0.9 min: -1.0 max: 0.0 step: 0.1;
	
	parameter "Pattern Importance main trip <$30000 " var: pattern_main_trip_30000 init: 0.0 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $300000 - $44999 " var: pattern_main_trip_30000_44999 init: 0.6 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $45000 - $59999 " var: pattern_main_trip_45000_59999 init: 0.2 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $60000 - $99999 " var: pattern_main_trip_60000_99999 init: 1.0 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $100000- $124999 " var: pattern_main_trip_100000_124999 init: 0.3 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $125000 - $149999 " var: pattern_main_trip_125000_149999 init: 0.9 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip $150000 - $199999 " var: pattern_main_trip_150000_199999 init: 1.0 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Importance main trip >$200000 " var: pattern_main_trip_200000 init: 0.3 min: 0.0 max: 1.0 step: 0.1;
	
	parameter "Difficulty Importance main trip <$30000 " var: difficulty_main_trip_30000 init: -0.2 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $300000 - $44999 " var: difficulty_main_trip_30000_44999 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $45000 - $59999 " var: difficulty_main_trip_45000_59999 init: -0.6 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $60000 - $99999 " var: difficulty_main_trip_60000_99999 init: -0.6 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $100000- $124999 " var: difficulty_main_trip_100000_124999 init: -1.0 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $125000 - $149999 " var: difficulty_main_trip_125000_149999 init: -0.3 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip $150000 - $199999 " var: difficulty_main_trip_150000_199999 init: -0.6 min: -1.0 max: 0.0 step: 0.1;
	parameter "Difficulty Importance main trip >$200000 " var: difficulty_main_trip_200000 init: -0.1 min: -1.0 max: 0.0 step: 0.1;
	
	parameter "Price Importance home <$30000 " var: price_home_30000 init: -0.9 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $300000 - $44999 " var: price_home_30000_44999 init: -0.1 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $45000 - $59999 " var: price_home_45000_59999 init: -0.2 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $60000 - $99999 " var: price_home_60000_99999 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $100000- $124999 " var: price_home_100000_124999 init: -0.3 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $125000 - $149999 " var: price_home_125000_149999 init: -0.3  min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home $150000 - $199999 " var: price_home_150000_199999 init: -0.3 min: -1.0 max: 0.0 step: 0.1;
	parameter "Price Importance home >$200000 " var: price_home_200000 init: -0.7 min: -1.0 max: 0.0 step: 0.1;
	
	parameter "Diversity Acceptance home <$30000 " var: diver_home_30000 init: -0.6 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $300000 - $44999 " var: diver_home_30000_44999 init: 0.6 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $45000 - $59999 " var: diver_home_45000_59999 init: 0.6 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $60000 - $99999 " var: diver_home_60000_99999 init: 0.6 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $100000- $124999 " var: diver_home_100000_124999 init: -1.0 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $125000 - $149999 " var: diver_home_125000_149999 init: -0.6 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home $150000 - $199999 " var: diver_home_150000_199999 init: 0.0 min: -1.0 max: 1.0 step: 0.2;
	parameter "Diversity Acceptance home >$200000 " var: diver_home_200000 init: 0.8  min: -1.0 max: 1.0 step: 0.2;
	
	parameter "Preferred zone home <$30000 " var: zone_home_30000 init: 47 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $300000 - $44999 " var: zone_home_30000_44999 init: 11 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $45000 - $59999 " var: zone_home_45000_59999 init: 42 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $60000 - $99999 " var: zone_home_60000_99999 init: 79 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $100000- $124999 " var: zone_home_100000_124999 init: 123 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $125000 - $149999 " var: zone_home_125000_149999 init: 148 min: 0 max: 150 step: 1;
	parameter "Preferred zone home $150000 - $199999 " var: zone_home_150000_199999  init: 5 min: 0 max: 150 step: 1;
	parameter "Preferred zone home >$200000 " var: zone_home_200000 init: 0 min: 0 max: 0 step: 1;
	
	parameter "Pattern Weight home <$30000 " var: pattern_home_30000 init: 0.8 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $300000 - $44999 " var: pattern_home_30000_44999 init: 0.8 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $45000 - $59999 " var: pattern_home_45000_59999 init: 0.8 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $60000 - $99999 " var: pattern_home_60000_99999 init: 0.4 min:0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $100000- $124999 " var: pattern_home_100000_124999 init: 0.9 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $125000 - $149999 " var: pattern_home_125000_149999 init: 0.8  min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home $150000 - $199999 " var: pattern_home_150000_199999 init: 0.0 min: 0.0 max: 1.0 step: 0.1;
	parameter "Pattern Weight home >$200000 " var: pattern_home_200000 init: 0.3 min: 0.0 max: 1.0 step: 0.1;
	
    
   
   //simple objective optimization. Multi-objective optimization has been narrowed down to the minimization of the sum of both errors. simple hill-climbing algorithm has been deployed
    method hill_climbing iter_max: 100 minimize: housingErrorTotal + mobilityError;
    /***method annealing 
    	temp_init: 100 temp_end:1
    	temp_decrease: 0.5 nb_iter_cst_temp: 5
    	minimize: (housingErrorTotal + mobilityError);***/
    /***method reactive_tabu
    	iter_max: 50 tabu_list_size_init: 5 tabu_list_size_min: 2 tabu_list_size_max: 10
    	nb_tests_wthout_col_max: 20 cycle_size_min: 2 cycle_size_max: 20 
        maximize: exhaustive minimize: (housingErrorTotal + mobilityError);***/
    /***method genetic minimize: (housingErrorTotal + mobilityError) 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20; 
    
   ***/
   reflex save_results_explo { //after each iteration the 64 parameters along with the corresponding errors and the amount of people thath would still want to live (expected to approach an asymptote after 4 iterations) have been recorded
        int cpt <- 0;
        int it;
        ask simulations {
        	it <- int(self);
            save [int(self), movingPeople, housingErrorTotal, mobilityError ,price_main_trip_30000, price_main_trip_30000_44999, price_main_trip_45000_59999, price_main_trip_60000_99999, price_main_trip_100000_124999, price_main_trip_125000_149999, price_main_trip_150000_199999, price_main_trip_200000, time_main_trip_30000, time_main_trip_30000_44999, time_main_trip_45000_59999, time_main_trip_60000_99999, time_main_trip_100000_124999, time_main_trip_125000_149999, time_main_trip_150000_199999, time_main_trip_200000, pattern_main_trip_30000, pattern_main_trip_30000_44999, pattern_main_trip_45000_59999, pattern_main_trip_60000_99999, pattern_main_trip_100000_124999, pattern_main_trip_125000_149999, pattern_main_trip_150000_199999, pattern_main_trip_200000, difficulty_main_trip_30000, difficulty_main_trip_30000_44999, difficulty_main_trip_45000_59999, difficulty_main_trip_60000_99999, difficulty_main_trip_100000_124999, difficulty_main_trip_125000_149999, difficulty_main_trip_150000_199999, difficulty_main_trip_200000, price_home_30000, price_home_30000_44999, price_home_45000_59999, price_home_60000_99999, price_home_100000_124999, price_home_125000_149999, price_home_150000_199999, price_home_200000, diver_home_30000, diver_home_30000_44999, diver_home_45000_59999, diver_home_60000_99999, diver_home_100000_124999, diver_home_125000_149999, diver_home_150000_199999, diver_home_200000, zone_home_30000, zone_home_30000_44999, zone_home_45000_59999, zone_home_60000_99999, zone_home_100000_124999, zone_home_125000_149999, zone_home_150000_199999, zone_home_200000, pattern_home_30000, pattern_home_30000_44999, pattern_home_45000_59999, pattern_home_60000_99999, pattern_home_100000_124999, pattern_home_125000_149999, pattern_home_150000_199999, pattern_home_200000] 
                   to: "../results/calibrateData/hillClimbing/parameterValues "+ cpt +".csv" type: "csv" rewrite: (int(self) = 0) ? true : false header: true;      
        	ask people{ //this could be omitted
				save[type, living_place.location.x, living_place.location.y, living_place.associatedBlockGroup.GEOID, activity_place.ID, activity_place.location.x, activity_place.location.y, activity_place.lat, activity_place.long, actualNeighbourhood, actualCity, happyNeighbourhood, mobility_mode_main_activity, time_main_activity_min, distance_main_activity, CommutingCost, living_place.rentNormVacancy, agent_per_point] type:csv to:"../results/calibrateData/hillClimbing/resultingPeopleChoice "+ cpt + it +".csv" rewrite: false header:true;	
			}
			cpt <- cpt + 1;
        }   
    }
}


	
