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

// Constants
new String:noSounds[10][24] = { "",  "vo/scout_no03.wav",   "vo/sniper_no04.wav", "vo/soldier_no01.wav",
                                      "vo/demoman_no03.wav", "vo/medic_no03.wav",  "vo/heavy_no02.wav",
                                      "vo/pyro_no01.wav",    "vo/spy_no02.wav",    "vo/engineer_no03.wav" };

// Variables
new bool:playerRestriction[32]; // Restriction status for each client
new playerClass[32]; // The last selected (valid) class for each client

new Handle:classRestriction[10]; // cvar for restricted classes
new Handle:classLimit[10]; // cvar for class limits (uses tournament settings)

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
  HookEvent("player_spawn",       Event_PlayerClass);
  HookEvent("player_team",        Event_PlayerClass);
  
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
  // Clear the client arrays
  for (new i = 1; i < MaxClients; ++i) { 
    playerRestriction[i] = false; 
    playerClass[i] = TF_CLASS_UNKNOWN;
  }
}

public OnClientDisconnect(client) {
  playerRestriction[client] = false; 
  playerClass[client] = TF_CLASS_UNKNOWN;
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast) {
  new client = GetClientOfUserId(GetEventInt(event, "userid"));
  new client_team = GetClientTeam(client);
  new client_class = GetEventInt(event, "class");
  
  if (isRestricted(client) && isClassRestricted(client_class)) {
    ShowVGUIPanel(client, client_team == TF_TEAM_BLU ? "class_blue" : "class_red"); // Show class select page
    EmitSoundToClient(client, noSounds[client_class]); // Make the "no" sounds in the classes' voice
    
    TF2_SetPlayerClass(client, TFClassType:playerClass[client]); // Set the player's class to the last valid one
  } else {
    playerClass[client] = client_class; // Class is valid, save it for later so we can revert to it
  }
}

public restrictPlayer(player) {
  if (!isRestricted(player)) {
    new player_team = GetClientTeam(player);
    new player_class = playerClass[player];
    
    if (isClassRestricted(player_class)) {
      // Player's current class is restricted, find him another one
      for (player_class = 9; player_class > 1 && (isClassRestricted(player_class) || isClassFull(player_class, player_team)); --player_class) { }
      
      playerClass[player] = player_class;
      TF2_SetPlayerClass(player, TFClassType:player_class);
    }

    playerRestriction[player] = true;
    
    new String:player_name[32]; GetClientName(player, player_name, sizeof(player_name));
    PrintToChatAll("%s was restricted from off-classing.", player_name);
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
  if (limit == -1) { return false; }
  
  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && GetClientTeam(i) == team && playerClass[i] == class) { --limit; }
  }
  
  return limit > 0;
}

public Action:Command_Restrict(client, args) {
  new client_team = GetClientTeam(client);
  
  if (client_team == TF_TEAM_BLU || client_team == TF_TEAM_RED) {
    new Handle:menu = CreateMenu(Menu_Restrict); // Create a menu
    SetMenuTitle(menu, "Who would you like to restrict from off-classing?");
    
    new String:player_name[32];
    new String:player_i[2];
    
    new count = 0;
    for (new i = 1; i < MaxClients; ++i) {
      if (IsClientInGame(i)) {
        if (GetClientTeam(i) == client_team && i != client) {
          GetClientName(i, player_name, sizeof(player_name));
          IntToString(i, player_i, 2);
          
          ++count;
          AddMenuItem(menu, player_i, player_name); // Add each player on the team to the menu
        }
      }
    }
    
    if (count > 0) { DisplayMenu(menu, client, 20); }
  }
  
  return Plugin_Handled;
}

public Menu_Restrict(Handle:menu, MenuAction:action, param1, param2) {
  if (IsVoteInProgress()) { return; }

  if (action == MenuAction_Select) {
    new String:info[2];
    
    if (GetMenuItem(menu, param2, info, sizeof(info))) {
      new client = param1;
      new player = StringToInt(info);

      if (IsClientInGame(player)) {
        new team = GetClientTeam(player);
      
        if (team == GetClientTeam(client)) {
          new String:player_name[32]; GetClientName(player, player_name, sizeof(player_name));
          PrintToChatAll("A vote is in progress to restrict %s from off-classing.", player_name);
        
          new Handle:menu_vote = CreateMenu(Menu_VoteRestrict);
          SetVoteResultCallback(menu, Menu_VoteRestrictResults); // Set the callback to handle the results
          
          SetMenuTitle(menu_vote, "Restrict %s from off-classing?", player_name);
          AddMenuItem(menu_vote, info, "Yes");
          AddMenuItem(menu_vote, "0", "No");
          SetMenuExitButton(menu, false);
          
          new clients[32];
          new num = 0;
          
          for (new i = 1; i <= MaxClients; i++) {
            // Show vote for all of the players on the team who are not the caster and player being restricted
            if (IsClientInGame(i) && GetClientTeam(i) == team && i != client && i != player) { clients[num++] = i; }
          }
          
          if (num > 0) { VoteMenu(menu, clients, num, 20); }
        }
      }
    }
  } else if (action == MenuAction_Cancel || action == MenuAction_End) {
    CloseHandle(menu);
  }
}

public Menu_VoteRestrict(Handle:menu, MenuAction:action, param1, param2) {
  if (action == MenuAction_End) { CloseHandle(menu); }
}

public Menu_VoteRestrictResults(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2]) {
  new winner = 0;
  if (num_items > 1 && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES])) {
	  winner = GetRandomInt(0, 1); // There was a tie, randomly pick a winner
  }

  new String:result[2];
  GetMenuItem(menu, item_info[winner][VOTEINFO_ITEM_INDEX], result, sizeof(result));
  
  new player = StringToInt(result);
  if (player > 0) { restrictPlayer(player); }
}
