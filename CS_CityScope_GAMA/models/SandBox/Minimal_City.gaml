/**
* Name: AbstractGeneratedCity
* Author: Arnaud Grignard
* Description: Generate an abstract city (and the corresponding GIS) compatible with CityScope Model.
*/

model AbstractGeneratedCity

global {
	float worldWidth<-1#km;
	float worldHeight<-1#km;
	geometry shape<-rectangle(worldWidth,worldHeight);
	float blockSize<-125#m;
	int nbCols<-8; 
	int nbRows<-8;
	list<string> usages<-["R","O"];
	list<string> scales<-["S","M","L"];
	bool saveGIS<-false;
	graph road_graph;
	graph<people, people> interaction_graph;

	init {

        create bounds{
         	location<-{world.shape.width/2,world.shape.height/2};
         	shape<-rectangle(world.shape.width*4,world.shape.height*2);
        }
        create table_bounds{
         	location<-{world.shape.width/2,world.shape.height/2};
         	shape<-rectangle(world.shape.width,world.shape.height);
        }
		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
              create building{
              	shape <- square(blockSize*0.8);
			    location <- {blockSize*i+blockSize/2,blockSize*j+blockSize/2};
			    usage<- usages[rnd(1)];
			    scale<- scales[rnd(2)];
			    create amenities{
			    	 shape<-square(size);
			    	 location <- myself.location;
			    	 usage<-"A";
			    	 scale<-myself.usage;
			    	 myBuilding<-myself;
			    }
              }
			}
        }  
        loop i from: 0 to: nbCols {
			create road{
				shape<-line([{blockSize*i,0},{blockSize*i,blockSize*nbRows}]);
			}
        } 
        
        loop j from: 0 to: nbRows {
			create road{
				shape<-line([{0,blockSize*j},{blockSize*nbCols,blockSize*j}]);
			}
        }
        road_graph <- as_edge_graph(road);
        
        create people number:100{
        	  location<-any_location_in(one_of(amenities));
        }
	}

}

species macroBlock skills:[moving]{
	point size;
	list<building> buildings;
	reflex move{
	 	do wander;	
	}

	aspect default{
		draw rectangle(size.x,size.y) color:#white border:#gray;
	}
}
  
species building skills:[moving]{
	string type;
	float size<-blockSize;
	string usage;
	string scale;
	reflex move{
		//do wander;
	}
	aspect default {
		draw shape color:#black border:#black;
	}
}


species road {
	string type;
	aspect default {
		draw shape color:#black;
	}
}

species amenities {
	string type;
	float size<-blockSize*0.1;
	string usage;
	string scale;
	building myBuilding;
	aspect default {
		draw shape color:#white;
	}
}
species people skills:[moving]{
	list<point> targets;
	point myTarget<-any_location_in(one_of(amenities));
	
	reflex move{
			do goto (target:myTarget,recompute_path: false);
	}
	aspect base{
		draw circle(2#m) color:#gamaorange;
	}
	
	aspect trajectory{
		draw curve(location,myTarget.location,rnd(0.5),true,100) color:#red;
	}
}

species bounds{
	aspect default {
		draw shape color:#black;
	}
}

species table_bounds{
	aspect default {
		draw shape color:#black;
	}
}
//grid cell width: 8 height: 8;

experiment main type: gui {
	output {
		display map type:opengl background:#white{
			//species bounds;
			//grid cell lines: #black;
			species macroBlock;
			species building position:{0,0,0};
			species road;
			species amenities;
			species people aspect:base;
			//species people aspect:trajectory;
		}
	}
}

