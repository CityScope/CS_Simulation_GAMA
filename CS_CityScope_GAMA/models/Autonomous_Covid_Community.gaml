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
	float districtSize<-250#m;
	geometry shape<-square (1#km);
	map<string, rgb> buildingColors <- ["residential"::#purple, "shopping"::#cyan, "business"::#orange];
	graph<district, district> macro_graph;
	bool drawMacroGraph<-true;
	init{	
		create district{
			shape<-circle (districtSize);
			location<-{500#m,250#m};
			if(scenario="Conventional Zoning"){
				do createBuildingByType(nbBuildingPerDistrict,"residential");
    	    }else{
				do createAllBuilding(nbBuildingPerDistrict);
			}
			
		}
		create district{
			shape<-circle (districtSize);
			location<-{150#m,850#m};
			if(scenario="Conventional Zoning"){
			  do createBuildingByType(nbBuildingPerDistrict,"shopping");
    	    }else{
			  do createAllBuilding(nbBuildingPerDistrict);
			}
		}
		create district{
			shape<-circle (districtSize);
			location<-{850#m,850#m};
			if(scenario="Conventional Zoning"){
				do createBuildingByType(nbBuildingPerDistrict,"business");
    	    }else{
				do createAllBuilding(nbBuildingPerDistrict);
			}
		}
		macro_graph<- graph<district, district>(district as_distance_graph (500#m ));
		
		if(scenario="Functional Autonomy"){
			 do createPeople(33,first(district where (each.name = "district0")).myBuildings);
			 do createPeople(33,first(district where (each.name = "district1")).myBuildings);
			 do createPeople(33,first(district where (each.name = "district2")).myBuildings);
				
		}
		if(scenario="Conventional Zoning"){
		  do createPeople(100,list(building));
		}
		if(scenario="Pandemic Response"){
		  do createPeople(33,first(district where (each.name = "district0")).myBuildings + first(district where (each.name = "district1")).myBuildings);
		  ask first(district where (each.name = "district2")){
		  	isQuarantine<-true;
		  }
		  do createPeople(33,first(district where (each.name = "district2")).myBuildings);
		}
		

	}
	
	action createPeople (int nb, list<building> _buildings){
		create people number:nb{
		  	current_trajectory <- [];
			myPlaces[0]<-one_of(_buildings where (each.type="residential"));
		    myPlaces[1]<-one_of(_buildings where (each.type="shopping"));
		    myPlaces[2]<-one_of(_buildings where (each.type="business"));
		   // location <- any_location_in(myPlaces[0]);
		    my_target<-any_location_in(myPlaces[0]);
		    myCurrentDistrict<- myPlaces[0].myDistrict;
		    //location<-my_target;
	    }
	}
}

species district{
	list<building> myBuildings;
	bool isQuarantine<-false;
	
	action createBuildingByType(int nb,string _type){
		create building number:nb{
		  shape<-square(20#m);
		  location<-any_location_in(myself.shape*0.9);
		  type<-_type;
		  myself.myBuildings<<self;
		  
		  myDistrict <- myself;
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
		  location<-any_location_in(myself.shape*0.9);
		  type<-_type;
		  myself.myBuildings<<self;
		  myDistrict <- myself;
	    }
	}
	

	
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
	parameter "Scenario" category:"" var: scenario <- "Pandemic Response" among: ["Conventional Zoning","Functional Autonomy","Pandemic Response"];
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
						//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90)color:#green;//rgb(0,w*10,0);
						draw line(edge_geom.points[0],edge_geom.points[1]) width: 10#m color:#white;
					}

				}
			}
		}
	}
}