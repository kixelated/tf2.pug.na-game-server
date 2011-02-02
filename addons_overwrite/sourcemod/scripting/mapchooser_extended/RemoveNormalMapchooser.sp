#include <sourcemod>

#pragma semicolon 1

public OnConfigsExecuted_Rem_MapCh()
{
	decl String:filename[200];
	BuildPath(Path_SM, filename, sizeof(filename), "plugins/mapchooser.smx");
	if(FileExists(filename))
	{
		decl String:newfilename[200];
		BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/mapchooser.smx");
		ServerCommand("sm plugins unload mapchooser");
		if(FileExists(newfilename))
			DeleteFile(newfilename);
		RenameFile(newfilename, filename);
		LogMessage("plugins/mapchooser.smx was unloaded and moved to plugins/disabled/mapchooser.smx");
	}
}