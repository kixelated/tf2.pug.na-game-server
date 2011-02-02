#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>

#pragma semicolon 1

#define Sound_Enable		0
#define Sound_VoteStart	1
#define Sound_VoteEnd		2

#define MAX_SOUND_CVARS	3

new Handle:g_Cvar_Sound[MAX_SOUND_CVARS];

// SoundCvars
public OnPluginStart_VoteSound()
{
	g_Cvar_Sound[Sound_Enable] = CreateConVar("sm_mapvote_enablesounds", "1", "Enable sounds to be played during vote start and end (assuming correct pure mode and the resp. sound variable is diffrent from \"\")", _, true, 0.0, true, 1.0);
	g_Cvar_Sound[Sound_VoteStart] = CreateConVar("sm_mapvote_sound_votestart", "sourcemod/mapchooser/startyourvoting.mp3", "Sound that is being played when a vote starts. (relative to $basedir/sound/)");
	g_Cvar_Sound[Sound_VoteEnd] = CreateConVar("sm_mapvote_sound_voteend", "sourcemod/mapchooser/endofvote.mp3", "Sound that is being played when a vote ends. (relative to $basedir/sound/)");
}

// LoadSound
public OnConfigsExecuted_VoteSound()
{
	if(GetConVarBool(g_Cvar_Sound[Sound_Enable]))
	{
		decl String:sound[255], String:filePath[255];
		
		// VoteStart
		GetConVarString(g_Cvar_Sound[Sound_VoteStart], sound, sizeof(sound));
		if(strlen(sound) > 0)
		{
			Format(filePath, sizeof(filePath), "sound/%s", sound);
			AddFileToDownloadsTable(filePath);
			PrecacheSound(sound, true);
			
			if(!FileExists(filePath))
				LogError("sound file %s does not exist.", sound);
			else if(!IsSoundPrecached(filePath))
				LogError("failed to precache sound file %s", sound);
		}
		
		// VoteEnd
		GetConVarString(g_Cvar_Sound[Sound_VoteEnd], sound, sizeof(sound));
		if(strlen(sound) > 0)
		{
			Format(filePath, sizeof(filePath), "sound/%s", sound);
			AddFileToDownloadsTable(filePath);
			PrecacheSound(sound, true);
			
			if(!FileExists(filePath))
				LogError("sound file %s does not exist.", sound);
			else if(!IsSoundPrecached(filePath))
				LogError("failed to precache sound file %s", sound);
		}
	}
}

public SoundVoteStart()
{
	decl String:sound[255];
	
	GetConVarString(g_Cvar_Sound[Sound_VoteStart], sound, sizeof(sound));	
	if(GetConVarBool(g_Cvar_Sound[Sound_Enable]) && strlen(sound) > 0)
	{
		EmitSoundToAll(sound);
	}
}

public SoundVoteEnd()
{
	if(GetConVarBool(g_Cvar_Sound[Sound_Enable]))
	{
		// delay due to button sound
		CreateTimer(1.0, Sound_VoteEnded, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Sound_VoteEnded(Handle:timer)
{
	decl String:sound[255];
	
	GetConVarString(g_Cvar_Sound[Sound_VoteEnd], sound, sizeof(sound));
	if(strlen(sound) > 0)
	{
		EmitSoundToAll(sound);
	}
}