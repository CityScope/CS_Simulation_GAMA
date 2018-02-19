/**
* Name: pie
* Author: Tri
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model pie_charts

/* Insert your model definition here */

/* 
global{
	list<rgb> color_list <- [rgb(3,169,244),rgb(255,235,59),rgb(255,152,0),rgb(255,87,34)];
	list<float> valeurs <- [4,7,22];
	
	init{
		create pie{
			labels <- ["Chat","Chien","Poulet"];
			labels_h_offset <- [15,15,18];
			values <- valeurs;
			colors <- [color_list[1],color_list[2],color_list[3]];
			location <-{50,50};
			diameter <- 50;
			inner_diameter <- 40;
			font_size <- round(diameter/30);
			type <- "ring";
		}
	}
		
	reflex change{
		loop i from: 0 to: length(valeurs)-1{
			valeurs[i] <- max([0,valeurs[i] -2 + rnd(4)]);
		}
		ask first(pie) {
			do calculate_pies;
			do update_values(valeurs);
		}
		
	}	
		
}*/
	
	species pie{
		/* general parameters that must be set by the user */
		string id;
		string type <- "pie"; // among "pie", "ring"
		list<string> labels; // labels of the categories to be displayed
		list<float> values; // values to be displayed
		list<rgb> colors; // colors of the different categories
		
		/* display parameters  */
		float diameter <- 50.0; // pie or ring diameter
		float inner_diameter <- 40.0; // ring inner diameter
		int nb_points <- 72; // number of points on the outer circle, useful to set the level of detail
		float labels_v_offset <- 1.3; // vertical offset for labels
		list<float> labels_h_offset; // horizontal offset for strings which are displayed on the left side of the chart. Necessary until the string display is fixed in Gama
		float font_size <- 20.0;
		float line_width <- float(round(diameter/30));
		
		/* parameters for internal use */
		list<list<point>> pies <-[];
		list<list<point>> label_lines <-[];
		list<point> label_locations <-[];
		
		list<point> calculate_slice(int start_index, int end_index){ // calculate the vertices coordinates for one slice of the pie
			list<point> vertices <- (type = "ring")?[]:[location];
			loop i from: start_index to: end_index{
				vertices << {location.x + sin(i/nb_points * 360)*diameter/2, location.y -cos(i/nb_points * 360)*diameter/2};
			}
			if type = "ring"{
				loop i from: start_index to: end_index {
					vertices << {location.x + sin((end_index+start_index-i)/nb_points * 360)*inner_diameter/2, location.y -cos((end_index+start_index-i)/nb_points * 360)*inner_diameter/2};
				}
			}
			return vertices;
		} 
		
		action update_values(list<float> val){// function use to update the values
			self.values <- val;
		}
			
		action calculate_pies{// main function for drawing the pie
			int nb_pies <- length(values);
			pies <- [];
			label_lines <- [];
			label_locations <- [];
			list<int> pies_indexes <- [0];
			if (sum(values) = 0) { // if all values are equal to 0
				pies <- list_with(nb_pies, []);
				pies[0] <- calculate_slice(0,nb_points);
				label_lines <- list_with(nb_pies, [location + {diameter/2,0},location + {diameter/1.3,0}]);
				label_locations <- list_with(nb_pies,location + {diameter/1.3,0});	
			}else{ // in the general case
				list<float> cum_sum <- [0.0];
				loop i from: 0 to: nb_pies-1{
					cum_sum << last(cum_sum) +  values[i]/sum(values) * nb_points;
				}
				pies_indexes <- cum_sum collect (round(each));
				loop i from:0 to: nb_pies-1{ 
					pies << calculate_slice(pies_indexes[i],pies_indexes[i+1]);
					float angle <-  (pies_indexes[i+1] + pies_indexes[i]) * 180 / nb_points;
					label_locations << location+{2+signum(sin(angle))*(diameter/1.3) - int(sin(angle)<0)* labels_h_offset[i],-cos(angle)*diameter/1.5+labels_v_offset};
					//label_lines << [location+{sin(angle)*diameter/2.2,-cos(angle)*diameter/2.2}, location+{sin(angle)*diameter/1.5,-cos(angle)*diameter/1.5},location+{signum(sin(angle))*diameter/1.3,-cos(angle)*diameter/1.5}];
					label_lines << [location+{sin(angle)*diameter/2,-cos(angle)*diameter/2}, location+{sin(angle)*diameter/1.5,-cos(angle)*diameter/1.5},location+{signum(sin(angle))*diameter/1.3,-cos(angle)*diameter/1.5}];
				}
			}
		}	
		

		aspect default{
			loop i from:0 to: length(values)-1{ 
				draw polygon(pies[i]) color: colors[i] ;
				draw polyline(label_lines[i]) color: colors[i] width: line_width;
				draw labels[i] font: font("Helvetica",font_size,#plain)  at: label_locations[i] color: colors[i] ;
			}
		}
		
	}
	
	



/* 
experiment "Pie Charts" type: gui{
	
	output {
		display camembert type: opengl background: color_list[0]  {
			species pie aspect:default;
		}		
	
	}
}*/