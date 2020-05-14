/***
* Name: CityScope Epidemiology
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model CityScopeCoronaizer

//import "./../CityScope/CityScope_main.gaml"
import "./Autonomous_Covid_Community.gaml"

global{
	float socialDistance <- 2#m;
	float quarantineRatio <- 0.0;
	float quarantineRatio_prev<-quarantineRatio;
	float maskRatio <- 0.0;
	float maskRatio_prev<-maskRatio;
	
	
	bool a_boolean_to_disable_parameters <- true;
   	int number_day_recovery<-10;
	int time_recovery<-1440*number_day_recovery*60;
	float infection_rate<-0.2;
	float mortality_rate<-0.1;
	int initial_nb_infected<-1;
	bool reinitCovid<-false;
	bool stopCovid<-false;
	//float step<-1#mn;
	
	bool drawInfectionGraph <- false;
	bool drawSocialDistanceGraph <- false;
	bool draw_grid <- false;
	bool showPeople<-true;
	float viralPeopleTransparency<-0.5;
	bool savetoCSV<-false;
	string filePathName;
	

	int nb_cols <- int(75*1.5);
	int nb_rows <- int(50*1.5);
	

	int nb_susceptible  <- 0 update: length(ViralPeople where (each.is_susceptible));
	int nb_infected <- 0 update: length(ViralPeople where (each.is_infected));
	int nb_recovered <- 0 update: length(ViralPeople where (each.is_recovered));
	int nb_death<-0;
	graph<people, people> infection_graph <- graph<people, people>([]);
	graph<people, people> social_distance_graph <- graph<people, people>([]);
	
	init{
		filePathName <-"../results/output"+date("now")+".csv";
	}
	
	reflex initCovid when:reinitCovid{
		ask ViralPeople{
			is_susceptible <-  true;
			is_infected <-  false;
	        is_immune <-  false;
	        is_recovered<-false;
		}
		
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
		infection_graph<-graph<people, people>([]);
		reinitCovid<-false;
		reinit<-false;
	}
	
	reflex stopCovid when:stopCovid{
		ask ViralPeople{
			is_susceptible <-  true;
			is_infected <-  false;
	        is_immune <-  false;
	        is_recovered<-false;
		}
		stopCovid<-false;
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
			      isQuarantine<-false;
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
	
	reflex updateDeath when:every(#day){
		ask (ViralPeople where (each.is_infected)){
			if flip(mortality_rate){
				nb_death<-nb_death+1;
				ask target{do die;}
				do die;
				
			}
		}
	}
	reflex save_model_output when: every(#day) and savetoCSV{
		// save the values of the variables name, speed and size to the csv file; the rewrite facet is set to false to continue to write in the same file
		save [time,nb_susceptible,nb_infected, nb_recovered, nb_death] to: filePathName type:"csv" rewrite: false;
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
			if (flip(infection_rate/step)) {
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
	aspect health {
		if(showPeople){
		  draw circle(world.shape.width/300) color:(is_susceptible) ? rgb(#green,viralPeopleTransparency) : ((is_infected) ? rgb(#red,viralPeopleTransparency) : rgb(#blue,viralPeopleTransparency));	
		}
		if (as_mask){
		  draw square(world.shape.width/600) color:#white;	
		}
	}
	
	aspect safety{
		if(showPeople ){
		  if(target.isQuarantine){
		    draw circle(9#m) color:rgb(135,206,250) border:rgb(135,206,250)-100;		
		  }
		  if (as_mask){
		    draw circle(7#m) color:rgb(70,130,180) border:rgb(70,130,180)-100;	
		  }	
		  draw circle(5#m) color:rgb(0,0,125) border:rgb(0,0,125)-100;
		}
	}
	
	aspect dynamic{
		if(safety){
          if(target.isQuarantine){
		    draw circle(world.shape.width/300*1.5) color:rgb(135,206,250) border:rgb(135,206,250)-100;		
		  }
		  if (as_mask){
		    draw circle(world.shape.width/300*1.3) color:rgb(70,130,180) border:rgb(70,130,180)-100;	
		  }	
		  draw circle(world.shape.width/300) color:rgb(0,0,125) border:rgb(0,0,125)-100;
		  if(drawTrajectory){
		    draw line(target.current_trajectory)  color: rgb(#white,trajectoryTransparency);
		  }
		}
		if(health){
		  draw circle(world.shape.width/300) color:(is_susceptible) ? rgb(#green,viralPeopleTransparency) : ((is_infected) ? rgb(#red,viralPeopleTransparency) : rgb(#blue,viralPeopleTransparency));	
		  if (as_mask){
		   draw square(4#m) color:#white;	
		  }	
		  if(drawTrajectory){
		    draw line(target.current_trajectory)  color: rgb(#white,trajectoryTransparency);
		  }
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

experiment Coronaizer type:gui autorun:true virtual:true{

	float minimum_cycle_duration<-0.02;
	parameter "Quarantine Ratio:" category: "Policy Covid" var:quarantineRatio min: 0.0 max: 1.0 step:0.1;
	parameter "Mask Ratio:" category: "Policy Covid" var: maskRatio min: 0.0 max: 1.0 step:0.1;
	bool a_boolean_to_disable_parameters <- true;
	parameter "Disable following parameters" category:"Covid" var: a_boolean_to_disable_parameters disables: [time_recovery,infection_rate,initial_nb_infected,mortality_rate,socialDistance];
	parameter "Nb recovery day"   category: "Covid" var:number_day_recovery min: 1 max: 30;
	parameter "Infection Rate"   category: "Covid" var:infection_rate min:0.0 max:1.0;
	parameter "Mortality"   category: "Covid" var: mortality_rate min:0.0 max:1.0;
	parameter "Initial Infected"   category: "Covid" var: initial_nb_infected <-1 min:0 max:100;
	parameter "Contamination Distance:" category: "Covid" var:socialDistance min: 1.0 max: 1000.0 step:1;
	parameter "Social Distance Graph:" category: "Covid Visualization" var:drawSocialDistanceGraph ;
	parameter "Infection Graph:" category: "Covid Visualization" var:drawInfectionGraph ;
	parameter "Draw Grid:" category: "Covid Visualization" var:draw_grid;
	parameter "Show People:" category: "Covid Visualization" var:showPeople;
	parameter "Viral People Transparency:" category: "Covid Visualization" var:viralPeopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Save results to CSV:" category: "Simulation Covid" var:savetoCSV;
	
	output{
	  layout #split;
	  /*display CoronaMap type:opengl background:backgroundColor draw_env:false synchronized:false toolbar:false
	  {  	
	  	species building aspect:default;
	  	species ViralPeople aspect:safety;
	  	species cell aspect:default;
	  	

			
	graphics "text" {
	     // draw "day" + string(current_day) + " - " + string(current_hour) + "h" color: #gray font: font("Helvetica", 25, #italic) at:{world.shape.width * 0.8, world.shape.height * 0.975};
	  	}	
	  	event ["i"] action:{reinitCovid<-true;};
	  }	
	 display CoronaChart refresh:every(#mn) toolbar:false {
		chart "Population: " type: series x_serie_labels: "time" 
		x_label: 'Infection rate: '+infection_rate + " Quarantine: " + length(people where !each.isMoving) + " Mask: " + length( ViralPeople where each.as_mask)
		y_label: 'Case'{
			data "susceptible" value: nb_susceptible color: #green;
			data "infected" value: nb_infected color: #red;	
			data "recovered" value: nb_recovered color: #blue;
			data "death" value: nb_death color: #black;
		}
	  }*/
	}		
}

