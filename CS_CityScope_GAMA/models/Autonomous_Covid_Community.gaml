/***
* Name: AutonomousCovidCommunity
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model AutonomousCovidCommunity

/* Insert your model definition here */

global{
	string scenario;
	bool drawTrajectory;
	geometry shape<-square (1#km);
	map<string, rgb> buildingColors <- ["residential"::#purple, "shopping"::#cyan, "business"::#orange];
	init{	
		create district{
			shape<-circle (250#m);
			location<-{500#m,250#m};
			if(scenario="Conventional Zoning"){
				do createBuildingByType(3,"residential");
    	    }else{
				do createAllBuilding(3);
			}
			
		}
		create district{
			shape<-circle (250#m);
			location<-{250#m,750#m};
			if(scenario="Conventional Zoning"){
			  do createBuildingByType(3,"shopping");
    	    }else{
			  do createAllBuilding(3);
			}
		}
		create district{
			shape<-circle (250#m);
			location<-{750#m,750#m};
			if(scenario="Conventional Zoning"){
				do createBuildingByType(3,"business");
    	    }else{
				do createAllBuilding(3);
			}
		}
		
		if(scenario="Functional Autonomy"){
			 do createPeople(33,first(district where (each.name = "district0")).myBuildings);
			 do createPeople(33,first(district where (each.name = "district1")).myBuildings);
			 do createPeople(33,first(district where (each.name = "district2")).myBuildings);
				
		}
		if(scenario="Conventional Zoning"){
			  do createPeople(100,list(building));
		}

	}
	
	action createPeople (int nb, list<building> _buildings){
		create people number:nb{
		  	current_trajectory <- [];
			myPlaces[0]<-one_of(_buildings where (each.type="residential"));
		    myPlaces[1]<-one_of(_buildings where (each.type="shopping"));
		    myPlaces[2]<-one_of(_buildings where (each.type="business"));
		    my_target<-any_location_in(myPlaces[0]);	
		    //location<-my_target;
	    }
	}
}

species district{
	list<building> myBuildings;
	
	action createBuildingByType(int nb,string _type){
		create building number:nb{
		  shape<-square(20#m);
		  location<-any_location_in(myself);
		  type<-_type;
		  myself.myBuildings<<self;
	    }
	}
	
	action createAllBuilding(int nb){
		do createBuilding(int(nb/3),"residential");
		do createBuilding(int(nb/3),"shopping");
		do createBuilding(int(nb/3),"business");	
	}
	
	action createBuilding(int nb,string _type){
		create building number:nb{
		  shape<-square(20#m);
		  location<-any_location_in(myself);
		  type<-_type;
		  myself.myBuildings<<self;
	    }
	}
	

	
	aspect default{
		draw shape empty:true border:#white;
	}
}



species building{
	rgb color;
	string type;
	aspect default{
		draw shape color:buildingColors[type];
	}
}

species people skills:[moving]{
	list<building> myPlaces<-[one_of(building),one_of(building),one_of(building)];
	point my_target;
	int curPlaces<-0;
	list<point> current_trajectory;
	
	reflex move{
	    do goto target:my_target speed:10.0;
    	if (my_target = location and my_target!=nil){
			curPlaces<-(curPlaces+1) mod 3;
			my_target<-any_location_in(myPlaces[curPlaces]);
		}
		do wander speed:1.0;
    }
    
    reflex computeTrajectory{
    	loop while:(length(current_trajectory) > 100){
	    		current_trajectory >> first(current_trajectory);
       		}
        	current_trajectory << location;
    }
	
	aspect default{
		draw circle(5#m) color:color;
		if(drawTrajectory){
			draw line(current_trajectory) color: color;
		}
	}
}

experiment autonomousCity{
	float minimu_cycle_duration<-0.02;
	parameter "Scenario" category:"" var: scenario <- "Functional Autonomy" among: ["Conventional Zoning","Functional Autonomy","Pandemic Response"];
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	output {
			
		display GotoOnNetworkAgent type:opengl background:rgb(10,40,55) draw_env:false synchronized:true{
			species district;
			species building;
			species people;

			
			graphics "legend" {
				   
					point hpos <- {world.shape.width * 1.1, world.shape.height * 1.1};
					float barH <- world.shape.width * 0.01;
					float factor <-  world.shape.width * 0.1;
					loop i from:0 to:length(buildingColors)-1{
						draw square(world.shape.width*0.02) empty:false color: buildingColors.values[i] at: {i*world.shape.width*0.175+world.shape.width*0.05, -100};
						draw buildingColors.keys[i] color: buildingColors.values[i] at: {i*world.shape.width*0.175+world.shape.width*0.025+world.shape.width*0.05, -75} perspective: true font:font("Helvetica", 20 , #bold);
					}
			}
			overlay position: { 0, 25 } size: { 240 #px, 680 #px } background: # black transparency: 0.0 border: #black {				    
		      draw string(scenario) color:#white at:{0,0} font:font("Helvetica", 30 , #bold);
			}
		}
	}
}