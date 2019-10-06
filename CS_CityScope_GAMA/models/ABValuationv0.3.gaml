/***
* Name: ABValuationv02
* Author: crisjf
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model ABValuationv03

global{
	// Grid parameters
	int grid_width<-20;
	int grid_height<-20;
	float cell_width<-100.0/grid_width;
	float cell_height<-100.0/grid_height;
	
	int firm_pos_1 <- int(2.0*grid_width/5.0);
	int firm_pos_2 <- int(3.0*grid_height/5.0);
	
	// Global model parameters
	float rentFarm<- 5.0;
	float buildingSizeGlobal <- 1.2;
	int unitsPerBuilding <- 10; 
	float globalWage <-1.0;
	float wageRatio<-7.0;
	float commutingCost <- 0.35;
	float commutingCostCar <- 0.3;
	float commutingCostCarFixed <- 0.5;
	float landUtilityParameter <- 10.0;
	float globalWage1<-globalWage;
	float globalWage2<-wageRatio*globalWage;
	
	int nAgents <- int(0.95*(unitsPerBuilding)*((grid_width+1)*(grid_height+1)-1));
	
	// Update parameters (non-equilibrium)
	float rentSplit<- 0.75;
	float rentDelta <- 0.05;
	float sizeDelta <- 0.05;
	float randomMoveRate <- 0.001;
		
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
				wage<-globalWage1;
				location <- {cell_width*firm_pos_1,cell_height*firm_pos_1};
			} else {
				wage<-globalWage2;
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
	
	action updateCityParams{
		maxRent <- max(building collect each.rent);
		maxDensity <- max(building collect each.density);
		maxWage <- max(firm collect each.wage);
	}
	
	reflex update{
		do updateCityParams;
	}
}

species firm{
	int nbWorkers;
	float wage;
	city myCity;

	aspect base{
		draw shape color:#blue;
	}
	
	aspect wage_aspect {
		int colorValue <- int(30+220*wage/myCity.maxWage);
		draw shape color: rgb(0,0,colorValue);
	}
}

species building {
	city myCity;
	float buildingSize;
	
	float rent;
	float unitSize;
	float vacant;
	
	float density;
	
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
	
	reflex raiseUnitSize {
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
	}

//	reflex updateUnitSize {
//		list<worker> myWorkers <- (worker where (each.myBuilding=self));
//		if length(myWorkers)!=0 {
//			worker myWorker <- one_of(myWorkers);
//			ask myWorker{
//				do updateUnitSize;
//			}
//		} 
//	}

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
		int colorValue <- int(255*(rent-rentFarm)/(myCity.maxRent-rentFarm));
		float heightValue;
		if (density=0) {
			heightValue<-0.0;
		} else {
			heightValue<-density;
		}
		heightValue<-0.3*heightValue;
		if (colorValue<=10) {
			colorValue<-0;
		}
    	draw shape color: rgb(colorValue,0,0) depth: heightValue;
    }
	
	aspect base{
		draw shape color:#gray;
	}
}

species worker {
	building myBuilding;
	firm myFirm;
	bool useCar;
	
	float myUtility (building referenceBuilding, firm referenceFirm, bool useCarLocal, float myUnitSize<-nil) {
		float utility; // BUG: The referenceBuilding, referenceFirm, and useCarLocal should have a default value.
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
		if (useCarLocal=false){
			outValue <- commutingCost*distance;
		} else {
			outValue <- commutingCostCarFixed+commutingCostCar*distance;
		}
		return outValue; 
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
	
	reflex updateUnitSize {
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
		draw circle(0.5) color:#green;					
	}
	
	aspect wage_aspect {
		int colorValue <- int(30+220*myFirm.wage/myFirm.myCity.maxWage);
		draw circle(0.5) color: rgb(0,0,colorValue);
	}
	
	aspect threeD_commuting {
		if (useCar=true) {
			draw sphere(1.0) color: rgb(8,81,156);
		} else {
			draw sphere(1.0) color: rgb(158,202,225);
		}	
	}
	
	aspect commuting_aspect {
		if (useCar=true) {
			draw circle(1.0) color: rgb(8,81,156);
		} else {
			draw circle(1.0) color: rgb(158,202,225);
		}	
	}
	
}

grid cell width: grid_width height: grid_height {

}

experiment name type: gui {
	parameter "Farm productivity" var: rentFarm min: 0.0 max: 10.0 step: 1.0;
	parameter "Land/rent price tradeoff" var: landUtilityParameter min: 1.0 max: 20.0 step: 1.0;
	parameter "Commuting cost" var: commutingCost min: 0.0 max: 1.0 step: 0.05;
	parameter "Wage ratio" var: globalWage2 min: 0.1 max: 20.0 step: 0.1; // BUG: This is not updating
	
	output {
//		when: (bool(cycle mod 10)) // BUG: Show outupt every 10 steps 
		layout #split;
		display map_3D type:opengl{
			species cell;			
//			species building aspect:density_aspect;
//			species building aspect:rent_aspect; // BUG: How do we switch aspect in the UI
//			species building aspect: threeD transparency: 0.5;
			species building aspect: density_aspect;
			species firm aspect:wage_aspect;
			species worker aspect:commuting_aspect;
			// BUG: How do we increase the number of agents in the UI?
		}
	}
}