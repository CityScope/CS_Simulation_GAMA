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
	int trajectoryLength<-100;
	float trajectoryTransparency<-0.5;
	int nbBuildingPerDistrict<-10;
	int nbPeople<-100;
	float districtSize<-250#m;
	geometry shape<-square (1#km);
	file district_shapefile <- file("../results/district.shp");
	map<string, rgb> buildingColors <- ["residential"::#purple, "shopping"::#cyan, "business"::#orange];
	graph<district, district> macro_graph;
	bool drawMacroGraph<-true;
	bool pandemy<-false;
	init{	
		
		create district from:district_shapefile{
			create building number:nbBuildingPerDistrict{
			  shape<-square(20#m);
			  location<-any_location_in(myself.shape*0.9);
			  myself.myBuildings<<self;
			  myDistrict <- myself;
		    }
		}
		create people number:nbPeople{
		  	current_trajectory <- [];
		}
		macro_graph<- graph<district, district>(district as_distance_graph (500#m ));
		do updateSim(scenario); 
				
		//save district to:"../results/district.shp" type:"shp"; 
	}


action updateSim(string _scenario){
	do updateDistrict(_scenario);
	do updatePeople(_scenario);
}

action updatePeople(string _scenario){
	if (_scenario = "Conventional"){
	  ask people{
		myPlaces[0]<-one_of(building where (each.type="residential"));
		myPlaces[1]<-one_of(building where (each.type="shopping"));
		myPlaces[2]<-one_of(building where (each.type="business"));
		my_target<-any_location_in(myPlaces[0]);
		myCurrentDistrict<- myPlaces[0].myDistrict;
	  }	
	}
	if (_scenario = "Autonomy"){
	  ask people{
	  	myCurrentDistrict<-one_of(district);
		myPlaces[0]<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
		myPlaces[1]<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
		myPlaces[2]<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
		my_target<-any_location_in(myPlaces[0]);
	  }	
	}
}

action updateDistrict( string _scenario){
	if (_scenario = "Conventional"){
		ask first(district where (each.name = "district0")).myBuildings{
			type<-"residential";
		}
		ask first(district where (each.name = "district1")).myBuildings{
			type<-"shopping";
		}
		ask first(district where (each.name = "district2")).myBuildings{
			type<-"business";
		}
	}
	if (_scenario = "Autonomy"){
		ask district{
			ask myBuildings{
				type<-flip(0.3) ? "residential" : (flip(0.3) ? "shopping" : "business");
			}
		}
	}	
}	
}

species district{
	list<building> myBuildings;
	bool isQuarantine<-false;
	aspect default{
		//draw string(self.name) at:{location.x+districtSize*1.1,location.y-districtSize*0.5} color:#white perspective: true font:font("Helvetica", 30 , #bold);
		if (isQuarantine){
			draw shape*1.1 color:rgb(#red,1) empty:true border:#red;
		}
		draw shape color:rgb(#white,0.2) border:#white;
		
	}
}



species building{
	rgb color;
	string type;
	district myDistrict;
	aspect default{
		draw shape color:buildingColors[type];
	}
}

species people skills:[moving]{
	list<building> myPlaces<-[one_of(building),one_of(building),one_of(building)];
	point my_target;
	int curPlaces<-0;
	list<point> current_trajectory;
	district myCurrentDistrict;
	district target_district;
	bool go_outside <- false;
	
	reflex move_to_target_district when: target_district != nil {
		if (go_outside) {
			do goto target: myCurrentDistrict.location speed:5.0;
			if (location = myCurrentDistrict.location) {
				go_outside <- false;
				
			}
		} else {
			do goto target: target_district.location  speed:10.0;
			if (location = target_district.location) {
				myCurrentDistrict <- target_district;
				target_district <- nil;
			}
		}
	}
	reflex move_inside_district when: target_district = nil{
	    do goto target:my_target speed:5.0;
    	if (my_target = location){
    		curPlaces<-(curPlaces+1) mod 3;
			building bd <- myPlaces[curPlaces];
			my_target<-any_location_in(bd);
			if (bd.myDistrict != myCurrentDistrict) {
				go_outside <- true;
				target_district <- bd.myDistrict;
			}
		}
		
    }
    
    reflex computeTrajectory{
    	loop while:(length(current_trajectory) > trajectoryLength){
	    		current_trajectory >> first(current_trajectory);
       		}
        	current_trajectory << location;
    }
    
    reflex rnd_move {
    	do wander speed:1.0;
    }
	
	aspect default{
		draw circle(5#m) color:color;
		if(drawTrajectory){
			draw line(current_trajectory) color: rgb(color,trajectoryTransparency);
		}
	}
}

experiment autonomousCity{
	float minimu_cycle_duration<-0.02;
	parameter "Scenario" category:"Policy" var: scenario <- "Autonomy" among: ["Conventional","Autonomy"] on_change: {ask world{do updateSim(scenario);}};
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.5 min:0 max:1.0 ;
	parameter "Draw Macro Graph:" category: "Visualization" var:drawMacroGraph <-false;
	
	
	output {
			
		display GotoOnNetworkAgent type:opengl background:#black draw_env:false synchronized:true 
		camera_pos: {398.5622,522.9339,1636.0924} camera_look_pos: {398.5622,522.9053,-4.0E-4} camera_up_vector: {0.0,1.0,0.0} 
		
		{
			overlay position: { 0, 25 } size: { 240 #px, 680 #px } background: #black border: #black {				    
		      draw string(scenario) color:#white at:{50,100} font:font("Helvetica", 50 , #bold);
		      loop i from:0 to:length(buildingColors)-1{
				draw square(world.shape.width*0.02) empty:false color: buildingColors.values[i] at: {75, 200+i*50};
				draw buildingColors.keys[i] color: buildingColors.values[i] at:  {100, 205+i*50} perspective: true font:font("Helvetica", 30 , #bold);
			  }
			}
			
			species district;
			species building;
			species people;
			

			
			graphics "macro_graph" {
				if (macro_graph != nil and drawMacroGraph) {
					loop eg over: macro_graph.edges {
						geometry edge_geom <- geometry(eg);
						float w <- macro_graph weight_of eg;
						draw line(edge_geom.points[0],edge_geom.points[1]) width: 10#m color:#white;
					}

				}
			}
			event["c"] action: {scenario<-"Conventional";ask world{do updateSim(scenario);}};
			event["a"] action: {scenario<-"Autonomy";ask world{do updateSim(scenario);}};
		}
		
	}
}