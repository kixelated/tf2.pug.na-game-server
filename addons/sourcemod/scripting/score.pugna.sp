#include <sourcemod>
#include <sdktools>

// Plugin Info
public Plugin:myinfo = {
  name = "tf2.pug.na - Score Grabber",
  author = "Luke Curley",
  description = "Adds client command to get the current score.",
  version = SOURCEMOD_VERSION,
  url = "http://github.com/qpingu/tf2.pug.na-irc-bot"
};

// Code
public OnPluginStart() {
  RegConsoleCmd("tf_score", Command_TFScore);
}

public Action:Command_TFScore(client, args) {
  new blueScore = GetTeamScore(3);
  new redScore = GetTeamScore(2);

  ReplyToCommand(client, "[SM] %t", "Blue Score", blueScore);
  ReplyToCommand(client, "[SM] %t", "Red Score", redScore);
  
  return Plugin_Handled;
}
