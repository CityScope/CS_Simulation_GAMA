model CityIOGAMA



global {

	geometry shape <- square(1 #km);
 	string cityIOurl <-"https://cityio.media.mit.edu/api/table/virtual_table";
    map<string, unknown> matrixData;
    map<int,rgb> buildingColors <-[-2::#red, -1::#orange,0::rgb(189,183,107), 1::rgb(189,183,107), 2::rgb(189,183,107),3::rgb(230,230,230), 4::rgb(230,230,230), 5::rgb(230,230,230),6::rgb(40,40,40),7::#cyan,8::#green,9::#gray];
    map<string, unknown> header;
    map<string, unknown> spatial;
	int refresh <- 100 min: 1 max:1000 parameter: "Refresh Grid rate (cycle):" category: "Grid";
	int nbCols;
	int nbRows;

	init {
	 do initGrid;
	}

	action initGrid{
        matrixData <- json_file(cityIOurl).contents;
		spatial <-matrixData["header"]["spatial"];
		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
				cityMatrix cell <- cityMatrix grid_at { i, j };
				cell.type<-int(matrixData["grid"][j*nbCols+i][0]);
				cell.depth<-int(matrixData["grid"][j*nbCols+i][1]);
			}
        }  
	}

	action pushGrid (map<string, unknown> _matrixData){
	  save(json_file("https://cityio.media.mit.edu/api/table/update/cityIO_Gama", _matrixData));
	}

	reflex updateGrid when: ((cycle mod refresh) = 0){
		do initGrid;
 	}
}

grid cityMatrix width:nbCols height:nbRows {
	int size;
	int type;
	int depth;
    aspect base{
	  draw shape color:buildingColors[type] depth:depth;
	  draw string(type) color:#black border:#black at:{location.x,location.y,depth+1};		
	}
}


experiment Display  type: gui {
	action _init_ {
   		map<string, unknown> data <- json_file("https://cityio.media.mit.edu/api/table/virtual_table").contents;
		create CityIOGAMA_model with: [nbCols::int(data["header"]["spatial"]["ncols"]), nbRows::int(data["header"]["spatial"]["nrows"]),matrixData::data];
	}

	output {	
		display cityMatrixView  type:opengl  background:#black {
			species cityMatrix aspect:base;
		}
	}
}