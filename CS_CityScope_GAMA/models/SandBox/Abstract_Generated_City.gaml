/**
* Name: AbstractGeneratedCity
* Author: Arnaud Grignard
* Description: Generate an abstract city (and the corresponding GIS) compatible with CityScope Model.
*/

model AbstractGeneratedCity

global {
	
	int nbCols<-10; 
	int nbRows<-10;
	list<string> usages<-["R","O"];
	list<string> scales<-["S","M","L"];

	init {

        create bounds{
         	location<-{world.shape.width/2,world.shape.height/2};
         	shape<-rectangle(world.shape.width,world.shape.height);
        }
        create table_bounds{
         	location<-{world.shape.width/2,world.shape.height/2};
         	shape<-rectangle(world.shape.width,world.shape.height);
        }
		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
              create building{
              	shape <- square(size*0.8);
			    location <- {size*i+size/2,size*j+size/2};
			    usage<- usages[rnd(1)];
			    scale<- scales[rnd(2)];
			    create amenities{
			    	 shape<-circle(size/2);
			    	 location <- myself.location;
			    	 usage<-"A";
			    	 scale<-myself.usage;
			    }
              }
			}
        }  
        loop i from: 0 to: nbCols {
			create road{
				shape<-line([{size*i,0},{size*i,size*nbRows}]);
			}
        } 
        
        loop j from: 0 to: nbRows {
			create road{
				shape<-line([{0,size*j},{size*nbCols,size*j}]);
			}
        } 
        
		save building to:"../SandBox/GeneratedGIS/buildings.shp" type:"shp" attributes: ["ID":: int(self), "Usage"::usage, "Scale"::scale];
		save road to:"../SandBox/GeneratedGIS/roads.shp" type:"shp" attributes: ["ID":: int(self), "TYPE"::type];
		save amenities to:"../SandBox/GeneratedGIS/amenities.shp" type:"shp" attributes: ["ID":: int(self),"Usage"::usage, "Scale"::scale];
		save bounds to:"../SandBox/GeneratedGIS/bounds.shp" type:"shp" attributes: ["ID":: int(self)];
		save table_bounds to:"../SandBox/GeneratedGIS/table_bounds.shp" type:"shp" attributes: ["ID":: int(self)];
	}
}
  
species building {
	string type;
	int size<-10;
	string usage;
	string scale;
	aspect default {
		draw shape color:#black border:#white;
	}
}


species road {
	string type;
	int size<-10;
	aspect default {
		draw shape color:#black;
	}
}

species amenities parent:building{
	string type;
	int size<-1;
	aspect default {
		draw shape color:#white;
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
		display map type:opengl{
			species bounds;
			species table_bounds;
			species building;
			species road;
			species amenities;
			
		}
	}
}

