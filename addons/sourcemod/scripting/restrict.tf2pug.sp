#include <clients>
#include <sourcemod>
#include <tf2_stocks>

#define TF_TEAM_BLU 3
#define TF_TEAM_RED 2

#define TF_CLASS_SCOUT    1
#define TF_CLASS_SOLDIER  3
#define TF_CLASS_PYRO     7
#define TF_CLASS_DEMOMAN  4
#define TF_CLASS_HEAVY    6
#define TF_CLASS_ENGINEER 9
#define TF_CLASS_MEDIC    5
#define TF_CLASS_SNIPER   2
#define TF_CLASS_SPY      8
#define TF_CLASS_UNKNOWN  0

// Variables
new bool:playerRestriction[32];
new playerClass[32];

new Handle:classRestriction[10];
new Handle:classLimit[10];

// Plugin Info
public Plugin:myinfo = {
  name = "tf2.pug.na - Off-class Restriction",
  author = "Luke Curley",
  description = "Limits off-classing using the !restrict command.",
  version = SOURCEMOD_VERSION,
  url = "http://github.com/qpingu/tf2.pug.na-irc-bot"
};

// Code
public OnPluginStart() {
  RegConsoleCmd("sm_restrict", Command_Restrict);

  HookEvent("player_changeclass", Event_PlayerClass);
  HookEvent("player_spawn", Event_PlayerSpawn);
  
  classRestriction[0] = INVALID_HANDLE;
  classRestriction[TF_CLASS_SCOUT] =    CreateConVar("tf2pug_restrict_scout",    "0", "Prevent player from selecting scout if restricted.");
  classRestriction[TF_CLASS_SOLDIER] =  CreateConVar("tf2pug_restrict_soldier",  "0", "Prevent player from selecting soldier if restricted.");
  classRestriction[TF_CLASS_PYRO] =     CreateConVar("tf2pug_restrict_pyro",     "1", "Prevent player from selecting pyro if restricted.");
  classRestriction[TF_CLASS_DEMOMAN] =  CreateConVar("tf2pug_restrict_demoman",  "0", "Prevent player from selecting demoman if restricted.");
  classRestriction[TF_CLASS_HEAVY] =    CreateConVar("tf2pug_restrict_heavy",    "1", "Prevent player from selecting heavy if restricted.");
  classRestriction[TF_CLASS_ENGINEER] = CreateConVar("tf2pug_restrict_engineer", "1", "Prevent player from selecting engineer if restricted.");
  classRestriction[TF_CLASS_MEDIC] =    CreateConVar("tf2pug_restrict_medic",    "0", "Prevent player from selecting medic if restricted.");
  classRestriction[TF_CLASS_SNIPER] =   CreateConVar("tf2pug_restrict_sniper",   "1", "Prevent player from selecting sniper if restricted.");
  classRestriction[TF_CLASS_SPY] =      CreateConVar("tf2pug_restrict_spy",      "1", "Prevent player from selecting spy if restricted.");
  
  classLimit[0] = INVALID_HANDLE;
  classLimit[TF_CLASS_SCOUT] =    FindConVar("tf_tournament_classlimit_scout");
  classLimit[TF_CLASS_SOLDIER] =  FindConVar("tf_tournament_classlimit_soldier");
  classLimit[TF_CLASS_PYRO] =     FindConVar("tf_tournament_classlimit_pyro");
  classLimit[TF_CLASS_DEMOMAN] =  FindConVar("tf_tournament_classlimit_demoman");
  classLimit[TF_CLASS_HEAVY] =    FindConVar("tf_tournament_classlimit_heavy");
  classLimit[TF_CLASS_ENGINEER] = FindConVar("tf_tournament_classlimit_engineer");
  classLimit[TF_CLASS_MEDIC] =    FindConVar("tf_tournament_classlimit_medic");
  classLimit[TF_CLASS_SNIPER] =   FindConVar("tf_tournament_classlimit_sniper");
  classLimit[TF_CLASS_SPY] =      FindConVar("tf_tournament_classlimit_spy");
}

public OnMapStart() {
  for (new i = 1; i < MaxClients; ++i) { 
    playerRestriction[i] = false; 
    playerClass[i] = TF_CLASS_UNKNOWN;
  }
}

public Action:Command_Restrict(client, args) {
  new client_team = GetClientTeam(client);
  
  if (client_team == TF_TEAM_BLU || client_team == TF_TEAM_RED) {
    new Handle:menu = CreateMenu(Menu_Restrict);
    SetMenuTitle(menu, "Who would you like to restrict from off-classing?");
    
    new String:player_name[32];
    new String:player_i[2];
    
    for (new i = 1; i < MaxClients; ++i) {
      if (IsClientInGame(i)) {
        if (GetClientTeam(i) == client_team && i != client) {
          GetClientName(i, player_name, sizeof(player_name));
          IntToString(i, player_i, 2);
          
          AddMenuItem(menu, player_name, player_i);
        }
      }
    }
  }
  
  return Plugin_Continue;  
}

public Menu_Restrict(Handle:menu, MenuAction:action, param1, param2) {
  new client = param1;

  if (action == MenuAction_Select) {
    new String:info[2];
    
    if (GetMenuItem(menu, param2, info, sizeof(info))) {
      new player = StringToInt(info);

      if (IsClientInGame(player)) {
        new player_team = GetClientTeam(player);
        new client_team = GetClientTeam(client);
      
        if (player_team == client_team) {
          new String:client_name[32]; GetClientName(client, client_name, sizeof(client_name));
          new String:player_name[32]; GetClientName(player, player_name, sizeof(player_name));

          if (!playerRestriction[player]) {
            playerRestriction[player] = true;
            PrintToChatAll("%s was restricted by %s", player_name, client_name);

            new i;            
            for (i = 9; i > 0 && (isClassRestricted(i) || isClassFull(i, player_team)); --i) { }
            playerClass[player] = i;
          }
        }
      }
    }
  } else if (action == MenuAction_Cancel || action == MenuAction_End) {
    CloseHandle(menu);
  }
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast) {
  new client = GetClientOfUserId(GetEventInt(event, "userid"));
  new client_class = GetEventInt(event, "class");
  
  if (isRestricted(client) && isClassRestricted(client_class)) {
    PrintToChat(client, "You have been restricted from playing that class.");
    
    TF2_SetPlayerClass(client, TFClassType:playerClass[client]);
  } else {
    playerClass[client] = client_class;
  }
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
  new client = GetClientOfUserId(GetEventInt(event, "userid"));
  new client_class = GetEventInt(event, "class");
  
  if (isRestricted(client) && isClassRestricted(client_class)) {
    PrintToChat(client, "You have been restricted from playing that class.");
    
    TF2_SetPlayerClass(client, TFClassType:playerClass[client]);
    TF2_RespawnPlayer(client); 
  }
}

public isRestricted(client) {
  return playerRestriction[client];
}

public isClassRestricted(class) {
  if (class < TF_CLASS_SCOUT) { return false; }
  
  return GetConVarInt(classRestriction[class]) == 1;
}

public isClassFull(class, team) {
  if (team < TF_TEAM_RED || class < TF_CLASS_SCOUT) { return false; }
  
  new limit = GetConVarInt(classLimit[class]);
  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && GetClientTeam(i) == team && _:TF2_GetPlayerClass(i) == class) { --limit; }
  }    
  
  return limit > 0;
}
