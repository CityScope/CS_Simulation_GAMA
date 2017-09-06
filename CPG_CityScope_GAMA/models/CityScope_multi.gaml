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
        create simulation with: [cityScopeCity::"andorra", minimum_cycle_duration::0.02, angle::3.0, center::{2550,895},brickSize::37.5,coeffPop::2.0,coeffSize::2];
		create simulation with: [cityScopeCity:: "San_Francisco", minimum_cycle_duration::0.02,angle::3.0, center::{2550,895},brickSize::37.5,coeffPop::15,coeffSize::1];
		create simulation with: [cityScopeCity:: "Taipei_MainStation", minimum_cycle_duration::0.02,angle::3.0, center::{2550,895},brickSize::37.5,coeffPop::40.0,coeffSize::1];
		create simulation with: [cityScopeCity:: "Shanghai", minimum_cycle_duration::0.02,angle::3.0, center::{2550,895},brickSize::37.5,coeffPop::10.0,coeffSize::1];	
	}

	parameter 'CityScope:' var: cityScopeCity category: 'GIS' <- "volpe" among: ["volpe", "andorra","San_Francisco","Taipei_MainStation","Shanghai"];
	float minimum_cycle_duration <- 0.02;
	output
	{
		display CityScope type: opengl parent: CityScopeVirtual
		{
		}

	}

}



