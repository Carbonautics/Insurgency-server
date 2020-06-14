#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#undef REQUIRE_PLUGIN

//#pragma newdecls required

#define PLUGIN_DESCRIPTION "Injured Effect"
#define PLUGIN_NAME "injured"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_WORKING "1"
#define PLUGIN_LOG_PREFIX "INJEF"
#define PLUGIN_AUTHOR "Carbonautics"
#define PLUGIN_URL ""

public Plugin myinfo = {
        name            = PLUGIN_NAME,
        author          = PLUGIN_AUTHOR,
        description     = PLUGIN_DESCRIPTION,
        version         = PLUGIN_VERSION,
        url             = PLUGIN_URL
};
UserMsg g_FadeUserMsgId;
new 
	Handle:cvar_injury_display_delay = INVALID_HANDLE,
	Handle:cvar_show_health_display_delay = INVALID_HANDLE,
	Float:g_fShowHealthDelay,
	Float:g_fDisplayDelay,
	bool:g_bIsInit = false,
	bool:g_bIsChangedDelay = false;
	bool:g_bIsChangedshDelay = false;

public void OnPluginStart() 
{
	cvar_injury_display_delay = CreateConVar("sm_injury_display_delay", "10", "Defines display delay time", FCVAR_PLUGIN);
	cvar_show_health_display_delay = CreateConVar("sm_show_health_display_delay", "35", "Defines display delay time", FCVAR_PLUGIN);
	HookConVarChange(cvar_injury_display_delay, OnDisplayDelayChange);
	HookConVarChange(cvar_show_health_display_delay, OnShowHealthDelayChange);
	LoadTranslations("common.phrases");
	AutoExecConfig(true, "plugin.injury");
	g_FadeUserMsgId = GetUserMessageId("Fade");
	HookEvent("player_hurt", Event_Hurt);
	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		g_fShowHealthDelay = GetConVarFloat(cvar_show_health_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshShowHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnMapStart()
{	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthAmt, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		g_fShowHealthDelay = GetConVarFloat(cvar_show_health_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshShowHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnMapEnd()
{	
	g_bIsInit = false;
}

public Action:Timer_RefreshHealthAmt(Handle:timer)
{
	if (g_bIsChangedDelay)
	{
		g_bIsChangedDelay = false;
		g_bIsInit = false;
		CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
		PrintToServer("[Injury] Restarting");
		return Plugin_Stop;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientObserver(client) && GetClientTeam(client) == 2)
		{
				//int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
			int iHealth = GetClientHealth(client);
			int amount;
			if(iHealth >=50 && iHealth < 70)
			{
				amount = 50;
			}
			else if(iHealth >=30 && iHealth < 50)
			{
				amount = 100;
			}
			else if(iHealth >=10 && iHealth < 30)
			{
				amount = 125;
			}
			else if(iHealth >=1 && iHealth < 10)
			{
				amount = 150;
			}
			//injury(client, 0);
			injury(client, amount);
		}
	}
	return Plugin_Continue;
}
public Action:Timer_RefreshShowHealthText(Handle:timer)
{
	if (g_bIsChangedshDelay)
	{
		g_bIsChangedshDelay = false;
		g_bIsInit = false;
		CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
		PrintToServer("[Injury] Restarting");
		return Plugin_Stop;
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientObserver(client) && GetClientTeam(client) == 2)
		{
			int iHealth = GetClientHealth(client);
			if(iHealth < 90)
			{
				PrintHintText(client,"You are injured, heal to gain Normal vision! HP: %d", iHealth);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_Hurt(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		//int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
		int iHealth = GetClientHealth(client);
		int amount;
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientObserver(client) && GetClientTeam(client) == 2)
		{
				//int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
			int iHealth = GetClientHealth(client);
			int amount;
			if(iHealth >=50 && iHealth < 70)
			{
				amount = 50;
				PrintCenterText(client,"You are injured, heal to gain Normal vision! HP: %d", iHealth);
			}
			else if(iHealth >=30 && iHealth < 50)
			{
				amount = 100;
				PrintCenterText(client,"You are injured, heal to gain Normal vision! HP: %d", iHealth);
			}
			else if(iHealth >=10 && iHealth < 30)
			{
				amount = 125;
				PrintCenterText(client,"You are injured, heal to gain Normal vision! HP: %d", iHealth);
			}
			else if(iHealth >=1 && iHealth < 10)
			{
				amount = 150;
				PrintCenterText(client,"You are injured, heal to gain Normal vision! HP: %d", iHealth);
			}
			//injury(client, 0);
			injury(client, amount);
		}
	}
	return Plugin_Continue;
}
void injury(int target, int amount)
{
	int targets[2];
	targets[0] = target;
	int duration = 700;
	int holdtime = 4536;
	int flags;
	if(amount == 0)
	{
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002);
	}

	int color[4] = { 0, 0, 0, 0 };
	color[3] = amount;
	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(flags);
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}
	EndMessage();
}
public OnDisplayDelayChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_bIsChangedDelay = true;
	g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
	CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
	PrintToServer("[Injury] Timer cvars changed (g_fDisplayDelay: %f)", g_fDisplayDelay);
}
public OnShowHealthDelayChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_bIsChangedshDelay = true;
	g_fDisplayDelay = GetConVarFloat(cvar_show_health_display_delay);

}

public Action:Timer_RestartHealthTimer(Handle:timer)
{
	PrintToServer("[Injury] Restart Timer (g_bIsInit: %d)", g_bIsInit);
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthAmt, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnCVarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	GetCVars();
	PrintToServer("[Injury] Cvars changed");
}

public GetCVars()
{
	//injury = GetConVarBool(cvar_injury);
	//injury_text_area = GetConVarInt(cvar_injury_text_area);
	//injury_on_hit_only = GetConVarBool(cvar_injury_on_hit_only);
	g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
}