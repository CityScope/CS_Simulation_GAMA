model microFromMacro

global {
	file JsonFile <- json_file("https://cityio.media.mit.edu/api/table/grasbrook/od");	
	file geo_file <- geojson_file("https://raw.githubusercontent.com/CityScope/CS_Mobility_Service/master/scripts/cities/Hamburg/clean/sim_area.geojson");
	geometry shape <- envelope(geo_file);
	
	
	init {
		create areas from: geo_file;
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
	
	reflex save_results when: (cycle = 10)  {
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
		draw shape color: #gray;
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
		draw circle(10#m) color: color;
	}

}

experiment Display type: gui {
	output {
		display map type:opengl{
			species areas;
			species people;
		}

	}

}