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
	float priceDelta<-50.0;
	float neighborhoodDistance<-10.0;
	float mutationRate<-0.3;
	
	//Gloabl Worker parameters
	float resU<-100.0;
	float commutingCost<-10.0;
	
	
	init{
		create firm{
			location<-{50,50};
			nbWorkers<-0;
			wage<-100.0;
		}
		
		create building number:100{
			shape<-square(10);
			create unit number:3{
				shape<-square(4);
				myBuilding<-myself;
				location<-any_location_in(myself);
				myself.myUnits<<self;
				vacant<-true;
				price<-10.0;
				size<-1.0;	
			}
		}
		
		create worker number:100{
		  myUnit<- one_of(unit where (each.vacant=true));
		  myFirm<-one_of(firm);
		  if(myUnit!=nil){
		  	myUnit.vacant<-false;
		    location<-any_location_in(myUnit);
		  }
		  else{
		  	suburban<-true;
		  	location<-{-10-rnd(10),-10-rnd(10)};
		  }
		}
	}
	
}


species unit{
	building myBuilding;
	bool vacant;
	float price;
	float size;
	aspect base{
		draw shape color:vacant ? #orange: #green;
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
	firm myFirm;
	bool suburban<-false;
	float utility;
	
	reflex updateUnit{
		list<unit> possibleUnit<-(unit where (each.vacant=true));
		utility <-myFirm.wage - commutingCost * (myUnit distance_to myFirm) - myUnit.price * myUnit.size;
		if(length(possibleUnit)>0){
			float tmpUtil;
			float tmpMax<--1000.0;
			unit newUnit;
			
			ask possibleUnit{
				tmpUtil<-myself.myFirm.wage - commutingCost * (self distance_to myself.myFirm) - self.price * self.size;
				//write "tmpUtil" +tmpUtil;
				if(tmpUtil>tmpMax){
					tmpMax<-tmpUtil;
					newUnit<-self;
				}
			}
			
			if (tmpMax>utility){
				myUnit.vacant<-true;
				myUnit<-newUnit;
				newUnit.vacant<-false;
			}
		}
	}
	
	reflex move{
		do goto target:myUnit;
	}
	
	aspect base{
		draw circle(0.5) color:#red;
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

	output {
		display grid type:opengl{
			species cell;
			species firm aspect:base;
			species building aspect:base;
			species unit aspect:base;
			species worker aspect:base;
		}
	}
}