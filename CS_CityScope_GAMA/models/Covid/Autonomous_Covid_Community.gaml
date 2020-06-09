/***
* Name: AutonomousCovidCommunity
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model AutonomousCovidCommunity


import "./CityScope_Coronaizer.gaml"

/* Insert your model definition here */

global{
	bool autonomy;
	float crossRatio<-0.1;
	bool drawTrajectory<-true;
	int trajectoryLength<-100;
	float trajectoryTransparency<-0.25;
	float peopleTransparency<-0.5;
	float macroTransparency<-0.5;
	int nbBuildingPerDistrict<-10;
	int nbPeople<-100;
	float step<-1#sec;
	bool accelerationEffect<-false;
	float speedFactor<-1.0;
	bool transitionPhase<-false;
	int current_min update: (time / #mn) mod 60;
	int current_hour update: (time / #hour) mod 24;
	int current_day  update: (int(time/#day));
	float districtSize<-250#m;
	float buildingSize<-40#m;
	string cityScopeCity<-"Boston";
	bool drawMap<-true;
	file bound_shapefile <- shape_file("./../../includes/AutonomousCities/"+cityScopeCity+"/bound.shp");
	file district_shapefile <- shape_file("./../../includes/AutonomousCities/"+cityScopeCity+"/Districts.shp");
	file legend_shapefile <- shape_file("./../../includes/AutonomousCities/"+cityScopeCity+"/legend.shp");
	image_file cityMap <- image_file("./../../includes/AutonomousCities/"+cityScopeCity+"/background.png");
	geometry shape<-envelope(bound_shapefile);
	rgb conventionalDistrictColor <-rgb(225,235,241);
	rgb autonomousDistrictColor <-rgb(39,62,78)+50;
	rgb macroGraphColor<-rgb(245,135,51);
	rgb backgroundColor<-rgb(39,62,78);
	map<string, rgb> buildingColors <- ["residential"::rgb('#FE7134'), "shopping"::rgb('#5AB8B8'), "business"::rgb('#FCC8B1')];
	map<string, geometry> buildingShape <- ["residential"::circle(buildingSize/2), "shopping"::square(buildingSize) rotated_by 45, "business"::triangle(buildingSize*1.25)];
	
	map<string,float> proportion_per_type<-["homeWorker"::0.2,"OfficeWorker"::0.6,"ShopWorker"::0.2];
	map<string,rgb> color_per_type<-["homeWorker"::rgb('#FE7134')-75,"OfficeWorker"::rgb('#5AB8B8')-75,"ShopWorker"::rgb('#FCC8B1')-75];

	graph<district, district> macro_graph;
	bool drawMacroGraph<-false;
	bool pandemy<-false;	
	//COVID Related
	bool reinit<-false;
	bool health<-true;
	bool profile<-false;
	bool safety<-false;
	
	//KPIS
	float PANDEMIC_LEVEL;
	float CITY_EFFICIENCY;
	float SAFETY_LEVEL;
		
			
	
	init{
		speedFactor<-world.shape.width/3600#m;
		create legend from: legend_shapefile;
		create cityMapper{
			shape<-myself.shape;
			location<-myself.location;
		}
		create district from:district_shapefile{
			create building number:nbBuildingPerDistrict{
			  shape<-square(world.shape.width/50);
			  location<-any_location_in(myself.shape*0.9);
			  myself.myBuildings<<self;
			  myDistrict <- myself;
		    }
		}
		
		macro_graph<- graph<district, district>(district as_distance_graph (1000#m ));
		do updateSim(autonomy); 
	}
	
	reflex updateStep when:(transitionPhase and accelerationEffect){
		if(step > 1#sec){
			step<-step-1#sec;
		}else{
			transitionPhase<-false;
		}
	}
	
	action updateSim(bool _autonomy){
		if(accelerationEffect){
		  step<-60#sec;	
		}
		do updateDistrict(_autonomy);
		do updatePeople(_autonomy);
		transitionPhase<-true;
		reinit<-true;
	}

	action updatePeople(bool _autonomy){
		ask people{
			do die;
		}
		create people number:nbPeople{
		  	current_trajectory <- [];
		  	color<-rgb(125)+rnd(-125,125);
		  	type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
		  	crossingPeople<-false;
		}
		if (!_autonomy){
		  ask people{
			myHome<-one_of(building where (each.type="residential"));
			myShop<-one_of(building where (each.type="shopping"));
			myOffice<-one_of(building where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
			myCurrentDistrict<- myPlaces[0].myDistrict;
		  }	
		}
		else{
		  ask people{
		  	myCurrentDistrict<-one_of(district);
			myHome<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myShop<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myOffice<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
		  }
		  ask (length(people)*crossRatio) among people{
		  	myCurrentDistrict<-one_of(district);
			myHome<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myCurrentDistrict<-one_of(district);
			myShop<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myCurrentDistrict<-one_of(district);
			myOffice<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
			crossingPeople<-true;
		  }		
		}
		do updatePlaces;
		
}

action updatePlaces{
			ask people{
			if (type = proportion_per_type.keys[0]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myHome;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myHome;
				myPlaces[4]<-myHome;
			}
			if (type = proportion_per_type.keys[1]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myOffice;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myOffice;
				myPlaces[4]<-myHome;
			}
			if (type = proportion_per_type.keys[2]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myShop;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myShop;
				myPlaces[4]<-myHome;
			}
		}
}
action updateDistrict( bool _autonomy){
	if (!_autonomy){
		ask district where (each.type = "R"){
			isAutonomous<-false;
			conventionalType<-"residential";
			ask myBuildings{
				type<-"residential";
			}
		}
		ask district where (each.type = "S"){
			isAutonomous<-false;
			conventionalType<-"shopping";
			ask myBuildings{
			  type<-"shopping";
			}
		}
		ask district where (each.type = "O"){
			isAutonomous<-false;
			conventionalType<-"business";
			ask myBuildings{
			  type<-"business";	
			}
			create hospital{
				location<-any_location_in(myself);
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
	string type;
	
	user_command "Quarantine"action: quarantine;
	user_command "UnQuarantine"action: unquarantine;
	
	action quarantine{
		if(autonomy){
			isQuarantine<-true;
			ask (people where (each.myHome.myDistrict = self)){
				//isMoving<-false;
				isQuarantine<-true;
				if(crossingPeople){
				  myShop<-one_of(myself.myBuildings where (each.type="shopping"));
			      myOffice<-one_of(myself.myBuildings where (each.type="business"));	
				}
			}
		}
		ask world{do updatePlaces;}	
	}
	action unquarantine{
		if(autonomy){
			isQuarantine<-false;
		}

		ask (people where (each.myHome.myDistrict = self)){
				//isMoving<-true;
				isQuarantine<-false;
				if(crossingPeople){
				  myCurrentDistrict<-one_of(district);
				  myShop<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
				  myCurrentDistrict<-one_of(district);
			      myOffice<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));	
				}
		}	
		ask world{do updatePlaces;}	
	}
	
	aspect default{
		if (isQuarantine){
			draw shape*1.1 - shape color:rgb(255,0,0,0.25) border:conventionalDistrictColor-50 empty:false;
		}
		if(isAutonomous){
			//draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:autonomousDistrictColor border:autonomousDistrictColor-50;
			draw shape color:rgb(255,255,255,0.1) border:conventionalDistrictColor-50 empty:false;
		}else{
			//draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:buildingColors[conventionalType] border:buildingColors[conventionalType]-50;
			draw shape color:rgb(255,255,255,0.1) border:buildingColors[conventionalType]-50 empty:false;
		}
		
	}
}



species building{
	rgb color;
	string type;
	district myDistrict;
	aspect default{
		draw buildingShape[type] at: location color:buildingColors[type] border:buildingColors[type]-100;
	}
}

species cityMapper{
	aspect default{
		if(drawMap){
			draw shape texture:cityMap color:rgb(backgroundColor,0.25);
		}
	}
}

species people skills:[moving]{
	rgb color;
	building myHome;
	building myOffice;
	building myShop;
	string type;
	list<building> myPlaces<-[one_of(building),one_of(building),one_of(building),one_of(building),one_of(building)];
	point my_target;
	int curPlaces<-0;
	list<point> current_trajectory;
	district myCurrentDistrict;
	district target_district;
	bool go_outside <- false;
	bool isMoving<-true;
	bool macroTrip<-false;
	bool isQuarantine<-false;
	bool crossingPeople<-false;
	
	reflex move_to_target_district when: (target_district != nil and isMoving){
		if (go_outside) {
			macroTrip<-false;
			do goto target: myCurrentDistrict.location speed:5.0*speedFactor;
			if (location = myCurrentDistrict.location) {
				go_outside <- false;
				
			}
		} else {
			macroTrip<-true;
			do goto target: target_district.location  speed:10.0*speedFactor;
			if (location = target_district.location) {
				myCurrentDistrict <- target_district;
				target_district <- nil;
			}
		}
	}
	reflex move_inside_district when: (target_district = nil and isMoving){
	    macroTrip<-false;
	    do goto target:my_target speed:5.0*speedFactor;
    	if (my_target = location){
    		curPlaces<-(curPlaces+1) mod 5;
			building bd <- myPlaces[curPlaces];
			my_target<-any_location_in(bd);
			if (bd.myDistrict != myCurrentDistrict) {
				go_outside <- true;
				target_district <- bd.myDistrict;
			}
		}
		
    }
    
    reflex ManageQuarantine when: !isMoving{
    	macroTrip<-false;
    	if(isQuarantine=false){
    	  do goto target:myPlaces[0] speed:5.0*speedFactor;	
    	}
    	if(location=myPlaces[0].location and isQuarantine=false){
    		location<-any_location_in(myPlaces[0].shape);
    		isQuarantine<-true;
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
			draw square(15#m) color:rgb(color,macroTransparency);
		}
		if(drawTrajectory){
			draw line(current_trajectory)  color: rgb(color,trajectoryTransparency);
		}
	}
	

	
	aspect dynamique{
		if(profile){
		  draw circle(world.shape.width/300) color:color_per_type[type];
		  if(macroTrip){
			draw square(world.shape.width/150) color:color_per_type[type];
		}
		  if(drawTrajectory){
		    draw line(current_trajectory)  color: rgb(color_per_type[type],trajectoryTransparency);
		  }
		}

	}
}

species hospital{
	int nbMedicalBeds<-10;
	int nbBeds<-100;
	int occupiedBed<-0;
	aspect default{
		draw cross(buildingSize) color:#red width:10 rotate:45;
		draw ("beds:") + occupiedBed + "/" + nbMedicalBeds  at:  location perspective: true font:font("Helvetica", 10 , #plain) color:#white;	
	}
}


species legend{
	string type;
	aspect default{
		draw shape color:#white empty:true;
	}
}

experiment City parent:Coronaizer autorun:true{
	float minimum_cycle_duration<-0.02;
	parameter 'City:' var: cityScopeCity category: 'GIS' <- "AbstractCity" among: ["AbstractCity", "MIT","Boston","Paris","Andorra","SanSebastian"];
	parameter "Autonomy" category:"Policy" var: autonomy <- false  on_change: {ask world{do updateSim(autonomy);}} enables:[crossRatio] ;
	parameter "Cross District Autonomy Ratio:" category: "Policy" var:crossRatio <-0.1 min:0.0 max:1.0 on_change: {ask world{do updateSim(autonomy);}};
	parameter "Map:" category: "Visualization" var:drawMap <-true ;
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.25 min:0.0 max:1.0 ;
	parameter "Transition acceleration effect:" category: "Visualization" var:accelerationEffect <-false ;
	parameter "People Transparency:" category: "Visualization" var:peopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Macro Transparency:" category: "Visualization" var:macroTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Draw Inter District Graph:" category: "Visualization" var:drawMacroGraph <-false;
    parameter "Simulation Step"  category: "Simulation" var:step min:1#sec max:60#sec step:1#sec;
	
	output {
		display GotoOnNetworkAgent type:opengl background:backgroundColor draw_env:false synchronized:true toolbar:false 
		{
			graphics "title" { 
		      draw !autonomy ? "Conventional Zoning" : "Autonomous Cities" color:#white at:{first(legend where (each.type="title")).location.x - first(legend where (each.type="title")).shape.width/2, first(legend where (each.type="title")).location.y} font:font("Helvetica", 50 , #bold);
		    } 
		    
		    graphics "clock" {
				draw "day" + string(current_day) + " - " + string(current_hour) + "h:" + string(current_min) + "min" color: #white font: font("Helvetica", 25, #plain) at:
				{world.shape.width * 0.8, world.shape.height * 0.975};
			}
		    
		    graphics "building"{
		      loop i from:0 to:length(buildingColors)-1{
				draw buildingShape[buildingColors.keys[i]] empty:false color: buildingColors.values[i] at: {first(legend where (each.type="left1")).location.x - first(legend where (each.type="left1")).shape.width/2, first(legend where (each.type="left1")).location.y - first(legend where (each.type="left1")).shape.height/2+i*first(legend where (each.type="left1")).shape.height/2};
				draw buildingColors.keys[i] color: buildingColors.values[i] perspective: true font:font("Helvetica", 25 , #plain) at: {40+ first(legend where (each.type="left1")).location.x - first(legend where (each.type="left1")).shape.width/2, 20+ first(legend where (each.type="left1")).location.y - first(legend where (each.type="left1")).shape.height/2+i*first(legend where (each.type="left1")).shape.height/2};
			  }
			  
			  loop i from:0 to:length(proportion_per_type)-1{
				draw circle (10)  empty:false color: color_per_type.values[i] at: {first(legend where (each.type="left3")).location.x - first(legend where (each.type="left3")).shape.width/2, first(legend where (each.type="left3")).location.y - first(legend where (each.type="left3")).shape.height/2+i*first(legend where (each.type="left3")).shape.height/2};
				draw proportion_per_type.keys[i] + " (" + proportion_per_type.values[i]+")" color: color_per_type.values[i] perspective: true font:font("Helvetica", 15 , #plain) at: {40+first(legend where (each.type="left3")).location.x - first(legend where (each.type="left3")).shape.width/2, first(legend where (each.type="left3")).location.y - first(legend where (each.type="left3")).shape.height/2+i*first(legend where (each.type="left3")).shape.height/2};
			  }
			}
			
			species building;
			species hospital;
			species cityMapper;
			species district;
			
		    graphics "infection_graph" {
				if (infection_graph != nil and drawInfectionGraph = true) {
					loop eg over: infection_graph.edges {
						geometry edge_geom <- geometry(eg);
						draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) color:#red;
					}

				}
			}
		    graphics "social_graph" {
				if (social_distance_graph != nil and drawSocialDistanceGraph = true) {
					loop eg over: social_distance_graph.edges {
						geometry edge_geom <- geometry(eg);
						draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) color:#gray;
					}

				}
		    }
			graphics "macro_graph" {
				if (macro_graph != nil and drawMacroGraph) {
					loop eg over: macro_graph.edges {
						geometry edge_geom <- geometry(eg);
						float w <- macro_graph weight_of eg;
						if(!autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 10#m color:macroGraphColor;	
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: world.shape.width/10000 color:macroGraphColor;	
						}
						if(autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 2#m color:macroGraphColor;
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: world.shape.width/20000 + crossRatio*8#m color:macroGraphColor;	
						}
						
					}

				}
			}
			
			
			graphics 'City Efficienty'{
			  float nbWalk<-float(length (people where (each.macroTrip= false)));
			  float nbMass<-float(length (people where (each.macroTrip= true)));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
				 //CITY EFFICIENTY
			  point posCE<-{first(legend where (each.type="right1")).location.x- first(legend where (each.type="right1")).shape.width/2,first(legend where (each.type="right1")).location.y- first(legend where (each.type="right1")).shape.height/2};
			  CITY_EFFICIENCY<-	int((nbWalk))/100;
			  draw "City Efficiency: " + CITY_EFFICIENCY color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right1")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right1")).shape.height/2};
			  draw rectangle(50,CITY_EFFICIENCY*first(legend where (each.type="right1")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - CITY_EFFICIENCY*first(legend where (each.type="right1")).shape.height/2};
			  
			 
			 
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/3; 	
			  float offsetX<-first(legend where (each.type="right1")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right1")).shape.height/8;
			  draw rectangle(nbWalk,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nbWalk/2,posCE.y+spacebetween+20+offsetY};
			  draw "Walk: " + with_precision(nbWalk/length(people), 2) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nbMass,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nbMass/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "Mass: " + with_precision(nbMass/length(people),2) color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
			  
			  
			  int toalTheoreticalWork <- length(ViralPeople)*8;
			  int effectiveWork <- length(ViralPeople where each.is_susceptible)*8 + length (ViralPeople where (each.is_asymptomatic and each.is_infected))*7 + length (ViralPeople where (!each.is_asymptomatic and each.is_infected))*4 +length(ViralPeople where each.is_recovered)*8;
			  draw rectangle(effectiveWork/toalTheoreticalWork * length(people),20) color: buildingColors.values[2] at: {offsetX+posCE.x+effectiveWork/toalTheoreticalWork/2, posCE.y+3*spacebetween+20+offsetY};
			  draw "Working forces: " + with_precision(effectiveWork/toalTheoreticalWork,2) color: buildingColors.values[2] at:  {offsetX+posCE.x, posCE.y+3*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);			  
			}
			
			graphics 'Pandemic Level'{
			  float nbWalk<-float(length (people where (each.macroTrip= false)));
			  float nbMass<-float(length (people where (each.macroTrip= true)));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
				 //CITY EFFICIENTY
			  point posCE<-{first(legend where (each.type="right2")).location.x- first(legend where (each.type="right2")).shape.width/2,first(legend where (each.type="right2")).location.y- first(legend where (each.type="right2")).shape.height/2};
			 
			  PANDEMIC_LEVEL<-nb_infected/length(ViralPeople);
			  draw "Pandemic Level: " + PANDEMIC_LEVEL color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right2")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right2")).shape.height/2};
			  draw rectangle(50,PANDEMIC_LEVEL*first(legend where (each.type="right2")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - PANDEMIC_LEVEL*first(legend where (each.type="right2")).shape.height/2};
			    
			  float offsetX<-first(legend where (each.type="right2")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right2")).shape.height/8;
			  draw rectangle(nb_susceptible,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nb_susceptible/2,posCE.y+spacebetween+20+offsetY};
			  draw "S: " + with_precision(nb_susceptible/length(people),2) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nb_infected,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nb_infected/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "I: " + with_precision(nb_infected/length(people),2) color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
 
		}
		
		
		graphics 'Safety Measures'{
			  int nbMask <- length(ViralPeople where (each.as_mask = true));
			  int nbQ <- length(ViralPeople where (each.target.isQuarantine = true));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
			  //SAFETY LEVEL
			  point posCE<-{first(legend where (each.type="right3")).location.x- first(legend where (each.type="right3")).shape.width/2,first(legend where (each.type="right3")).location.y- first(legend where (each.type="right3")).shape.height/2};
			  
			  SAFETY_LEVEL<-((nbMask+nbQ)/200);	
			  draw "Safety: " + SAFETY_LEVEL color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right3")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right3")).shape.height/2};
			  draw rectangle(50,SAFETY_LEVEL*first(legend where (each.type="right3")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - SAFETY_LEVEL*first(legend where (each.type="right3")).shape.height/2};
			  
			  
			  
			  float offsetX<-first(legend where (each.type="right3")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right3")).shape.height/8;
			  draw rectangle(nbMask,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nbMask/2,posCE.y+spacebetween+20+offsetY};
			  draw "Mask: " + with_precision(nbMask/length(people),2) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nbQ,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nbQ/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "Quarantine: " + with_precision(nbQ/length(people),2) color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
 
		}
		
		
		graphics 'Interface'{	  
   		  point posCE<-{first(legend where (each.type="bottom")).location.x-first(legend where (each.type="bottom")).shape.width/3,first(legend where (each.type="bottom")).location.y};		
		  float offsetX<-first(legend where (each.type="bottom")).shape.width/3;
		
		  draw "Health: (H)" color: health ?  #white :#grey at:  {posCE.x, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);		  
		  draw "Profile: (P)" color: profile ? #white :#grey at:  {posCE.x+offsetX, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);		 
		  draw "Safety: (S)" color: safety ?  #white :#grey at:  {posCE.x+2*offsetX, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);	
			
		}
			species people aspect:dynamique;
			species ViralPeople aspect:dynamic;
			event["p"] action: {profile<-true;safety<-false;health<-false;};
			event["s"] action: {profile<-false;safety<-true;health<-false;};
			event["h"] action: {profile<-false;safety<-false;health<-true;};
			event["c"] action: {autonomy<-false;ask world{do updateSim(autonomy);}};
			event["a"] action: {autonomy<-true;ask world{do updateSim(autonomy);}};
			event ["i"] action:{reinitCovid<-true;};
			event ["o"] action:{stopCovid<-true;};
		}
		
		display CoronaChart refresh:every(#mn)  {
			 chart "Population: " type: series x_serie_labels: "time" axes: rgb(142,142,142)  background: rgb(53,53,53) color: rgb (146,146,146) size: point (1,1) 
			 x_label: 'Infection rate: '+infection_rate + " Quarantine: " + length(people where !each.isMoving) + " Mask: " + length( ViralPeople where each.as_mask)
			 y_label: 'Case'{
				data "susceptible" value: nb_susceptible color: #green;
				data "infected" value: nb_infected color: #red;	
				data "recovered" value: nb_recovered color: #blue;
				data "death" value: nb_death color: #black;
			 } 
		}
		
	}
}

/*experiment CityWithChart parent:City autorun:true{
	float minimum_cycle_duration<-0.02;
	parameter 'City:' var: cityScopeCity category: 'GIS' <- "AbstractCity" among: ["AbstractCity", "MIT","Boston","Paris","Andorra","SanSebastian"];
	parameter "Autonomy" category:"Policy" var: autonomy <- false  on_change: {ask world{do updateSim(autonomy);}} enables:[crossRatio] ;
	parameter "Cross District Autonomy Ratio:" category: "Policy" var:crossRatio <-0.1 min:0.0 max:1.0 on_change: {ask world{do updateSim(autonomy);}};
	parameter "Map:" category: "Visualization" var:drawMap <-true ;
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.25 min:0.0 max:1.0 ;
	parameter "Transition acceleration effect:" category: "Visualization" var:accelerationEffect <-false ;
	parameter "People Transparency:" category: "Visualization" var:peopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Macro Transparency:" category: "Visualization" var:macroTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Draw Inter District Graph:" category: "Visualization" var:drawMacroGraph <-false;
    parameter "Simulation Step"  category: "Simulation" var:step min:1#sec max:60#sec step:1#sec;
	
	output {

		
		 display CoronaChart refresh:every(#mn) toolbar:false {
			 chart "Population: " type: series x_serie_labels: "time" 
			 x_label: 'Infection rate: '+infection_rate + " Quarantine: " + length(people where !each.isMoving) + " Mask: " + length( ViralPeople where each.as_mask)
			 y_label: 'Case'{
				data "susceptible" value: nb_susceptible color: #green;
				data "infected" value: nb_infected color: #red;	
				data "recovered" value: nb_recovered color: #blue;
				data "death" value: nb_death color: #black;
			 } 
		}
		
	}
}*/



