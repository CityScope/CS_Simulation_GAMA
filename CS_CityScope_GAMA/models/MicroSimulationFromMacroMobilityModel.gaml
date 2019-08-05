model microFromMacro

global {
	file JsonFile <- json_file("https://cityio.media.mit.edu/api/table/grasbrook/od");	
	file geo_file <- geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/sim_area.geojson");
	
	file walk_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/walking_net.geojson");
	file cycling_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/cycling_net.geojson");
	file car_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/driving_net.geojson");
	file pt_network<-geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/pt_net.geojson");
	graph walk_graph;
	graph cycling_graph;
	graph car_graph;
	graph pt_graph;
	geometry shape <- envelope(geo_file);
	map<int, rgb> color_map <- [0::#black, 1::#gamared, 2::#gamablue, 3::#gamaorange];
	
	
	
	init {
		create areas from: geo_file;
		create road from: walk_network{
			type<-0;
		}
		create road from: cycling_network{
			type<-1;
		}
		create road from: car_network{
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
				create people with: [mode::int(m["mode"]), home::point(m["home_ll"]), work::point(m["work_ll"]), start_time::int(m["start_time"])] {
					location <- home;
					home <- point(to_GAMA_CRS(home, "EPSG:4326"));
					work <- point(to_GAMA_CRS(work, "EPSG:4326"));
					location<-home;
				}
			}

		}
	}
	
	reflex save_results when: (cycle = 1000)  {
		string t;
		save "[" to: "result.json";
		ask people {
			t <- "{\n\"vendor\": 1,\n\"segments\": [";
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
	int start_time;
	point home;
	point work;
	rgb color <- rnd_color(255);
	list<point> locs ;
	
	init {
		locs << location;
	}
	
	reflex move{
		do goto target:work;
		do wander;
		if(cycle mod 50 = 0){
			locs << {location.x,location.y,cycle};
		}
		
	}

	aspect default {
		draw circle(10#m) color: color_map[mode] border:color_map[mode]-50;
	}
}

species road schedules: [] {
	int type;
	aspect default {
		draw shape color: color_map[type];
	}

}

experiment Display type: gui {
	output {
		display map type:opengl background:#black{
			species areas;
			species road;
			species people;
		}

	}

}