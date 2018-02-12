/**
* Name: AbstractGeneratedCity
* Author: Arnaud Grignard
* Description: Generate an abstract city (and the corresponding GIS) compatible with CityScope Model.
*/

model AbstractGeneratedCity

global {
	
	int nbCols<-10; 
	int nbRows<-10;
	geometry shape<-square(nbCols*10);
	init {

		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
              create building{
              	shape <- square(size*0.8);
			    location <- {size*i+size/2,size*j+size/2};
			    create amenities{
			    	 shape<-circle(size/2);
			    	 location <- myself.location;
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
        
		//save building to:"../SandBox/GeneratedGIS/buildings.shp" type:"shp" attributes: ["ID":: int(self), "TYPE"::type];
		//save road to:"../SandBox/GeneratedGIS/roads.shp" type:"shp" attributes: ["ID":: int(self), "TYPE"::type];
		//save amenities to:"../SandBox/GeneratedGIS/amenities.shp" type:"shp" attributes: ["ID":: int(self)];
	}
}
  
species building {
	string type;
	int size<-10;
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

species amenities {
	string type;
	int size<-1;
	aspect default {
		draw shape color:#white;
	}
}



experiment main type: gui {
	output {
		display map type:opengl{
			species building;
			species road;
			species amenities;
		}
	}
}

