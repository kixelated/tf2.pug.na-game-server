#include <sourcemod>
#include <sdktools>

#define TF_TEAM_BLU	3
#define TF_TEAM_RED	2

// Convars
new Handle:hExtendThreshold;
new Handle:hCancelThreshold;
new Handle:hExtendTime;
new Handle:hExtendMax;

// Variables
new extendCount = 0;
new bool:extendCancel = false;
new lastExtend = 0;
new lastExtendMessage = 0;

// Plugin Info
public Plugin:myinfo = {
  name = "tf2.pug.na - Match Extender",
  author = "Luke Curley",
  description = "Enables the !extend command and automatically extends a tied game.",
  version = SOURCEMOD_VERSION,
  url = "http://github.com/qpingu/tf2.pug.na-irc-bot"
};

// Code
public OnPluginStart() {
  hExtendThreshold = CreateConVar("tf2pug_extend_threshold", "140", "Maximum amount of time remaining before extends can be triggered. (seconds)", _, true, 0.0, false, 0.0);
  hCancelThreshold = CreateConVar("tf2pug_cancel_threshold", "140", "Maximum amount of time after an extend before a cancel can occur. (seconds)", _, true, 0.0, false, 0.0);
  hExtendTime = CreateConVar("tf2pug_extend_time", "10", "Amount of time added to the map time limit on extend. (minutes)", _, true, 1.0, false, 0.0);
  hExtendMax = CreateConVar("tf2pug_extend_max", "2", "Maximum number of extensions.", _, true, 0.0, false, 0.0);

  AutoExecConfig(true, "tf2pug");
  
  RegConsoleCmd("sm_extend", Command_Extend);
  RegConsoleCmd("sm_cancel", Command_Cancel);

  CreateTimer(20.0, Timer_CheckRemaining, _, TIMER_REPEAT);
}

public OnMapStart() {
  extendCount = 0;
  extendCancel = false;
}

public Action:Timer_CheckRemaining(Handle:timer) {
  new timeLeft; GetMapTimeLeft(timeLeft);
  new timeLimit; GetMapTimeLimit(timeLimit);
  new extendThreshold = GetConVarInt(hExtendThreshold);

  if (timeLimit != 0 && timeLeft <= extendThreshold) {
    new blueScore = GetTeamScore(3);
    new redScore = GetTeamScore(2);
  
    if (blueScore == redScore && ExtendMatch()) {
      PrintToChatAll("Stalemate detected, adding %i minutes overtime.", GetConVarInt(hExtendTime));
    } else if ((GetTime() - lastExtendMessage) > extendThreshold) {
      PrintToChatAll("%i minutes left in the match. Type \"!extend\" in chat to increase the time limit.", extendThreshold / 60);
      lastExtendMessage = GetTime();
    }
  }
}

public Action:Command_Extend(client, args) {
  new client_team = GetClientTeam(client);
  new String:client_name[32]; GetClientName(client, client_name, sizeof(client_name));
  
  if (client_team == TF_TEAM_BLU || client_team == TF_TEAM_RED) {
    new extendThreshold = GetConVarInt(hExtendThreshold);
    new timeLeft; GetMapTimeLeft(timeLeft);
    new timeLimit; GetMapTimeLimit(timeLimit);

    if (extendCancel) {
      PrintToChatAll("The extention was already canceled.");
    } else if (timeLimit != 0 && timeLeft <= extendThreshold && ExtendMatch()) {
      PrintToChatAll("Match extended %i minutes by %s.", GetConVarInt(hExtendTime), client_name);
    } else {
      PrintToChat(client, "You can only extend with %i minutes left in the match.", extendThreshold / 60);
    }
  }
  
  return Plugin_Handled;
}

public Action:Command_Cancel(client, args) {
  new client_team = GetClientTeam(client);
  new String:client_name[32]; GetClientName(client, client_name, sizeof(client_name));

  if (client_team == TF_TEAM_BLU || client_team == TF_TEAM_RED) {
    new cancelThreshold = GetConVarInt(hCancelThreshold);
    
    if (extendCancel) {
      PrintToChatAll("The extention was already canceled.");
    } else if ((GetTime() - lastExtend) <= cancelThreshold && CancelMatch()) {
      PrintToChatAll("Extend canceled by %s", client_name);
    } else {
      PrintToChat(client, "You can only cancel up to %i minutes after an extension.", cancelThreshold / 60);
    }
  }
  
  return Plugin_Handled;
}


public ExtendMatch() {
  new extendMax = GetConVarInt(hExtendMax);
  
  if (extendCount >= extendMax || extendCancel) {
    return false;
  } else {
    new timeLimit; GetMapTimeLimit(timeLimit);
    new extendTime = GetConVarInt(hExtendTime);
    
    ServerCommand("mp_timelimit %i", timeLimit + extendTime);
    
    lastExtend = GetTime();
    ++extendCount;
  
    if (extendCount == extendMax) { 
      PrintToChatAll("The maximum number of extensions has been met, this extension is final!"); 
    }
    
    return true;
  }
}

public CancelMatch() {
  extendCancel = true;

  if (extendCount > 0) {
    new timeLimit; GetMapTimeLimit(timeLimit);
    new extendTime = GetConVarInt(hExtendTime);
  
    ServerCommand("mp_timelimit %i", timeLimit - extendTime);
    --extendCount;
    
    return true;
  } else {
    return false;
  }
}
