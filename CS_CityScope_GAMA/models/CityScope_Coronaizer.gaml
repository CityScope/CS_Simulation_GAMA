/***
* Name: CityScope Epidemiology
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model CityScopeCoronaizer

import "CityScope_main.gaml"

global{
	float socialDistance <- 2#m;
	float quarantineRatio <- 0.5;
	float quarantineRatio_prev<-quarantineRatio;
	float maskRatio <- 0.2;
	float maskRatio_prev<-maskRatio;
	
	
	bool a_boolean_to_disable_parameters <- true;
   	int number_day_recovery<-10;
	int time_recovery<-1440*number_day_recovery*60;
	float infection_rate<-0.05;
	int initial_nb_infected<-1;
	float step<-1#mn;
	
	bool drawInfectionGraph <- false;
	bool drawSocialDistanceGraph <- false;
	bool draw_grid <- false;
	bool showPeople<-true;
	

	int nb_cols <- int(75*1.5);
	int nb_rows <- int(50*1.5);
	

	int nb_susceptible  <- 0 update: length(ViralPeople where (each.is_susceptible));
	int nb_infected <- 0 update: length(ViralPeople where (each.is_infected));
	int nb_recovered <- 0 update: length(ViralPeople where (each.is_recovered));
	graph<people, people> infection_graph <- graph<people, people>([]);
	graph<people, people> social_distance_graph <- graph<people, people>([]);
	
	init{
			
	}
	
	reflex initCovid when:cycle=1{
		ask initial_nb_infected among ViralPeople{
			is_susceptible <-  false;
	        is_infected <-  true;
	        is_immune <-  false;
	        is_recovered<-false;
		}
		ask ViralPeople{
			if (flip(maskRatio)){
				as_mask<-true;
			}
		}
		ask (quarantineRatio*length(people)) among ViralPeople{
			target.isMoving<-false;
		}
	}
	reflex updateGraph when: (drawSocialDistanceGraph = true) {
		social_distance_graph <- graph<people, people>(people as_distance_graph (socialDistance));
	}
	
	
	reflex manageDynamicValue {
		if(quarantineRatio_prev != quarantineRatio or maskRatio_prev!=maskRatio) {
			if(quarantineRatio>quarantineRatio_prev){
			  ask ((quarantineRatio - quarantineRatio_prev)*length(people)) among (people where (each.isMoving)){
			      isMoving<-false;
		      }
			}else{
				ask ((quarantineRatio_prev - quarantineRatio)*length(people)) among (people where (!each.isMoving)){
			      isMoving<-true;
		      }
			}
			if(maskRatio>maskRatio_prev){
			  ask ((maskRatio - maskRatio_prev)*length(people)) among (ViralPeople where (!each.as_mask)){
			      as_mask<-true;
		      }
			}else{
				ask ((maskRatio_prev-maskRatio)*length(people)) among (ViralPeople where (each.as_mask)){
			      as_mask<-false;
		      }
			}
		}
		quarantineRatio_prev <- quarantineRatio;
		maskRatio_prev<-maskRatio;
	}
}

species ViralPeople  mirrors:people{
	point location <- target.location update: {target.location.x,target.location.y,target.location.z+5};
	bool is_susceptible <- true;
	bool is_infected <- false;
    bool is_immune <- false;
    bool is_recovered<-false;
    bool as_mask<-false;
    float infected_time<-0.0;
    geometry shape<-circle(1);
		
	reflex infected_contact when: is_infected and !as_mask{
		ask ViralPeople where !each.as_mask at_distance socialDistance {
			if (flip(infection_rate)) {
        		is_susceptible <-  false;
            	is_infected <-  true;
            	infected_time <- time; 
            	ask (cell overlapping self.target){
					nbInfection<-nbInfection+1;
					if(firstInfectionTime=0){
						firstInfectionTime<-time;
					}
				}
				infection_graph <<edge(self,myself);
        	}
		}
	}
	
	reflex recover when: (is_infected and (time - infected_time) >= time_recovery){
		is_infected<-false;
		is_recovered<-true;
	}

	
	aspect base {
		if(showPeople){
		  draw circle(is_infected ? 7#m : 5#m) color:(is_susceptible) ? #green : ((is_infected) ? #red : #blue);	
		}
		if (as_mask){
		  draw square(4#m) color:#white;	
		}
	}
}
grid cell cell_width: world.shape.width/50 cell_height:world.shape.width/50 neighbors: 8 {
	bool is_wall <- false;
	bool is_exit <- false;
	rgb color <- #white;
	float firstInfectionTime<-0.0;
	int nbInfection;
	aspect default{
		if (draw_grid){
			if(nbInfection>0){
			  draw shape color:blend(#white, #red, firstInfectionTime/time)  depth:nbInfection;		
			}
		}
	}	
}

experiment Coronaizer type:gui autorun:true{

	//float minimum_cycle_duration<-0.02;
	parameter "Social distance:" category: "Policy" var:socialDistance min: 1.0 max: 100.0 step:1;
	parameter "Quarantine Ratio:" category: "Policy" var:quarantineRatio min: 0.0 max: 1.0 step:0.1;
	parameter "Mask Ratio:" category: "Policy" var: maskRatio min: 0.0 max: 1.0 step:0.1;
	bool a_boolean_to_disable_parameters <- true;
	parameter "Disable following parameters" category:"Corona" var: a_boolean_to_disable_parameters disables: [time_recovery,infection_rate,initial_nb_infected,step];
	parameter "Nb recovery day"   category: "Corona" var:number_day_recovery min: 1 max: 30;
	parameter "Infection Rate"   category: "Corona" var:infection_rate min:0.0 max:1.0;
	parameter "Initial Infected"   category: "Corona" var: initial_nb_infected min:0 max:100;
	parameter "Simulation Step"   category: "Corona" var:step min:0.0 max:100.0;
	parameter "Social Distance Graph:" category: "Visualization" var:drawSocialDistanceGraph ;
	parameter "Infection Graph:" category: "Visualization" var:drawInfectionGraph ;
	parameter "Draw Grid:" category: "Visualization" var:draw_grid;
	parameter "Show People:" category: "Visualization" var:showPeople;
	
	output{
	  layout #split;
	  display CoronaMap type:opengl background:#white draw_env:false synchronized:false{
	  	species building aspect:base;
	  	species road aspect:base;
	  	species ViralPeople aspect:base;
	  	species cell aspect:default;
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
		graphics "text" {
	      draw "day" + string(current_day) + " - " + string(current_hour) + "h" color: #gray font: font("Helvetica", 25, #italic) at:{world.shape.width * 0.8, world.shape.height * 0.975};
	  	}	
	  }	
	 display CoronaChart refresh:every(#day/2) toolbar:false {
		chart "Population in "+cityScopeCity type: series x_serie_labels: (current_day) x_label: 'Infection rate: '+infection_rate + " Quarantine: " + length(people where !each.isMoving) + " Mask: " + length( ViralPeople where each.as_mask) y_label: 'Case'{
			data "susceptible" value: nb_susceptible color: #green;
			data "infected" value: nb_infected color: #red;	
			data "recovered" value: nb_recovered color: #blue;
		}
	  }
	}		
}


experiment CityScopeMulti type: gui parent: Coronaizer
{
	init
	{
		create simulation with: [cityScopeCity:: "volpe", infection_rate::0.005];
	}
	output
	{
	}

}
experiment CityScopeMultiCity type: gui parent: Coronaizer
{
	init
	{	
		create simulation with: [cityScopeCity:: "Taipei"];
		create simulation with: [cityScopeCity:: "otaniemi"];
		create simulation with: [cityScopeCity:: "Lyon"];		
	}
	output
	{
	}

}

