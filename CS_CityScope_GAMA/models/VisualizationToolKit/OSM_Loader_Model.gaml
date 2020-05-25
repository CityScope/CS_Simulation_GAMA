/***
* Part of the SWITCH Project
* Author: Patrick Taillandier
* Tags: gis, OSM data
***/

model switch_utilities_gis

global {
	
	//define the path to the dataset folder
	string dataset_path <- "./../../includes/AutonomousCities/Andorra/";
		
	//define the bounds of the studied area
	file data_file <-shape_file(dataset_path + "bound.shp");
	
	
	//optional
	string osm_file_path <- dataset_path + "map.osm";
		
	float mean_area_flats <- 200.0;
	float min_area_buildings <- 20.0;
	
	float default_road_speed <- 50#km/#h;
	int default_num_lanes <- 1;
	
	bool display_google_map <- true parameter:"Display google map image";
	
	bool saveShp<-false;
	
	//-----------------------------------------------------------------------------------------------------------------------------
	
	list<rgb> color_bds <- [rgb(241,243,244), rgb(255,250,241)];
	
	map<string,rgb> google_map_type <- ["restaurant"::rgb(255,159,104), "shop"::rgb(73,149,244)];
	
	geometry shape <- envelope(data_file);
	map filtering <- ["building"::[], "shop"::[], "historic"::[], "amenity"::[], "sport"::[], "military"::[], "leisure"::[], "office"::[],  "highway"::[]];
	image_file static_map_request ;
	init {
		write "Start the pre-processing process";
		create Boundary from: data_file;
		
		osm_file osmfile;
		if (file_exists(osm_file_path)) {
			osmfile  <- osm_file(osm_file_path, filtering);
		} else {
			point top_left <- CRS_transform({0,0}, "EPSG:4326").location;
			point bottom_right <- CRS_transform({shape.width, shape.height}, "EPSG:4326").location;
			string adress <-"http://overpass.openstreetmap.ru/cgi/xapi_meta?*[bbox="+top_left.x+"," + bottom_right.y + ","+ bottom_right.x + "," + top_left.y+"]";
			osmfile <- osm_file<geometry> (adress, filtering);
		}
		
		write "OSM data retrieved";
		list<geometry> geom <- osmfile  where (each != nil);// and not empty(Boundary overlapping each) );
		list<geometry> roads_intersection <- geom where (each.attributes["highway"] != nil);
		
		
		create Building from: (geom - roads_intersection) with:[building_att:: get("building"),shop_att::get("shop"), historic_att::get("historic"), 
			office_att::get("office"), military_att::get("military"),sport_att::get("sport"),leisure_att::get("lesure"),
			height::float(get("height")), flats::int(get("building:flats")), levels::int(get("building:levels"))
		];
		ask Building {
			if (shape = nil) or empty(Boundary overlapping self) {do die;} 
		}
		list<Building> bds <- Building where (each.shape.area > 0);
		ask Building where ((each.shape.area = 0) and (each.shape.perimeter = 0)) {
			list<Building> bd <- bds overlapping self;
			ask bd {
				sport_att  <- myself.sport_att;
				office_att  <- myself.office_att;
				military_att  <- myself.military_att;
				leisure_att  <- myself.leisure_att;
				amenity_att  <- myself.amenity_att;
				shop_att  <- myself.shop_att;
				historic_att <- myself.historic_att;
			}
			do die; 
		}
		ask Building where (each.shape.area < min_area_buildings) {
			do die;
		}
		ask Building {
			if (amenity_att != nil) {
				type <- amenity_att;
			}else if (shop_att != nil) {
				type <- shop_att;
			}
			else if (office_att != nil) {
				type <- office_att;
			}
			else if (leisure_att != nil) {
				type <- leisure_att;
			}
			else if (sport_att != nil) {
				type <- sport_att;
			} else if (military_att != nil) {
				type <- military_att;
			} else if (historic_att != nil) {
				type <- historic_att;
			} else {
				type <- building_att;
			} 
		}
		
		ask Building where (each.type = nil or each.type = "") {
			do die;
		}
		ask Building {
			if (flats = 0) {
				if type in ["apartments","hotel"] {
					if (levels = 0) {levels <- 1;}
					flats <- int(shape.area / mean_area_flats) * levels;
				} else {
					flats <- 1;
				}
			}
		}
	
		if(saveShp){
		  save Building to:dataset_path +"buildings.shp" type: shp attributes: ["type"::type, "flats"::flats,"height"::height, "levels"::levels];
		}
		
		
		map<string, list<Building>> buildings <- Building group_by (each.type);
		loop ll over: buildings {
			rgb col <- rnd_color(255);
			ask ll {
				color <- col;
			}
		}
		
		map<point, Node> nodes_map;
	
		loop geom over: roads_intersection {
			string highway_str <- string(geom get ("highway"));
			if (length(geom.points) > 1 ) {
				if not(empty(Boundary overlapping geom)) {
					string oneway <- string(geom get ("oneway"));
					float maxspeed_val <- float(geom get ("maxspeed"));
					string lanes_str <- string(geom get ("lanes"));
					int lanes_val <- empty(lanes_str) ? 1 : ((length(lanes_str) > 1) ? int(first(lanes_str)) : int(lanes_str));
					create Road from: [geom] with: [type:: highway_str, lanes::lanes_val] {
						if lanes < 1 {lanes <- default_num_lanes;} //default value for the lanes attribute
						if maxspeed = 0 {maxspeed <- default_road_speed;} //default value for the maxspeed attribute
						switch oneway {
							match "yes"  {
								
							}
							match "-1" {
								shape <- polyline(reverse(shape.points));
							}
							default {
								create Road {
									lanes <- lanesbackw > 0 ? lanesbackw : max([1, int(myself.lanes / 2.0)]);
									shape <- polyline(reverse(myself.shape.points));
									maxspeed <- myself.maxspeed;
								}
								lanes <- lanesforwa > 0 ? lanesbackw : int(lanes / 2.0 + 0.5);
							}

						}
					}
				
				}
			} else if (length(geom.points) = 1 ) {
				if ( highway_str != nil ) {
					string crossing <- string(geom get ("crossing"));
					create Node with: [shape ::geom, type:: highway_str, crossing::crossing] {
						nodes_map[location] <- self;
					}
				}
			}
		}
		
		graph network<- main_connected_component(as_edge_graph(Road));
		ask Road {
			if not (self in network.edges) {
				do die;
			}
		}
		
		write "Road and node agents created";
		
		ask Road {
			point ptF <- first(shape.points);
			if (not(ptF in nodes_map.keys)) {
				create Node with:[location::ptF] {
					nodes_map[location] <- self;
				}	
			}
			point ptL <- last(shape.points);
			if (not(ptL in nodes_map.keys)) {
				create Node with:[location::ptL] {
					nodes_map[location] <- self;
				}
			}
		}
			
		write "Supplementary node agents created";
		list<point> locs <- remove_duplicates(Road accumulate ([first(each.shape.points),last(each.shape.points)]));
		ask Node {
			if not (location in locs) {
				do die;
			}
		}
		
		write "node agents filtered";
		if(saveShp){
		  save Road type:"shp" to:dataset_path +"roads.shp" attributes:["junction"::junction, "type"::type, "lanes"::self.lanes, "maxspeed"::maxspeed, "oneway"::oneway] ;
		}
		if(saveShp){
		  save Node type:"shp" to:dataset_path +"nodes.shp" attributes:["type"::type, "crossing"::crossing] ;
		}
		
		do load_satellite_image;
	}
	
	
	
	action load_satellite_image
	{ 
		point top_left <- CRS_transform({0,0}, "EPSG:4326").location;
		point bottom_right <- CRS_transform({shape.width, shape.height}, "EPSG:4326").location;
		int size_x <- 1500;
		int size_y <- 1500;
		
		string rest_link<- "https://dev.virtualearth.net/REST/v1/Imagery/Map/Aerial/?mapArea="+bottom_right.y+"," + top_left.x + ","+ top_left.y + "," + bottom_right.x + "&mapSize="+int(size_x)+","+int(size_y)+ "&key=AvZ5t7w-HChgI2LOFoy_UF4cf77ypi2ctGYxCgWOLGFwMGIGrsiDpCDCjliUliln" ;
		static_map_request <- image_file(rest_link);
	
		write "Satellite image retrieved";
		ask cell {		
			color <-rgb( (static_map_request) at {grid_x,1500 - (grid_y + 1) }) ;
		}
		save cell to: dataset_path +"satellite.png" type: image;
		
		string rest_link2<- "https://dev.virtualearth.net/REST/v1/Imagery/Map/Aerial/?mapArea="+bottom_right.y+"," + top_left.x + ","+ top_left.y + "," + bottom_right.x + "&mmd=1&mapSize="+int(size_x)+","+int(size_y)+ "&key=AvZ5t7w-HChgI2LOFoy_UF4cf77ypi2ctGYxCgWOLGFwMGIGrsiDpCDCjliUliln" ;
		file f <- json_file(rest_link2);
		list<string> v <- string(f.contents) split_with ",";
		int ind <- 0;
		loop i from: 0 to: length(v) - 1 {
			if ("bbox" in v[i]) {
				ind <- i;
				break;
			}
		} 
		float long_min <- float(v[ind] replace ("'bbox'::[",""));
		float long_max <- float(v[ind+2] replace (" ",""));
		float lat_min <- float(v[ind + 1] replace (" ",""));
		float lat_max <- float(v[ind +3] replace ("]",""));
		point pt1 <- CRS_transform({lat_min,long_max},"EPSG:4326", "EPSG:3857").location ;
		point pt2 <- CRS_transform({lat_max,long_min},"EPSG:4326","EPSG:3857").location;
		float width <- abs(pt1.x - pt2.x)/1500;
		float height <- (pt2.y - pt1.y)/1500;
			
		string info <- ""  + width +"\n0.0\n0.0\n"+height+"\n"+min(pt1.x,pt2.x)+"\n"+(height < 0 ? max(pt1.y,pt2.y) : min(pt1.y,pt2.y));
	
		save info to: dataset_path +"satellite.pgw";
		
		
		write "Satellite image saved with the right meta-data";
		 
		
	}
	
	
}


species Node {
	string type;
	string crossing;
	aspect default { 
		if (type = "traffic_signals") {
			draw circle(2#px) color: #green border: #black depth: 1.0;
		} else {
			draw square(2#px) color: #magenta border: #black depth: 1.0 ;
		}
		
	}
}


species Road{
	rgb color <- #red;
	string type;
	string oneway;
	float maxspeed;
	string junction;
	int lanesforwa;
	int lanesbackw;
	int lanes;
	aspect default {
		draw shape color: color end_arrow: 5; 
	}
	
} 
grid cell width: 1500 height:1500 use_individual_shapes: false use_regular_agents: false use_neighbors_cache: false;

species Building {
	string type;
	string building_att;
	string shop_att;
	string historic_att;
	string amenity_att;
	string office_att;
	string military_att;
	string sport_att;
	string leisure_att;
	float height;
	int flats;
	int levels;
	rgb color;
	aspect default {
		draw shape color: color border: #black depth: (1 + flats) * 3;
	}
}

species Boundary {
	aspect default {
		draw shape color: #gray border: #black;
	}
}

experiment generateGISdata type: gui {
	output {
		display map  draw_env: false{
			image dataset_path +"satellite.png"  transparency: 0.2 refresh: false;
			//species Building;
			//species Node;
			//species Road;
			
		}
	}
}