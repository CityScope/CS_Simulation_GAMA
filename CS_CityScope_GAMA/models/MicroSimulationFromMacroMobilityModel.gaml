model microFromMacro

global {
	string city<-'Hamburg';
	map<string, string> table_name_per_city <- ['Detroit'::'corktown', 'Hamburg'::'grasbrook'];
	string city_io_table<-table_name_per_city[city];
	
	file JsonFile <- json_file("https://cityio.media.mit.edu/api/table/"+city_io_table+"/od");	
	file geo_file <- geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/table_area.geojson");
	
	file walk_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/walking_net.geojson");
	file cycling_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/cycling_net.geojson");
	file car_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/driving_net.geojson");
	file pt_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/"+city+"/clean/pt_net.geojson");
	graph walk_graph;
	graph cycling_graph;
	graph car_graph;
	graph pt_graph;
	map<int, graph> graph_map <-[0::car_graph, 1::cycling_graph, 2::walk_graph, 3::pt_graph];
	geometry shape <- envelope(geo_file);
	map<int, rgb> color_type_per_mode <- [0::#black, 1::#gamared, 2::#gamablue, 3::#gamaorange];
	map<int, rgb> color_type_per_type <- [0::#gamared, 1::#gamablue, 2::#gamaorange];
	
	
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
	
	reflex save_results when: (cycle = 1000)  {
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
	  	  save(json_file("https://cityio.media.mit.edu/api/table/update/"+city_io_table+"/cityIO_Gama_"+city, c));		
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
		do wander;
		do goto target:work;// on:car_graph recompute_path:false;
		if(cycle mod 250 = 0 and cycle>1){
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
			species areas;
			species road;
			species people aspect:mode;
		}
		
		display map_type type:opengl background:#black{
			species areas;
			species road;
			species people aspect:type;
		}

	}

}