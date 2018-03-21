/**
* Name: CaaSl
* Author: doorleyr
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model CaaS

/* Insert your model definition here */
global{
	
	float buying_scale_factor <- 40000.0; // just for drawing
	float selling_scale_factor <- 25000.0; // just for drawing
	
	string cityScopeCity <-"Aalto";
	// GIS FILE //	
	file bound_shapefile <- file("./../../../includes/City/"+cityScopeCity+"/SiteScope_region.shp");
	file buildings_shapefile <- file("./../../../includes/City/"+cityScopeCity+"/bldswTypes.shp");
	file roads_shapefile <- file("./../../../includes/City/"+cityScopeCity+"/osmRoads.shp");
	file table_bound_shapefile <- file("./../../../includes/City/"+cityScopeCity+"/SiteScope_region.shp");
	file imageRaster <- file('./../../images/gama_black.png') ;
	geometry shape <- envelope(bound_shapefile);
	map<string,int> class_map<- ["U"::1, "H"::2,  "E"::3,  "N"::4];
	map<string,int> energy_price_map<- ["U"::10, "H"::10,  "E"::15,  "N"::999];
	matrix consumption_matrix ;
	map<string,rgb> class_color_map<- ["U"::rgb(55,126,184), "H"::rgb(77,175,74),  "E"::rgb(152,78,163),  "N"::rgb(228,26,28)];
		
	file consumption_csv_file <- csv_file("./../../../includes/City/"+cityScopeCity+"/180321_Space_Demand_CSV.csv",",");
	file production_csv_file <- csv_file("./../../../includes/City/"+cityScopeCity+"/180321_Space_Supply_CSV.csv",",");
	float average_surface;
	float max_surface;
	float max_energy;
	matrix production_matrix;
	float max_produce_energy;

	int distance <- 500 min: 1 max:1000 parameter: "Sharing Distance:" category: "Simulation";
	
	init{
		
		create building from: buildings_shapefile with: 
		[btype::string(read ("Type")), nbFloors::1+float(read ("LEGOLayer"))]{

	    price <-float(energy_price_map[btype]);			
		area <-shape.area;
		}
		
		ask building{
			nearest_buildings <- building at_distance distance;
		}
		
		//TODO these min and max make no sense
		max_surface <-max (building collect (each.area));
		average_surface<-mean (building collect (each.area));
	
		consumption_matrix <- matrix(consumption_csv_file); 
		max_energy <- float (max (consumption_matrix))*max_surface;
		write 'Max consumed resources: '+max_energy;	
	
		production_matrix <- matrix(production_csv_file); 
		max_produce_energy <- float (max (production_matrix))*max_surface;
		write 'Max supplied resources: '+max_produce_energy;	
	}
		
	
	reflex simulation{
		string moment <- (mod(time,24)<12? "AM":"PM");
		write "Day "+int(time/24+1)+': '+ (1+mod(time-1,12)) +":00 "+moment;
		ask building {			
			do calculate_consumption;
			do calculate_production ;
			do update_status ;			
		}
	}	
}

species building {
	rgb color;
	float area;
	float production <-0.0;
	float consumption <-0.0;
	string btype;
	float nbFloors;
	string status <- "idle"; //among "buying", "selling", "finished_buying", "finished_selling","idle"
	float energyPrice;
	float price;
	float energy_shared;
	list<building> mySellers;
	list<building> nearest_buildings;

			
	action calculate_consumption {
		//TODO calculation of consumption
		consumption<-float(consumption_matrix[mod (time,24)+1,class_map[btype]])*((1/2)*(1+sqrt(average_surface/(area+1))))*(area*nbFloors);
	}
	
	action calculate_production {
		//TODO calculation of production
		production<-float(production_matrix[mod (time,24)+1,class_map[btype]])*((1/2)*(1+sqrt(average_surface/(area+1))))*(area*nbFloors);
	}
	
	
	action update_status{
		status <- "idle";
		if(production - consumption>0){
			status<- "selling";
		}
		if(production - consumption<0){
			status<-"buying";
		}
		energy_shared <- 0.0;
	}
	
	reflex sharingEnergy{
		mySellers <- [];
		list<building> nearest_selling_buildings<- nearest_buildings where (each.status="selling");
		loop while: (status = "buying") {//look for sellers because need to buy energy
			if(length(nearest_selling_buildings)=0){//	cannot find anyone who sells energy;
				status <- "finished_buying";
			}else{
			 	building seller <- nearest_selling_buildings with_min_of price;	
			 	mySellers <- mySellers + seller;
			 	nearest_selling_buildings <- nearest_selling_buildings - seller;
			 	float amount_transfered <- min([self.consumption - self.production - energy_shared, seller.production - seller.consumption - seller.energy_shared]);
			 	energy_shared <- energy_shared + amount_transfered;
			 	seller.energy_shared <- seller.energy_shared + amount_transfered;
			 	if (energy_shared = consumption - production){
			 		status <- "finished_buying";	
			 	}
			 	if (seller.energy_shared = seller.production - seller.consumption){
			 		seller.status <- "finished_selling";	
			 	}	 	
			}				
		}
	}
	
	float color_magnitude(float value, float steepness, float midpoint){
		return 255/(1+exp(steepness*(midpoint-value)));
	}

	aspect prod{
		draw shape color:rgb((3.5*production/max_produce_energy)^0.3*255,55-(3.5*production/max_produce_energy)^0.3*55,0);
	}
	
	aspect con{
		draw shape color:rgb((3.5*consumption/max_energy)^0.3*255,55-(3.5*consumption/max_energy)^0.3*55,0);
	}
	
	aspect diff{
		draw shape color:rgb((consumption - production)*255,(production - consumption)*55,0);
	}
	
	aspect base {	
		draw shape color: class_color_map[btype];
	}
		
	aspect status {	
		if (status = "idle"){
			draw shape color:rgb(50,50,50);
		}
		if (status in ["finished_buying","buying"]){
			draw shape color:rgb(50+(consumption - production - energy_shared)/buying_scale_factor*205,0,0);
		}
		if (status in ["finished_selling", "selling"]){
			draw shape color:rgb(min([(production - consumption - energy_shared)/selling_scale_factor*150,150]),50+(production - consumption - energy_shared)/selling_scale_factor*205,min([50,(production - consumption - energy_shared)/selling_scale_factor*50]));
		}
		
	}
	
	aspect sales_network{
			loop while: (not empty(mySellers)){		
				draw line([self.location+{0,0,1},first(mySellers).location+{0,0,1}]) color:rgb(48,78,208) width:1;// end_arrow:5;
				mySellers <- mySellers - first(mySellers);
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
		
		display view1  type:opengl  {	
			species building aspect:base;	
 			chart prod size:{0.5,0.5} position:{world.shape.width*1.1,0} axes:rgb(175,175,175) 
			{
				data 'production' value:sum(building collect each.production) color:rgb(218,82,82) marker:false thickness:2.0;
				data 'consumption' value:sum(building collect each.consumption) color:rgb(76,140,218) marker:false thickness:2.0;
				data 'Differential' value:sum(building collect each.consumption) - sum(building collect each.production) color:rgb(143,176,9) marker:false thickness:2.0; //green
			}
		}
		/*display prod  type:opengl  {		
			species building aspect:prod;
		}
		display cons  type:opengl  {		
			species building aspect:con;
		}
		display diff  type:opengl  {		
			species building aspect:diff;
		}*/	
		display sharing type:opengl{
			species building aspect:status;
			species building aspect:sales_network transparency: 0.5;
		}
		
		
		display chartprod type:opengl
		{
			chart prod axes:rgb(125,125,125) size:{0.5,0.5} type:histogram style:stack //white
			{
				data 'production' value:sum(building collect each.production) accumulate_values:true color:rgb(169,25,37) marker:false thickness:2.0; //red
				data 'consumption' value:-sum(building collect each.consumption)  accumulate_values:true color:rgb(71,168,243) marker:false thickness:2.0; //blue
			}
			
			chart prod axes:rgb(125,125,125) size:{0.5,0.5} position:{world.shape.width/2,0}
			{
				data 'production' value:sum(building collect each.production) color: rgb(169,25,37) marker:false thickness:2.0;  //red
				data 'consumption' value:sum(building collect each.consumption) color:rgb(71,168,243) marker:false thickness:2.0; //blue
				data 'Differential' value:sum(building collect each.consumption) - sum(building collect each.production) color:rgb(143,176,9) marker:false thickness:2.0; //Green
			}
			
			
			chart prod axes:rgb(125,125,125) size:{0.5,0.5} type:pie style:stack position:{world.shape.width,0}
			{
				data 'production' value:sum(building collect each.production) color: rgb(169,25,37) marker:false thickness:2.0;  //red
				data 'consumption' value:sum(building collect each.consumption) color:rgb(71,168,243) marker:false thickness:2.0; //blue
				data 'Differential' value:sum(building collect each.consumption) - sum(building collect each.production) color:rgb(143,176,9) marker:false thickness:2.0; //Green
			}
		}
	}
}

