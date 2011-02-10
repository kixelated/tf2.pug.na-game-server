/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Mapchooser Plugin
 * Creates a map vote at appropriate times, setting sm_nextmap to the winning
 * vote
 *
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
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
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1
#include <sourcemod>
#include <mapchooser>
#include <nextmap>
#include <colors>
#include "mapchooser_extended/VoteSound.sp"
#include "mapchooser_extended/VoteWarning.sp"
#include "mapchooser_extended/DisplayVoteProgress.sp"
#include "mapchooser_extended/RemoveNormalMapchooser.sp"
#include "mapchooser_extended/MapListCustomization.sp"

#define VERSION "1.3"

public Plugin:myinfo =
{
	name = "Extended Mapvote",
	author = "Zuko, SM Community and AlliedModders LLC",
	description = "Extended Mapvoting Plugin",
	version = VERSION,
	url = "http://www.sourcemod.net/"
};

/* Valve ConVars */
new Handle:g_Cvar_Winlimit = INVALID_HANDLE;
new Handle:g_Cvar_Maxrounds = INVALID_HANDLE;
new Handle:g_Cvar_Fraglimit = INVALID_HANDLE;
new Handle:g_Cvar_Bonusroundtime = INVALID_HANDLE;

/* Plugin ConVars */
new Handle:g_Cvar_StartTime = INVALID_HANDLE;
new Handle:g_Cvar_StartRounds = INVALID_HANDLE;
new Handle:g_Cvar_StartFrags = INVALID_HANDLE;
new Handle:g_Cvar_ExtendTimeStep = INVALID_HANDLE;
new Handle:g_Cvar_ExtendRoundStep = INVALID_HANDLE;
new Handle:g_Cvar_ExtendFragStep = INVALID_HANDLE;
new Handle:g_Cvar_ExcludeMaps = INVALID_HANDLE;
new Handle:g_Cvar_IncludeMaps = INVALID_HANDLE;
new Handle:g_Cvar_NoVoteMode = INVALID_HANDLE;
new Handle:g_Cvar_Extend = INVALID_HANDLE;
new Handle:g_Cvar_DontChange = INVALID_HANDLE;
new Handle:g_Cvar_EndOfMapVote = INVALID_HANDLE;
new Handle:g_Cvar_VoteDuration = INVALID_HANDLE;
new Handle:g_Cvar_RunOff = INVALID_HANDLE;
new Handle:g_Cvar_RunOffPercent = INVALID_HANDLE;
new Handle:g_Cvar_BlockSlots = INVALID_HANDLE;
new Handle:g_Cvar_MaxRunOffs = INVALID_HANDLE;
new Handle:g_Cvar_StartTimePercent = INVALID_HANDLE;
new Handle:g_Cvar_StartTimePercentEnable = INVALID_HANDLE;

new Handle:g_VoteTimer = INVALID_HANDLE;
new Handle:g_RetryTimer = INVALID_HANDLE;

/* Data Handles */
new Handle:g_MapList = INVALID_HANDLE;
new Handle:g_NominateList = INVALID_HANDLE;
new Handle:g_NominateOwners = INVALID_HANDLE;
new Handle:g_OldMapList = INVALID_HANDLE;
new Handle:g_NextMapList = INVALID_HANDLE;
new Handle:g_VoteMenu = INVALID_HANDLE;

new g_Extends;
new g_RunOffs;
new g_TotalRounds;
new bool:g_HasVoteStarted;
new bool:g_WaitingForVote;
new bool:g_MapVoteCompleted;
new bool:g_ChangeMapAtRoundEnd;
new bool:g_ChangeMapInProgress;
new g_mapFileSerial = -1;

new String:g_map1[128];
new String:g_map2[128];
new String:g_mapd1[128];
new String:g_mapd2[128];
new g_NominateCount = 0;
new MapChange:g_ChangeTime;

new Handle:g_NominationsResetForward = INVALID_HANDLE;

/* Upper bound of how many team there could be */
#define MAXTEAMS 10
new g_winCount[MAXTEAMS];

#define VOTE_EXTEND "##extend##"
#define VOTE_DONTCHANGE "##dontchange##"

public OnPluginStart()
{
	LoadTranslations("mapchooser_extended.phrases"); // $ changed
	LoadTranslations("common.phrases");

	new arraySize = ByteCountToCells(33);
	g_MapList = CreateArray(arraySize);
	g_NominateList = CreateArray(arraySize);
	g_NominateOwners = CreateArray(1);
	g_OldMapList = CreateArray(arraySize);
	g_NextMapList = CreateArray(arraySize);

	CreateConVar("sm_mapvote_version", VERSION, "MapChooser Extended Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_Cvar_EndOfMapVote = CreateConVar("sm_mapvote_endvote", "1", "Specifies if MapChooser should run an end of map vote", _, true, 0.0, true, 1.0);
	g_Cvar_StartTime = CreateConVar("sm_mapvote_start", "10.0", "Specifies when to start the vote based on time remaining.", _, true, 1.0);
	g_Cvar_StartRounds = CreateConVar("sm_mapvote_startround", "2.0", "Specifies when to start the vote based on rounds remaining. Use 0 on TF2 to start vote during bonus round time", _, true, 0.0);
	g_Cvar_StartFrags = CreateConVar("sm_mapvote_startfrags", "5.0", "Specifies when to start the vote base on frags remaining.", _, true, 1.0);
	g_Cvar_ExtendTimeStep = CreateConVar("sm_extendmap_timestep", "15", "Specifies how much many more minutes each extension makes", _, true, 5.0);
	g_Cvar_ExtendRoundStep = CreateConVar("sm_extendmap_roundstep", "5", "Specifies how many more rounds each extension makes", _, true, 1.0);
	g_Cvar_ExtendFragStep = CreateConVar("sm_extendmap_fragstep", "10", "Specifies how many more frags are allowed when map is extended.", _, true, 5.0);
	g_Cvar_ExcludeMaps = CreateConVar("sm_mapvote_exclude", "5", "Specifies how many past maps to exclude from the vote.", _, true, 0.0);
	g_Cvar_IncludeMaps = CreateConVar("sm_mapvote_include", "5", "Specifies how many maps to include in the vote.", _, true, 2.0, true, 6.0);
	g_Cvar_NoVoteMode = CreateConVar("sm_mapvote_novote", "1", "Specifies whether or not MapChooser should pick a map if no votes are received.", _, true, 0.0, true, 1.0);
	g_Cvar_Extend = CreateConVar("sm_mapvote_extend", "1", "Number of extensions allowed each map.", _, true, 0.0);
	g_Cvar_DontChange = CreateConVar("sm_mapvote_dontchange", "0", "Specifies if a 'Don't Change' option should be added to early votes", _, true, 0.0);
	g_Cvar_VoteDuration = CreateConVar("sm_mapvote_voteduration", "20", "Specifies how long the mapvote should be available for.", _, true, 5.0);
	g_Cvar_RunOff = CreateConVar("sm_mapvote_runoff", "1", "Hold run of votes if winning choice is less than a certain margin", _, true, 0.0, true, 1.0);
	g_Cvar_RunOffPercent = CreateConVar("sm_mapvote_runoffpercent", "50", "If winning choice has less than this percent of votes, hold a runoff", _, true, 0.0, true, 100.0);
	g_Cvar_BlockSlots = CreateConVar("sm_mapvote_blockslots", "1", "Block slots to prevent stupid votes.", _, true, 0.0, true, 1.0);
	g_Cvar_MaxRunOffs = CreateConVar("sm_mapvote_maxrunoffs", "1", "Number of run off votes allowed each map.", _, true, 0.0);
	g_Cvar_StartTimePercent = CreateConVar("sm_mapvote_start_percent", "35.0", "Specifies when to start the vote based on percents.", _, true, 0.0, true, 100.0);
	g_Cvar_StartTimePercentEnable = CreateConVar("sm_mapvote_start_percent_enable", "0", "Enable or Disable percentage calculations when to start vote.", _, true, 0.0, true, 1.0);

	RegAdminCmd("sm_mapvote", Command_Mapvote, ADMFLAG_CHANGEMAP, "sm_mapvote - Forces MapChooser to attempt to run a map vote now.");
	RegAdminCmd("sm_setnextmap", Command_SetNextmap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");

	g_Cvar_Winlimit = FindConVar("mp_winlimit");
	g_Cvar_Maxrounds = FindConVar("mp_maxrounds");
	g_Cvar_Fraglimit = FindConVar("mp_fraglimit");
	g_Cvar_Bonusroundtime = FindConVar("mp_bonusroundtime");

	if (g_Cvar_Winlimit != INVALID_HANDLE || g_Cvar_Maxrounds != INVALID_HANDLE)
	{
		HookEvent("round_end", Event_RoundEnd);
		HookEventEx("teamplay_win_panel", Event_TeamPlayWinPanel);
		HookEventEx("teamplay_restart_round", Event_TFRestartRound);
		HookEventEx("arena_win_panel", Event_TeamPlayWinPanel);
	}

	if (g_Cvar_Fraglimit != INVALID_HANDLE)
	{
		HookEvent("player_death", Event_PlayerDeath);
	}

	AutoExecConfig(true, "mapchooser_extended");

	//Change the mp_bonusroundtime max so that we have time to display the vote
	//If you display a vote during bonus time good defaults are 17 vote duration and 19 mp_bonustime
	if (g_Cvar_Bonusroundtime != INVALID_HANDLE)
	{
		SetConVarBounds(g_Cvar_Bonusroundtime, ConVarBound_Upper, true, 30.0);
	}

	g_NominationsResetForward = CreateGlobalForward("OnNominationRemoved", ET_Ignore, Param_String, Param_Cell);

	OnPluginStart_VoteSound(); // $ added
	OnPluginStart_VoteWarning(); // $ added
	OnPluginStart_DisplayVote(); // $ added
	OnPluginStart_MapListCustom(); // $ added
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("mapchooser");

	CreateNative("NominateMap", Native_NominateMap);
	CreateNative("InitiateMapChooserVote", Native_InitiateVote);
	CreateNative("CanMapChooserStartVote", Native_CanVoteStart);
	CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
	CreateNative("GetExcludeMapList", Native_GetExcludeMapList);
	CreateNative("EndOfMapVoteEnabled", Native_EndOfMapVoteEnabled);

	return APLRes_Success;
}

public OnConfigsExecuted()
{
	OnConfigsExecuted_VoteSound(); // $ added
	OnConfigsExecuted_VoteWarning(); // $ added
	OnConfigsExecuted_Rem_MapCh(); // $ added
	if (ReadMapList(g_MapList,
					 g_mapFileSerial,
					 "mapchooser",
					 MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
		!= INVALID_HANDLE)

	{
		if (g_mapFileSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}

	CreateNextVote();
	SetupTimeleftTimer();

	g_TotalRounds = 0;

	g_Extends = 0;
	g_RunOffs = 0;

	g_MapVoteCompleted = false;

	g_NominateCount = 0;
	ClearArray(g_NominateList);
	ClearArray(g_NominateOwners);

	for (new i=0; i<MAXTEAMS; i++)
	{
		g_winCount[i] = 0;
	}


	/* Check if mapchooser will attempt to start mapvote during bonus round time - TF2 Only */
	if ((g_Cvar_Bonusroundtime != INVALID_HANDLE) && !GetConVarInt(g_Cvar_StartRounds))
	{
		if (GetConVarFloat(g_Cvar_Bonusroundtime) <= GetConVarFloat(g_Cvar_VoteDuration))
		{
			LogError("Warning - Bonus Round Time shorter than Vote Time. Votes during bonus round may not have time to complete");
		}
	}
}

public OnMapEnd()
{
	OnMapEnd_DisplayVote(); // $ added
	g_HasVoteStarted = false;
	g_WaitingForVote = false;
	g_ChangeMapAtRoundEnd = false;
	g_ChangeMapInProgress = false;

	g_VoteTimer = INVALID_HANDLE;
	g_RetryTimer = INVALID_HANDLE;

	decl String:map[32];
	GetCurrentMap(map, sizeof(map));
	PushArrayString(g_OldMapList, map);

	if (GetArraySize(g_OldMapList) > GetConVarInt(g_Cvar_ExcludeMaps))
	{
		RemoveFromArray(g_OldMapList, 0);
	}
}

public OnClientDisconnect(client)
{
	OnClientDisconnect_DisplayVote(client); // $ added
	new index = FindValueInArray(g_NominateOwners, client);

	if (index == -1)
	{
		return;
	}

	new String:oldmap[33];
	GetArrayString(g_NominateList, index, oldmap, sizeof(oldmap));
	Call_StartForward(g_NominationsResetForward);
	Call_PushString(oldmap);
	Call_PushCell(GetArrayCell(g_NominateOwners, index));
	Call_Finish();

	RemoveFromArray(g_NominateOwners, index);
	RemoveFromArray(g_NominateList, index);
	g_NominateCount--;
}

public Action:Command_SetNextmap(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setnextmap <map>");
		return Plugin_Handled;
	}

	decl String:map[64];
	GetCmdArg(1, map, sizeof(map));

	if (!IsMapValid(map))
	{
		ReplyToCommand(client, "[SM] %t", "Map was not found", map);
		return Plugin_Handled;
	}

	ShowActivity(client, "%T", "Changed Next Map", LANG_SERVER, map);
	LogMessage("\"%L\" changed nextmap to \"%s\"", client, map);

	SetNextMap(map);
	g_MapVoteCompleted = true;

	return Plugin_Handled;
}

public OnMapTimeLeftChanged()
{
	if (GetArraySize(g_MapList))
	{
		SetupTimeleftTimer();
	}
}

SetupTimeleftTimer()
{
	new time;
	new startTime;
	if (GetMapTimeLeft(time) && time > 0)
	{
		if (GetConVarBool(g_Cvar_StartTimePercentEnable))
			startTime = (GetConVarInt(g_Cvar_StartTimePercent) * time / 100);
		else
			startTime = GetConVarInt(g_Cvar_StartTime) * 60;

		if (time - startTime < 0 && GetConVarBool(g_Cvar_EndOfMapVote) && !g_MapVoteCompleted && !g_HasVoteStarted)
		{
			g_runoffvote = false;
			SetupWarningTimer();
		}
		else
		{
			if (g_VoteTimer != INVALID_HANDLE)
			{
				KillTimer(g_VoteTimer);
				g_VoteTimer = INVALID_HANDLE;
			}
			g_VoteTimer = CreateTimer(float(time - startTime), Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_StartMapVote(Handle:timer)
{
	if (timer == g_RetryTimer)
	{
		g_WaitingForVote = false;
		g_RetryTimer = INVALID_HANDLE;
	}
	else
	{
		g_VoteTimer = INVALID_HANDLE;
	}

	if (!GetArraySize(g_MapList) || !GetConVarBool(g_Cvar_EndOfMapVote) || g_MapVoteCompleted || g_HasVoteStarted)
	{
		return Plugin_Stop;
	}
	g_runoffvote = false;
	SetupWarningTimer();
	return Plugin_Stop;
}

public Event_TFRestartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;
}

public Event_TeamPlayWinPanel(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_ChangeMapAtRoundEnd)
	{
		g_ChangeMapAtRoundEnd = false;
		CreateTimer(2.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		g_ChangeMapInProgress = true;
	}

	new bluescore = GetEventInt(event, "blue_score");
	new redscore = GetEventInt(event, "red_score");

	if(GetEventInt(event, "round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_TotalRounds++;

		if (!GetArraySize(g_MapList) || g_HasVoteStarted || g_MapVoteCompleted || !GetConVarBool(g_Cvar_EndOfMapVote))
		{
			return;
		}

		CheckMaxRounds(g_TotalRounds);

		switch(GetEventInt(event, "winning_team"))
		{
			case 3:
			{
				CheckWinLimit(bluescore);
			}
			case 2:
			{
				CheckWinLimit(redscore);
			}
			//We need to do nothing on winning_team == 0 this indicates stalemate.
			default:
			{
				return;
			}
		}
	}
}
/* You ask, why don't you just use team_score event? And I answer... Because CSS doesn't. */
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_ChangeMapAtRoundEnd)
	{
		g_ChangeMapAtRoundEnd = false;
		CreateTimer(2.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		g_ChangeMapInProgress = true;
	}

	new winner = GetEventInt(event, "winner");

	if (winner == 0 || winner == 1 || !GetConVarBool(g_Cvar_EndOfMapVote))
	{
		return;
	}

	if (winner >= MAXTEAMS)
	{
		SetFailState("Mod exceed maximum team count - Please file a bug report.");
	}

	g_TotalRounds++;

	g_winCount[winner]++;

	if (!GetArraySize(g_MapList) || g_HasVoteStarted || g_MapVoteCompleted)
	{
		return;
	}

	CheckWinLimit(g_winCount[winner]);
	CheckMaxRounds(g_TotalRounds);
}

public CheckWinLimit(winner_score)
{
	if (g_Cvar_Winlimit != INVALID_HANDLE)
	{
		new winlimit = GetConVarInt(g_Cvar_Winlimit);
		if (winlimit)
		{
			if (winner_score >= (winlimit - GetConVarInt(g_Cvar_StartRounds)))
			{
				g_runoffvote = false;
				SetupWarningTimer();
			}
		}
	}
}

public CheckMaxRounds(roundcount)
{
	if (g_Cvar_Maxrounds != INVALID_HANDLE)
	{
		new maxrounds = GetConVarInt(g_Cvar_Maxrounds);
		if (maxrounds)
		{
			if (roundcount >= (maxrounds - GetConVarInt(g_Cvar_StartRounds)))
			{
				g_runoffvote = false;
				SetupWarningTimer();
			}
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetArraySize(g_MapList) || g_Cvar_Fraglimit == INVALID_HANDLE || g_HasVoteStarted)
	{
		return;
	}
	
	if (!GetConVarInt(g_Cvar_Fraglimit) || !GetConVarBool(g_Cvar_EndOfMapVote))
	{
		return;
	}

	if (g_MapVoteCompleted)
	{
		return;
	}

	new fragger = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!fragger)
	{
		return;
	}

	if (GetClientFrags(fragger) >= (GetConVarInt(g_Cvar_Fraglimit) - GetConVarInt(g_Cvar_StartFrags)))
	{
		g_runoffvote = false;
		SetupWarningTimer();
	}
}

public Action:Command_Mapvote(client, args)
{
	g_runoffvote = false;
	SetupWarningTimer();

	return Plugin_Handled;
}

/**
 * Starts a new map vote
 *
 * @param when			When the resulting map change should occur.
 * @param inputlist		Optional list of maps to use for the vote, otherwise an internal list of nominations + random maps will be used.
 * @param noSpecials	Block special vote options like extend/nochange (upgrade this to bitflags instead?)
 */
InitiateVote(MapChange:when, Handle:inputlist=INVALID_HANDLE)
{
	new NumClients = 0;
	for (new i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && !IsFakeClient(i)) NumClients++;
	if (!NumClients) return;

	g_WaitingForVote = true;

	if (IsVoteInProgress())
	{
		// Can't start a vote, try again in 5 seconds.
		//g_RetryTimer = CreateTimer(5.0, Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);

		new Handle:data;
		g_RetryTimer = CreateDataTimer(5.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, _:when);
		WritePackCell(data, _:inputlist);
		ResetPack(data);
		return;
	}

	/* If the main map vote has completed (and chosen result) and its currently changing (not a delayed change) we block further attempts */
	if (g_MapVoteCompleted && g_ChangeMapInProgress)
	{
		return;
	}

	g_ChangeTime = when;

	g_WaitingForVote = false;

	g_HasVoteStarted = true;
	g_VoteMenu = CreateMenu(Handler_MapVoteMenu);//, MenuAction:MENU_ACTIONS_ALL);
	SetMenuPagination(g_VoteMenu, MENU_NO_PAGINATION);
	decl String:title[128];
	Format(title, sizeof(title),"%T", "Vote Nextmap", LANG_SERVER);
	SetMenuTitle(g_VoteMenu, title);
	SetVoteResultCallback(g_VoteMenu, Handler_MapVoteFinished);

	/**
	 * TODO: Make a proper decision on when to clear the nominations list.
	 * Currently it clears when used, and stays if an external list is provided.
	 * Is this the right thing to do? External lists will probably come from places
	 * like sm_mapvote from the adminmenu in the future.
	 */

	decl String:map[32];

	/* No input given - User our internal nominations and maplist */
	if (inputlist == INVALID_HANDLE)
	{
		new nominateCount = GetArraySize(g_NominateList);
		new voteSize = GetConVarInt(g_Cvar_IncludeMaps);

		/* Smaller of the two - It should be impossible for nominations to exceed the size though (cvar changed mid-map?) */
		new nominationsToAdd = nominateCount >= voteSize ? voteSize : nominateCount;
		
		/* Block Vote Slots */
		if (GetConVarBool(g_Cvar_BlockSlots))
		{
			new includedmaps = (GetConVarInt(g_Cvar_IncludeMaps));
			decl String:lineone[128], String:linetwo[128];
			switch (includedmaps)
			{
				case 2:
				{
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
					Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
				}
				case 3:
				{
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
					Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
				}
				case 4:
				{
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
					Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
					Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
				}
				case 5:
				{
					Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
					Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
					AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
				}
				case 6:
				{
					Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
					Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
					AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
				}
			}
		}
		
		for (new i=0; i<nominationsToAdd; i++)
		{
			GetArrayString(g_NominateList, i, map, sizeof(map));
			/* $ changed */

			if (!MapIsOfficial(map))
			{
				decl String:map_custom[255];
				Format(map_custom, sizeof(map_custom), "%t", "Custom", map, LANG_SERVER);
				AddMenuItem(g_VoteMenu, map, map_custom);
			}
			else 
			{
				AddMenuItem(g_VoteMenu, map, map);
			}
			RemoveStringFromArray(g_NextMapList, map);
			/* end of $ changed */

			/* Notify Nominations that this map is now free */
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(GetArrayCell(g_NominateOwners, i));
			Call_Finish();
		}

		/* Clear out the rest of the nominations array */
		for (new i=nominationsToAdd; i<nominateCount; i++)
		{
			GetArrayString(g_NominateList, i, map, sizeof(map));
			/* These maps shouldn't be excluded from the vote as they weren't really nominated at all */
			/* Notify Nominations that this map is now free */
			Call_StartForward(g_NominationsResetForward);
			Call_PushString(map);
			Call_PushCell(GetArrayCell(g_NominateOwners, i));
			Call_Finish();
		}

		/* There should currently be 'nominationsToAdd' unique maps in the vote */

		new i = nominationsToAdd;
		new count = 0;
		new availableMaps = GetArraySize(g_NextMapList);

		while (i < voteSize)
		{
			GetArrayString(g_NextMapList, count, map, sizeof(map));
			count++;

			//Check if this map is in the nominate list (and thus already in the vote) */
			if (FindStringInArray(g_NominateList, map) == -1)
			{
				/* Insert the map and increment our count */
				/* $ changed */

				if (!MapIsOfficial(map))
				{
					decl String:map_custom[255];
					Format(map_custom, sizeof(map_custom), "%t", "Custom", map, LANG_SERVER);
					AddMenuItem(g_VoteMenu, map, map_custom);
				}
				else 
				{
					AddMenuItem(g_VoteMenu, map, map);
				}
				/* end of $ changed */
				i++;
			}

			if (count >= availableMaps)
			{
				//Run out of maps, this will have to do.
				break;
			}
		}

		/* Wipe out our nominations list - Nominations have already been informed of this */
		ClearArray(g_NominateOwners);
		ClearArray(g_NominateList);
	}
	else //We were given a list of maps to start the vote with
	{
		new size = GetArraySize(inputlist);

		for (new i=0; i<size; i++)
		{
			GetArrayString(inputlist, i, map, sizeof(map));

			if (IsMapValid(map))
			{
				/* $ changed */
				if (!MapIsOfficial(map))
				{
					decl String:map_custom[255];
					Format(map_custom, sizeof(map_custom), "%t", "Custom", map, LANG_SERVER);
					AddMenuItem(g_VoteMenu, map, map_custom);
				}
				else 
				{
					AddMenuItem(g_VoteMenu, map, map);
				}
				/* end of $ changed */
			}
		}
	}

	/* Do we add any special items? */
	if ((when == MapChange_Instant || when == MapChange_RoundEnd) && GetConVarBool(g_Cvar_DontChange))
	{
		AddMenuItem(g_VoteMenu, VOTE_DONTCHANGE, "Don't Change");
	}
	else if (GetConVarBool(g_Cvar_Extend) && g_Extends < GetConVarInt(g_Cvar_Extend))
	{
		decl String:buffer[40];
		Format(buffer, sizeof(buffer), "%T", "Extend Map", LANG_SERVER);
		AddMenuItem(g_VoteMenu, VOTE_EXTEND, buffer);
	}

	new voteDuration = GetConVarInt(g_Cvar_VoteDuration);

	SetMenuExitButton(g_VoteMenu, false);
	VoteMenuToAll(g_VoteMenu, voteDuration);

	LogMessage("Voting for next map has started.");
	CPrintToChatAll("[SM] %t", "Nextmap Voting Started"); // $ changed
	SoundVoteStart(); // $ added
}

public Handler_MapVoteFinished(Handle:menu,
						   num_votes,
						   num_clients,
						   const client_info[][2],
						   num_items,
						   const item_info[][2])
{

	if (num_votes == 0)
	{
		LogError("No Votes recorded yet Advanced callback fired - Tell pRED* to fix this");
		VoteEnded("Vote failed"); // $ added
		SoundVoteEnd(); // $ added
		return;
	}

	if (GetConVarBool(g_Cvar_RunOff) && num_items > 1)
	{
		new Float:winningvotes = float(item_info[0][VOTEINFO_ITEM_VOTES]);
		new Float:required = num_votes * (GetConVarFloat(g_Cvar_RunOffPercent) / 100.0);
		
		if ((g_RunOffs < GetConVarInt(g_Cvar_MaxRunOffs)) && (winningvotes <= required))
		{
			decl String:buffer_runoffvote[255];
			new infopercent = GetConVarInt(g_Cvar_RunOffPercent);
			Format(buffer_runoffvote, sizeof(buffer_runoffvote), "%T", "Revote Is Needed", LANG_SERVER, infopercent);
				
			/* Get map names and store it */
			GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], g_map1, sizeof(g_map1), _, g_mapd1, sizeof(g_mapd1));
			GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], g_map2, sizeof(g_map2), _, g_mapd2, sizeof(g_mapd2));
				
			CreateTimer(5.0, RunOffVoteWarningDelay, _, TIMER_FLAG_NO_MAPCHANGE);
			VoteEnded(buffer_runoffvote);
			g_RunOffs++;
			return;
		}
	}

	decl String:map[32];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map));

	/* $ added */
	decl String:buffer[255];
	if (strcmp(map, VOTE_EXTEND, false) == 0 || strcmp(map, VOTE_DONTCHANGE, false) == 0)
	{
		// this should be equal to fetching the translations
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], buffer, 0, _, buffer, sizeof(buffer));
	}
	else
	{
		Format(buffer, sizeof(buffer), "%T", "Next Map", LANG_SERVER, map);
	}
	VoteEnded(buffer);
	SoundVoteEnd();
	/* end of $ added */

	if (strcmp(map, VOTE_EXTEND, false) == 0)
	{
		g_Extends++;

		new time;
		if (GetMapTimeLimit(time))
		{
			if (time > 0)
			{
				ExtendMapTimeLimit(GetConVarInt(g_Cvar_ExtendTimeStep)*60);
			}
		}

		if (g_Cvar_Winlimit != INVALID_HANDLE)
		{
			new winlimit = GetConVarInt(g_Cvar_Winlimit);
			if (winlimit)
			{
				SetConVarInt(g_Cvar_Winlimit, winlimit + GetConVarInt(g_Cvar_ExtendRoundStep));
			}
		}

		if (g_Cvar_Maxrounds != INVALID_HANDLE)
		{
			new maxrounds = GetConVarInt(g_Cvar_Maxrounds);
			if (maxrounds)
			{
				SetConVarInt(g_Cvar_Maxrounds, maxrounds + GetConVarInt(g_Cvar_ExtendRoundStep));
			}
		}

		if (g_Cvar_Fraglimit != INVALID_HANDLE)
		{
			new fraglimit = GetConVarInt(g_Cvar_Fraglimit);
			if (fraglimit)
			{
				SetConVarInt(g_Cvar_Fraglimit, fraglimit + GetConVarInt(g_Cvar_ExtendFragStep));
			}
		}

		CPrintToChatAll("[SM] %t", "Current Map Extended", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes); // $ changed
		LogMessage("Voting for next map has finished. The current map has been extended.");
		SoundVoteEnd();
		// We extended, so we'll have to vote again.
		g_HasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();

	}
	else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
	{
		CPrintToChatAll("[SM] %t", "Current Map Stays", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes); // $ changed
		LogMessage("Voting for next map has finished. 'No Change' was the winner");
		
		g_HasVoteStarted = false;
		CreateNextVote();
		SetupTimeleftTimer();
	}
	else 
	{
		/* $ moved */
		NextMap(map); 

		PrintCenterTextAll("%T", "Next Map", LANG_SERVER, map);

		CPrintToChatAll("[SM] %t", "Nextmap Voting Finished", map, RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes); // $ changed
		LogMessage("Voting for next map has finished. Nextmap: %s.", map);
		SoundVoteEnd();
	}
}

NextMap(const String:map[]) 
/* end */
{
		if (g_ChangeTime == MapChange_MapEnd)
		{
			SetNextMap(map);
		}
		else if (g_ChangeTime == MapChange_Instant)
		{
			new Handle:data;
			CreateDataTimer(2.0, Timer_ChangeMap, data);
			WritePackString(data, map);
			g_ChangeMapInProgress = false;
		}
		else // MapChange_RoundEnd
		{
			SetNextMap(map);
			g_ChangeMapAtRoundEnd = true;
		}

		g_HasVoteStarted = false;
		g_MapVoteCompleted = true;
}

public Handler_MapVoteMenu(Handle:menu, MenuAction:action, param1, param2)
{
	VoteAction(menu, action, param1, param2); // $ added
	switch (action)
	{
		case MenuAction_End:
		{
			g_VoteMenu = INVALID_HANDLE;
			CloseHandle(menu);
		}

		case MenuAction_Display:
		{
	 		decl String:buffer[255];
			Format(buffer, sizeof(buffer), "%T", "Vote Nextmap", param1);

			new Handle:panel = Handle:param2;
			SetPanelTitle(panel, buffer);
		}

		case MenuAction_DisplayItem:
		{
			if (GetMenuItemCount(menu) - 1 == param2)
			{
				decl String:map[64], String:buffer[255];
				GetMenuItem(menu, param2, map, sizeof(map));
				if (strcmp(map, VOTE_EXTEND, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%T", "Extend Map", param1);
					return RedrawMenuItem(buffer);
				}
				else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%T", "Dont Change", param1);
					return RedrawMenuItem(buffer);
				}
			}
		}

		case MenuAction_VoteCancel:
		{
			decl String:buffer[255]; // $ added

			// If we receive 0 votes, pick at random.
			if (param1 == VoteCancel_NoVotes && GetConVarBool(g_Cvar_NoVoteMode))
			{
				new count = GetMenuItemCount(menu);
				new item;
				
				if (GetConVarBool(g_Cvar_BlockSlots))
				{
					new includedmaps = (GetConVarInt(g_Cvar_IncludeMaps));
					switch (includedmaps)
					{
						case 2:
						{
							item = GetRandomInt(6, count - 1);
						}
						case 3:
						{
							item = GetRandomInt(5, count - 1);
						}
						case 4:
						{
							item = GetRandomInt(4, count - 1);
						}
						case 5:
						{
							item = GetRandomInt(3, count - 1);
						}
						case 6:
						{
							item = GetRandomInt(2, count - 1);
						}
					}
				}
				else
				{
					item = GetRandomInt(0, count - 1);
				}
				
				decl String:map[32];
				GetMenuItem(menu, item, map, sizeof(map));

				while (strcmp(map, VOTE_EXTEND, false) == 0)
				{
					if (GetConVarBool(g_Cvar_BlockSlots))
					{
						new includedmaps = (GetConVarInt(g_Cvar_IncludeMaps));
						switch (includedmaps)
						{
							case 2:
							{
								item = GetRandomInt(6, count - 1);
							}
							case 3:
							{
								item = GetRandomInt(5, count - 1);
							}
							case 4:
							{
								item = GetRandomInt(4, count - 1);
							}
							case 5:
							{
								item = GetRandomInt(3, count - 1);
							}
							case 6:
							{
								item = GetRandomInt(2, count - 1);
							}
						}
					}
					else
					{
						item = GetRandomInt(0, count - 1);
					}
					GetMenuItem(menu, item, map, sizeof(map));
				}

				/* $ added */
				if(strcmp(map, VOTE_DONTCHANGE, false) == 0)
				{
					Format(buffer, sizeof(buffer), "%t", "Dont Change",param1);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%T", "Next Map", LANG_SERVER, map);
					NextMap(map);
					g_MapVoteCompleted = true; // $ moved
				}
				SoundVoteEnd();
				VoteEnded(buffer);
				LogMessage("No votes received, randomly selected %s as nextmap.", map);
				/* end of $ added */
			}
			else
			{
				// We were actually cancelled. I guess we do nothing.
				Format(buffer, sizeof(buffer), "%t", "Cancelled Vote",param1); // $ added
				VoteEnded(buffer);
			}

			g_HasVoteStarted = false;
			g_MapVoteCompleted = true;
		}
	}

	return 0;
}

public Action:Timer_ChangeMap(Handle:hTimer, Handle:dp)
{
	g_ChangeMapInProgress = false;

	new String:map[65];

	if (dp == INVALID_HANDLE)
	{
		if (!GetNextMap(map, sizeof(map)))
		{
			//No passed map and no set nextmap. fail!
			return Plugin_Stop;
		}
	}
	else
	{
		ResetPack(dp);
		ReadPackString(dp, map, sizeof(map));
	}

	ForceChangeLevel(map, "Map Vote");

	return Plugin_Stop;
}

bool:RemoveStringFromArray(Handle:array, String:str[])
{
	new index = FindStringInArray(array, str);
	if (index != -1)
	{
		RemoveFromArray(array, index);
		return true;
	}

	return false;
}

CreateNextVote()
{
	if(g_NextMapList != INVALID_HANDLE)
	{
		ClearArray(g_NextMapList);
	}

	decl String:map[32];
	new Handle:tempMaps  = CloneArray(g_MapList);

	GetCurrentMap(map, sizeof(map));
	RemoveStringFromArray(tempMaps, map);

	if (GetConVarInt(g_Cvar_ExcludeMaps) && GetArraySize(tempMaps) > GetConVarInt(g_Cvar_ExcludeMaps))
	{
		for (new i = 0; i < GetArraySize(g_OldMapList); i++)
		{
			GetArrayString(g_OldMapList, i, map, sizeof(map));
			RemoveStringFromArray(tempMaps, map);
		}
	}

	new limit = (GetConVarInt(g_Cvar_IncludeMaps) < GetArraySize(tempMaps) ? GetConVarInt(g_Cvar_IncludeMaps) : GetArraySize(tempMaps));
	for (new i = 0; i < limit; i++)
	{
		new b = GetRandomInt(0, GetArraySize(tempMaps) - 1);
		GetArrayString(tempMaps, b, map, sizeof(map));
		PushArrayString(g_NextMapList, map);
		RemoveFromArray(tempMaps, b);
	}

	CloseHandle(tempMaps);
}

bool:CanVoteStart()
{
	if (g_WaitingForVote || g_HasVoteStarted)
	{
		return false;
	}

	return true;
}

NominateResult:InternalNominateMap(String:map[], bool:force, owner)
{
	if (!IsMapValid(map))
	{
		return Nominate_InvalidMap;
	}

	new index;

	/* Look to replace an existing nomination by this client - Nominations made with owner = 0 aren't replaced */
	if (owner && ((index = FindValueInArray(g_NominateOwners, owner)) != -1))
	{
		new String:oldmap[33];
		GetArrayString(g_NominateList, index, oldmap, sizeof(oldmap));
		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(owner);
		Call_Finish();

		SetArrayString(g_NominateList, index, map);
		return Nominate_Replaced;
	}

	/* Too many nominated maps. */
	if (g_NominateCount >= GetConVarInt(g_Cvar_IncludeMaps) && !force)
	{
		return Nominate_VoteFull;
	}

	/* Map already in the vote */
	if (FindStringInArray(g_NominateList, map) != -1)
	{
		return Nominate_AlreadyInVote;
	}


	PushArrayString(g_NominateList, map);
	PushArrayCell(g_NominateOwners, owner);
	g_NominateCount++;

	while (GetArraySize(g_NominateList) > GetConVarInt(g_Cvar_IncludeMaps))
	{
		new String:oldmap[33];
		GetArrayString(g_NominateList, 0, oldmap, sizeof(oldmap));
		Call_StartForward(g_NominationsResetForward);
		Call_PushString(oldmap);
		Call_PushCell(GetArrayCell(g_NominateOwners, 0));
		Call_Finish();

		RemoveFromArray(g_NominateList, 0);
		RemoveFromArray(g_NominateOwners, 0);
	}

	return Nominate_Added;
}

/* Add natives to allow nominate and initiate vote to be call */

/* native  bool:NominateMap(const String:map[], bool:force, &NominateError:error); */
public Native_NominateMap(Handle:plugin, numParams)
{
	new len;
	GetNativeStringLength(1, len);

	if (len <= 0)
	{
	  return false;
	}

	new String:map[len+1];
	GetNativeString(1, map, len+1);

	return _:InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3));
}

SetupRunOffVote()
{
	/* Insufficient Winning margin - Lets do a runoff */
	g_VoteMenu = CreateMenu(Handler_MapVoteMenu);//, MenuAction:MENU_ACTIONS_ALL);
	decl String:title[128];
	Format(title, sizeof(title),"%T", "Runoff Vote Nextmap", LANG_SERVER);
	SetMenuTitle(g_VoteMenu, title);
	SetVoteResultCallback(g_VoteMenu, Handler_MapVoteFinished);

	/* Block Vote Slots */
	if (GetConVarBool(g_Cvar_BlockSlots))
	{
		decl String:lineone[128], String:linetwo[128];
		AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
		Format(lineone, sizeof(lineone),"%T", "Line One", LANG_SERVER);
		AddMenuItem(g_VoteMenu, "nothing", lineone, ITEMDRAW_DISABLED);
		Format(linetwo, sizeof(linetwo),"%T", "Line Two", LANG_SERVER);
		AddMenuItem(g_VoteMenu, "nothing", linetwo, ITEMDRAW_DISABLED);
		AddMenuItem(g_VoteMenu, "nothing", " ", ITEMDRAW_SPACER);
	}

	AddMenuItem(g_VoteMenu, g_map1, g_mapd1);
	AddMenuItem(g_VoteMenu, g_map2, g_mapd2);

	new voteDuration = GetConVarInt(g_Cvar_VoteDuration);
	SetMenuExitButton(g_VoteMenu, false);
	VoteMenuToAll(g_VoteMenu, voteDuration);

	LogMessage("Voting for next map was indecisive, beginning runoff vote");
}

public Action:RunOffVoteWarningDelay(Handle:timer)
{
	g_runoffvote = true;
	SetupWarningTimer();
}

/* native InitiateMapChooserVote(); */
public Native_InitiateVote(Handle:plugin, numParams)
{
	new MapChange:when = MapChange:GetNativeCell(1);
	new Handle:inputarray = Handle:GetNativeCell(2);

	LogMessage("Starting map vote because outside request");
	InitiateVote(when, inputarray);
}

public Native_CanVoteStart(Handle:plugin, numParams)
{
	return CanVoteStart();
}

public Native_CheckVoteDone(Handle:plugin, numParams)
{
	return g_MapVoteCompleted;
}

public Native_EndOfMapVoteEnabled(Handle:plugin, numParams)
{
	return GetConVarBool(g_Cvar_EndOfMapVote);
}

public Native_GetExcludeMapList(Handle:plugin, numParams)
{
	new Handle:array = Handle:GetNativeCell(1);

	if (array == INVALID_HANDLE)
	{
		return;
	}

	new size = GetArraySize(g_OldMapList);
	decl String:map[33];

	for (new i=0; i<size; i++)
	{
		GetArrayString(g_OldMapList, i, map, sizeof(map));
		PushArrayString(array, map);
	}

	return;
}