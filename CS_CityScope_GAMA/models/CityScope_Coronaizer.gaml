/***
* Name: CityScope Epidemiology
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model CityScopeCoronaizer

import "CityScope_main.gaml"

global{
	float socialDistance <- 20#m parameter: "Social distance:" category: "Corona" min: 1.0 max: 100.0 step:1;
	float time_recovery<-1000.0 parameter: "Recovery Time"   category: "Corona" min: 1.0 max: 10000.0;
	float infection_rate<-0.01 parameter: "Infection Rate"   category: "Corona" min:0.0 max:1.0;
	int initial_nb_infected<-50 parameter: "Infection Rate"   category: "Corona" min:0 max:100;
	bool drawDirectGraph <- false parameter: "Social Distance Graph:" category: "Corona";
	bool draw_grid <- false parameter: "Draw Grid:" category: "Corona";
	int nb_cols <- int(75*1.5);
	int nb_rows <- int(50*1.5);

	int nb_susceptible  <- 0 update: length(ViralPeople where (each.state='susceptible'));
	int nb_infected <- 0 update: length(ViralPeople where (each.state='infected'));
	int nb_recovered <- 0 update: length(ViralPeople where (each.state='recovered'));
	graph<people, people> social_distance_graph;
	init{
	//Init from Imported Model is first called	
		ask 50 among ViralPeople{
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
		transition to: recovered when: time - infected_time >= time_recovery*1000 {
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
		draw circle(5#m) color:(state = 'susceptible') ? #green : ((state = 'infected') ? #red : #blue);
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
	output{
	  layout #split;
	  display CoronaMap type:opengl background:#white{
	  	//species building aspect:base;
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
	  }	
	  /*display CoronaChart refresh:every(100#cycle) {
			chart "Population in "+cityScopeCity type: series {
				data "susceptible" value: nb_susceptible color: #green;
				data "infected" value: nb_infected color: #red;	
				data "recovered" value: nb_recovered color: #blue;
			}
		}*/
	}		
}

experiment CityScopeMulti type: gui parent: Corona
{
	init
	{
		create simulation with: [cityScopeCity:: "Taipei", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02, cityMatrix::false];
		//create simulation with: [cityScopeCity:: "Lyon", minimum_cycle_duration::0.02, cityMatrix::false];
		create simulation with: [cityScopeCity:: "otaniemi", minimum_cycle_duration::0.02, cityMatrix::false];			
	}

	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <- "volpe" among: ["volpe", "andorra","San_Francisco","Taipei_MainStation","Shanghai"];
	float minimum_cycle_duration <- 0.02;
	output
	{

	}

}

