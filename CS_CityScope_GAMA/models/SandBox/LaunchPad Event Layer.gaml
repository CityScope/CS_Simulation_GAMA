/**
* Name: Launch Pad Event Feature
* Author: Arnaud Grignard 
* Description: Model which shows how to use the event layer to trigger an action with a LaunchPad Novation (This model only work with the launchpad plugins extension available in GAMA 1.7 since January 2018)
* Tags: tangible interface, gui, launchpad
 */
model event_layer_model

global skills:[launchpadskill]
{
	list<string> buttonColors <-["red","orange","brown","yellow","lightyellow","green","darkgreen","black"];
	map<string,string> function_map <-["UP"::buttonColors[0],"DOWN"::buttonColors[1],"LEFT"::buttonColors[2],"RIGHT"::buttonColors[3],"SESSION"::buttonColors[4],"USER_1"::buttonColors[5],"USER_2"::buttonColors[6],"MIXER"::buttonColors[7]];
	init{
	  do resetPad;
	  do setButtonLight colors:buttonColors;	
	}
	
	action updateGrid
	{   
		if(function_map.keys contains buttonPressed and buttonPressed != "MIXER"){
		    ask cell[ int(padPressed.y *8 + padPressed.x)]{color <- rgb(function_map[buttonPressed]);}
		    do setPadLight color:function_map[buttonPressed];
		}
		if(buttonPressed = "MIXER"){
			ask cell[ int(padPressed.y *8 + padPressed.x)]{color <- #white;}
		}			
		if(buttonPressed="ARM"){
			do resetPad;
			do setButtonLight colors:buttonColors;	
			ask cell{
				color<-#white;
			}
		}
		do updateDisplay;
	}	
}

grid cell width: 8 height: 8;

experiment Displays type: gui
{
	output
	{
		display View_change_color 
		{
			grid cell lines: #black;
			event "pad_down2" type: "launchpad" action: updateGrid;
		}
	}
}