/**
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */
#include <sourcemod>

new bool:isPaused;

public Plugin:myinfo =
{
	name = "Supplemental Stats",
	author = "Jean-Denis Caron",
	description = "Logs additional information about the game.",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/qpingu/tf2.pug.na-game-server"
};

public OnPluginStart()
{
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);

	AddCommandListener(Listener_Pause, "pause");

	PrintToChatAll("\x01\x03Logging supplemental statistics.");
}


public Action:Listener_Pause(client, const String:command[], argc)
{
	isPaused = !isPaused;

	if (isPaused)
		LogToGame("World triggered \"Game_Paused\"");
	else
		LogToGame("World triggered \"Game_Unpaused\"");

	return Plugin_Continue;
}

public Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
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
	
	LogToGame("\"%s<%d><%s><%s>\" picked up item \"%s\"",
		playerName,
		playerId,
		playerSteamId,
		playerTeam,
		item);
}

public Event_PlayerHealed(Handle:event, const String:name[], bool:dontBroadcast)
{
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
	
	LogToGame("\"%s<%d><%s><%s>\" triggered \"healed\" against \"%s<%d><%s><%s>\" (healing \"%d\")",
		healerName,
		healerId,
		healerSteamId,
		healerTeam,
		patientName,
		patientId,
		patientSteamId,
		patientTeam,
		amount);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
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
		LogToGame("\"%s<%d><%s><%s>\" triggered \"damage\" (damage \"%d\")",
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
