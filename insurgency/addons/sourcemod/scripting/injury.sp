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
	Float:g_fDisplayDelay,
	bool:g_bIsInit = false,
	bool:g_bIsChangedDelay = false;

public void OnPluginStart() 
{
	cvar_injury_display_delay = CreateConVar("sm_injury_display_delay", "10", "Defines display delay time", FCVAR_PLUGIN);
	HookConVarChange(cvar_injury_display_delay, OnDisplayDelayChange);
	LoadTranslations("common.phrases");
	AutoExecConfig(true, "plugin.injury");
	g_FadeUserMsgId = GetUserMessageId("Fade");
	HookEvent("player_hurt", Event_Hurt);
	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnMapStart()
{	
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnMapEnd()
{	
	g_bIsInit = false;
}

public Action:Timer_RefreshHealthText(Handle:timer)
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
			if(iHealth >=90 && iHealth <= 100 || iHealth == 0)
			{
				amount = 0;
			}
			else if(iHealth >=70 && iHealth < 90)
			{
				amount = 50;
			}
			else if(iHealth >=50 && iHealth < 70)
			{
				amount = 100;
			}
			else if(iHealth >=30 && iHealth < 50)
			{
				amount = 150;
			}
			else if(iHealth >=10 && iHealth < 30)
			{
				amount = 175;
			}
			else if(iHealth >=1 && iHealth < 10)
			{
				amount = 230;
			}
			injury(client, 0);
			injury(client, amount);
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
		if(iHealth >=90 && iHealth <= 100 || iHealth == 0)
		{
			amount = 0;
		}
		else if(iHealth >=70 && iHealth < 90)
		{
			amount = 50;
		}
		else if(iHealth >=50 && iHealth < 70)
		{
			amount = 100;
		}
		else if(iHealth >=30 && iHealth < 50)
		{
			amount = 150;
		}
		else if(iHealth >=10 && iHealth < 30)
		{
			amount = 175;
		}
		else if(iHealth >=1 && iHealth < 10)
		{
			amount = 230;
		}
		injury(client, amount);
	}
	return Plugin_Continue;
}
void injury(int target, int amount)
{
	int targets[2];
	targets[0] = target;
	int duration = 236;
	int holdtime = 1536;
	int flags;
	if(amount == 0)
	{	
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002 | 0x0008);
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
	//injury_on_hit_only = GetConVarBool(cvar_injury_on_hit_only);
	g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
	CreateTimer(g_fDisplayDelay, Timer_RestartHealthTimer);
	PrintToServer("[Injury] Timer cvars changed (g_fDisplayDelay: %f)", g_fDisplayDelay);
}

public Action:Timer_RestartHealthTimer(Handle:timer)
{
	PrintToServer("[Injury] Restart Timer (g_bIsInit: %d)", g_bIsInit);
	if(!g_bIsInit)
	{
		g_bIsInit = true;
		g_fDisplayDelay = GetConVarFloat(cvar_injury_display_delay);
		CreateTimer(g_fDisplayDelay, Timer_RefreshHealthText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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