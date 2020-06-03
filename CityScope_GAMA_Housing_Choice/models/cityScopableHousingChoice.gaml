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
	
	file utopianCase <- file("../includesCalibration/Criteria/syntheticDataMLcomm.csv");
	file calibratedCase <- file("../includesCalibration/Criteria/calibratedDataMLcomm.csv");
	
	//PARAMETERS
	//int builtFloors <- 10 parameter: "Built Floors: " category: "Area" min: 0 max: 50 step: 5;
	int builtFloors <- 10;
	//int caseStudy <- 0 parameter: "Case Study: " category: "Calibrated vs Utopian" min: 0 max: 1; //0: calibrated 1: utopian
	int caseStudy <- 0;
	//float devotedResidential <- 0.5 parameter: "Percentage of area for residential use: " category: "Area" min: 0.4 max: 1.0 step: 0.1; //slider
	float devotedResidential <- 0.5;
	//float subsidyPerc <- 0.0 parameter: "Percentage of subsidy: " category: "Subsidy" min: 0.0 max: 1.0 step: 0.1; //slider
	float subsidyPerc <- 0.0;
	//int initPopulation <- 11585 max: 50000 parameter: "Population: " category: "Population";
	int initPopulation <- 11585;
	
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
	float carProp;
	float busProp;
	float TProp;
	float bikeProp;
	float walkingProp;
	float meanCommTime;
	float meanCommDist;
	int minRentPrice;
	int maxRentPrice;
	float angle <- atan((899.235 - 862.12)/(1083.42 - 1062.038));
	//point startingPoint <- {1030.86, 1157.84}; 
	point startingPoint <- {1025, 1160}; 
	float brickSize <- 21.3;
	
	map<string,float> mobilityMap;
	map<string,rgb> mobilityColorMap;
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
		if (caseStudy = 0){
			 data_matrix<-matrix(calibratedCase);
		}
		if (caseStudy = 1){
			 data_matrix<-matrix(utopianCase);
		}
		
		float minDifferenceUntilNow <- 10000000000.0;
		float minDifferenceNow <- 0.0;
		int location <- 0;
		//write "primer elem " + data_matrix[0,1];
		write "builtArea " + builtArea;
		write "subsidy percentage " + subsidyPerc;
		
		loop i from:1 to: data_matrix.rows - 1{ //provisional. Increase granularity with ML
			float areaValue <- data_matrix[0,i];
			float perMarketPrice <- data_matrix[1,i];
			if ((1 - subsidyPerc) = perMarketPrice){
				//write "Ha entrao "; 
				//write "builtArea " + builtArea;
				//write "areaValue " + areaValue;
				//write "perMarketPrice " + perMarketPrice;
				minDifferenceNow <- abs(builtArea - areaValue);
				//write "minDifferenceNow " + minDifferenceNow;
				//write "minDifferenceUntilNow " + minDifferenceUntilNow;
				if(minDifferenceNow < minDifferenceUntilNow){
					minDifferenceUntilNow <- minDifferenceNow;
					location <- i;
				}
			}
		}
		write "min difference " + minDifferenceNow;
		write "location " + location;
		write "area value matrix " + data_matrix[0,location];
		untilNowInKendall <- propInKendall;
		write "prop i-1 in Kendall " + untilNowInKendall;
		propInKendall <- data_matrix[2,location];
		nbPeopleKendall <- int(propInKendall*initPopulation);
		propProf1 <- data_matrix[3,location];
		propProf2 <- data_matrix[4,location];
		propProf3 <- data_matrix[5,location];
		propProf4 <- data_matrix[6,location];
		propProf5 <- data_matrix[7,location];
		propProf6 <- data_matrix[8, location];
		propProf7 <- data_matrix[9,location];
		propProf8 <- data_matrix[10,location];
		float lets_see <- propProf1 + propProf2 + propProf3 + propProf4 + propProf5 + propProf6 + propProf7 + propProf8;
		carProp <- data_matrix[11,location];
		busProp <- data_matrix[12,location];
		TProp <- data_matrix[13,location];
		bikeProp <- data_matrix[14,location];
		walkingProp <- data_matrix[15,location];
		meanCommTime <- data_matrix[16,location];
		meanCommDist <- data_matrix[17,location];
		
		profileMap <- ['<$30,000'::propProf1, '$30,000 - $44,999'::propProf2, '$45,000 - $59,999'::propProf3, '$60,000 - $99,999'::propProf4, '$100,000 - $124,999'::propProf5, '$125,000 - $149,999'::propProf6, '$150,000 - $199,999'::propProf7, '>$200,000'::propProf8];
		write "profileMap " + profileMap;
		mobilityMap <- ['car'::carProp, 'bus'::busProp, 'T'::TProp, 'bike'::bikeProp, 'walking'::walkingProp];
		mobilityColorMap <- ['car'::#red, 'bus'::#yellow, 'T'::#orange, 'bike'::#blue, 'walking'::#green];
		write "mobilityMap " + mobilityMap;
		write "meanCommTime " + meanCommTime;
		write "meanCommDist " + meanCommDist;
		write "propPeopleKendall " + propInKendall;
		write "propPeopleInKendall sum " + lets_see;
		colorMap <- ['<$30,000'::#yellow, '$30,000 - $44,999'::#blue, '$45,000 - $59,999'::#green, '$60,000 - $99,999'::#cyan, '$100,000 - $124,999'::#orange, '$125,000 - $149,999'::#red, '$150,000 - $199,999'::#pink, '>$200,000'::#purple];
		rentMap <- ['<$30,000'::0.7, '$30,000 - $44,999'::0.7, '$45,000 - $59,999'::0.8, '$60,000 - $99,999'::0.8, '$100,000 - $124,999'::0.9, '$125,000 - $149,999'::0.9, '$150,000 - $199,999'::1.0, '>$200,000'::1.0];
		listProfiles <-  ['<$30,000', '$30,000 - $44,999', '$45,000 - $59,999', '$60,000 - $99,999', '$100,000 - $124,999', '$125,000 - $149,999', '$150,000 - $199,999','>$200,000'];
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
		            //draw string(builtArea with_precision 2) + " m2" at: {x, y + 4#px} color: text_color font: font("Helvetica",100,#plain) perspective: false;
		            //y <- y + 50#px;
		            draw "Percentage of subsidy: " + string(int(subsidyPerc*100)) + " %" at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw rectangle(int(subsidyPerc*250)#px,10#px) at: {40#px+int(subsidyPerc*250/2)#px, y} color:#white border: #white;
		            y <- y + 100#px;
		            draw "OUTPUT: " at:{40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50#px;
		            draw "Percentage of people working and living in Kendall: " + string(int(propInKendall*100) ) + " %" at: {40#px, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            y <- y + 50 #px;    
		            draw rectangle(int(propInKendall*250)#px,10#px) at: {40#px+int(propInKendall*250/2)#px, y} color:#white border: #white;
		            y <- y - 200#px;
		            
		            
		            //draw "OUPUT: " at:{x, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            //y<- y + 50#px;
		            //draw string(subsidyPerc*100 with_precision 0) + " %" at:{x, y + 4#px} color: text_color font: font("Helvetica",100,#plain) perspective: false;
		            //y <- y + 50#px;
		            //draw "Percentage of people working and living in Kendall: " + string(int(propInKendall*100) ) + " %" at: {x, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            //y <- y + 50 #px;    
		            //draw string(int(propInKendall*100) ) + " %" at: {x, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            
		            //y <- y + 50 #px;    
		            //draw "Mean Commuting Distance: " + string(meanCommDist with_precision 2) + " m" at: {x, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            //y <- y + 50#px;
		            //draw string(meanCommDist with_precision 2) + " m" at: {x, y + 4#px} color: text_color font: font("Helvetica",100,#plain) perspective: false;
		            //y <- y + 50#px;             
		          
		            //draw "Mean Commuting Time: " + string(meanCommTime with_precision 2) + " min" at: {x, y + 4#px} color: text_color font: font("Helvetica",25,#plain) perspective: false;
		            //y <- y + 50#px;
		            //draw string(meanCommTime with_precision 2) + " min" at: {x, y + 4#px} color: text_color font: font("Helvetica",100,#plain) perspective: false;
		            
		             //y <- y - 250#px;
		           
		            
		            
		    	}
		    	
		    	chart "Mean Commuting Time [min]" background: #black type: series size: {0.5,0.5} position: {world.shape.width*1,world.shape.height*0.05} color: #white axes: #white title_font: 'Helvetica' title_font_size: 12.0{
		    		data "Mean Commuting Time" value:meanCommTime color:#blue;
		    	}
		    	
		    	/***chart "Mean Commuting Time" background: #black type: series size: {0.5,0.5} position: {world.shape.width*1.2,world.shape.height*0.35} color: #white axes: #white title_font: 'Helvetica' title_font_size: 12.0{
		    		data "Mean Commuting Time" value:meanCommDist color:#blue;
		    	}***/
		    	
		    	chart "Mobility Modes" background:#black  type: pie size: {0.5,0.5} position: {world.shape.width*1,world.shape.height*0.7} color: #white axes: #yellow title_font: 'Helvetica' title_font_size: 12.0 
				tick_font: 'Helvetica' tick_font_size: 10 tick_font_style: 'bold' label_font: 'Helvetica' label_font_size: 32 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
				{
					loop i from: 0 to: length(mobilityMap.keys)-1	{
					  data mobilityMap.keys[i] value: mobilityMap.values[i] color:mobilityColorMap[mobilityMap.keys[i]];
					}
				}	    	
		    	
	    	}
	    	
		}    
}


