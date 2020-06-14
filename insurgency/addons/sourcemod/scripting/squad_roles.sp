/*
Edited [INS]Country Nick PLugin by Neko from Github.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
 
#define VERSION "1.0.0"
public Plugin:myinfo =
{
	name = "[=F|A=] Squad Roles",
	author = "Carbonautics",
	description = "Add Squad Roles Prefix to Player Names",
	version = VERSION
};
new String:oName[MAXPLAYERS+1][64];
public OnPluginStart()
{
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post);
	//HookEvent("player_changename", Event_PlayerChangename, EventHookMode_Pre);
}

public OnClientPutInServer(client)
{
	new String:sNickname[64];
	Format(sNickname, sizeof(sNickname), "%N", client);
	oName[client] = sNickname;
}

public Action:Event_PlayerPickSquad_Post( Handle:event, const String:name[], bool:dontBroadcast )
{
	//decl String:sName[64];
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// Get class name
	decl String:class_template[64];
	GetEventString(event, "class_template", class_template, 64);
	if(!IsFakeClient(client))
	{
		//GetEventString(event, "newname", sName, 65);
		//GetClientName(client, sName, sizeof(sName));
		SetNewName(client, class_template);
		return Plugin_Handled; // avoid printing the change to the chat
	}
	return Plugin_Continue;
}

SetNewName(client, String:class_template[])
{
	decl String:flag[65];

	if(StrContains(class_template, "leader") > -1)
	{
		// Admin Leader
		if (GetUserFlagBits(client) & ADMFLAG_KICK)
			Format(flag, sizeof(flag), "|ADM|LEAD|%s", oName[client]);
		// Donor Leader
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
			Format(flag, sizeof(flag), "|DONOR|LEAD|%s", oName[client]);
		//Admin Donor Leader
		else if (GetUserFlagBits(client) & (ADMFLAG_KICK | ADMFLAG_CUSTOM2) == (ADMFLAG_KICK | ADMFLAG_CUSTOM2))
			Format(flag, sizeof(flag), "|ADM|DONOR|LEAD|%s", oName[client]);
		// Normal Leader
		else
			Format(flag, sizeof(flag), "|LEAD|%s", oName[client]);
	}
	else if (StrContains(class_template, "mg") > -1)
	{
		// Admin MG
		if (GetUserFlagBits(client) & ADMFLAG_KICK)
			Format(flag, sizeof(flag), "|ADM|MG|%s", oName[client]);
		// Donor MG
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
			Format(flag, sizeof(flag), "|DONOR|MG|%s", oName[client]);
		// Admin Donor MG
		else if (GetUserFlagBits(client) & (ADMFLAG_KICK | ADMFLAG_CUSTOM2) == (ADMFLAG_KICK | ADMFLAG_CUSTOM2))
			Format(flag, sizeof(flag), "|ADM|DONOR|MG|%s", oName[client]);
		// Normal MG
		else
			Format(flag, sizeof(flag), "|MG|%s", oName[client]);
	}
	else if (StrContains(class_template, "medic") > -1)
	{
		// Admin MG
		if (GetUserFlagBits(client) & ADMFLAG_KICK)
			Format(flag, sizeof(flag), "|ADM|DOC|%s", oName[client]);
		// Donor MG
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
			Format(flag, sizeof(flag), "|DONOR|DOC|%s", oName[client]);
		// Admin Donor MG
		else if (GetUserFlagBits(client) & (ADMFLAG_KICK | ADMFLAG_CUSTOM2) == (ADMFLAG_KICK | ADMFLAG_CUSTOM2))
			Format(flag, sizeof(flag), "|ADM|DONOR|DOC|%s", oName[client]);
		// Normal MG
		else
			Format(flag, sizeof(flag), "|DOC|%s", oName[client]);
	}
	else if (StrContains(class_template, "engineer") > -1)
	{
		// Admin Engineer
		if (GetUserFlagBits(client) & ADMFLAG_KICK)
			Format(flag, sizeof(flag), "|ADM|ENG|%s", oName[client]);
		// Donor Engineer
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
			Format(flag, sizeof(flag), "|DONOR|ENG|%s", oName[client]);
		// Admin Donor Engineer
		else if (GetUserFlagBits(client) & (ADMFLAG_KICK | ADMFLAG_CUSTOM2) == (ADMFLAG_KICK | ADMFLAG_CUSTOM2))
			Format(flag, sizeof(flag), "|ADM|DONOR|ENG|%s", oName[client]);
		// Normal Engineer
		else
			Format(flag, sizeof(flag), "|ENG|%s", oName[client]);
	}
	else
	{
		// Admin
		if (GetUserFlagBits(client) & ADMFLAG_KICK)
			Format(flag, sizeof(flag), "|ADM|%s", oName[client]);
		// Donor
		else if (GetUserFlagBits(client) & ADMFLAG_CUSTOM2)
			Format(flag, sizeof(flag), "|DONOR|%s", oName[client]);
		// Admin Donor
		else if (GetUserFlagBits(client) & (ADMFLAG_KICK | ADMFLAG_CUSTOM2) == (ADMFLAG_KICK | ADMFLAG_CUSTOM2))
			Format(flag, sizeof(flag), "|ADM|DONOR|%s", oName[client]);
		else
			Format(flag, sizeof(flag), "%s", oName[client]);
	}

	// Set player nickname
	decl String:sCurNickname[64];
	Format(sCurNickname, sizeof(sCurNickname), "%N", client);
	if (!StrEqual(sCurNickname, flag))
		SetClientName(client, flag);
}