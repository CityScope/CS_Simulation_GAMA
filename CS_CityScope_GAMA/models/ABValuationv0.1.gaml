/***
* Name: ABvaluation
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model ABvaluation

global{
	int grid_width<-8;
	int grid_height<-8;
	
	
	//Global House parameters
	float priceDelta<-5.0;
//	float neighborhoodDistance<-10.0;
	float mutationRate<-0.5;
	
	//Global Worker parameters 
	float resU<-10.0;
	float commutingCost<-1.0;
	float globalWage<-100.0;
	
	
	init{
		int i<-0;
		create farm number:10{
			location<-{-10+i*10,-10};
			i<-i+1;
		}
		
		create firm{
			location<-{50,50};
			nbWorkers<-0;
			wage<-globalWage;
		}

		create building number:100{
			shape<-square(10);
			create unit number:3{
				shape<-square(4);
				myBuilding<-myself;
				location<-any_location_in(myself);
				myself.myUnits<<self;
				vacant<-true;
				rent<-gauss(50.0,5.0);
				size<-1.0;	
			}
		}
		
		create worker number:500{
		  myUnit<- one_of(unit where (each.vacant=true));
		  myFirm<-one_of(firm);
		  myFarm<-one_of(farm);
		  if(myUnit!=nil){
		  	myUnit.vacant<-false;
		    location<-any_location_in(myUnit);
		    myFirm.nbWorkers<-myFirm.nbWorkers+1;
		  }
		  else{
		  	suburban<-true;
		  	location<-any_location_in(one_of(farm));
		  }
		}
	}
	
}

species farm{
	aspect base{
		draw square(5) color:#gray;
	}
}


species unit{
	building myBuilding;
	bool vacant;
	float rent;
	float size;
	float utility;
	
	
	reflex updateRent {
		if (rnd(1.0)<mutationRate){
			if (vacant=true) {
				rent <- rent-gauss(priceDelta,priceDelta/10.0);
			} else {
				rent <- rent+gauss(priceDelta,priceDelta/10.0);
			}
		}
		if (rent<0) {
			rent<-0.0;
		}
		utility <- globalWage - commutingCost * (self distance_to one_of(firm)) - rent * size;
	}
	
	aspect base{
		draw shape color:vacant ? #orange: #green;
	}
	
	aspect rent_aspect {
		draw shape color: rgb(255*rent/((globalWage-resU)/1.0),0,0);
	}
	
	aspect utility_aspect {
		draw shape color: rgb(255*utility/resU,0,0);
	}
}

species building{
	list<unit> myUnits;
	aspect base{
		draw shape color:#yellow;
	}
}

species worker skills:[moving]{
	unit myUnit;
	farm myFarm;
	firm myFirm;
	bool suburban<-false;
	float utility;
	
	reflex updateUnit{ // when:(bool(cycle mod 10)) 
		
		if (suburban=true) {
			utility <- resU;
		} else {
			utility <-myFirm.wage - commutingCost * (myUnit distance_to myFirm) - myUnit.rent * myUnit.size;
		}
		
//		write "utility" +utility;
		
		list<unit> possibleUnit<-(unit where (each.vacant=true));
		
		if(length(possibleUnit)=0) {
			if (resU>utility) {
				myUnit.vacant<-true;
				myUnit <- nil;
				suburban<-true;
				myFirm.nbWorkers<-myFirm.nbWorkers-1;
				myFarm <- farm closest_to self;
			}
		} else {
			float tmpUtil;
			float tmpMax<-resU;
			unit newUnit;
			
			ask possibleUnit{
				tmpUtil<-myself.myFirm.wage - commutingCost * (self distance_to myself.myFirm) - self.rent * self.size;
				if (tmpUtil>tmpMax) {
					tmpMax<-tmpUtil;
					newUnit<-self;
				}
			}
			if(tmpMax>utility and tmpMax>resU){
				if (suburban=true) {
					myFirm.nbWorkers<-myFirm.nbWorkers+1;
					myUnit<-newUnit;
					newUnit.vacant<-false;
					suburban<-false;
				} else {
					myUnit.vacant<-true;
					myUnit<-newUnit;
					newUnit.vacant<-false;
					suburban<-false;
				}
			} else {
				if (resU>utility) {
					myUnit.vacant<-true;
					suburban<-true;
					myUnit<-nil;
					myFirm.nbWorkers<-myFirm.nbWorkers-1;
					myFarm <- farm closest_to self;
				}
			}
		}
	}
	
	reflex move{
		if (suburban=true) {
			location <- any_location_in(myFarm);
		} else {
			location <- any_location_in(myUnit);			
		}
		 
//		if (suburban=true) {
//			do goto target:myFarm speed:10.0;
//		} else {
//			do goto target:myUnit speed:10.0;
//		}
	}
	
	aspect base{
		draw circle(0.5) color:#green;
	}
	
}

species firm{
	int nbWorkers;
	float wage;
	
	
	action hire{}
	action fire{}
	
	aspect base{
		draw square(10) color:#blue;
	}
}

grid cell width: grid_width height: grid_height {
	
}


experiment name type: gui {
	parameter "Res U" var: resU min: 0.0 max: 50.0 step: 1.0;
	parameter "Wage" var: globalWage min: 0.0 max: 500.0 step: 10.0;
	 
	output {
		layout #split;
		display grid type:opengl{
			species cell;			
//			species building aspect:base;
//			species unit aspect:base;
			species unit aspect:rent_aspect;
//			species unit aspect:utility_aspect;
			species farm aspect:base;
			species firm aspect:base;
			species worker aspect:base;
		}
		
		display "Utility and rent" type: java2D synchronized: true
		{
			chart "Utility and rent" type: series x_serie_labels: ("T+" + cycle)
			{
				data "Rent" value: mean(unit collect each.rent);
				data "Utility" value: mean(worker collect each.utility);
			}
		}
		
		display "Urbanites" type: java2D synchronized: true
		{
			chart "Urbanites" type: series x_serie_labels: ("T+" + cycle)
			{
				data "N Urbanites" value: length(worker where (each.suburban=false));
				data "N Rural" value: length(worker where (each.suburban=true));
				data "N Workers" value: mean(firm collect each.nbWorkers);
			}
		}

		
	}
}