 /**
* Name: cityIO API for GAMA
* Author: Arnaud Grignard
* Description: Gives the basic read and write feature for cityIO
*  Note: The save to geojson is a feature that is not available in the GAMA 1.8 RC2 (you need a newe version)
*/
model CityIOGAMA



global {

	//geometry shape <- square(1 #km);
 	string cityIOurl <-"http://cityio.media.mit.edu/api/table/dungeonmaster"; 	
 	string VIRTUAL_LOCAL_DATA <- "./../includes/virtual_table.json";
    map<string, unknown> inputMatrixData;
    map<string, map> outputMatrixData;
    map<string, unknown> outputSimulationData;
    map<int,rgb> buildingColors <-[-2::#red, -1::#orange,0::rgb(189,183,107), 1::rgb(189,183,107), 2::rgb(189,183,107),3::rgb(230,230,230), 4::rgb(230,230,230), 5::rgb(230,230,230),6::rgb(40,40,40),7::#cyan,8::#green,9::#gray];
    map<string, unknown> header;
    map<string, unknown> spatial;
    bool updateGrid <- true parameter: "Update Grid:" category: "Grid";
	int gridRrefresh <- 100 min: 1 max:1000 parameter: "Refresh Grid rate (cycle):" category: "Grid";
	bool pushGridToCityIO <- false parameter: "Push Grid to cityIO every refresh cycles" category: "Grid";
	bool pushGridToLocalFile <- false parameter: "Push Grid to a local every refresh cycles" category: "Grid";
	
	int agentRrefresh <- 100 min: 1 max:1000 parameter: "Refresh Agent rate (cycle):" category: "Agent";
	bool pushAgentToCityIO <- false parameter: "Push Agent to cityIO every refresh cycles" category: "Agent";
	bool pushAgentToLocalFile <- false parameter: "Push Agent to a local every refresh cycles" category: "Agent";
	
	int nbCols;
	int nbRows;
	int cellSize;

	init {
	 write " --------------------- in global init ---------------";	
	 do initGrid;
	 write "---------------------- after init Grid --------------";
	 create people number:10{
	 	shape<-circle(1);
	 }
	}
    // Get a cityIO grid from a url and populate matrixData object
	action initGrid{
		write " --------------------- initGrid before try ---------------";	
		try {
			inputMatrixData <- json_file(cityIOurl).contents;
		}

		catch {
			inputMatrixData <- json_file(VIRTUAL_LOCAL_DATA).contents;
			write #current_error + " Impossible to read from cityIO  - Connection to Internet lost or cityIO is offline - inputMatrixData is a local version from cityIO_Kendall.json";
		}
        write " --------------------- initGrid after try ---------------";
        write " nbCols in InitGrid  " + nbCols;
        write inputMatrixData;
		spatial <-map(inputMatrixData["header"])["spatial"];
		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
				cityMatrix cell <- cityMatrix grid_at { i, j };
				cell.type<-int(list(list(inputMatrixData["grid"])[j*nbCols+i])[0]);
				cell.depth<-int(list(list(inputMatrixData["grid"])[j*nbCols+i])[1]);
			}
        } 
       write length(cityMatrix where (each.type=-1)); 
	}

	action pushGrid (map<string, unknown> _matrixData){
	  outputMatrixData <- _matrixData;
	  map(outputMatrixData["header"]["owner"])["institute"]<-"Gama Platform";
	  map(outputMatrixData["header"]["owner"])["institute"]<-"Gama Platform";
	  map(outputMatrixData["header"]["owner"])["name"]<-"Arnaud Grignard";
	  map(outputMatrixData["header"]["spatial"])["longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["latitude"]<-21.02;
	  map(outputMatrixData["header"]["spatial"])["physical_longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["physical_latitude"]<-21.02;
	  
	  if(pushGridToCityIO){
	  	try{
	  	  save(json_file("https://cityio.media.mit.edu/api/table/update/cityIO_Gama", outputMatrixData));		
	  	}catch{
	  	  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
	  	} 
	  }
	  if(pushGridToLocalFile){
	  	save(json_file("./../includes/cityIO_Gama.json", outputMatrixData));
	  }
	}
	
	action pushAgent(map<string, unknown> _matrixData){
	  outputMatrixData <- _matrixData;
	  map(outputMatrixData["header"]["owner"])["institute"]<-"Gama Platform";
	  map(outputMatrixData["header"]["owner"])["institute"]<-"Gama Platform";
	  map(outputMatrixData["header"]["owner"])["name"]<-"Arnaud Grignard";
	  map(outputMatrixData["header"]["spatial"])["longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["latitude"]<-21.02;
	  map(outputMatrixData["header"]["spatial"])["physical_longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["physical_latitude"]<-21.02;
		list projected_points <- people collect ([each.location]);
		list<map> features<-list_with(length(projected_points), map([]));	
		loop i from: 0 to:length(projected_points)-1{
			list unprojected_point <-point(projected_points[i][0] CRS_transform "EPSG:4326");
			map point_geometry<-['coordinates'::unprojected_point, 'type'::'Point'];
			map point_properties<-['property_1'::2];
			map feature<-["type":: "Feature",'geometry'::point_geometry, 'properties'::point_properties, 'id'::i];
			features[i]<-feature;
			}
		map output_geo<-["type":: "FeatureCollection",'features'::features];	
		outputMatrixData["objects"]<-["points"::output_geo];
		if(pushAgentToCityIO){
	  	try{
	  	  save(json_file("https://cityio.media.mit.edu/api/table/update/cityIO_Gama_Agent", outputMatrixData));		
	  	}catch{
	  	  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
	  	} 
	  }
	  if(pushAgentToLocalFile){
	  	save(json_file("./../includes/cityIO_Gama_Agent.json", outputMatrixData));
	  }
	}

	reflex updateGrid when: ((cycle mod gridRrefresh) = 0 and updateGrid){
		do initGrid;
		if(pushGridToCityIO){
		  do pushGrid(inputMatrixData);	
		}
 	}
 	
 	reflex updateAgent when: ((cycle mod agentRrefresh) = 0){
	  do pushAgent(inputMatrixData);	
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

species people skills:[moving]{
	int attribute1;
	int attribute2;
	reflex move{
		do wander;
	}
	aspect default{
		draw shape color:#blue;
	}
}


experiment Display  type: gui autorun:true{
	action _init_ {
		write "------------------------- Expe init 1 ---------------------- ";
   		map<string, map> data;
   		try {
			data <- json_file(cityIOurl).contents;
		}

		catch {
			data <- json_file(VIRTUAL_LOCAL_DATA).contents;
			write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_Kendall.json";
		}
   		write "------------------------- Expe init 2---------------------- ";
   		
		create CityIOGAMA_model with: [nbCols::int(map(data["header"]["spatial"])["ncols"]), nbRows::int(map(data["header"]["spatial"])["nrows"]),cellSize::int(map(data["header"]["spatial"])["cellSize"]),inputMatrixData::data]{
			//shape <-rectangle(nbCols*cellSize, nbRows*cellSize);
			write "nbCols: " + nbCols + "nbRows: " + nbRows + " cellSize: " + cellSize + "data: " + inputMatrixData ;
		}
		
		write "------------------------- Expe init 3---------------------- ";
		
		write simulations[0];
		
		write "------------------------- Expe init 4 ---------------------- ";
	}

	output {	
		display cityMatrixView  type:opengl  background:#black {
			species cityMatrix aspect:base;
			species people aspect: default;
		}
	}
}