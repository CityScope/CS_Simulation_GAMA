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
	float maskRatio <- 0.0;
	float gloveRatio <- 0.0;
	
	
	bool a_boolean_to_disable_parameters <- true;
    int number_day_recovery<-15;
	int time_recovery<-1440*60*number_day_recovery;
	float infection_rate<-0.005;
	int initial_nb_infected<-1;
	float step<-1#mn;
	
	bool drawDirectGraph <- false;
	bool draw_grid <- false;
	

	int nb_cols <- int(75*1.5);
	int nb_rows <- int(50*1.5);
	

	int nb_susceptible  <- 0 update: length(ViralPeople where (each.state='susceptible'));
	int nb_infected <- 0 update: length(ViralPeople where (each.state='infected'));
	int nb_recovered <- 0 update: length(ViralPeople where (each.state='recovered'));
	graph<people, people> social_distance_graph;
	
	init{
		ask initial_nb_infected among ViralPeople{
			is_susceptible <-  false;
	        is_infected <-  true;
	        is_immune <-  false; 
		}	
	}
	reflex updateGraph when: (drawDirectGraph = true) {
		social_distance_graph <- graph<people, people>(people as_distance_graph (socialDistance));
	}
}


species ViralPeople control: fsm mirrors:people{
	point location <- target.location update: {target.location.x,target.location.y,target.location.z+5}; 
	bool is_susceptible <- true;
	bool is_infected <- false;
    bool is_immune <- false;
    float infected_time<-0.0;

	state init initial: true {
		transition to: infected when: flip(0.01) {
    	}
    	transition to: susceptible when: is_susceptible {
    	}
	}
	state susceptible {
		transition to: infected when: is_infected {
    	}
	}
	state infected {
		enter {
			infected_time <- time;
		}
 		transition to: recovered when: (time - infected_time) >= time_recovery {
    	}
	}
	state recovered final: true {
	}
		
	reflex infected_contact when: state='infected' {
		ask ViralPeople at_distance socialDistance {
			if (flip(infection_rate)) {
        	is_susceptible <-  false;
            is_infected <-  true; 
        }
		}
	}

	aspect base {
		draw circle(is_infected ? 7#m : 5#m) color:(state = 'susceptible') ? #green : ((state = 'infected') ? #red : #blue);
	}
}
grid cell width: nb_cols height: nb_rows neighbors: 8 {
	bool is_wall <- false;
	bool is_exit <- false;
	rgb color <- #white;
	int nbCollision;
	aspect default{
		/*if (draw_grid){
		  draw shape color:is_wall? #red:#black border:rgb(75,75,75) empty:false;	
		}*/
		if (draw_grid){
			if(nbCollision>0){
			  draw shape color:rgb(nbCollision) empty:false border:rgb(nbCollision);		
			}
		}
	}	
}

experiment Coronaizer type:gui {

	parameter "Social distance:" category: "Policy" var:socialDistance min: 1.0 max: 100.0 step:1;
	
	
	
	parameter "Mask Ratio:" category: "Policy" var: maskRatio min: 0.0 max: 1.0 step:0.1;
	parameter "Glove Ratio:" category: "Policy" var: gloveRatio min: 0.0 max: 1.0 step:0.1;
	
	
	bool a_boolean_to_disable_parameters <- true;
	parameter "Disable following parameters" category:"Corona" var: a_boolean_to_disable_parameters disables: [time_recovery,infection_rate,initial_nb_infected,step];
	parameter "Nb recovery day"   category: "Corona" var:number_day_recovery min: 1 max: 30;
	parameter "Infection Rate"   category: "Corona" var:infection_rate min:0.0 max:1.0;
	parameter "Initial Infected"   category: "Corona" var: initial_nb_infected min:0 max:100;
	parameter "Simulation Step"   category: "Corona" var:step min:0.0 max:100.0;
	
	parameter "Social Distance Graph:" category: "Visualization" var:drawDirectGraph ;
	parameter "Draw Grid:" category: "Visualization" var:draw_grid;
	
	output{
	  layout #split;
	  
	
	  display CoronaMap type:opengl background:#white draw_env:false toolbar:false{
	  	species building aspect:base;
	  	species road aspect:base;
	  	species ViralPeople aspect:base;
	  	species cell aspect:default;
	  	graphics "simulated_graph" {
				if (social_distance_graph != nil and drawDirectGraph = true) {
					loop eg over: social_distance_graph.edges {
						geometry edge_geom <- geometry(eg);
						draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) color:#gray;
						ask (cell overlapping edge_geom){
							nbCollision<-nbCollision+1;
						}
					}

				}
			}
		graphics "text" {
	    	draw "day" + string(current_day) + " - " + string(current_hour) + "h" color: #gray font: font("Helvetica", 25, #italic) at:{world.shape.width * 0.8, world.shape.height * 0.975};
	  	}	
	  }	
	  display CoronaChart refresh:every(#hour) toolbar:false {
		chart "Population in "+cityScopeCity type: series x_serie_labels: (current_day) x_label: 'Day' y_label: 'Case'{
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
		create simulation with: [cityScopeCity:: "Taipei", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "otaniemi", minimum_cycle_duration::0.02, cityMatrix::false];			
	}

	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <- "volpe" among: ["volpe", "andorra","San_Francisco","Taipei_MainStation","Shanghai"];
	float minimum_cycle_duration <- 0.02;
	output
	{
	}

}

