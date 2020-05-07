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
	int current_hour update: (time / #hour) mod 24;
	int current_day  update: (int(time/#day));
	float districtSize<-250#m;
	float buildingSize<-40#m;
	geometry shape<-square (1#km);
	string cityScopeCity<-"volpe";
	file bound_shapefile <- file("./../../includes/AutonomousCities/bound.shp");
	file district_shapefile <- file("./../../includes/AutonomousCities/GridDistrict.shp");
	file legend_shapefile <- file("./../../includes/AutonomousCities/Legend.shp");
	rgb conventionalDistrictColor <-rgb(225,235,241);
	rgb autonomousDistrictColor <-rgb(39,62,78)+50;
	rgb macroGraphColor<-rgb(245,135,51);
	rgb backgroundColor<-rgb(39,62,78);
	map<string, rgb> buildingColors <- ["residential"::rgb('#FE7134'), "shopping"::rgb('#5AB8B8'), "business"::rgb('#FCC8B1')];
	//map<string, rgb> buildingColors <- ["residential"::rgb(168,192,208), "shopping"::rgb(245,135,51), "business"::rgb(217,198,163)];
	map<string, geometry> buildingShape <- ["residential"::circle(buildingSize/2), "shopping"::square(buildingSize) rotated_by 45, "business"::triangle(buildingSize*1.25)];
	
	map<string,float> proportion_per_type<-["homeWorker"::0.2,"OfficeWorker"::0.6,"ShopWorker"::0.2];
	//map<string,rgb> color_per_type<-["homeWorker"::rgb(240,255,56),"OfficeWorker"::rgb(82,171,255),"ShopWorker"::rgb(179,38,30)];
	map<string,rgb> color_per_type<-["homeWorker"::rgb('#FE7134')-75,"OfficeWorker"::rgb('#5AB8B8')-75,"ShopWorker"::rgb('#FCC8B1')-75];

	graph<district, district> macro_graph;
	bool drawMacroGraph<-false;
	bool pandemy<-false;	
	//COVID Related
	bool reinit<-false;
	bool profile<-true;
	bool safety<-false;
	bool health<-false;
	
	init{
		shape<-envelope(bound_shapefile);	
		create legend from: legend_shapefile;
		create district from:district_shapefile{
			create building number:nbBuildingPerDistrict{
			  shape<-square(20#m);
			  location<-any_location_in(myself.shape*0.9);
			  myself.myBuildings<<self;
			  myDistrict <- myself;
		    }
		}
		
		macro_graph<- graph<district, district>(district as_distance_graph (500#m ));
		do updateSim(autonomy); 
	}
	
	reflex updateStep{
		if(step > 1#sec){
			step<-step-1#sec;
		}
	}
	
	action updateSim(bool _autonomy){
		step<-60#sec;
		do updateDistrict(_autonomy);
		do updatePeople(_autonomy);
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
		  }		
		}
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
			//draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:autonomousDistrictColor border:autonomousDistrictColor-50;
			draw shape color:conventionalDistrictColor border:conventionalDistrictColor-50 empty:true;
		}else{
			//draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:buildingColors[conventionalType] border:buildingColors[conventionalType]-50;
			draw shape color:conventionalDistrictColor border:buildingColors[conventionalType]-50 empty:true;
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
    	  do goto target:myPlaces[0] speed:5.0;	
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
		  draw circle(4#m) color:color_per_type[type];
		  if(macroTrip){
			draw square(15#m) color:color_per_type[type];
		}
		  if(drawTrajectory){
		    draw line(current_trajectory)  color: rgb(color_per_type[type],trajectoryTransparency);
		  }
		}

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
	parameter "Autonomy" category:"Policy" var: autonomy <- false  on_change: {ask world{do updateSim(autonomy);}} enables:[crossRatio] ;
	parameter "Cross District Autonomy Ratio:" category: "Policy" var:crossRatio <-0.1 min:0.0 max:1.0 on_change: {ask world{do updateSim(autonomy);}};
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.25 min:0.0 max:1.0 ;
	parameter "People Transparency:" category: "Visualization" var:peopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Macro Transparency:" category: "Visualization" var:macroTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Draw Inter District Graph:" category: "Visualization" var:drawMacroGraph <-false;
    //parameter "Simulation Step"  category: "Simulation" var:step min:1#sec max:60#sec step:1#sec;
	
	output {
		display GotoOnNetworkAgent type:opengl background:backgroundColor draw_env:false synchronized:true toolbar:false 
		{
			graphics "title" { 
		      draw !autonomy ? "Conventional Zoning" : "Autonomous Cities" color:#white at:{first(legend where (each.type="title")).location.x - first(legend where (each.type="title")).shape.width/2, first(legend where (each.type="title")).location.y} font:font("Helvetica", 50 , #bold);
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
			
			species district position:{0,0,-0.001};
			species building;
			//species legend;
			
			
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
			
			
			graphics 'City Efficienty'{
			  float nbWalk<-float(length (people where (each.macroTrip= false)));
			  float nbMass<-float(length (people where (each.macroTrip= true)));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
				 //CITY EFFICIENTY
			  point posCE<-{first(legend where (each.type="right1")).location.x- first(legend where (each.type="right1")).shape.width/2,first(legend where (each.type="right1")).location.y- first(legend where (each.type="right1")).shape.height/2};
			  	
			  draw "City Efficiency: " + int((nbWalk)) color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right1")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right1")).shape.height/2};
			  draw rectangle(50,(nbWalk/100)*first(legend where (each.type="right1")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - ((nbWalk/100))*first(legend where (each.type="right1")).shape.height/2};
			  
			  
			  
			  float offsetX<-first(legend where (each.type="right1")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right1")).shape.height/8;
			  draw rectangle(nbWalk,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nbWalk/2,posCE.y+spacebetween+20+offsetY};
			  draw "Walk: " + nbWalk/length(people) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nbMass,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nbMass/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "Mass: " + nbMass/length(people)color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
 
			}
			
			graphics 'Pandemic Level'{
			  float nbWalk<-float(length (people where (each.macroTrip= false)));
			  float nbMass<-float(length (people where (each.macroTrip= true)));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
				 //CITY EFFICIENTY
			  point posCE<-{first(legend where (each.type="right2")).location.x- first(legend where (each.type="right2")).shape.width/2,first(legend where (each.type="right2")).location.y- first(legend where (each.type="right2")).shape.height/2};
			  	
			  draw "Pandemic Level: " + int((nb_infected)) color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right2")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right2")).shape.height/2};
			  draw rectangle(50,(nb_infected/100)*first(legend where (each.type="right2")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - ((nb_infected/100))*first(legend where (each.type="right2")).shape.height/2};
			  
			  
			  
			  float offsetX<-first(legend where (each.type="right2")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right2")).shape.height/8;
			  draw rectangle(nb_susceptible,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nb_susceptible/2,posCE.y+spacebetween+20+offsetY};
			  draw "S: " + nb_susceptible/length(people) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nb_infected,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nb_infected/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "I: " + nb_infected/length(people)color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
 
		}
		
		
		graphics 'Safety Measures'{
			  int nbMask <- length(ViralPeople where (each.as_mask = true));
			  int nbQ <- length(ViralPeople where (each.target.isQuarantine = true));
			  float spacebetween<-first(legend where (each.type="right1")).shape.height/2; 	
				 //CITY EFFICIENTY
			  point posCE<-{first(legend where (each.type="right3")).location.x- first(legend where (each.type="right3")).shape.width/2,first(legend where (each.type="right3")).location.y- first(legend where (each.type="right3")).shape.height/2};
			  	
			  draw "Safety: " + ((nbMask+nbQ)/200) color: #white at:  {40+ posCE.x, posCE.y+40} perspective: true font:font("Helvetica", 20 , #bold);			  
			  draw rectangle(55,first(legend where (each.type="right3")).shape.height) color: #white empty:true at: {posCE.x, posCE.y + 2*spacebetween- first(legend where (each.type="right3")).shape.height/2};
			  draw rectangle(50,(((nbMask+nbQ)/200))*first(legend where (each.type="right3")).shape.height) color: #white at: {posCE.x, posCE.y + 2*spacebetween - ((((nbMask+nbQ)/200)))*first(legend where (each.type="right3")).shape.height/2};
			  
			  
			  
			  float offsetX<-first(legend where (each.type="right3")).shape.width/4;
			  float offsetY<--first(legend where (each.type="right3")).shape.height/8;
			  draw rectangle(nbMask,20) color: buildingColors.values[1] at: {offsetX+posCE.x+nbMask/2,posCE.y+spacebetween+20+offsetY};
			  draw "Mask: " + nbMask/length(people) color: buildingColors.values[1] at:  {offsetX+posCE.x,posCE.y+spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: buildingColors.values[1] at: {offsetX+posCE.x-20, posCE.y+spacebetween-20+offsetY};
			  
			  draw rectangle(nbQ,20) color: buildingColors.values[0] at: {offsetX+posCE.x+nbQ/2, posCE.y+2*spacebetween+20+offsetY};
			  draw "Quarantine: " + nbQ/length(people)color: buildingColors.values[0] at:  {offsetX+posCE.x, posCE.y+2*spacebetween+offsetY} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: buildingColors.values[0] at: {offsetX+posCE.x-20, posCE.y+2*spacebetween-20+offsetY};
 
		}
		
		
		graphics 'Interface'{	  
   		  point posCE<-{first(legend where (each.type="bottom")).location.x-first(legend where (each.type="bottom")).shape.width/3,first(legend where (each.type="bottom")).location.y};		
		  float offsetX<-first(legend where (each.type="bottom")).shape.width/3;
		
		  draw "Profile: (P)" color: profile ? #white :#grey at:  {posCE.x, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);		 
		  draw "Safety: (S)" color: safety ?  #white :#grey at:  {posCE.x+offsetX, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);	
		  draw "Health: (H)" color: health ?  #white :#grey at:  {posCE.x+2*offsetX, posCE.y} perspective: true font:font("Helvetica", 20 , #bold);		  
			
		}
			species people aspect:dynamique;
			species ViralPeople aspect:dynamic;
			event["p"] action: {profile<-true;safety<-false;health<-false;};
			event["s"] action: {profile<-false;safety<-true;health<-false;};
			event["h"] action: {profile<-false;safety<-false;health<-true;};
			event["c"] action: {autonomy<-false;ask world{do updateSim(autonomy);}};
			event["a"] action: {autonomy<-true;ask world{do updateSim(autonomy);}};
			event ["i"] action:{reinitCovid<-true;};
			
			chart "Population: " type: series x_serie_labels: "time" background:backgroundColor
			x_label: 'Infection rate: '+infection_rate + " Quarantine: " + length(people where !each.isMoving) + " Mask: " + length( ViralPeople where each.as_mask)
			y_label: 'Case'
			position:{world.shape.width/6,world.shape.height*0.95}
			size:{0.5,0.5}
			{
			data "susceptible" value: nb_susceptible color: #green;
			data "infected" value: nb_infected color: #red;	
			data "recovered" value: nb_recovered color: #blue;
			data "death" value: nb_death color: #black;
		}
		}
		
	}
}

