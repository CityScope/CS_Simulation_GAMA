/***
* Name: AutonomousCovidCommunity
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model AutonomousCovidCommunity

/* Insert your model definition here */

global{
	bool autonomy;
	float crossRatio;
	bool drawTrajectory;
	int trajectoryLength<-100;
	float trajectoryTransparency<-0.5;
	float peopleTransparency<-0.5;
	int nbBuildingPerDistrict<-10;
	int nbPeople<-100;
	float step<-1#sec;
	int current_hour update: (time / #hour) mod 24;
	int current_day  update: (int(time/#day));
	float districtSize<-250#m;
	float buildingSize<-40#m;
	bool randomColor<-true;
	geometry shape<-square (1#km);
	string cityScopeCity<-"volpe";
	file district_shapefile <- file("./../../includes/AutonomousCities/district.shp");
	rgb conventionalDistrictColor <-rgb(225,235,241);
	rgb autonomousDistrictColor <-rgb(39,62,78)+50;
	rgb macroGraphColor<-rgb(245,135,51);
	rgb backgroundColor<-rgb(39,62,78);
	map<string, rgb> buildingColors <- ["residential"::rgb(168,192,208), "shopping"::rgb(245,135,51), "business"::rgb(217,198,163)];
	map<string, geometry> buildingShape <- ["residential"::circle(buildingSize/2), "shopping"::square(buildingSize) rotated_by 45, "business"::triangle(buildingSize*1.25)];
	

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
		do updateSim(autonomy); 
	}
	
	action updateSim(bool _autonomy){
		do updateDistrict(_autonomy);
		do updatePeople(_autonomy);
		do updatePeopleColor(randomColor);
	}

	action updatePeople(bool _autonomy){
		if (!_autonomy){
		  ask people{
			myPlaces[0]<-one_of(building where (each.type="residential"));
			myPlaces[1]<-one_of(building where (each.type="shopping"));
			myPlaces[2]<-one_of(building where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
			myCurrentDistrict<- myPlaces[0].myDistrict;
		  }	
		}
		else{
		  ask people{
		  	myCurrentDistrict<-one_of(district);
			myPlaces[0]<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myPlaces[1]<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myPlaces[2]<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
		  }
		  ask (length(people)*crossRatio) among people{
		  	myCurrentDistrict<-one_of(district);
			myPlaces[0]<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myCurrentDistrict<-one_of(district);
			myPlaces[1]<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myCurrentDistrict<-one_of(district);
			myPlaces[2]<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
		  }		
		}
		
}
action updatePeopleColor(bool _randomColor){
	ask people{
			if (_randomColor){
				color<-rnd_color(255);
			}
			else{
				color<-#darkgray;
			}
		}
}

action updateDistrict( bool _autonomy){
	if (!_autonomy){
		ask first(district where (each.name = "district0")){
			isAutonomous<-false;
			conventionalType<-"residential";
			ask myBuildings{
				type<-"residential";
			}
		}
		ask first(district where (each.name = "district1")){
			isAutonomous<-false;
			conventionalType<-"shopping";
			ask myBuildings{
			  type<-"shopping";
			}
		}
		ask first(district where (each.name = "district2")){
			isAutonomous<-false;
			conventionalType<-"business";
			ask myBuildings{
			  type<-"business";	
			}
		}
	}
	else{
		ask district{
			isAutonomous<-true;
			ask myBuildings{
				type<-flip(0.3) ? "residential" : (flip(0.3) ? "shopping" : "business");
			}
			if(length (myBuildings where (each.type="residential"))=0){
				ask one_of(myBuildings){
				  type<-"residential";	
				}		
			}
			if(length (myBuildings where (each.type="shopping"))=0){
				ask one_of(myBuildings){
				  type<-"shopping";	
				}		
			}
			if(length (myBuildings where (each.type="business"))=0){
				ask one_of(myBuildings){
				  type<-"business";	
				}		
			}
		}
	}	
}	
}

species district{
	list<building> myBuildings;
	bool isQuarantine<-false;
	bool isAutonomous<-false;
	string conventionalType;
	aspect default{
		//draw string(self.name) at:{location.x+districtSize*1.1,location.y-districtSize*0.5} color:#white perspective: true font:font("Helvetica", 30 , #bold);
		if (isQuarantine){
			draw shape*1.1 color:rgb(#red,1) empty:true border:#red;
		}
		if(isAutonomous){
			draw (shape*1.05) at_location {location.x,location.y,-0.01} color:autonomousDistrictColor border:autonomousDistrictColor-50;
			draw shape color:conventionalDistrictColor border:conventionalDistrictColor-50;
		}else{
			draw (shape*1.05) at_location {location.x,location.y,-0.01} color:buildingColors[conventionalType] border:buildingColors[conventionalType]-50;
			draw shape color:conventionalDistrictColor border:buildingColors[conventionalType]-50;
		}
		
	}
}



species building{
	rgb color;
	string type;
	district myDistrict;
	aspect default{
		draw buildingShape[type] at: location color:buildingColors[type] border:buildingColors[type]-50;
	}
}

species people skills:[moving]{
	rgb color;
	list<building> myPlaces<-[one_of(building),one_of(building),one_of(building)];
	point my_target;
	int curPlaces<-0;
	list<point> current_trajectory;
	district myCurrentDistrict;
	district target_district;
	bool go_outside <- false;
	bool isMoving<-true;
	bool macroTrip<-false;
	
	reflex move_to_target_district when: (target_district != nil and isMoving){
		if (go_outside) {
			macroTrip<-false;
			do goto target: myCurrentDistrict.location speed:5.0;
			if (location = myCurrentDistrict.location) {
				go_outside <- false;
				
			}
		} else {
			macroTrip<-true;
			do goto target: target_district.location  speed:10.0;
			if (location = target_district.location) {
				myCurrentDistrict <- target_district;
				target_district <- nil;
			}
		}
	}
	reflex move_inside_district when: (target_district = nil and isMoving){
	    macroTrip<-false;
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
    	do wander speed:0.1;
    }
	
	aspect default{
		draw circle(4#m) color:rgb(color,peopleTransparency);
		if(macroTrip){
			draw square(15#m) color:color;
		}
		if(drawTrajectory){
			draw line(current_trajectory) color: rgb(color,trajectoryTransparency);
		}
	}
}

experiment autonomousCity{
	float minimum_cycle_duration<-0.02;
	parameter "Autonomy" category:"Policy" var: autonomy <- false  on_change: {ask world{do updateSim(autonomy);}} enables:[crossRatio] ;
	parameter "Cross District Autonomy Ratio:" category: "Policy" var:crossRatio <-0.1 min:0.0 max:1.0 on_change: {ask world{do updateSim(autonomy);}};
	parameter "Random Color:" category: "Visualization" var:randomColor <-true on_change: {ask world{do updatePeopleColor(randomColor);}};
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "People Transparency:" category: "Visualization" var:peopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Draw Inter District Graph:" category: "Visualization" var:drawMacroGraph <-false;
    parameter "Simulation Step"  category: "Simulation" var:step min:1#sec max:60#sec step:1#sec;
	
	

	output {
			
		display GotoOnNetworkAgent type:opengl background:backgroundColor draw_env:false synchronized:true toolbar:false
		camera_pos: {398.5622,522.9339,1636.0924} camera_look_pos: {398.5622,522.9053,-4.0E-4} camera_up_vector: {0.0,1.0,0.0} 
		
		{
			overlay position: { 0, 25 } size: { 240 #px, 680 #px } background: #black border: #black {				    
		      draw !autonomy ? "Conventional" : "Autonomy" color:#white at:{50,100} font:font("Helvetica", 50 , #bold);
		      loop i from:0 to:length(buildingColors)-1{
				draw buildingShape[buildingColors.keys[i]] empty:false color: buildingColors.values[i] at: {75, 200+i*100};
				draw buildingColors.keys[i] color: buildingColors.values[i] at:  {120, 210+i*100} perspective: true font:font("Helvetica", 30 , #bold);
			  }
			}
			
			species district position:{0,0,-0.001};
			species building;
			
			
			graphics "macro_graph" {
				if (macro_graph != nil and drawMacroGraph) {
					loop eg over: macro_graph.edges {
						geometry edge_geom <- geometry(eg);
						float w <- macro_graph weight_of eg;
						if(!autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 10#m color:macroGraphColor;	
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: 10#m color:macroGraphColor;	
						}
						if(autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 2#m color:macroGraphColor;
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: 2#m + crossRatio*8#m color:macroGraphColor;	
						}
						
					}

				}
			}
			species people;
			event["c"] action: {autonomy<-false;ask world{do updateSim(autonomy);}};
			event["a"] action: {autonomy<-true;ask world{do updateSim(autonomy);}};
		}
		
	}
}