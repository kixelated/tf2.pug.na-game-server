#include <sourcemod>

public Plugin:myinfo = {
  name = "tf2.pug.na - Humiliation Immunity",
  author = "Luke Curley",
  description = "Gives players immunity during the humiliation round to prevent stat padding",
  version = SOURCEMOD_VERSION,
  url = "https://github.com/qpingu/tf2.pug.na-game-server"
}

public OnPluginStart() {
  HookEvent("teamplay_round_start", Event_RoundStart);
  HookEvent("teamplay_round_win",   Event_RoundEnd);
}

public OnClientDisconnect(client) {
  SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
    }
  }
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
    }
  }
}
