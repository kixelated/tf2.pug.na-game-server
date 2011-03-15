#include <sourcemod>

new live = 0;

public Plugin:myinfo =
{
	name = "Supplemental Stats",
	author = "Jean-Denis Caron",
	description = "Adds per player damage done and heals received stats.",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/qpingu/tf2.pug.na-game-server"
};

public OnMapStart()
{
    live = -1;
}

public OnPluginStart()
{
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_win_panel", Event_WinPanel);
}

public Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(live != 1)
		return;

	decl String:playerName[32];
	decl String:playerSteamId[64];
	decl String:playerTeam[64];
	decl String:item[64];
	
	new playerId = GetEventInt(event, "userid");
	new player = GetClientOfUserId(playerId);
	GetClientAuthString(player, playerSteamId, sizeof(playerSteamId));
	GetClientName(player, playerName, sizeof(playerName));
	playerTeam = GetPlayerTeam(GetClientTeam(player));
	GetEventString(event, "item", item, sizeof(item))
	
	if ((strcmp(item, "medkit_medium") == 0) || (strcmp(item, "medkit_small") == 0))
	{
		LogToGame("\"%s<%d><%s><%s>\" picked up item \"%s\"",
			playerName,
			playerId,
			playerSteamId,
			playerTeam,
			item);
	}
}

public Event_PlayerHealed(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(live != 1)
		return;

	decl String:patientName[32];
	decl String:healerName[32];
	decl String:patientSteamId[64];
	decl String:healerSteamId[64];
	decl String:patientTeam[64];
	decl String:healerTeam[64];		// Silly medic healing a spy
	
	new patientId = GetEventInt(event, "patient");
	new healerId = GetEventInt(event, "healer");
	new patient = GetClientOfUserId(patientId);
	new healer = GetClientOfUserId(healerId);
	new amount = GetEventInt(event, "amount");
	
	GetClientAuthString(patient, patientSteamId, sizeof(patientSteamId));
	GetClientName(patient, patientName, sizeof(patientName));
	GetClientAuthString(healer, healerSteamId, sizeof(healerSteamId));
	GetClientName(healer, healerName, sizeof(healerName));
	
	patientTeam = GetPlayerTeam(GetClientTeam(patient));
	healerTeam = GetPlayerTeam(GetClientTeam(healer));
	
	LogToGame("\"%s<%d><%s><%s>\" triggered \"healed\" %d against \"%s<%d><%s><%s>\"",
		healerName,
		healerId,
		healerSteamId,
		healerTeam,
		amount,
		patientName,
		patientId,
		patientSteamId,
		patientTeam);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(live != 1)
		return;

	decl String:clientname[32];
	decl String:steamid[64];
	decl String:team[64];

	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	new attackerid = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(attackerid);
	new damage = GetEventInt(event, "damageamount");
	if(userid != attacker && attacker != 0)
	{
		GetClientAuthString(attacker, steamid, sizeof(steamid));
		GetClientName(attacker, clientname, sizeof(clientname));
		team = GetPlayerTeam(GetClientTeam(attacker));
		LogToGame("\"%s<%d><%s><%s>\" triggered \"damage\" %d",
			clientname,
			attackerid,
			steamid,
			team,
			damage);
	}
}

String:GetPlayerTeam(teamIndex)
{
	decl String:team[64];
	switch (teamIndex)
	{
		case 2:
			team = "Red";
		case 3:
			team = "Blue";
		default:
			team = "undefined";
	}
	
	return team;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(live == -1)
    {
        live = 0
    }
    else
    {
        live = 1;
    }
}

public Action:Event_WinPanel(Handle:event, const String:name[], bool:dontBroadcast)
{
    live = 0;
}
