#include <amxmodx>
#include <hamsandwich>
#include <fun>

#define PLUGIN "Team Gang Up"
#define VERSION "1.0"
#define AUTHOR "payampap"
#define TEAM_CT 0
#define TEAM_T 1

new Float:C_STASK_INTERVAL = 2.0
new C_MAX_GANG_DISTANCE = 400

new g_max_players
new g_list_ptr = 0
new g_player_gang_count_list[32][2] // [ id, gangCount ]


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("gang_heal_per_member", "2")
	register_cvar("gang_heal_max_value", "10")
	register_cvar("gang_reduce_per_member", "0.15")
	register_cvar("gang_reduce_max_value", "0.5")
	
	RegisterHam(Ham_TakeDamage, "player", "hook_TakeDamage")
	
	g_max_players = get_maxplayers()
	
	set_task(C_STASK_INTERVAL,"check_gang_state",0,"",0,"b",0)
}

public calculate_gang_for_team(team)
{
	new iPlayers[32], iPnum
	new iStartPos[3], iEndPos[3], iDist
	
	
	if (team == TEAM_CT)
	{
		get_players(iPlayers, iPnum, "aeh", "CT")
	}
	else if (team == TEAM_T)
	{
		get_players(iPlayers, iPnum, "aeh", "TERRORIST")
	}
	for (new i=0; i<iPnum; i++)
	{
		g_player_gang_count_list[g_list_ptr][0] = iPlayers[i]
		
		for (new j=i+1; j<iPnum; j++)
		{
			get_user_origin(iPlayers[i], iStartPos);
			get_user_origin(iPlayers[j], iEndPos);
			iDist = get_distance(iStartPos, iEndPos)
			if (iDist <= C_MAX_GANG_DISTANCE)
			{
				g_player_gang_count_list[g_list_ptr][1] += 1
				// also upadte opponent
				g_player_gang_count_list[g_list_ptr+j-i][1] += 1
			}
		}
		
		g_list_ptr++
	}
}

public check_gang_state()
{
	/* reset damage reduction list */
	for (new i=0; i<g_max_players; i++)
	{
		g_player_gang_count_list[i][1] = 0
	}
	g_list_ptr = 0
	calculate_gang_for_team(TEAM_CT)
	calculate_gang_for_team(TEAM_T)
	
	new iPlayerId, iPlayerGangSize, iPlayerHealth
	new cv_hp 	= get_cvar_num("gang_heal_per_member")
	new cv_max_hp 	= get_cvar_num("gang_heal_max_value")
	
	for (new i = 0; i < g_list_ptr; i++)
	{
		iPlayerId = g_player_gang_count_list[i][0]
		iPlayerGangSize = g_player_gang_count_list[i][1]
		
		set_hudmessage(255, 255, 255, 0.9, 0.8, 0, 0.0, C_STASK_INTERVAL, 0.0, 0.0)
		
		if (iPlayerGangSize)
		{
			show_hudmessage(iPlayerId, "Gang Size: %i^nDamage Reduction: %.1f%%", iPlayerGangSize + 1, getPlayerDamageReduction(iPlayerId) * 100.0)
			new array[1]
			array[0] = iPlayerId
			show_effect(array)
			
			/* heal player */
			iPlayerHealth = get_user_health(iPlayerId)
			if (iPlayerHealth < 100)
			{
				set_user_health(iPlayerId, min(iPlayerHealth + min(iPlayerGangSize * cv_hp, cv_max_hp), 100))
			}
		}
	}
	
}

public show_effect(args[])
{
	new iStartPos[3];
	get_user_origin(args[0], iStartPos);
	
	message_begin(MSG_ALL, SVC_TEMPENTITY, .player = 0);
	write_byte(TE_ELIGHT);
	write_short(args[0]); //entity
	write_coord(iStartPos[0]);
	write_coord(iStartPos[1]);
	write_coord(iStartPos[2]);
	write_coord(10); //radius
	if (get_user_team(args[0]) == TEAM_T)
	{
		write_byte(255); //r
		write_byte(0); //g
		write_byte(0); //b
	}
	else
	{
		write_byte(0); //r
		write_byte(255); //g
		write_byte(255); //b
	}
	write_byte(20); //life
	write_coord(0); //decay
	message_end();
}


public Float:getPlayerDamageReduction(id)
{
	new Float:iReduction 		= 0.0
	new Float:cv_reduction 		= get_cvar_float("gang_heal_per_member")
	new Float:cv_max_reduction	= get_cvar_float("gang_heal_max_value")
	
	for (new i=0; i<g_max_players; i++)
	{
		if (g_player_gang_count_list[i][0] == id)
		{
			iReduction = floatmin(float(g_player_gang_count_list[i][1]) * cv_reduction, cv_max_reduction)
			break
		}
	}
	return iReduction
}

public hook_TakeDamage(Victim, inflictor, attacker, Float:damage, damagebits)
{
	damage *= 1.0 - getPlayerDamageReduction(Victim)
	SetHamParamFloat(4, floatmax(damage, 1.0))
	return HAM_HANDLED
}

public plugin_end( )
{
	
}
