/**
* Name: SolarBlockChain
* Author: Luis Alonso
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model SolarBlockChain

/* Insert your model definition here */

global{
	string cityScopeCity <-"Andorra";
	// GIS FILE //	
	file bound_shapefile <- file("./../includes/"+cityScopeCity+"/Bounds.shp");
	file buildings_shapefile <- file("./../includes/"+cityScopeCity+"/Buildings.shp");
	file roads_shapefile <- file("./../includes/"+cityScopeCity+"/Roads.shp");
	file table_bound_shapefile <- file("./../includes/"+cityScopeCity+"/table_bounds.shp");
	file imageRaster <- file('./../images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	int maxProd;
	int minProd;
	int maxCon;
	int minCon;
	map<string,int> class_map<- ["OL"::2, "OM"::3,  "OS"::3,  "RL"::4, "RM"::5,  "RS"::6, "PL"::7, "PM"::8,  "PS"::9];
	matrix consumption_matrix ;
	map<string,rgb> class_color_map<- ["OL"::rgb(12,30,51), "OM"::rgb(31,76,128),  "OS"::rgb(53,131,219),  "RL"::rgb(143,71,12), "RM"::rgb(219,146,25),  "RS"::rgb(219,198,53), "PL"::rgb(110,46,100), "PM"::rgb(127,53,116),  "PS"::rgb(179,75,163), "Park"::rgb(142,183,31)];
		file my_csv_file <- csv_file("../includes/171203_Energy_Consumption_CSV.csv",",");
	file my_csv_file2 <- csv_file("../includes/171203_Energy_Production_CSV.csv",",");
	float average_surface;
	float max_surface;
	float max_energy;
	matrix production_matrix;
	float max_produce_energy;
	
	init{
		
		
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale")),category::string(read ("Category")), nbFloors::1+float(read ("Floors"))]{
	    //option1
	    //consumption<-consomption_map[usage];
		
		
		//option2
		if(usage="R"){//Residential
			//write "hey guys I am a residential";	
			if(scale="S"){
				consumption<-4.2;
			}
			if(scale="M"){
				consumption<-4.2;
			}
			if(scale="L"){
				consumption<-4.2;
			}
		}
		if(usage="O"){//Residential
			//write "hey guys I am a Office and my scale";
			consumption<-2.3;
		}
		
			
			area <-shape.area;
			//consumption<-area* (50+rnd(50));
			//production<-area* (10+rnd(10));
		}
		//maxProd<-max(building collect int(each["production"]));
		//minProd<-min(building collect int(each["production"]));
		//maxCon<-max(building collect int(each["consumption"]));
		//minCon<-min(building collect int(each["consumption"]));
		
		max_surface <-max (building collect (each.area));
		write max_surface;
		

		

		
		average_surface<-mean (building collect (each.area));
		write average_surface;
	
	//convert the file into a matrix
		consumption_matrix <- matrix(my_csv_file); 

		max_energy <- float (max (consumption_matrix))*max_surface;
				write 'max '+max_energy;	
				
		/*//loop on the matrix rows (skip the first header line)
		loop i from: 1 to: consumption_matrix.rows -1{
			//loop on the matrix columns
			loop j from: 0 to: consumption_matrix.columns -1{
				//write "consumption_matrix rows:"+ i +" colums:" + j + " = " + consumption_matrix[j,i];
		
			}	
		}*/
		production_matrix <- matrix(my_csv_file2); 

		max_produce_energy <- float (max (production_matrix))*max_surface;
				write 'max '+max_produce_energy;	
	}
	
	
	reflex show_time{
		write "It is "+int(time)+':00';

		
	}
	

	
}

species building {
	rgb color;
	float area;
	float production <-0;
	float consumption <-0;
	string usage; 
	string scale;
	float nbFloors;
	string category;
		
	//float get_consumption(string class,int t){
		//write float(consumption_matrix[t+1,class_map[class]])*((1/2)*(1+sqrt(average_surface/(area+1))))*(area*nbFloors);
		//return float(consumption_matrix[t+1,class_map[class]])*((1/2)*(1+sqrt(average_surface/(area+1))))*(area*nbFloors);
	//}
	
	reflex calculate_consumption when:not (category= "Park"){
		consumption<-float(consumption_matrix[mod (time,24)+1,class_map[usage+scale]])*((1/2)*(1+sqrt(average_surface/(area+1))))*(area*nbFloors);
		//write consumption;
	}
	
	reflex calculate_production when:not (category= "Park"){
		production<-float(production_matrix[mod (time,24)+1,1])*((1/2)*(1+sqrt(average_surface/(area+1))))*area;
		write production_matrix[mod (time,24)+1,1];
		write production_matrix;
		//write consumption;
	}
	
	float color_magnitude(float value, float steepness, float midpoint){
		return 255/(1+exp(steepness*(midpoint-value)));
	}

	
	aspect prod{
		//draw shape color:rgb(((production-minProd)/maxProd)*255,0,0);
		draw shape color:rgb((3.5*production/max_produce_energy)^0.3*255,55-(3.5*production/max_produce_energy)^0.3*55,0);
		
		if 3.5*production/max_produce_energy*255>255 {
			write "Power "+(3.5*production/max_produce_energy*255);
		}
	}
	aspect con{
		//draw shape color:rgb(((consumption-minCon)/maxCon)*255,0,0);
		//draw shape color:rgb((3.5*consumption/max_energy)^0.3*255,0,0);
		draw shape color:rgb((3.5*consumption/max_energy)^0.3*255,55-(3.5*consumption/max_energy)^0.3*55,0);
		//draw shape color:rgb(color_magnitude(consumption,1,max_energy/10),0,0);
		
		if 3.5*consumption/max_energy*255>255 {
			write "Power "+(3.5*consumption/max_energy*255);
		}
		
	}
	aspect diff{
		draw shape color:rgb((production-consumption)*10,0,0);
	}
	aspect base {
		
		if category="Park"{
			draw shape color: class_color_map["Park"];
		}
		else{
			draw shape color: class_color_map[usage+scale];
		}
	}
}

species road {
	rgb color;
	aspect base {
		draw shape color: color;
	}
}

experiment start type: gui {
	output {
		display view  type:opengl  {		
			species building aspect:base;
		}
		display prod  type:opengl  {		
			species building aspect:prod;
		}
		display cons  type:opengl  {		
			species building aspect:con;
		}
		display diff  type:opengl  {		
			species building aspect:base;
		}
	}
}



