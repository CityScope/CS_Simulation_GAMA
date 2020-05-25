/***
* Name: GridDesign
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model GridDesign

global {
	/** Insert the global definitions, variables and actions here */
	file shape_file_world<- shape_file("./../../includes/AutonomousCities/Andorra/bound.shp");
				
	geometry shape<-envelope(shape_file_world);
	float width<-shape.width;
	float height<-shape.height;
	int nbCols<-5;
	int nbRows<-5;
    
	init{
		
		create bound{
			shape<-(rectangle(width,height)) at_location {width/2,height/2};
		}
		loop i from:0 to:nbCols-1{
			loop j from:0 to:nbRows-1{
				create squareCell{
					shape<-rectangle(width/nbCols,height/nbRows)*0.9;
					location<-{i*width/nbCols+width/nbCols/2,j*height/nbRows+height/nbRows/2 };
				}
			}
		}
		//title
		create legend{
			type<-"title";
			shape<-rectangle(3*width/nbCols,height/nbRows);
			location<-{2*width/nbCols+width/nbCols/2,0*height/nbRows+height/nbRows/2 };
		}
		//left
		loop i from:1 to:3{
			create legend{
				type<-"left"+i;
				shape<-rectangle(width/nbCols,height/nbRows)*0.9;
				location<-{0*width/nbCols+width/nbCols/2,i*height/nbRows+height/nbRows/2 };
			}
		}
		//right
		loop i from:1 to:3{
			create legend{
				type<-"right"+i;
				shape<-rectangle(width/nbCols,height/nbRows)*0.9;
				location<-{4*width/nbCols+width/nbCols/2,i*height/nbRows+height/nbRows/2 };
			}
		}
		//bottom
		create legend{
			type<-"bottom";
			shape<-rectangle(3*width/nbCols,height/nbRows);
			location<-{2*width/nbCols+width/nbCols/2,4*height/nbRows+height/nbRows/2 };
		}
		
		save bound to:"../results/bound.shp" type:"shp"; 
		save legend to:"../results/legend.shp" type:"shp" attributes: ["type"::type]; 
		save squareCell to:"../results/squareCell.shp" type:"shp"; 
	}
	
}

species bound{
	aspect default{
	  draw shape color:#red empty:true;	
	}
}

species legend{
	string type;
	aspect default{
	  draw shape color:#green empty:true width:2;	
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
			species legend;
			species squareCell;
		}
	}
}
