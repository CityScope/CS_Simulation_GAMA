/**
* Name: SolarBlockChain
* Author: Luis Alonso, Tri Nguyen Huu and Arnaud Grignard
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
	map<string,int> energy_price_map<- ["OL"::10, "OM"::7,  "OS"::6,  "RL"::3, "RM"::2,  "RS"::1];
	matrix consumption_matrix ;
	map<string,rgb> class_color_map<- ["OL"::rgb(12,30,51), "OM"::rgb(31,76,128),  "OS"::rgb(53,131,219),  "RL"::rgb(143,71,12), "RM"::rgb(219,146,25),  "RS"::rgb(219,198,53), "PL"::rgb(110,46,100), "PM"::rgb(127,53,116),  "PS"::rgb(179,75,163), "Park"::rgb(142,183,31)];
		file my_csv_file <- csv_file("../includes/171203_Energy_Consumption_CSV.csv",",");
	file my_csv_file2 <- csv_file("../includes/171203_Energy_Production_CSV.csv",",");
	float average_surface;
	float max_surface;
	float max_energy;
	matrix production_matrix;
	float max_produce_energy;
	int distance <- 100 min: 1 max:1000 parameter: "Sharing Distance:" category: "Simulation";
	
	init{
		
		
		create building from: buildings_shapefile with: 
		[usage::string(read ("Usage")),scale::string(read ("Scale")),category::string(read ("Category")), nbFloors::1+float(read ("Floors"))]{
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
	    price <-	energy_price_map[usage+scale];			
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
	bool isSeller;
	float energyPrice;
	float price;
	building myBuyer;
		
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
		//write production_matrix[mod (time,24)+1,1];
		//write production_matrix;
		//write consumption;
	}
	
	reflex updateSellingStatus{
		if(production-consumption>0){
			isSeller<-true;
		}
		else{
			isSeller<-false;
		}
	}
	
	reflex sharingEnergy{
		if(isSeller){
			list<building> nearest_building<- building where (!each.isSeller) at_distance distance;
			if(length(nearest_building)=0){
				write "it's a shame i cannot sell my stuff";
				myBuyer<-nil;
				
			}else{
			  myBuyer<- nearest_building with_min_of price;	
			}
			

			
		}else{
			
		}
	}
	
	float color_magnitude(float value, float steepness, float midpoint){
		return 255/(1+exp(steepness*(midpoint-value)));
	}

//	reflex essai{// when: max_produce_energy < 10 {
//		write max_produce_energy;
//	}
	
	aspect prod{
		//draw shape color:rgb(((production-minProd)/maxProd)*255,0,0);
		draw shape color:rgb((3.5*production/max_produce_energy)^0.3*255,55-(3.5*production/max_produce_energy)^0.3*55,0);
		//write max_produce_energy;
		if (3.5*production/max_produce_energy*255>255) {	
			write "Power "+(3.5*production/max_produce_energy*255);
		}
	}
	aspect con{
		//draw shape color:rgb(((consumption-minCon)/maxCon)*255,0,0);
		//draw shape color:rgb((3.5*consumption/max_energy)^0.3*255,0,0);
		draw shape color:rgb((3.5*consumption/max_energy)^0.3*255,55-(3.5*consumption/max_energy)^0.3*55,0);
		//draw shape color:rgb(color_magnitude(consumption,1,max_energy/10),0,0);
		
		if 3.5*consumption/max_energy*255>255 {
			//write "Power "+(3.5*consumption/max_energy*255);
		}
		
	}
	aspect diff{
		draw shape color:rgb((consumption - production)*10,(production - consumption)*10,0);
	}
	aspect base {
		
		if category="Park"{
			draw shape color: class_color_map["Park"];
		}
		else{
			draw shape color: class_color_map[usage+scale];
		}
	}
	aspect selling{
		if(isSeller){
			if(myBuyer != nil){
				draw line([self.location,myBuyer.location]) color:rgb(48,78,208) width:1 end_arrow:5;
			}else{
				draw circle(20) color:rgb(208,73,20);
			}
		 
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
		display chartprod
		{
			chart prod axes:#white 
			{
				data 'production' value:sum(building collect each.production) color:#red marker:false thickness:2.0;
				data 'consumption' value:sum(building collect each.consumption) color:#blue marker:false thickness:2.0;
				data 'Differential' value:sum(building collect each.consumption) - sum(building collect each.production) color:#green marker:false thickness:2.0;
			}
		}
		display chartprodhist
		{
			chart prod axes:#white type:histogram style:stack
			{
				data 'production' value:sum(building collect each.production) accumulate_values:true color:#red marker:false thickness:2.0;
				data 'consumption' value:-sum(building collect each.consumption)  accumulate_values:true color:#blue marker:false thickness:2.0;
			}
		}
		display view  type:opengl  {		
			species building aspect:base;
			chart prod size:{0.5,0.5} position:{world.shape.width*1.1,0} axes:#white 
			{
				data 'production' value:sum(building collect each.production) color:#red marker:false thickness:2.0;
				data 'consumption' value:sum(building collect each.consumption) color:#blue marker:false thickness:2.0;
				data 'Differential' value:sum(building collect each.consumption) - sum(building collect each.production) color:#green marker:false thickness:2.0;
			}
		}
		display prod  type:opengl  {		
			species building aspect:prod;
		}
		display cons  type:opengl  {		
			species building aspect:con;
		}
		display diff  type:opengl  {		
			species building aspect:diff;
		}
		
		display sharing type:opengl{
			species building aspect:diff;
			species building aspect:selling;
		}
	}
}



