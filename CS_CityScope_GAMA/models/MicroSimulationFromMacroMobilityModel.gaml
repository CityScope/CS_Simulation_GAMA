/***
* Name: MicroSimulationFromMacroMobilityModel
* Author: wangc
* Description: copy and debug form the same model file in Github 
* Tags: Tag1, Tag2, TagN
***/

model MicroSimulationFromMacroMobilityModel

global {
	date starting_date <- date([2019,11,20,0,0,0]);
	string city<-'Detroit';
	map<string, string> table_name_per_city <- ['Detroit'::'corktown', 'Hamburg'::'grasbrook'];
	string city_io_table<-table_name_per_city[city];

	file od_file <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/od2");	
	file meta_grid_file <- geojson_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/meta_grid","EPSG:4326");	
	file table_area_file <- geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/table_area.geojson");
	file walking_net_file<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/walking_net.geojson");
	file cycling_net_file<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/cycling_net.geojson");
	file driving_net_file<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/driving_net.geojson");
	file pt_net_file<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/pt_net.geojson");
	file portals_file<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/portals.geojson");
	
	map<string, unknown> hashes;
	file hash_od_file<-json_file("https://cityio.media.mit.edu/api/table/grasbrook/meta/hashes/"); //grasbrook?
	string current_hash;
	bool reinit<-true;
	
	graph walking_graph;
	graph cycling_graph;
	graph driving_graph;
	graph pt_graph;
	map<int, graph> graph_map; 
	
	geometry shape <- envelope(meta_grid_file);
	geometry free_space <- copy(shape);
	bool simple_landuse<-true;
	
	//LANDUSE FOR CORKTOWN (https://data.detroitmi.gov/app/parcel-viewer-2)
	map<string, rgb> string_type_per_landuse <- ["B1"::rgb(161,80,98),"B2"::rgb(190,60,94),"B3"::rgb(218,26,91),"B4"::rgb(153,0,51),"B5"::rgb(130,16,54),"B6"::rgb(96,0,21),
	"M1"::rgb(133,84,157),"M2"::rgb(144,72,183),"M3"::rgb(155,55,209),"M4"::rgb(93,32,128),"M5"::rgb(101,0,151),
	"P1"::rgb(95,152,61),"PC"::rgb(95,152,61),"PCA"::rgb(95,152,61),"PD"::rgb(95,152,61),"PR"::rgb(95,152,61),
	"R1"::rgb(109,129,159),"R2"::rgb(77,130,197),"R3"::rgb(16,131,237),"R4"::rgb(11,83,176),"R5"::rgb(30,83,141),"R6"::rgb(8,45,121),
	"SD1"::rgb(185,105,40),"SD2"::rgb(185,105,40),"SD4"::rgb(185,105,40),"SD5"::rgb(185,105,40),"TM"::rgb(185,105,40),"W1"::rgb(185,105,40)	
	];
	//map<string, rgb> string_type_per_landuse_Simple <- ["B"::rgb(161,80,98),"M"::rgb(133,84,157),"P"::rgb(95,152,61),"R"::rgb(109,129,159),"S"::rgb(185,105,40),nil::#black];
	map<string, rgb> string_type_per_landuse_Simple <- ["B"::rgb(0,0,255),"M"::rgb(255,0,0),"P"::rgb(0,255,0),"R"::rgb(255,255,0),"S"::rgb(0,255,255),nil::#black];
	map<string, string> detailed_to_simple_landuse <- ["B1"::"B","B2"::"B","B3"::"B","B4"::"B","B5"::"B","B6"::"B","M1"::"M","M2"::"M","M3"::"M","M4"::"M","M5"::"M",
	"P1"::"P","PC"::"P","PCA"::"P","PD"::"P","PR"::"P","R1"::"R","R2"::"R","R3"::"R","R4"::"R","R5"::"R","R6"::"R","SD1"::"S","SD2"::"S","SD4"::"S","SD5"::"S","TM"::"S","W1"::"S"];

	map<int,rgb> interactive_bloc_color <-[0::rgb("#373F51"),1::rgb("#002DD5"),2::rgb("#008DD5"),3::rgb("#E43F0F"),4::rgb("#F51476")];
	
	//MODE PARAMETERS
	map<int, rgb> color_type_per_mode <- [0::#violet, 1::#gamared, 2::#gamablue, 3::#gamaorange];
	map<int, string> string_type_per_mode <- [0::"driving", 1::"cycling", 2::"walking", 3::"transit"];
	map<int, float> speed_per_mode <- [0::30.0, 1::15.0, 2::5.0, 3::10.0];
	//Profile
	map<int, rgb> color_type_per_type <- [0::#gamared, 1::#gamablue, 2::#gamaorange];
	map<int, string> string_type_per_type <- [0::"live and works here ", 1::"works here", 2::"lives here"];
	
	//Activities
	map<string,rgb> color_type_per_activity <- [
		'H'::#violet, 'W'::#gamared, 'C'::#gamablue, 'D'::#gamaorange, 'G'::#navy, 'S'::#olive,
		'E'::#orchid, 'R'::#peru, 'X'::#pink, 'V'::#purple, 'P'::#chocolate, 'Z'::#aqua
	];
	map<string,string> string_type_per_activity <- [
		'H'::'Home', 'W'::'Work', 'C'::'School','D'::'Drop-off',
		'G'::'Buy Groceries', 'S'::'Buy Services', 'E'::'Eat',
		'R'::'Recreation', 'X'::'Exercise', 'V'::'Visit Friends',
		'P'::'Hospital', 'Z'::'Religion' 
	];
	
	float step <- 30 #sec;
	float saveLocationInterval<-step;
	int totalTimeInSec<-86400; //24hx60minx60sec 1step is 10#sec
	
	bool showLegend parameter: 'Show Legend' category: "Parameters" <-true;
	bool showLandUse parameter: 'Show Landuse' category: "Parameters" <-false; 
	bool showMode <- true;
	bool showType <- false;
	bool showActivity <- false;
    bool showRoad parameter: 'Show Road' category: "Parameters" <-false;
    bool savePedestrian parameter: 'Save Pedestrian' category: "Parameters" <-false;  
    
    date initial_date;
    date tmp_date;
    float current_machine_time;
    
    int nb_active -> {length (people where each.active)};
    int nb_home -> {length (people where (each.active and each.activity='H'))};
    int nb_work -> {length (people where (each.active and each.activity='W'))};
    int nb_other -> {length (people where (each.active and each.activity!='H' and each.activity!='W'))}; 
    int nb_HBW -> {length (people where (each.active and each.trip_type='HBW'))};
    int nb_HBO -> {length (people where (each.active and each.trip_type='HBO'))};
    int nb_NHB -> {length (people where (each.active and each.trip_type='NHB'))};
    int nb_driving -> {length (people where (each.active and each.macro and each.mode=0))};
    int nb_cycling -> {length (people where (each.active and each.macro and each.mode=1))};
    int nb_walking -> {length (people where (each.active and each.macro and each.mode=2))};
    int nb_PT -> {length (people where (each.active and each.macro and each.mode=3))};
    int nb_staying -> {length (people where (each.active and !each.macro))};
    int nb_moving -> {length (people where (each.active and each.macro))};
    
	init {
		//hashes<-hash_od_file.contents;
		hashes<-hash_od_file;
		current_hash<-hashes["od"];
		initial_date<-date("now");
		tmp_date<- date("now");
		create areas from: table_area_file;
		create portal from: portals_file;
		create block from:meta_grid_file with:[land_use::read("land_use"), interactive::bool(read("interactive"))]{
			if(simple_landuse){
				land_use<-detailed_to_simple_landuse[land_use];
			}
			if(land_use!=nil){
				//free_space <- free_space - shape;
			}
		}
		create road from: driving_net_file{
			type<-0;
		}
		create road from: cycling_net_file{
			type<-1;
		}
		create road from: walking_net_file{
			type<-2;
		}
		create road from: pt_net_file{
			type<-3;
		}
		driving_graph <- as_edge_graph(road where (each.type=0));
		cycling_graph <- as_edge_graph(road where (each.type=1));
		walking_graph <- as_edge_graph(road where (each.type=2));
		pt_graph <- as_edge_graph(road where (each.type=3));
		graph_map <-[0::driving_graph, 1::cycling_graph, 2::walking_graph, 3::pt_graph];
		do initiatePeople;		
	}
	
	action initiatePeople{
		  ask people{
		    do die;
		  }
		  loop lo over: od_file {
			loop l over: list(lo) {
				map m <- map(l);
				create people with: [type::int(m["type"]), mode::int(m["activity_mode"]), home::point(m["home_ll"]), work::point(m["work_ll"]), 
					origin::point(m["from_place"]), desti::point(m["activity_place"]), start_time::int(m["activity_trip_start_time"]), 
					stay_until_time::int(m["activity_stay_until_time"]), active::false, activity::m['activity'], trip_type::m["trip_type"],
					from_portal:: int(m["from_portal"]), to_portal::int(m["to_portal"]), external_time::int(m["external_time"]) 	
				] {
					if (from_portal=1){
						start_time <- (start_time+external_time) mod totalTimeInSec;
					}
					if (start_time>stay_until_time){
						stay_until_time <-86399;
					}
					home <- point(to_GAMA_CRS(home, "EPSG:4326"));
					work <- point(to_GAMA_CRS(work, "EPSG:4326"));
					origin <- point(to_GAMA_CRS(origin, "EPSG:4326"));
					desti <- point(to_GAMA_CRS(desti, "EPSG:4326"));
			        location<-origin;
			        macro<-true;
				}
			}
		  }	
    }
    
	reflex useless {
		//write #now + ' ' + current_date;
	}

	reflex save_results when: (cycle mod (totalTimeInSec/step) = 0 and cycle>1)  {
		
		string t;
		map<string, unknown> test;
		save "[" to: "result.json";
		ask people {
			test <+ "mode"::mode;
			test<+"path"::locs;
			test<+locs;
			t <- "{\n\"mode\": ["+ mode + ","+type+    "],\n\"path\": [";
			//t <- "{\n\"mode\": "+mode+"\n\"type\": "+type+ ",\n\"segments\": [";
			int curLoc<-0;
			loop l over: locs {
				point loc <- CRS_transform(l).location;
				if(curLoc<length(locs)-1){
				t <- t + "[" + loc.x + ", " + loc.y + "],\n";	
				}else{
				t <- t + "[" + loc.x + ", " + loc.y + "]\n";	
				}
				curLoc<-curLoc+1;
			}
			t <- t + "]";
			t <- t+",\n\"timestamps\": [";
			curLoc<-0;
			loop l over: locs {
				
				point loc <- CRS_transform(l).location;
				if(curLoc<length(locs)-1){
				t <- t + loc.z + ",\n";	
				}else{
				t <- t +  loc.z + "\n";	
				}
				curLoc<-curLoc+1;
			}
			t <- t + "]";
			
			
			t<- t+ "\n}";
			if (int(self) < (length(people) - 1)) {
				t <- t + ",";
			}
			save t to: "result.json" rewrite: false;
		}

		save "]" to: "result.json" rewrite: false;
		file JsonFileResults <- json_file("./result.json");
        map<string, unknown> c <- JsonFileResults.contents;
        if(reinit){    
			try{			
		  	  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/ABM", c));		
		  	}catch{
		  	  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
		  	}
		  	write #now +" Send to cityIO - Iteration " + int(time/totalTimeInSec)  + ": " + (date("now") - tmp_date) + "s - timestep:" + step + " s" + " - Sampling rate: " + saveLocationInterval + " s" ;
		  	list<int> list_of_locs<-people collect length((each.locs));
		  	list<float> list_of_distance<-people collect (each.distance);
		  	write "Nb Agent:" + length(people) + " Trajectory: (min,max,mean): (" + min(list_of_locs) + "," + max(list_of_locs) + "," + int(mean(list_of_locs))+")" 
		  	+ " Modes: (car,bikes,walks,transit): (" + length(people where (each.mode = 0)) + "," + length(people where (each.mode = 1)) + "," + length(people where (each.mode = 2)) + "," + length(people where (each.mode = 3)) + ") " 
		  	+ " Distance: (min,max,mean): (" + min(list_of_distance)/1000 + "," + max(list_of_distance)/1000 + "," + int(mean(list_of_distance))/1000+")" + " Distance: (car,bikes,walks,transit): (" + sum(people where (each.mode = 0) collect each.distance)/1000 + "," + sum(people where (each.mode = 1) collect each.distance) + "," + sum(people where (each.mode = 2) collect each.distance)/1000 + "," + sum(people where (each.mode = 3) collect each.distance)/1000 + ");";
		} 	  	
	  
	  	do initiatePeople;
	  	current_machine_time<-machine_time;
	  	tmp_date<-date("now");
	}
	
	reflex updateSimStatus when: (cycle mod (totalTimeInSec/step) = 0 and cycle>1){
		  if(current_hash = json_file("https://cityio.media.mit.edu/api/table/grasbrook/meta/hashes/").contents["od"]){
		  	reinit<-false;
		  }else{
		  	reinit<-true;
		  	current_hash <-json_file("https://cityio.media.mit.edu/api/table/grasbrook/meta/hashes/").contents["od"];
		  }
    }
}

species people skills:[moving]{
	point origin;
	point desti;
	int start_time;
	int stay_until_time;
	int mode;
	int type;
	point home;
	point work;
	bool macro;
	bool active;
	point current_target;
	float last_speed;
	float last_heading;
	bool save_sample<-false;
	string activity;
	string trip_type;
	int from_portal;
	int to_portal;
	int external_time;

	rgb color <- rnd_color(255);
	list<point> locs;
	float distance;
		
	reflex active_people{
		int tmp <- time mod totalTimeInSec;
		if (tmp<start_time and tmp+step>=start_time){
			active <- true;
		}
	}
	
	reflex trip_finised when:(time mod totalTimeInSec >stay_until_time){
		active <- false;
		do die;
	}
	
	
	reflex move_macro when:(macro=true){
		if(time mod totalTimeInSec >start_time and location!=desti){
			if(mode=2){
			 // do walk target: work speed:0.01 * speed_per_mode[2];	
			 	do goto target: desti speed:0.01 * speed_per_mode[2];	
			}else{
			   do goto target:desti speed:0.01 * speed_per_mode[mode] on: graph_map[mode];	
			}
			do goto target:desti speed:0.01 * speed_per_mode[mode] on: graph_map[mode];
					
		}
		if(active and (time mod saveLocationInterval = 0) and (time mod totalTimeInSec)>1 and (location!=origin) and (location !=desti)
		){
			save_sample<-((abs((real_speed-last_speed)/(last_speed+1e-10))>0.05) or (abs((heading-last_heading)/(last_heading+1e-10))>0.01));
		 	if save_sample{
		 	  locs << {location.x,location.y,time mod totalTimeInSec};	
		 	  distance <- line(locs).perimeter;
		 	}
		}
		last_speed<-real_speed;
		last_heading<-heading;
		if(active and time mod totalTimeInSec>start_time and location=desti){//The people that only lives here are not shown as micro agent as there are not in the table anymore.
			//active and time mod totalTimeInSec>start_time and location=desti and type!=2
			if (to_portal=1){
				active<-false;
				do die;
			}else{
				macro<-false;
			}
			
		}	
	}
	
	reflex choose_target_pedestrian when: (active and current_target = nil and macro=false) {
		current_target <- any_location_in(one_of(block where (each.interactive=true)));
	}
	reflex move_pedestrian when: (active and current_target != nil and macro=false){
		//do walk target: current_target  speed:0.01 * speed_per_mode[2];
		do goto target: current_target  speed:0.01 * speed_per_mode[2];	
		if (self distance_to current_target < 0.1) {
			current_target <- any_location_in(one_of(block where (each.interactive=true)));
		}
		if(savePedestrian){
			if((time mod saveLocationInterval = 0) and (time mod totalTimeInSec)>1){
		 	locs << {location.x,location.y,time mod totalTimeInSec};
		 	distance <- line(locs).perimeter;
		}
		}			
	}
	
	reflex saveLoc{
		
	}

	aspect base {
		if(active){
			if(macro){
			  if(showMode){
			  	draw circle(5#m) color: color_type_per_mode[mode] border:color_type_per_mode[mode]-50;	
			  }else if(showType){
			    draw circle(5#m) color: color_type_per_type[type] border:color_type_per_type[type]-50;	
			  }else if(showActivity){
			  	draw circle(5#m) color: color_type_per_activity[activity] border:color_type_per_activity[activity]-50;	
			  }
			}else{
				if(showMode){
			  	draw triangle(5#m) color: color_type_per_mode[mode] border:color_type_per_mode[mode]-50;	
			  }else if(showType){
			    draw triangle(5#m) color: color_type_per_type[type] border:color_type_per_type[mode]-50;	
			  }else if(showActivity){
			  	draw triangle(5#m) color: color_type_per_activity[activity] border:color_type_per_activity[activity]-50;	
			  }
			}
		}
	}
}

species block{
	string land_use;
	bool interactive;
	aspect base {
		if(showLandUse){
		  draw shape color: simple_landuse ? string_type_per_landuse_Simple[land_use]: string_type_per_landuse[land_use];	
		}
	}
	aspect white {
		if(showLandUse){
		  if(land_use != nil){
		    draw shape color: #white border:#gray;		
		  }
		}
	}
}

species areas {
	rgb color <- rnd_color(255);
	rgb text_color <- (color.brighter); //Java error: nil value detected
	
	aspect default {
		draw shape color: #gray;
	}
}

species portal{
	aspect base {
		draw circle(25#m) color: #gamablue;
	}
}

species road schedules: [] {
	int type;
	aspect default {
		if(showRoad and type=0){
		  //draw shape color: color_type_per_mode[type] width:1;	
		  draw shape color: #white width:1;	
		}	
	}
}


experiment Dev type: gui autorun:true{
	parameter "Show Mode" var: showMode category: Parameters;
	parameter "Show Type" var: showType category: Parameters;
	parameter "Show Activity" var: showActivity category: Parameters;
	
	output {
		monitor "Current Time" value: string(current_date.hour) + ": " + string(current_date.minute) + ": " + string(current_date.second);
		monitor "Number of People" value: nb_active;
		display map_mode type:opengl background:#black draw_env:false{	
			//species areas refresh:false;
			species block aspect:base;
			species road;
			species people aspect:base;
			species portal aspect:base;
			/* 
			event["b"] action: {showLandUse<-!showLandUse;};
			event["l"] action: {showLegend<-!showLegend;};
			event["m"] action: {showMode<-!showMode;};
			event["r"] action: {showRoad<-!showRoad;};
			*/

			overlay position: { 5, 5 } size: { 180 #px, 100 #px } background: # black transparency: 0.5 border: #black rounded: true
			
            {
            	if(showLegend){
	            	float y <- 30#px;
	            	if(showMode){
	            	  loop mode over: color_type_per_mode.keys
	                	{
	                    draw square(10#px) at: { 20#px, y } color: color_type_per_mode[mode] border: #white;
	                    draw string(string_type_per_mode[mode]) at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
	                    y <- y + 25#px;
	                	}	
	            	}else if(showType){
	            		loop type over: color_type_per_type.keys
		                {
		                    draw square(10#px) at: { 20#px, y } color: color_type_per_type[type] border: #white;
		                    draw string(string_type_per_type[type]) at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
		                    y <- y + 25#px;
		                }
	            	}else if(showActivity){
	            		loop activity over: color_type_per_activity.keys
		                {
		                    draw square(10#px) at: { 20#px, y } color: color_type_per_activity[activity] border: #white;
		                    draw string(string_type_per_activity[activity]) at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
		                    y <- y + 25#px;
		                }
	            	}	                
            	}
            }
		}
		display charts{

			 chart "Number of People" type: series size: {0.5,0.5} position: {0,0}{
				data "Total" value: nb_active color: #aqua marker:false thickness:2;
				data "Moving" value: nb_moving color: #gamared marker:false thickness:2;
				data "Staying" value: nb_staying color: #gamablue marker:false thickness:2;
			} 
			chart "Activity Share" type: pie style: exploded size:{0.5,0.5} position:{0.5,0}{
				data "Home" value: nb_home color:#violet;
				data "Work" value: nb_work color: #gamared;
				data "Others" value: nb_other color: #gamablue;
			}
			chart "Trip Share" type:pie style: exploded size:{0.5,0.5} position:{0,0.5}{
				data "HBW" value: nb_HBW color:#violet;
				data "HBO" value: nb_HBO color: #gamared;
				data "NHB" value: nb_NHB color: #gamablue;
			}
			chart "Mode Share" type:pie style:exploded size:{0.5,0.5} position:{0.5,0.5}{
				data "Driving" value: nb_driving color:#violet;
				data "Cycling" value: nb_cycling color: #gamared;
				data "Walking" value: nb_walking color: #gamablue;
				data "PT" value: nb_PT color: #gamaorange;
			}
		}
	}
}