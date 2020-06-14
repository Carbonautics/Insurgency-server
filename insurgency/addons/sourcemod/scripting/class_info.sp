/* 
 * Class Details Panel Plugin
 * This plugin display a panel with current class details to players.
 *
 * ConVars:
 * sm_cdp_enable 		- Enable/Disable Plugin
 * sm_cdp_timer			- When the message should be displayed after the player join on the server (in seconds)
 *
 *
 * Colored Message Example:
 * {green}Hello! {lightgreen}Don't be shy! Say {green}Hello {lightgreen}to other players.
 *
 * Color list:
 * http://forums.alliedmods.net/showthread.php?t=96831
 *
 * Changelog:
 * Version 1.0 (7.07.20)
 * - Initial Release

 *
 */

#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION "1.0"

#define PANEL 2

new Handle:g_Cvar_PluginEnable = INVALID_HANDLE;
new Handle:g_Cvar_PanelLines = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[=F|A=]Class Details Panel",
	author = "Carbonautics",
	description = "Display a panel/menu after choosing class, showing details about the current class.",
	version = PLUGIN_VERSION,
	url = "http://github.com/carbonautics/"
}

public OnPluginStart()
{
	CreateConVar("cdp_version", PLUGIN_VERSION, "Class Details Panel Plugin Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_Cvar_PluginEnable = 		CreateConVar("sm_cdp_enable", "1", "Enable/Disable Plugin", _, true, 0.0, true, 1.0);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post);
    RegConsoleCmd("sm_cdp", Cdp_Func);
	LoadTranslations("classdetails.phrases");
}
public Action:Cdp_Func(client, args)
{
    // Function To Create the panel and send it to client
    	if (IsClientInGame(client) && !IsFakeClient(client))
    	{
    		CreateTimer(0.1, PanelMessageDisplay, client, TIMER_FLAG_NO_MAPCHANGE);
	    }
    return Plugin_Handled;
}
/*public OnClientPostAdminCheck(client)
{
	if (GetConVarInt(g_Cvar_PluginEnable) == 1)
	{
		CreateTimer (GetConVarFloat(g_Cvar_PluginTimer), Timer_Welcome, client);
	}
}
	
public Action:Timer_Welcome(Handle:timer, any:client)
{
	//new msgbits = GetConVarInt(g_Cvar_MsgType);
	//if (msgbits & PANEL)
	PanelMessageDisplay(client);
	//if (msgbits & HINT)
	//	HintMessageDisplay(client);

	return Plugin_Handled;
}*/

public Action:Event_PlayerPickSquad_Post(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client_id = GetEventInt(event, "userid");
	new client = GetClientOfUserId(client_id);
    	if (IsClientInGame(client) && !IsFakeClient(client))
    	{
    		CreateTimer(0.1, PanelMessageDisplay, client, TIMER_FLAG_NO_MAPCHANGE);
	    }
}
public Action:PanelMessageDisplay(Handle:timer, any:client) 
{
	decl String:message1[255], String:message2[255], String:message3[255], String:message4[255], String:message5[255], String:message6[255], String:message7[255], String:message8[255];
	decl String:message9[255], String:message10[255], String:message11[255], String:message12[255], String:message13[255], String:message14[255], String:message15[255];
	decl String:closepanel[255];
	
	new Handle:WelcomePanel = CreatePanel(INVALID_HANDLE);
	        
            Format(message1, sizeof(message1), "%T", "PanelTitle", LANG_SERVER);
			SetPanelTitle(WelcomePanel, message1);
			Format(message2, sizeof(message2), "%T", "PanelLine1", LANG_SERVER);
			DrawPanelText(WelcomePanel, message2);
			Format(message3, sizeof(message3), "%T", "PanelLine2", LANG_SERVER);
			DrawPanelText(WelcomePanel, message3);
			Format(message4, sizeof(message4), "%T", "PanelLine3", LANG_SERVER);
			DrawPanelText(WelcomePanel, message4);
			Format(message5, sizeof(message5), "%T", "PanelLine4", LANG_SERVER);
			DrawPanelText(WelcomePanel, message5);
			Format(message6, sizeof(message6), "%T", "PanelLine5", LANG_SERVER);
			DrawPanelText(WelcomePanel, message6);
			Format(message7, sizeof(message7), "%T", "PanelLine6", LANG_SERVER);
			DrawPanelText(WelcomePanel, message7);
			Format(message8, sizeof(message8), "%T", "PanelLine7", LANG_SERVER);
			DrawPanelText(WelcomePanel, message8);
			Format(closepanel, sizeof(closepanel), "%T", "PanelClose", LANG_SERVER);
			DrawPanelText(WelcomePanel, closepanel);
			SendPanelToClient(WelcomePanel, client, NullMenuHandler, 20);
			CloseHandle(WelcomePanel);
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) 
{
}