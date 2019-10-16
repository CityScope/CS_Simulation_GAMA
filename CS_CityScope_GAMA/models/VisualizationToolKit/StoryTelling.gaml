/***
* Name: StoryTelling
* Author: Arnaud Grignard
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model StoryTelling

global{

	string cityGISFolder <- "./../../includes/City/volpe";
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp");
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp");
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp");
	geometry shape <- envelope(bound_shapefile);
	map<float,rgb> color_palette <-[2::rgb(37,193,34),5::rgb(193,146,34),10::rgb(34,154,193),4::rgb(56,34,193)];
	graph the_graph;
	
	init{
		create road from: roads_shapefile;
		the_graph <- as_edge_graph(road);	
		create building from:buildings_shapefile with: [usage::string(read("Usage")), type::int(read("MIT"))];
		create people number:250{
			speed<-10#km/#h + rnd(10)#km/#h;
			location<-any_location_in(one_of(road));
			location<-any_location_in(one_of(building where (each.usage="R")));
			target<-any_location_in(one_of(building where (each.usage="O")));
			color <-color_palette.values[rnd(3)];
			aleatoire<-false;
			timeToLeave<-rnd(200)+300;
		}
		create people number:500{
			speed<-5#km/#h + rnd(2)#km/#h;
			location<-any_location_in(one_of(road));
			location<-any_location_in(one_of(building where (each.usage="R")));
			target<-any_location_in(one_of(building where (each.usage="O")));
			color <-color_palette.values[rnd(3)];
			aleatoire <- flip(0.5) ? false:true;
			timeToLeave<-rnd(200)+300;
		}		
	}
}

species building{
	int type;
	string usage;
	aspect base{
		draw shape color:#gray;
	}
}

species road  {
    aspect base {
	draw shape color: color ;
	}
}

species people skills:[moving]{
	rgb color;
	point target;
	float speed;
	bool aleatoire;
	int timeToLeave;
	aspect base{
		if(aleatoire){
			draw circle(5#m) color:color;
		}
		else{
		    draw circle(5#m) color:color border:color-50;	
		}	
	}
	
	reflex move {
		if(cycle>timeToLeave){
			if(aleatoire){
				do wander on:the_graph speed:speed; 
			}else{
			    do goto target:target on: the_graph speed:speed;	
			}	
		}else{
			do wander speed:speed*0.1;
		}
	}
}

experiment stroytelling type:gui autorun:false{
	output{
		display Boston type:opengl autosave:false  fullscreen:1 synchronized:true  draw_env:false{
			species road aspect:base refresh:false;
			species building aspect:base refresh:false;
			species people aspect:base;	
		}
	}	
}