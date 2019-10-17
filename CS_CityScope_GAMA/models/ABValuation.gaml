/***
* Name: ABValuation
* Author: crisjf
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model ABValuation

global{
	// Model mode
	bool updateUnitSize<-true;
	bool modeCar <- false;	
	
	// Grid parameters
	int grid_width<-16;
	int grid_height<-16;
	float cell_width<-100.0/grid_width;
	float cell_height<-100.0/grid_height;
	
	int firm_pos_1 <- int(2.0*grid_width/5.0-1.0);
	int firm_pos_2 <- int(3.0*grid_height/5.0);
	
	// Global model parameters
	float rentFarm<- 5.0;
	float buildingSizeGlobal <- 1.2;
	int unitsPerBuilding <- 5; 
	float globalWage <-1.0;
	float wageRatio<-7.0;
	float commutingCost <- 0.35;
	float commutingCostCar <- 0.3;
	float commutingCostCarFixed <- 0.5;
	float landUtilityParameter <- 10.0;
	
	int nAgents <- int(0.95*(unitsPerBuilding)*((grid_width+1)*(grid_height+1)-1));
	
	// Update parameters (non-equilibrium)
	float rentSplit<- 0.75;
	float rentDelta <- 0.05;
	float sizeDelta <- 0.05;
	float randomMoveRate <- 0.001;
	
	// Display parameters
	bool controlBool;
	string firmTypeToAdd<-'low';
	
	rgb servicesColor<-rgb('#a50f15');
	rgb manufactoringColor<-rgb('#fc9272');
	
	action change_color 
	{
		write "change color";
	}
	
	reflex update_pop {
//		loop while: (length(worker)<nAgents) {
////			Create people
//		}
//		if (length(worker)<nAgents) {
////			Create people
//		}
	}
	
	action create_firm {
		building toKill<- (building closest_to(#user_location));
		create firm {
			myCity<-one_of(city);
			shape<-square(0.95*cell_width);
			myType<-firmTypeToAdd;
			wage<-wageRatio*globalWage;	
			location <- toKill.location;
			nbWorkers<-0;
			write location;
		}
		ask worker {
			if (myBuilding=toKill) {
				do forceBuildingUpdate;				
			}
		}
		ask toKill {
			do die;
		}
	}

	init{
		write "Number of units " +unitsPerBuilding*((grid_width+1)*(grid_height+1)-2);
		write "Number of workers "+nAgents;
		create city {
			maxRent<-rentFarm;
		}
		
		int i<-0;
		int j<-0;
		create building number:((grid_width+1)*(grid_height+1)-2){
			myCity<-one_of(city);
			shape<-square(0.95*cell_width);
			
			rent <- rentFarm;
			buildingSize <- buildingSizeGlobal;
			vacant <- buildingSizeGlobal;
			unitSize <- buildingSizeGlobal/float(unitsPerBuilding);
			
			location <- {cell_width*i,cell_height*j};
			i<-((i+1) mod (grid_width+1));			
			if (i=0) {
				j<-j+1;
			}
			if (i=firm_pos_1 and j=firm_pos_1) {
				i<-((i+1) mod (grid_width+1));
			}
			if (i=firm_pos_2 and j=firm_pos_2) {
				i<-((i+1) mod (grid_width+1));
			}
			
		}
		
		i<-0;
		create firm number:2{
			myCity<-one_of(city);
			shape<-square(0.95*cell_width);
			if (i=0){
				myType<-'low';
				wage<-globalWage;
				location <- {cell_width*firm_pos_1,cell_height*firm_pos_1};
			} else {
				myType<-'high';
				wage<-wageRatio*globalWage;	
				location <- {cell_width*firm_pos_2,cell_height*firm_pos_2};
			}
			i<-i+1;
			nbWorkers<-0;
		}
		
		create worker number:nAgents {
			myFirm <- one_of(firm);
			myFirm.nbWorkers <- myFirm.nbWorkers+1;
			
			list<building> possibleBuildings<-(building where (each.vacant>0));
			
			if (length(possibleBuildings)!=0) {
				myBuilding <- one_of(possibleBuildings);
				myBuilding.vacant <- myBuilding.vacant-myBuilding.unitSize;
			} else {
				
			}
			location <- any_location_in(myBuilding);
		}
		
		ask one_of(city) {
			do updateCityParams;
		}
			
	}
	
}

species city {
	float maxRent;
	float maxDensity;
	float maxWage;
	float maxSupportedDensity;
	
	action updateCityParams{
		maxRent <- max(building collect each.rent);
		maxDensity <- max(building collect each.density);
		maxSupportedDensity <- max(building collect each.supportedDensity);
		maxWage <- max(firm collect each.wage);
	}
	
	reflex update{
		do updateCityParams;
	}
}

species firm{
	int nbWorkers;
	string myType;
	float wage;
	city myCity;

	aspect base{
		draw shape color:#blue;
	}
	
	reflex updateWage {
		if (myType='high') {
			wage <- wageRatio*globalWage;
		} else {
			wage <- globalWage;
		}
	}
	
	aspect threeD {
		if (myType='high') {
			color <- servicesColor;
		} else {
			color <- manufactoringColor;
		}
		draw shape color: color depth: 20;
	}
}

species building {
	city myCity;
	float buildingSize;
	
	float rent;
	float unitSize;
	float vacant;
	
	float density;
	float supportedDensity;
	float heightValue;
	
	reflex lowerRent {  
		if (vacant>=unitSize) {
			rent <- rent-rentDelta*rent;
			if (rent<rentFarm){
				rent <-rentFarm;
			}
		} 
		if (rent<rentFarm){
			rent <-rentFarm;
		}
	}
	
	reflex raiseUnitSize when: (updateUnitSize=true) {
		float newUnitSize;
		newUnitSize <- (1.0+sizeDelta)*unitSize;
		if (vacant>=(1.0+sizeDelta)*(buildingSize-vacant) and newUnitSize<=buildingSize) {
			vacant <- buildingSize-(1.0+sizeDelta)*(buildingSize-vacant); 
			unitSize <- newUnitSize;
		}
	}
	
	reflex updateParameters {
		density <- float(int((buildingSize-vacant)/(unitSize)));
		if (density<0) {
			density<-0.0;
		}
		
		supportedDensity <- buildingSize/unitSize;
		if (supportedDensity=0) {
			heightValue<-0.0;
		} else {
			heightValue<-supportedDensity;
		}
		heightValue<-0.3*heightValue;
		
	}

	aspect rent_aspect {
		int colorValue <- int(220-220*rent/myCity.maxRent);
		draw shape color: rgb(colorValue,colorValue,colorValue);
	}
	
	aspect rent_log_aspect {
		int colorValue <- int(220-220*log(rent)/log(myCity.maxRent));
		draw shape color: rgb(colorValue,colorValue,colorValue);
	}
	
	aspect density_aspect {
		int colorValue <- int(220-220*density/myCity.maxDensity);
		draw shape color: rgb(colorValue,colorValue,colorValue);
	}
	
	aspect threeD {
		int colorValue <- int(220-220*log(rent+1.0)/log(myCity.maxRent+1.0));
		if (colorValue<=10) {
			colorValue<-0;
		}
    	draw shape color: rgb(colorValue,colorValue,colorValue) depth: heightValue;
    }
	
	aspect base{
		draw shape color:#gray;
	}
}

species worker {
	building myBuilding;
	firm myFirm;
	bool useCar;
	float currentUtility;
	

	float myUtility (building referenceBuilding, firm referenceFirm, bool useCarLocal, float myUnitSize<-nil) {
		float utility;
		float workDistance <- (referenceBuilding distance_to referenceFirm);
		if (myUnitSize=nil){
			utility <- referenceFirm.wage - commutingValue(workDistance,useCarLocal) - referenceBuilding.rent * referenceBuilding.unitSize + landUtilityParameter * log(referenceBuilding.unitSize);
		} else {
			utility <- referenceFirm.wage - commutingValue(workDistance,useCarLocal) - referenceBuilding.rent * myUnitSize + landUtilityParameter * log(myUnitSize);
		}
		return utility;
	}
	
	float commutingValue (float distance, bool useCarLocal) {
		float outValue;
		if (modeCar=true) {
			if (useCarLocal=false){
				outValue <- commutingCost*distance;
			} else {
				outValue <- commutingCostCarFixed+commutingCostCar*distance;
			}
		} else {
			outValue <- commutingCost*distance;
		}
		return outValue; 
	}
	
	action forceBuildingUpdate {
		bool updateSuccess<-false;
		building newBuilding;
		
		loop while: (updateSuccess=false) {
			newBuilding <- one_of(building);
			if (newBuilding!=myBuilding) {
				if (newBuilding.vacant>=newBuilding.unitSize) {
					myBuilding.vacant <- myBuilding.vacant + myBuilding.unitSize;
					newBuilding.vacant <- newBuilding.vacant - newBuilding.unitSize;
					myBuilding <- newBuilding;
					location <- any_location_in(myBuilding);
					updateSuccess<-true;
				}
			} 
		}
	}
		
	action attemptFirmUpdate (firm newFirm) {
		myFirm.nbWorkers<-myFirm.nbWorkers-1;
		newFirm.nbWorkers<-newFirm.nbWorkers+1;
		myFirm <- newFirm;
	}
	
	action attemptBuildingUpdate (building newBuilding, float utilityChange<-0.0) {
		if (newBuilding.vacant<newBuilding.unitSize) {
			if (utilityChange!=0) {
				newBuilding.rent <- newBuilding.rent + rentSplit * utilityChange/newBuilding.unitSize;
			}
		} else {
			myBuilding.vacant <- myBuilding.vacant + myBuilding.unitSize;
			newBuilding.vacant <- newBuilding.vacant - newBuilding.unitSize;
			myBuilding <- newBuilding;
			location <- any_location_in(myBuilding);
		}
	}
	
	reflex updateUtility {
		float utility<-myUtility(myBuilding,myFirm,useCar);
		currentUtility<-utility;
	}
	
	reflex updateCommutingMode {
		float utilityCar<-myUtility(myBuilding,myFirm,true);
		float utilityNoCar<-myUtility(myBuilding,myFirm,false);
		if (utilityCar>utilityNoCar){
			useCar<-true;
		} else {
			useCar<-false;
		}
	}
	
	reflex updateBuilding {
		float utility <- myUtility(myBuilding,myFirm,useCar);
		building possibleBuilding <- one_of(building);

		float possibleUtility <- myUtility(possibleBuilding,myFirm,useCar);
		float utilityChange <- possibleUtility-utility;
		
		if (utilityChange>0.0){
			do attemptBuildingUpdate(possibleBuilding, utilityChange);
		}
	}
	
	reflex updateWork {		
		float utility <- myUtility(myBuilding,myFirm,useCar);
		firm possibleFirm <- one_of(firm);
		float possibleUtility<- myUtility(myBuilding,possibleFirm,useCar);
		if (possibleUtility>utility){
			do attemptFirmUpdate(possibleFirm);
		}
	}
	
	reflex updateBuildingRandom {
		if (rnd(1.0)<randomMoveRate) {
			building possibleBuilding <- one_of(building);
			do attemptBuildingUpdate(possibleBuilding);
		}
	}
	
	reflex updateWorkRandom {
		if (rnd(1.0)<randomMoveRate) {
			firm possibleFirm;
			possibleFirm <- one_of(firm);
			do attemptFirmUpdate(possibleFirm);
		}
	}
	
	reflex updateUnitSize when: (updateUnitSize=true) {
		float utility;		
		float newUnitSizem;
		float newUnitSizep;
		float possibleUtilitym;
		float possibleUtilityp;
		bool updateFlag<-true;
		
		loop while: (updateFlag=true) {
			updateFlag<-false;
			
			utility <- myUtility(myBuilding,myFirm,useCar);
			newUnitSizem <- (1.0-sizeDelta)*myBuilding.unitSize;
			newUnitSizep <- (1.0+sizeDelta)*myBuilding.unitSize;
			
			possibleUtilitym <- myUtility(myBuilding,myFirm,useCar,newUnitSizem);
			possibleUtilityp <- myUtility(myBuilding,myFirm,useCar,newUnitSizep);
			
			if (possibleUtilityp>utility and myBuilding.vacant>=(1.0+sizeDelta)*(myBuilding.buildingSize-myBuilding.vacant) and newUnitSizep<=myBuilding.buildingSize) {
				myBuilding.vacant <- myBuilding.buildingSize-(1.0+sizeDelta)*(myBuilding.buildingSize-myBuilding.vacant); 
				myBuilding.unitSize <- newUnitSizep;
				updateFlag<-true;
			} else {
				if (possibleUtilitym>utility) {
					myBuilding.vacant <- myBuilding.buildingSize-(1.0-sizeDelta)*(myBuilding.buildingSize-myBuilding.vacant); 
					myBuilding.unitSize <- newUnitSizem;
					updateFlag<-true;
				}
			}
			updateFlag<-false; // Force exit
		}
	}
	
	aspect threeD {
		int colorValue <- int(30+220*myFirm.wage/myFirm.myCity.maxWage);
		draw sphere(1.0) color: rgb(0,0,colorValue);
	}
	
	aspect base{
		draw circle(0.25) color:#green;					
	}
	
	aspect wage_aspect {
		if (myFirm.myType='high') {
			color<-rgb('#08519c');
		} else {
			color<-rgb('#6baed6');
		}
		draw circle(0.25) color: color;
	}
	
	aspect threeD {
		if (myFirm.myType='high') {
			color<-rgb('#08519c');
		} else {
			color<-rgb('#6baed6');
		}
		draw cylinder(0.1,0.5) at_location {location.x,location.y,rnd(myBuilding.heightValue)} color: color;	
		//draw sphere(0.2) at_location {location.x,location.y,rnd(myBuilding.heightValue)} color: color;
	}
	
}

grid cell width: grid_width height: grid_height {
	aspect dark_aspect {
		draw shape color: #black;
	}
}

experiment ABValuationDemo type: gui autorun:true{
	parameter "Commuting cost" var: commutingCost min: 0.0 max: 1.0 step: 0.05; 
	output { 
		display map_3D  type:opengl background: #black draw_env: false  toolbar:false fullscreen:1
		camera_pos: {-31.3849,154.8123,60.965} camera_look_pos: {39.7081,49.4125,-9.5042} camera_up_vector: {0.2711,0.4019,0.8746}
		//camera_interaction:false
		{
			species cell aspect: dark_aspect;			
			species worker aspect:threeD;
			species building aspect:threeD transparency: 0.5;
			species firm aspect: threeD transparency: 0.5;
			
			event "e" action: {controlBool <- !controlBool;}; //<- Do this in the aspect (aspect++ will allow you to show aspects)

			event mouse_down action: create_firm;
			event "p" action: {if(commutingCost<1){commutingCost<-commutingCost+0.1;}};
			event "m" action: {if(commutingCost>0){commutingCost<-commutingCost-0.1;}};
			event "h" action: {firmTypeToAdd<-'high';};
			event "l" action: {firmTypeToAdd<-'low';};
			event "s" action: {updateUnitSize<-!updateUnitSize;};
						
			overlay position: { 5, 5 } size: { 180 #px, 100 #px } background: # black transparency: 0.5 border: #black rounded: true
            {   
            	
            	draw string("MULTI EMPLOYER HOUSING MARKET SIMULATION") at: { 10#px, 20#px } color: #white font: font("SansSerif", "bold" ,72);
            	
            	float y <- 150#px;
            	draw string("Population (Income)") at: { 10#px, y-20#px } color: #white font: font("SansSerif", "bold" ,32);
                draw circle(10#px) at: { 20#px, y } color: rgb('#08519c') border: rgb('#08519c')-25;
                draw string("High") at: { 40#px, y + 4#px } color: #white font: font("SansSerif","plain", 18);
                y <- y + 25#px;
                draw circle(10#px) at: { 20#px, y } color: rgb('#6baed6') border: rgb('#6baed6')-25;
                draw string("Medium") at: { 40#px, y + 4#px } color: #white font: font("SansSerif", 18);
                y <- y + 25#px;
                draw string("Employement (Sector)") at: { 10#px, y } color: #white font: font("SansSerif", "bold" ,32);
                y <- y + 25#px;
                draw square(20#px) at: { 20#px, y } color: servicesColor border: servicesColor-25;
                draw string("Services") at: { 40#px, y + 4#px } color: #white font: font("SansSerif", 18);
                y <- y + 25#px;
                draw square(20#px) at: { 20#px, y } color: manufactoringColor border: manufactoringColor-25;
                draw string("Manufacturing") at: { 40#px, y + 4#px } color: #white font: font("SansSerif", 18);
                
                y <- y + 25#px;
                draw string("Housing (Cost)") at: { 10#px, y } color: #white font: font("SansSerif", "bold" ,32);
                y <- y + 25#px;
                draw square(20#px) at: { 20#px, y } color: rgb(50,50,50) border: rgb(50,50,50)-25;
                draw string("High") at: { 40#px, y + 4#px } color: #white font: font("SansSerif", 18);  
                
                y <- y + 25#px;
                draw square(20#px) at: { 20#px, y } color: #lightgray border: #lightgray-25;
                draw string("Low") at: { 40#px, y + 4#px } color: #white font: font("SansSerif", 18); 
                
                y <- y + 100#px;
                draw string("Comutting Cost") at: { 20#px, y + 4#px } color: #white font: font("SansSerif", 32);
                y <- y + 25#px;
                draw rectangle(200#px,2#px) at: { 50#px, y } color: #white;
                draw rectangle(2#px,10#px) at: { commutingCost*100#px, y } color: #white;

                y <- y + 25#px;
                draw string("Inequality") at: { 20#px, y + 4#px } color: #white font: font("SansSerif", 32);
                y <- y + 25#px;
                draw rectangle(200#px,2#px) at: { 50#px, y } color: #white;
                draw rectangle(2#px,10#px) at: { commutingCost*100#px, y } color: #white;
                
                y <- y + 25#px;
                float x<-0#px;
                draw string("Housing Supply: Fixed/Dynamic") at: { 20#px + x , y + 4#px } color: #white font: font("SansSerif", 32);
                  
            }
		}
		/*display map_2D  type:opengl background: #black draw_env: false fullscreen:1 toolbar:false
		{
			species cell aspect: dark_aspect;			
			species worker aspect:threeD;
			species building aspect:threeD transparency: 0.5;
			species firm aspect: threeD transparency: 0.5;
			
			event "e" action: {controlBool <- !controlBool;}; //<- Do this in the aspect (aspect++ will allow you to show aspects)

			event mouse_down action: create_firm;
			event "p" action: {if(commutingCost<1){commutingCost<-commutingCost+0.1;}};
			event "m" action: {if(commutingCost>0){commutingCost<-commutingCost-0.1;}};
			event "h" action: {firmTypeToAdd<-'high';};
			event "l" action: {firmTypeToAdd<-'low';};
			event "s" action: {updateUnitSize<-!updateUnitSize;};
		}*/
	}
	
}