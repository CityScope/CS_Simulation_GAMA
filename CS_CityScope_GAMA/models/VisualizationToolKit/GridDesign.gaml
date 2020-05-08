/***
* Name: GridDesign
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model GridDesign

global {
	/** Insert the global definitions, variables and actions here */
	file shape_file_world<- shape_file("./../../includes/City/volpe/Bounds.shp");
				
	geometry shape<-envelope(shape_file_world);
	float width<-3600#m*3;
	float height<-2400#m*3;
	int nbCols<-5;
	int nbRows<-5;
    
	init{
		
		create bound{
			shape<-rectangle(width,height) at_location {width/2,height/2};
		}
		loop i from:0 to:nbCols-1{
			loop j from:0 to:nbRows-1{
				create squareCell{
					shape<-rectangle(width/nbCols,height/nbRows)*0.9;
					location<-{i*width/nbCols+width/nbCols/2,j*height/nbRows+height/nbRows/2 };
				}
			}
		}
		save bound to:"../results/bound.shp" type:"shp"; 
		save squareCell to:"../results/squareCell.shp" type:"shp"; 
	}
	
}

species bound{
	aspect default{
	  draw shape color:#black empty:true;	
	}
}

species squareCell{
	aspect default{
	  draw shape color:#black empty:true;	
	}	
}

experiment GridDesign type: gui{
	output {
		display Grid  type:opengl{
			species bound;
			species squareCell;
		}
	}
}
