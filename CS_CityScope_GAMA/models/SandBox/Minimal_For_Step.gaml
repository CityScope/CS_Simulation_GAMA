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
	int nbCols<-20; 
	int nbRows<-20;
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
			    create TAZ number:1{
        	  		  nbProducedTrip<-rnd(10);
	      		  nbAttractedTrip<-rnd(5);
        	  		  location<-myself.location;
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
        list<geometry> geoms <- split_lines(road);
		create road from:geoms;
		road_graph <- as_edge_graph(geoms);
        
        ask TAZ{
        	 loop i from:0 to:nbProducedTrip{
        	 	point tg<-one_of(TAZ).location;
        	 	trips<+ tg::path_between(road_graph,self.location, tg);
        	 }
        }
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


species people skills:[moving]{
	list<point> targets;		
}

species TAZ skills:[moving]{
	int nbProducedTrip;
	int nbAttractedTrip;
	int nbResidential;
	int nbOffice;
	map<point,path> trips;
	bool drawTrip<-false;
	bool drawPath<-false;
    user_command "showTrip" action:showTrip;
	action showTrip{
		ask TAZ{
			drawTrip<-false;
		}
		self.drawTrip<-true;
	}
	user_command "showPath" action:showPath;
	action showPath{
		ask TAZ{
			drawPath<-false;
		}
		self.drawPath<-true;
	}

	aspect base{
		draw circle(10#m) color:#orange;
		//draw " " + nbProducedTrip +"/"+ nbAttractedTrip font: font("Helvetica", 12 + #zoom, #bold) color: #red at: location  perspective:false;
		if(drawTrip){
			loop i from:0 to:nbProducedTrip{
			draw circle(10#m) color:#orange;
			draw line([location,trips.keys[i]]) color:#gamablue width:2 end_arrow:10;
		}
		}
		if(drawPath){
			loop i from:0 to:nbProducedTrip{
		    rgb color<-rnd_color(255);
			loop seg over: trips.values[i].edges {
	  		  draw seg color:color  width:3;
	 	    }
		}
		}
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


experiment main type: gui {
	output {
		display map type:opengl background:#white{
			//species building position:{0,0,0};
			species road;
			species TAZ aspect:base;
		}
	}
}

