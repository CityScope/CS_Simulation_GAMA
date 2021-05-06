model citIOGAMA
// Example of a model that uses GAMABrix to connect to cityio. 

import "GAMABrix.gaml"

global {
	string city_io_table<-"dungeonmaster";
  
    geometry shape <- envelope(setup_cityio_world());
	bool post_on<-true;
	
	int update_frequency<-10;
	bool forceUpdate<-true;
	
	graph road_network;
	list<string> road_types <- ["Road", "LRT street"];	
	bool display_road_network <- true parameter: "road network visualization";
	
	init {
		create people number:10; 
		create thermometer number:100;
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Mean Height", indicator_value: "mean(brix collect each.height)");
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Min Height",  indicator_value: "min(brix collect each.height)");
		create cityio_numeric_indicator with: (viz_type:"bar",indicator_name: "Max Height",  indicator_value: "max(brix collect each.height)");
		create my_numeric_indicator     with: (viz_type:"bar",indicator_name: "Number of blocks");
		
	}
	
	reflex initGraphAndTarget when:cycle=1{
		road_network <- as_intersection_graph(roads, first(brix).shape.width/ 100.0);
		ask people{
			my_residence<-one_of(brix where (each.type="Residential tower"));
			my_office<-one_of(brix where (each.type="offices"));
			location<-my_residence.location;
		}
	}
	
	
}

// Example of how a user would define their own numeric indicator
species my_numeric_indicator parent: cityio_agent {
	// Users might want more complex indicators that cannot be constructed by passing indicator to the constructor for cityio_numeric_indicator
	string viz_type <- "bar";
	bool is_numeric<-true;
	
	reflex update_numeric {
		numeric_values<-[];
		numeric_values<+indicator_name::length(brix);
	}
}

species thermometer parent: cityio_agent {
	bool is_heatmap<-true;
	string indicator_name<-"thermometer";
	
	reflex update_heatmap {
		heatmap_values<-[];
		heatmap_values<+ "heat"::rnd(10);
		heatmap_values<+ "map"::rnd(10);
	}	
}

species people parent: cityio_agent skills:[moving]{ 
	bool is_visible<-true;
	brix my_office;
	brix my_residence;
	
	reflex move{
		if (road_network != nil) {
			do wander on: road_network speed:0.1;
		} else {
			do wander speed:0.1;
		}
		//do goto target:my_office speed:0.1;	
	}	
	aspect base{
		draw circle(10) color:#blue;
	}
}

experiment CityScope type: gui autorun:false{
	output {
		display map_mode type:opengl background:#black{	
			species brix aspect:base;
			graphics "road network" position:{0,0,0.01}{
				if road_network != nil and display_road_network {
					loop e over: road_network {
						draw geometry(e) color: #red;
					}
				}
			}
			species people aspect:base position:{0,0,0};
		}
	}
}
