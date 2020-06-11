/***
* Name: cityScopableHousingChoice
* Author: mireia yurrita
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model cityScopableHousingChoice

global{
	
	file<geometry>buildings_shapefile<-file<geometry>("./../includesCalibration/City/volpe/Buildings.shp");
	file<geometry> roads_shapefile<-file<geometry>("./../includesCalibration/City/volpe/Roads.shp");
	geometry shape<-envelope(roads_shapefile);
	
	
	file calibratedCase <- file("../includesCalibration/Criteria/calibratedDataMLcomm.csv");
	file diversityIncentive <- file("../results/incentivizedScenarios/MLresultsDiversityIncentive.csv");
	file kendallFancyIncentive <- file("../results/incentivizedScenarios/MLresultsKendallFancyIncentive.csv");
	file envFriendlyIncentive <- file("../results/incentivizedScenarios/MLresultsEnvFriendlyIncentive.csv");
	file diversityKendallFancyIncentive <- file("../results/incentivizedScenarios/MLresultsDiversityKendallFancyIncentive.csv");
	file diversityEnvFriendlyIncentive <- file("../results/incentivizedScenarios/MLresultsDiversityEnvFriendlyIncentive.csv");
	file kendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenarios/MLresultsKendallFancyEnvFriendlyIncentive.csv");
	file diversityKendallFancyEnvFriendlyIncentive <- file("../results/incentivizedScenario/MLresultsDiveristyKendallFancyEnvFriendlyIncentive.csv");
	
	//PARAMETERS
	int builtFloors <- 10 parameter: "Built Floors: " category: "Area" min: 0 max: 50 step: 5;
	float devotedResidential <- 0.5 parameter: "Percentage of area for residential use: " category: "Area" min: 0.4 max: 1.0 step: 0.1; //slider
	float subsidyPerc <- 0.0 parameter: "Percentage of subsidy: " category: "Financial incentives " min: 0.0 max: 1.0 step: 0.1; //slider
	bool kendallFancy <- false parameter: "Kendall fanciness incentive " category: "Behavioural incentives ";
	bool diversityAcceptance <- false parameter: "Diversity acceptance incentive " category: "Behavioural incentives ";
	bool environmentallyFriendly <- false parameter: "Environmentally friendly transport promotion " category: "Behavioural incentives ";
	int initPopulation <- 11585 max: 50000 parameter: "Population: " category: "Population";
	
	
	int nbPeopleKendall;
	float builtArea<- 0.0; //if Volpe grid, different floors for each building possible. builtArea is the one to search
	float untilNowInKendall <- 0.0;
	float propInKendall <- 0.0;
	float propProf1;
	float propProf2;
	float propProf3;
	float propProf4;
	float propProf5;
	float propProf6;
	float propProf7;
	float propProf8;
	float mobProp1;
	float mobProp2;
	float mobProp3;
	float mobProp4;
	float mobProp5;
	float meanCommTime;
	float meanCommDist;
	int minRentPrice;
	int maxRentPrice;
	float angle <- atan((899.235 - 862.12)/(1083.42 - 1062.038));
	point startingPoint <- {1025, 1160}; 
	float brickSize <- 21.3;
	list<string> prof_list <- ['<$30,000','$30,000 - $44,999', '$45,000 - $59,999', '$60,000 - $99,999', '$100,000 - $124,999', '$125,000 - $149,999', '$150,000 - $199,999', '>$200,000'];
	map<string> mobility_list <- ['car', 'bus', 'T', 'bike', 'walking'];
	map<string,rgb> mobilityColorMap <- ['car'::#red, 'bus'::#yellow, 'T'::#orange, 'bike'::#blue, 'walking'::#green];
	map<string,float> mobilityMap;
	map<string,float> profileMap;
	map<string,rgb> colorMap;
	map<string,float> rentMap;
	list<string> listProfiles;
	
	init{
		do createBuildings;
		do createRoads;
		do createGrid;
		do normaliseRents;
		do importData;
		do createPopulation;
	}
	
	reflex iterations{
		if (subsidyPerc < 1.0){
			subsidyPerc <- subsidyPerc + 0.2;
			ask building where(each.fromGrid = true){
				rentPrice <- (1-subsidyPerc) * 3400;
			}
		}
		else{
			builtFloors <- builtFloors + 5;
			builtArea <- 0.0;
			subsidyPerc <- 0.0;
			ask building where(each.fromGrid = true){
				nbFloors <- builtFloors; //variable batch experiment
				heightValue <- builtFloors*5;
				builtArea <- builtArea + shape.area*nbFloors*devotedResidential;
				rentPrice <- (1-subsidyPerc)*3400;
			}
		}
		do normaliseRents;
		do importData;
		
		ask people{
			do die;
		}
		do createPopulation;
	}
	
	action createBuildings{
		create building from: buildings_shapefile with:[usage::string(read("Usage")), rentPrice::read("PRICE")]{
			if(usage != "R"){
				rentPrice <- 0.0;
			}
			heightValue <- 15;
			
		}
	}
	
	action normaliseRents{
		maxRentPrice <- max(building collect each.rentPrice);
		minRentPrice <- min(building where(each.usage="R") collect each.rentPrice);
		float geometricMean <- geometric_mean(building collect(each.rentPrice));
		write "geometric mean " + geometricMean;
		ask building where(each.usage="R"){
			do normaliseRentPrice;
		}
	}
	
	action createRoads{
		create road from:roads_shapefile{
			
		}
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
		
		loop i from:1 to: data_matrix.rows - 1{ //provisional. Increase granularity with ML
			float areaValue <- data_matrix[0,i];
			float perMarketPrice <- data_matrix[1,i];
			if ((1 - subsidyPerc) = perMarketPrice){
				minDifferenceNow <- abs(builtArea - areaValue);
				if(minDifferenceNow < minDifferenceUntilNow){
					minDifferenceUntilNow <- minDifferenceNow;
					location <- i;
				}
			}
		}
		untilNowInKendall <- propInKendall;
		propInKendall <- data_matrix[2,location];
		nbPeopleKendall <- int(propInKendall*initPopulation);
		string prof1 <- prof_list[0];
		propProf1 <- data_matrix[3,location];
		string prof2 <- prof_list[1];
		propProf2 <- data_matrix[4,location];
		string prof3 <- prof_list[2];
		propProf3 <- data_matrix[5,location];
		string prof4 <- prof_list[3];
		propProf4 <- data_matrix[6,location];
		string prof5 <- prof_list[4];
		propProf5 <- data_matrix[7,location];
		string prof6 <- prof_list[5];
		propProf6 <- data_matrix[8, location];
		string prof7 <- prof_list[6];
		propProf7 <- data_matrix[9,location];
		string prof8 <- prof_list[7];
		propProf8 <- data_matrix[10,location];
		float lets_see <- propProf1 + propProf2 + propProf3 + propProf4 + propProf5 + propProf6 + propProf7 + propProf8;
		mobProp1 <- data_matrix[11,location];
		string mob1 <- mobility_list[0];
		mobProp2 <- data_matrix[12,location];
		string mob2 <- mobility_list[1];
		mobProp3 <- data_matrix[13,location];
		string mob3 <- mobility_list[2];
		mobProp4 <- data_matrix[14,location];
		string mob4 <- mobility_list[3];
		mobProp5 <- data_matrix[15,location];
		string mob5 <- mobility_list[4];
		mobilityMap <- [mob1::mobProp1, mob2::mobProp2, mob3::mobProp3, mob4::mobProp4, mob5::mobProp5];
		meanCommTime <- data_matrix[16,location];
		meanCommDist <- data_matrix[17,location];
		
		profileMap <- [prof1::propProf1, prof2::propProf2, prof3::propProf3, prof4::propProf4, prof5::propProf5, prof6::propProf6, prof7::propProf7, prof8::propProf8];
		
	}
	
	action createPopulation{
		create people number: int(nbPeopleKendall/2){
			type <- profileMap.keys[rnd_choice(profileMap.values)];
			float maxRentProf <- rentMap[type];
			livingPlace <- one_of(building where(each.usage = "R"));
			//livingPlace <- one_of(building where (each.usage = "R" and each.rentPrice <= maxRentProf*maxRentPrice));
			/***if (empty(livingPlace) = true){
				livingPlace <- one_of(building where(each.usage = "R"));
			}***/
			location <- any_location_in(livingPlace);
			/***if (self overlaps livingPlace = false){
				do die;
			}***/
			mobilityMode <- mobilityMap.keys[rnd_choice(mobilityMap.values)];
			color <- colorMap[type];
		}
	}
		
	action createGrid{
		angle <- angle / 2;
		float acum_area <- 0.0;
		//write startingPoint;
		startingPoint <- {startingPoint.x - brickSize / 2, startingPoint.y - brickSize / 2};
		//write startingPoint;				
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
					create building{
						fromGrid <- true;
						int x <- j;
						int y <- i;
						point location_local_axes <- {x * brickSize + 15, y * brickSize};
						location <- {startingPoint.x + location_local_axes.x*sin(angle) - location_local_axes.y*cos(angle), startingPoint.y - location_local_axes.y*sin(angle) - location_local_axes.x*cos(angle)};
						shape <- square(brickSize * 0.9) at_location location;
						usage <- "R";
						//scale <- "microUnit";
						nbFloors <- builtFloors; //variable batch experiment
						heightValue <- builtFloors*5;
						builtArea <- builtArea + shape.area*nbFloors*devotedResidential;
						rentPrice <- (1-subsidyPerc)*3400;
						//write "calc builtArea " + builtArea;
					}				
				}
			}	
		}
	}

}

	


species building{
	int nbFloors;
	string usage;
	int rentPrice;
	float normalisedRentPrice;
	bool fromGrid <- false;
	float heightValue;
	
	action normaliseRentPrice{
		normalisedRentPrice <- (rentPrice - minRentPrice)/(maxRentPrice - minRentPrice);
	}
	
	aspect default{
		if(fromGrid = true){
			draw shape rotated_by angle color: rgb(50,50,50) depth:heightValue;
		}
		else{
			draw shape color: rgb(50,50,50) depth: heightValue;	
		}
	}
}


species road{
	aspect default{
		draw shape color: #grey;
	}
}

species people{
	string type;
	rgb color;
	string mobilityMode;
	building livingPlace;
	building targetPlace;
	
	aspect default{
		draw circle(10) at_location {location.x,location.y,livingPlace.heightValue} color:color ;
	}
}


experiment visual type:gui{

	output{
		display map type: opengl draw_env: false  autosave: false background: #black 
			{
			species building aspect: default;
			species road;
			species people aspect: default;
	
			overlay position: { 5, 5 } size: { 240 #px, 270 #px } background: rgb(50,50,50,125) transparency: 1.0 border: #black 
		        {            	
		            rgb text_color<-#white;
		            float y <- 30#px;
		            float x <- world.shape.height*1.75;
		            draw "Icons" at: { 40#px, y } color: text_color font: font("Helvetica", 20, #bold) perspective:false;
		            y <- y + 30#px;
		            
		            loop i from: 0 to: length(listProfiles) - 1 {
		            	draw square(10#px) at: {20#px, y} color:colorMap[listProfiles[i]] border: #white;
		            	draw string(listProfiles[i]) at: {40#px, y + 4#px} color: text_color font: font("Helvetica",16,#plain) perspective: false;
		            	y <- y + 25#px;
		            } 
		            y <- y + 100#px;
		            draw "INPUT: " at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw "BuiltArea: " +  string(builtArea with_precision 2) + " m2" at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw rectangle(builtArea/1000#px,10#px) at: {40#px+builtArea/2/1000#px, y} color:#white border: #white;
		            y <- y + 50#px;
		            draw "Percentage of subsidy: " + string(int(subsidyPerc*100)) + " %" at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw rectangle(int(subsidyPerc*250)#px,10#px) at: {40#px+int(subsidyPerc*250/2)#px, y} color:#white border: #white;
		            y <- y + 100#px;
		            draw "OUTPUT: " at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw "Percentage of people working and living in Kendall: " + string(int(propInKendall*100) ) + " %" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50 #px;    
		            draw rectangle(int(propInKendall*250)#px,10#px) at: {40#px+int(propInKendall*250/2)#px, y} color:#white border: #white;
		            y <- y + 50#px;
		            draw "Mean Commuting Distance: " + string(meanCommDist with_precision 2) + " m" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		                       
		          
		            draw "Mean Commuting Time: " + string(meanCommTime with_precision 2) + " min" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            
		           
		            
		            
		    	}
		    	
		    	chart "Mobility Modes" background:#black  type: pie size: {0.5,0.5} position: {world.shape.width*0.7,world.shape.height*0.7} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
				tick_font: 'Helvetica' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Helvetica' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
				{
					loop i from: 0 to: length(mobilityMap.keys)-1	{
					  data mobilityMap.keys[i] value: mobilityMap.values[i] color:mobilityColorMap[mobilityMap.keys[i]];
					}
				}	    	
		    	
	    	}
	    	
		}    
}


