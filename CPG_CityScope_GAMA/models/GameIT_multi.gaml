/**
* Name: Game IT on different cities
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform.
*/
model CityScope

import "game_it_v1.0.gaml"


global
{
}

experiment GameITMulti type: gui parent: gameit
{
	init
	{
        create simulation with: [case_study::"Taipei"];
	}


}



