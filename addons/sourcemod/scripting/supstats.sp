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
#include <sdktools>

new live = 0;
new bool:isPaused
new String:map[64];

public Plugin:myinfo =
{
	name = "Supplemental Stats",
	author = "Jean-Denis Caron",
	description = "Logs additional information about the game.",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/qpingu/tf2.pug.na-game-server"
};

public OnMapStart()
{
	live = -1;
	GetCurrentMap(map, sizeof(map));
}

public OnPluginStart()
{
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_win_panel", Event_WinPanel);
	AddCommandListener(Listener_Pause, "pause");
	RegConsoleCmd("tournament_info", Command_TournamentInfo, "Gets the remaining time and score for the current tournament");
}

public Action:Command_TournamentInfo(client, args)
{
	if (live != 1)
	{
		ReplyToCommand(client, "Tournament is not live");
		return Plugin_Handled;
	}

	new blueScore = GetTeamScore(3);
	new redScore = GetTeamScore(2);
	new clientCount = GetClientCount(false);
	decl String:finalOutput[1024];
	finalOutput[0] = 0;

	new timeleft;
	if (GetMapTimeLeft(timeleft))
	{
		new mins, secs;

		if (timeleft > 0)
		{
			mins = timeleft / 60;
			secs = timeleft % 60;
			FormatEx(finalOutput, sizeof(finalOutput), "Time left: \"%02d:%02d\" Score: \"%d:%d\" Map: \"%s\" Players: \"%d\"", mins, secs, blueScore, redScore, map, clientCount);
		}
		else
		{
			FormatEx(finalOutput, sizeof(finalOutput), "Time left: \"00:00\" Score: \"%d:%d\" Map: \"%s\" Players: \"%d\"", mins, secs, blueScore, redScore, map, clientCount);
		}
	}
	ReplyToCommand(client, finalOutput);
	return Plugin_Handled;
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
	
	LogToGame("\"%s<%d><%s><%s>\" picked up item \"%s\"",
		playerName,
		playerId,
		playerSteamId,
		playerTeam,
		item);
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
