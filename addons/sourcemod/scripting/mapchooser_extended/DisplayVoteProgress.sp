#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>

#pragma semicolon 1

#define ITEM_MAX_LENGTH		128
#define CLIENT_MAX_LENGTH	32

new g_PlayerVotes[MAXPLAYERS+1];

new Handle:g_Cvar_PrintVotes = INVALID_HANDLE;
new Handle:g_Cvar_ShowVotes = INVALID_HANDLE;
new Handle:g_VoteDuration = INVALID_HANDLE;
new Handle:g_AllowedVoters = INVALID_HANDLE;

new Handle:g_timer_ShowVotes = INVALID_HANDLE;

new g_VoteTimeStart2;

public OnPluginStart_DisplayVote()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basetriggers.phrases");

	g_Cvar_PrintVotes = CreateConVar("sm_mapvote_printvotes", "0", "Should the option that a player vote on get printed (1 - yes print player votes, 0 - don't print).", _, true, 0.0, true, 1.0);
	g_Cvar_ShowVotes = CreateConVar("sm_mapvote_showvotes", "3", "How many vote options the hint box should show. 0 will disable it", _, true, 0.0, true, 5.0);

	g_VoteDuration = FindConVar("sm_mapvote_voteduration");

	g_AllowedVoters = CreateArray(1);
}

public OnMapEnd_DisplayVote()
{
	g_timer_ShowVotes = INVALID_HANDLE; // Being closed on mapchange: TIMER_FLAG_NO_MAPCHANGE
}

public OnClientDisconnect_DisplayVote(client)
{
	// reset the clients vote
	g_PlayerVotes[client] = -1;

	// if client is allowed to vote then remove him (to fix max number of voters)
	new index = FindValueInArray(g_AllowedVoters, client);
	if (index > -1)
	{
		RemoveFromArray(g_AllowedVoters, index);
	}

	// if we display vote then update it
	if (GetConVarBool(g_Cvar_ShowVotes) && g_timer_ShowVotes != INVALID_HANDLE)
	{
		TriggerTimer(g_timer_ShowVotes);
	}
}

public VoteAction(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_VoteStart:
		{
			VoteStarted();
			if (GetConVarBool(g_Cvar_ShowVotes))
			{
				if (g_timer_ShowVotes == INVALID_HANDLE)
				{
					g_timer_ShowVotes = CreateTimer(0.95, ShowVoteProgress, menu, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				}
				TriggerTimer(g_timer_ShowVotes);
			}
		}

		case MenuAction_Select:
		{
			if (GetConVarBool(g_Cvar_PrintVotes))
			{
				decl String:name[CLIENT_MAX_LENGTH], String:option[ITEM_MAX_LENGTH];
				GetClientName(param1, name, sizeof(name));
				GetMenuItem(menu, param2, option, 0, _, option, sizeof(option));

				PrintToChatAll("[SM] %t", "Vote Select", name, option);
			}
			if (GetConVarBool(g_Cvar_ShowVotes))
			{
				g_PlayerVotes[param1] = param2;
				TriggerTimer(g_timer_ShowVotes);
			}
		}
	}
}

VoteStarted()
{
	// reset all votes
	for (new i = 0; i <= MAXPLAYERS ; i++)
	{
		g_PlayerVotes[i] = -1;
	}

	// set clients allowed to vote
	ClearArray(g_AllowedVoters);
	for (new i = GetMaxClients(); i > 0; i--)
		if (IsClientInGame(i) && !IsFakeClient(i))
			PushArrayCell(g_AllowedVoters, i);

	g_VoteTimeStart2 = GetTime();
}

public VoteEnded(const String:voteEndInfo[])
{
	if (g_timer_ShowVotes != INVALID_HANDLE)
	{
		KillTimer(g_timer_ShowVotes);
		g_timer_ShowVotes = INVALID_HANDLE;
	}
	PrintHintTextToAll(voteEndInfo);
}

/**
 * Show/updates the hintbox with current vote status
 * ex.
 *
   Next map: (3/7) - 17 s
   1. de_dust2 - 2
   2. de_nuke -1
 */
public Action:ShowVoteProgress(Handle:timer, Handle:menu)
{
	if (menu == INVALID_HANDLE) return Plugin_Continue;

	decl String:hintboxText[1024];
	decl String:option[ITEM_MAX_LENGTH];
	decl String:formatBuffer[256];
	decl String:translation_buffer[256];

	// <title> - <timeleft>
	//GetMenuTitle(menu, hintboxText, sizeof(hintboxText));
	Format(translation_buffer, sizeof(translation_buffer),"%T", "Number Of Votes", LANG_SERVER);
	Format(hintboxText, sizeof(hintboxText), "%s (%i/%i) - %is", translation_buffer, GetNrReceivedVotes(), GetArraySize(g_AllowedVoters), VoteTimeRemaining());

	// <X>. <option>
	new nrItems = GetMenuItemCount(menu);
	new itemIndex[nrItems];
	new itemVotes[nrItems];
	GetItemsSortedByVotes(itemIndex, itemVotes, nrItems);

	new displayNrOptions = GetConVarInt(g_Cvar_ShowVotes) >= nrItems ? nrItems : GetConVarInt(g_Cvar_ShowVotes);
	for (new i = 1; i <= displayNrOptions; i++)
	{
		if (itemVotes[i-1] > 0)
		{
			GetMenuItem(menu, itemIndex[i-1], option, 0, _, option, sizeof(option));

			new percent = ((itemVotes[i-1] * 100) / GetNrReceivedVotes());

			Format(formatBuffer, sizeof(formatBuffer), "%T", "Vote Progress", LANG_SERVER, i, option, itemVotes[i-1], percent);
			StrCat(hintboxText, sizeof(hintboxText), formatBuffer);
		}
		else
			break;
	}
	PrintHintTextToAll("%s", hintboxText);

	return Plugin_Continue;
}

/**
 * @return        timeleft (remaining) of vote.
 */
VoteTimeRemaining()
{
	new remainingTime = g_VoteTimeStart2 + GetConVarInt(g_VoteDuration) - GetTime();
	if (remainingTime < 0)
	{
		return 0;
	}
	else
	{
		return remainingTime;
	}
}

/**
 * Returns a list of all items (their index) and number of votes on each, ordered by nr of received votes in descending order
 */
GetItemsSortedByVotes(itemIndex[], itemVotes[], nrOfItems)
{
	// Get nr of votes on each item
	new votesOnItem[nrOfItems+1];		// simplify by increasing by one and having index 0 being "not voted"
	for (new i = 0; i <= MAXPLAYERS; i++)
	{
		votesOnItem[g_PlayerVotes[i]+1]++;
	}

	// simple insertion sort
	new mostVotes, index;
	for (new i = 0; i < nrOfItems; i++)
	{
		mostVotes = -1;
		for (new j = 1; j <= nrOfItems; j++)
		{
			if (votesOnItem[j] > mostVotes)
			{
				mostVotes = votesOnItem[j];
				index = j;
			}
		}

		itemIndex[i] = index-1;
		itemVotes[i] = mostVotes;

		// make sure it will not be selected again
		votesOnItem[index] = -1;
	}
}

/**
 * @return        return the total nr of votes received
 */
GetNrReceivedVotes()
{
	new nrVotes = 0;
	for (new i = GetMaxClients(); i > 0; i--)
	{
		if(g_PlayerVotes[i] > -1)
			nrVotes++;
	}
	return nrVotes;
}