model microFromMacro

global {
	file JsonFile <- json_file("https://cityio.media.mit.edu/api/table/grasbrook/od");	
	file geo_file <- geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/table_area.geojson");
	file walk_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/walking_net.geojson");
	file cycling_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/cycling_net.geojson");
	file car_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/driving_net.geojson");
	file pt_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/pt_net.geojson");
	graph walk_graph;
	graph cycling_graph;
	graph car_graph;
	graph pt_graph;
	map<int, graph> graph_map <-[0::car_graph, 1::cycling_graph, 2::walk_graph, 3::pt_graph];
	geometry shape <- envelope(geo_file);
	map<int, rgb> color_type_per_mode <- [0::#black, 1::#gamared, 2::#gamablue, 3::#gamaorange];
	map<int, string> string_type_per_mode <- [0::"driving", 1::"cycling", 2::"walking", 3::"transit"];
	map<int, float> speed_per_mode <- [0::30.0, 1::15.0, 2::5.0, 3::10.0];
	
	
	map<int, rgb> color_type_per_type <- [0::#gamared, 1::#gamablue, 2::#gamaorange];
	map<int, string> string_type_per_type <- [0::"live and works here ", 1::"works here", 2::"lives here"];
	
	
	init {
		create areas from: geo_file;
		create road from: car_network{
			type<-0;
		}
		create road from: cycling_network{
			type<-1;
		}
		create road from: walk_network{
			type<-2;
		}
		create road from: pt_network{
			type<-3;
		}
		walk_graph <- as_edge_graph(road where (each.type=0));
		cycling_graph <- as_edge_graph(road where (each.type=1));
		car_graph <- as_edge_graph(road where (each.type=2));
		pt_graph <- as_edge_graph(road where (each.type=3));
		
		loop lo over: JsonFile {
			loop l over: list(lo) {
				map m <- map(l);
				create people with: [type::int(m["type"]), mode::int(m["mode"]), home::point(m["home_ll"]), work::point(m["work_ll"]), start_time::int(m["start_time"])] {
					location <- home;
					home <- point(to_GAMA_CRS(home, "EPSG:4326"));
					work <- point(to_GAMA_CRS(work, "EPSG:4326"));
			        location<-home;
				}
			}

		}
		
		ask people{
			if flip(0.9){
				//do die;
			}
		}
	}
	
	reflex save_results when: (cycle = 86400/2)  {
		string t;
		save "[" to: "result.json";
		ask people {
			t <- "{\n\"mode\": "+mode+",\n\"segments\": [";
			int curLoc<-0;
			loop l over: locs {
				
				point loc <- CRS_transform(l).location;
				if(curLoc<length(locs)-1){
				t <- t + "[" + loc.x + ", " + loc.y + ", " + l.z + "],\n";	
				}else{
				t <- t + "[" + loc.x + ", " + loc.y + ", " + l.z + "]\n";	
				}
				curLoc<-curLoc+1;
			}

			t <- t + "]\n}";
			if (int(self) < (length(people) - 1)) {
				t <- t + ",";
			}

			save t to: "result.json" rewrite: false;
		}

		save "]" to: "result.json" rewrite: false;
		file JsonFileResults <- json_file("./result.json");
        map<string, unknown> c <- JsonFileResults.contents;
		try{			
	  	  save(json_file("https://cityio.media.mit.edu/api/table/update/grasbrook/cityIO_Gama_Hamburg", c));		
	  	}catch{
	  	  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
	  	} 
	}
}


species areas {
	rgb color <- rnd_color(255);
	rgb text_color <- (color.brighter);
	
	aspect default {
		draw shape color: #white;
	}
}

species people skills:[moving]{
	int mode;
	int type;
	int start_time;
	point home;
	point work;
	rgb color <- rnd_color(255);
	list<point> locs;
		
	reflex move{
		if(cycle>start_time and location!=work){  
		  do goto target:work speed:0.01 * speed_per_mode[mode];
		  do wander speed:0.05;
		  
		}else{
		  do wander speed:0.1;
		}
		if(cycle mod 75 = 0 and cycle>1 and location!=work){
		 	locs << {location.x,location.y,cycle};
		}	
	}

	aspect mode {
		draw circle(10#m) color: color_type_per_mode[mode] border:color_type_per_mode[mode]-50;
	}
	
	aspect type{
		draw circle(10#m) color: color_type_per_type[type] border:color_type_per_mode[mode]-50;
	}
}

species road schedules: [] {
	int type;
	aspect default {
		draw shape color: color_type_per_mode[type];// at:{location.x,location.y,type*world.shape.width*0.1};
	}

}

experiment Display type: gui {
	output {
		layout #split;
		display map_mode type:opengl background:#black{
			species areas refresh:false;
			species road refresh:false;
			species people aspect:mode;
			overlay position: { 5, 5 } size: { 180 #px, 100 #px } background: # black transparency: 0.5 border: #black rounded: true
            {
                float y <- 30#px;
                loop mode over: color_type_per_mode.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_type_per_mode[mode] border: #white;
                    draw string(string_type_per_mode[mode]) at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }

            }
		}
		
		
		display map_type type:opengl background:#black{
			species areas refresh:false;
			species road refresh:false;
			species people aspect:type;
			overlay position: { 5, 5 } size: { 180 #px, 100 #px } background: # black transparency: 0.5 border: #black rounded: true
            {
                float y <- 30#px;
                loop type over: color_type_per_type.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_type_per_type[type] border: #white;
                    draw string(string_type_per_type[type]) at: { 40#px, y + 4#px } color: # white font: font("SansSerif", 18, #bold);
                    y <- y + 25#px;
                }

            }
		}

	}

}