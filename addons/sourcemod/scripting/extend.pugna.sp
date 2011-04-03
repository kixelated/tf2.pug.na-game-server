#include <sourcemod>
#include <sdktools>

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
  hExtendThreshold = CreateConVar("pugna_extend_threshold", "140", "Maximum amount of time remaining before extends can be triggered. (seconds)", _, true, 0.0, false, 0.0);
  hCancelThreshold = CreateConVar("pugna_cancel_threshold", "140", "Maximum amount of time after an extend before a cancel can occur. (seconds)", _, true, 0.0, false, 0.0);
  hExtendTime = CreateConVar("pugna_extend_time", "10", "Amount of time added to the map time limit on extend. (minutes)", _, true, 1.0, false, 0.0);
  hExtendMax = CreateConVar("pugna_extend_max", "2", "Maximum number of extensions.", _, true, 0.0, false, 0.0);

  AutoExecConfig(true, "tf2pug")

  CreateTimer(20.0, CheckTime, _, TIMER_REPEAT);
  HookEvent("player_say", Event_PlayerSay);
}

public OnMapStart() {
  extendCount = 0;
  extendCancel = false;
}

public Action:CheckTime(Handle:timer) {
  new timeLeft; GetMapTimeLeft(timeLeft);
  new timeLimit; GetMapTimeLimit(timeLimit);
  new extendThreshold = GetConVarInt(hExtendThreshold);

  if (timeLimit != 0 && timeLeft <= extendThreshold) {
    new blueScore = GetTeamScore(3);
    new redScore = GetTeamScore(2);
  
    if (blueScore == redScore && extendMatch()) {
      PrintToChatAll("Stalemate detected, adding %i minutes overtime.", GetConVarInt(hExtendTime));
    } else if ((GetTime() - lastExtendMessage) > extendThreshold) {
      PrintToChatAll("%i minutes left in the match. Type \"!extend\" in chat to increase the time limit.", extendThreshold / 60);
      lastExtendMessage = GetTime();
    }
  }
}

public Action:Event_PlayerSay(Handle:event, const String:name[], bool:dontBroadcast) {
  decl String:userText[192];
  userText[0] = '\0';
  if (!GetEventString(event, "text", userText, 192)) {
    return Plugin_Continue;
  }
  
  new client = GetClientOfUserId(GetEventInt(event, "userid"));
  new client_team = GetClientTeam(client);
  new String:client_name[32];
  
  GetClientName(client, client_name, sizeof(client_name));
  
  if (StrContains(userText, "!extend") == 0) { 
    new extendThreshold = GetConVarInt(hExtendThreshold);
    new timeLeft; GetMapTimeLeft(timeLeft);
    new timeLimit; GetMapTimeLimit(timeLimit);
  
    if (extendCancel) {
      PrintToChatAll("The extention was already canceled.");
    } else if (timeLimit != 0 && timeLeft <= extendThreshold && extendMatch()) {
      PrintToChatAll("Match extended %i minutes by %s.", GetConVarInt(hExtendTime), client_name);
    } else {
      PrintToChat(client, "You can only extend with %i minutes left in the match.", extendThreshold / 60);
    }
  }

  if (StrContains(userText, "!cancel") == 0 && (client_team == 2 || client_team == 3)) { 
    new cancelThreshold = GetConVarInt(hCancelThreshold);
  
    if (extendCancel) {
      PrintToChatAll("The extention was already canceled.");
    } else if ((GetTime() - lastExtend) <= cancelThreshold && cancelMatch()) {
      PrintToChatAll("Extend canceled by %s", client_name);
    } else {
      PrintToChat(client, "You can only cancel up to %i minutes after an extension.", cancelThreshold / 60);
    }
  }

  return Plugin_Continue;  
}

public extendMatch() {
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

public cancelMatch() {
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
