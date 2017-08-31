/**
* Name: CityScope Kendall
* Author: Arnaud Grignard
* Description: Agent-based model running on the CityScope Platform. Actually used on 2 different cities.
*/
model CityScope

import "CityScope_main.gaml"


global
{
}

experiment CityScopeMulti type: gui parent: CityScopeMainVirtual
{
	init
	{
		create simulation with: [cityScopeCity::"andorra", minimum_cycle_duration::0.02];
		//create simulation with: [cityScopeCity:: "san_Francisco", minimum_cycle_duration::0.02];
		//create simulation with: [cityScopeCity:: "Taipei_MainStation", minimum_cycle_duration::0.02];
		//create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02];	
	}

	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <- "volpe" among: ["volpe", "andorra"];
	float minimum_cycle_duration <- 0.02;
	output
	{
		display CityScope type: opengl parent: CityScopeVirtual
		{
		}

	}

}



