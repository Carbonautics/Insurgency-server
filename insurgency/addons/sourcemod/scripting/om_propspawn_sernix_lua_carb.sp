/*
	OM PropSpawn V3.0
 *	Author: Owned|Myself
 *	Contact: Please post on the forums!
 *	 
 *	Sorry this took so long!
 */
//Potential prop Lists:
// models\fortifications\barbed_wire_04a.mdl  (barb wire with low center dip in collision mesh)
// models\fortifications\barbed_wire_04.mdl same as above, slight less dip.
// models\fortifications\barbed_wire_04.mdl even, slightly less noticeable edge bars.
// models\fortifications\barbed_wire_03a.mdl even, slightly less noticeable edge bars.
// models\props\crate01.mdl if small enough good to climb
// insurgency_models.vpk\models\static_fittings\overhang_03.mdl  ramp for walls?
// \insurgency_models.vpk\models\static_military\sandbag_wall_short_b.mdl snow short sandbag
// insurgency\insurgency_models.vpk\models\fortifications\sandbag_wall_short.mdl  // Same sandbag short
// models\structures\overhang_01.mdl // slight overhand model ramp
// models/iraq/ir_hesco_basket_01.mdl Hesco single like large 4
// \insurgency\insurgency_models.vpk\models\static_afghan\prop_fortification_hesco_large.mdl   Large hesco
// insurgency2\insurgency\insurgency_models.vpk\models\iraq\ir_hesco_basket_01_row.mdl  Large 4 Hesco (need to engineers 10 points each)
//Ammo crates
//models/static_fittings/antenna02b.mdl //Old jammer
//models/static_props/wcache_crate_01.mdl //Old Ammo cache
//models/sernix/ied_jammer/ied_jammer.mdl //New jammer
//models/sernix/ammo_cache/ammo_cache_small.mdl //New Cache
 //Ramp for engineer
//\models\static_afghan\prop_panj_stairs.mdl


//SDKHook(g_iPlayerTempProp[client], SDKHook_Touch, SHook_OnTouch);
//SDKHook(client, SDKHook_PreThink, OnPreThink);

// Include the neccesary files
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

//Make it neccesary to have semicolons at the end of each line
#pragma semicolon 1


//Define keys
#define		INS_ATTACK1				(1 << 0)
#define		INS_JUMP				(1 << 1)
#define		INS_DUCK				(1 << 2)
#define		INS_PRONE				(1 << 3)
#define		INS_FORWARD				(1 << 4)
#define		INS_BACKWARD			(1 << 5)
#define		INS_USE					(1 << 6)
#define		INS_LEFT				(1 << 9)
#define		INS_RIGHT				(1 << 10)
#define		INS_RELOAD				(1 << 11)
#define		INS_FIREMODE			(1 << 12)
#define		INS_LEAN_LEFT			(1 << 13)
#define		INS_LEAN_RIGHT			(1 << 14)
#define		INS_SPRINT				(1 << 15)
#define		INS_WALK				(1 << 16)
#define		INS_SPECIAL1			(1 << 17)
#define		INS_AIM					(1 << 18)
#define		INS_SCOREBOARD			(1 << 19)
#define		INS_FLASHLIGHT			(1 << 22)
#define		INS_AIM_TOGGLE			(1 << 27)
#define		INS_ACCESSORY			(1 << 28)

#define JammerView_Radius	1200.0

// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1_SEC		2
#define TEAM_2_INS		3

#define MAX_BUTTONS 25
new bool:plug_debug = false;

new bool:isStuck[MAXPLAYERS+1];
//Version
new String:sVersion[5] = "3.0.2";
//Prefix
new String:sPrefix[256] = "\x01\x03[\x04PropSpawn\x03]\x01";

//Player properties (credits)
new iDefCredits = 30; //Default
new iDefCreditsConst = 90; //Constant that never changes, Used to scaled iDefCredits
new iCredits[MAXPLAYERS+1];
new iPropNo[MAXPLAYERS+1];//Stores the number of props a player has
new Handle:hCredits = INVALID_HANDLE;
new Handle:g_param1;
new Handle:g_param2;
new g_iBeaconBeam;
new g_iBeaconHalo;
//Team Only
// Teams:
// 0 = No restrictions
// 1 = T
// 2 = CT
new iTeam = 2;
//ConVar Handle
new Handle:hTeamOnly = INVALID_HANDLE;
//Admin only
new bool:bAdminOnly = false;
new Handle:hAdminOnly = INVALID_HANDLE;
//Remove props on death
new Handle:hRemoveProps = INVALID_HANDLE;
new bool:bRemoveProps = true;
//Add Credits on death
new Handle:hCreditsOnDeath = INVALID_HANDLE;
new bool:bCreditsOnDeath = false;
new iDeathCreditNo = 5;
new Handle:hDeathCreditNo = INVALID_HANDLE;
new Handle:hIntegDegrade = INVALID_HANDLE;
new Handle:hDegradeMultiplier = INVALID_HANDLE;
new Handle:hIntegRepair = INVALID_HANDLE;
new Handle:ConstructTimers[MAXPLAYERS+1];
new	g_integrityRepair = 2;
new g_CvarYellChance;

// Status
new
	String:g_client_last_classstring[MAXPLAYERS+1][64],
	Float:g_engineerPos[MAXPLAYERS+1][3],
	g_ConstructDeployTime = 1,
	g_engineerParam[MAXPLAYERS+1],
	g_ConstructRemainingTime[MAXPLAYERS+1],
	g_engInMenu[MAXPLAYERS+1],
	g_propIntegrity[MAXPLAYERS+1],
	bool:g_isSolid[MAXPLAYERS+1],
	g_ConstructPackTime = 1,
	Float:g_integrityDegrade = 40.0,
	Float:g_fPlayerLastChat[MAXPLAYERS+1] = {0.0, ...},
	g_LastButtons[MAXPLAYERS+1];

// whether or not the player has an active cooldown, end time for cooldown
new bool:PlayerCooldown[MAXPLAYERS + 1] = {true, ...};
new Float:PlayerTimedone[MAXPLAYERS + 1];

// length of time to wait before yelling can occur again (in seconds)
new Handle:hCvarYellChance;
new Handle:CooldownPeriod;
// Prop Command String
new String:sPropCommand[256] = "props";

//The Menu
new Handle:om_public_prop_menu = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "OM Prop Spawn",
	author = "Owned|Myself",
	description = "A plugin which allows you to spawn physics props predefined in a text file: Public Version with Credits",
	version = sVersion,
	url = "http://forums.alliedmods.net/showthread.php?t=119238"
};

// list of specific files that are decent
new String:BuildSounds[][] = {
	"player/voice/security/command/subordinate/cover1.ogg",
	"player/voice/security/command/subordinate/cover2.ogg",
	"player/voice/security/command/subordinate/cover3.ogg"

};


public OnPluginStart()
{
	// Control ConVars. 1 Team Only, Public Enabled etc.
	hTeamOnly = CreateConVar("om_prop_teamonly", "0", "0 is no team restrictions, 1 is Terrorist and 2 is CT. Default: 2");
	hAdminOnly = CreateConVar("om_prop_public", "0", "0 means anyone can use this plugin. 1 means admins only (no credits used)");
	hIntegDegrade = CreateConVar("om_integrity_degrade", "40", "This is the amount that degrades from the prop when enemy bots are near it per bot, per 3 second");
	hIntegRepair = CreateConVar("om_integrity_repair", "2", "When a engineer is repairing, this amount repairs per 3 second.");

	// Create the version convar!
	CreateConVar("om_propspawn_version", sVersion, "OM Prop Spawn Version",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	// Register the Credits Command
	//RegConsoleCmd("credits", Command_Credits);
	// Hook Player Spawn to restore player credits when they spawn
	HookEvent("player_spawn" , Event_PlayerSpawn);
	// Hook when the player dies so that props can be removed
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_pick_squad", Event_PlayerPickSquad);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);

	new String:tempCredits[5];
	IntToString(iDefCredits, tempCredits, sizeof(tempCredits));
	// Convar to control the credits players get when they spawn (default above)
	hCredits = CreateConVar("om_prop_credits", "tempCredits", "The number of credits each player should have when they spawn");
	
	/* NEW STUFF */
	hRemoveProps = CreateConVar("om_prop_removeondeath", "0", "0 is keep the props on death, 1 is remove them on death. Default: 1");
	hCreditsOnDeath = CreateConVar("om_prop_addcreditsonkill", "0", "0 is off, 1 is on. Default: 0");
	hDeathCreditNo = CreateConVar("om_prop_killcredits", "0", "Change this number to change the number of credits a player gets when they kill someone");
	hCvarYellChance = CreateConVar("fy_chance", "1.0", "Chance of Yelling [0-1]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
	CooldownPeriod = CreateConVar("fy_cooldown", "3.0", "Cooldown period between yells [>0.0]", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, false);
	
	//Hook all the ConVar changes
	HookConVarChange(hTeamOnly, OnConVarChanged);
	HookConVarChange(hAdminOnly, OnConVarChanged);
	HookConVarChange(hCredits, OnConVarChanged);
	HookConVarChange(hRemoveProps, OnConVarChanged);
	HookConVarChange(hCreditsOnDeath, OnConVarChanged);
	HookConVarChange(hDeathCreditNo, OnConVarChanged);
	HookConVarChange(hIntegDegrade, OnConVarChanged);
	HookConVarChange(hIntegRepair, OnConVarChanged);
	HookConVarChange(hCvarYellChance, OnConVarChanged);
	
	// Register the admin command to add credits (or remove if a minus number is used)
	RegAdminCmd("om_admin_credits", AdminCreditControl, ADMFLAG_SLAY, "Admin Credit Control Command for OM PropSpawn");
	RegAdminCmd("om_remove_prop", AdminRemovePropAim, ADMFLAG_SLAY, "Admin Prop Removal by aim");
	//RegConsoleCmd(sPropCommand, PropCommand);

	AutoExecConfig(true, "sernix_prop_spawn");
}

// On map starts, call initalizing function
public OnMapStart()
{	
	
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/halo01.vmt");
	PrecacheSound("player/voice/security/command/subordinate/cover1.ogg");
	PrecacheSound("player/voice/security/command/subordinate/cover2.ogg");
	PrecacheSound("player/voice/security/command/subordinate/cover3.ogg");
	PrecacheSound("ui/sfx/noise_11.wav");
	PrecacheSound("soundscape/emitters/loop/military_radio_01.wav");

	CreateTimer(5.0, Timer_MapStart);
	CreateTimer(16.0, Timer_MonitorAntennas,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

}
public Action:Timer_MapStart(Handle:Timer)
{
	//CreateTimer(2.0, Timer_Monitor_Props,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}


public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == hTeamOnly)
		iTeam = GetConVarInt(convar);
	if(convar == hAdminOnly)
		bAdminOnly = GetConVarBool(convar);
	if(convar == hCredits)
		iDefCredits = GetConVarInt(convar);
	if(convar == hRemoveProps)
		bRemoveProps = GetConVarBool(convar);
	if(convar == hCreditsOnDeath)
		bCreditsOnDeath = GetConVarBool(convar);
	if(convar == hDeathCreditNo)
		iDeathCreditNo = GetConVarInt(convar);
	if(convar == hIntegRepair)
		g_integrityRepair = GetConVarInt(convar);
	if(convar == hIntegDegrade)
		g_integrityDegrade = GetConVarInt(convar);
	if(convar == hCvarYellChance)
		g_CvarYellChance = GetConVarFloat(convar);
}

public Action:Command_Credits(client, args)
{
	new tempCredits = iCredits[client];
	PrintToChat(client, "You currently have %d credits!", tempCredits);
}

public OnClientPutInServer(client) {
	iCredits[client] = iDefCredits;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
}

public ScaleBuildPoints() {
	
	new tEngCount = 0;

	ConVar cvar_tokenBase = FindConVar("mp_supply_token_base");
	new nSupplyTokenBase = GetConVarInt(cvar_tokenBase);
	int nAvailableSupplyPoint = nSupplyTokenBase;
	int nReceivedSupplyPoint = 0;

	
	//Calculate engineer points
	for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
	{
		if (engineerCheck > 0)
		{
			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{
				tEngCount++;
				nReceivedSupplyPoint = GetEntProp(engineerCheck, Prop_Send, "m_nRecievedTokens");
			}
		}
	}
	nAvailableSupplyPoint += nReceivedSupplyPoint;
	
	if (nAvailableSupplyPoint <= 22)
		nAvailableSupplyPoint = 22;
	//Credits 
	if (tEngCount > 0)
		iDefCredits = ((nAvailableSupplyPoint * 3) / tEngCount);
	else
		iDefCredits = (nAvailableSupplyPoint * 3);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{

	//Clear props
	for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
	{
		if (engineerCheck > 0)
		{
			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{
				KillProps(engineerCheck);
			}
		}
	}
}
// When ammo cache destroyed, clear props refund credits
public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{

	ScaleBuildPoints();
	//Clear props
	for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
	{
		if (engineerCheck > 0)
		{
			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{
				iCredits[engineerCheck] = iDefCredits;
				//KillProps(engineerCheck);
			}
		}
	}
	
	return Plugin_Continue;
}
// When control point captured, reset variables
public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	ScaleBuildPoints();
	//Clear props
	for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
	{
		if (engineerCheck > 0)
		{
			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{
				iCredits[engineerCheck] = iDefCredits;
				//KillProps(engineerCheck);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_BroadcastJammer(Handle:timer, Handle:hDatapack)
{
	ResetPack(hDatapack);
	new validAntenna = ReadPackCell(hDatapack);
	//Give jammer effects
	new Float:propOrigin[3];
	GetEntPropVector(validAntenna, Prop_Send, "m_vecOrigin", propOrigin);
	propOrigin[2] += 50.0; 
	TE_SetupBeamRingPoint(propOrigin, 1.0, JammerView_Radius, g_iBeaconBeam, g_iBeaconHalo, 0, 30, 6.0, 0.8, 0.0, {102, 204, 255, 255}, 1, (FBEAM_FADEIN, FBEAM_FADEOUT));
	TE_SendToAll();
	EmitSoundToAll("ui/sfx/noise_11.wav", validAntenna, SNDCHAN_VOICE, _, _, 1.0);
	// switch(GetRandomInt(1, 2))
	// {
	// 	case 1: EmitSoundToAll("ui/sfx/noise_11.wav", prop, SNDCHAN_VOICE, _, _, 1.0);
	// 	case 2: EmitSoundToAll("soundscape/emitters/loop/military_radio_01.wav", prop, SNDCHAN_VOICE, _, _, 1.0);
	// }
}
public Action:Timer_MonitorAntennas(Handle:Timer)
{
	new validAntenna;
	//validAntenna = FindValidAntenna();
	while ((validAntenna = FindEntityByClassname(validAntenna, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
	{
		decl String:propModelName[128];
		GetEntPropString(validAntenna, Prop_Data, "m_ModelName", propModelName, 128);
		if (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
		{
			new Handle:hDatapack;
			new fRandomBroadcast = GetRandomFloat(1.0, 8.0);
			CreateDataTimer(fRandomBroadcast, Timer_BroadcastJammer, hDatapack);
			WritePackCell(hDatapack, validAntenna);
		}

	}
}

//Find Valid Prop
public FindValidAntenna()
{
	new prop = -1;
	while ((prop = FindEntityByClassname(prop, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
	{
		decl String:propModelName[128];
		GetEntPropString(prop, Prop_Data, "m_ModelName", propModelName, 128);
		if (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
		{
			return prop;
		}

	}
	return -1;
}

public GetPropType(entity)
{
	new propType = -1; //1 == Sandbag, 2 == Barbwire, 3 == other
	decl String:propModelName[128];
	GetEntPropString(entity, Prop_Data, "m_ModelName", propModelName, 128);
	//PrintToServer("MODEL NAME: %s", propModelName);
	if (StrEqual(propModelName, "models/fortifications/barbed_wire_02b.mdl"))
	{
		propType = 2;
	}
	else if (StrEqual(propModelName, "models/static_fortifications/sandbagwall01.mdl") || StrEqual(propModelName, "models/static_fortifications/sandbagwall02.mdl"))
	{
		propType = 1;
	}
	else if (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
	{
		propType = 3;
	}
	else if (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl"))
	{
		propType = 4;
	}
	else if (StrEqual(propModelName, "models/static_afghan/prop_panj_stairs.mdl")) //Ramp
	{
		propType = 5;
	}
	return propType;

}

public Action:Timer_Monitor_Props(Handle:Timer)
{
	//PrintToServer("DEBUG 1");
	for (new client = 1; client <= MaxClients; client++)
	{
		//ENgineer specific
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && (StrContains(g_client_last_classstring[client], "engineer") > -1))
		{
			//PrintToServer("DEBUG 2");
			for(new i=0; i<=iPropNo[client]; i++)
			{
				decl String:EntName[MAX_NAME_LENGTH+5];
				Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, i);
				new prop = Entity_FindByName(EntName);
				if(prop != -1)
				{	
					//Check bots near engineer props and reduce integrity
					new isNearby = Check_NearbyBots(prop);
					new propType = GetPropType(prop);
					if (isNearby == true)
					{
						//PrintToServer("g_integrityDegrade %d", g_integrityDegrade);
						if (propType == 2) //Degrade 4x as slow for barbwire
						{
							g_propIntegrity[i] = g_propIntegrity[i] - (g_integrityDegrade / 6);
							//Hurt_NearbyBots(prop, client);
						}
						else if (propType !=  2) //Degrade normal for defense fortifications
						{
							g_propIntegrity[i] = g_propIntegrity[i] - g_integrityDegrade;
						}
						
						if (g_propIntegrity[i] <= 0)
						{

							if(prop != -1)
								AcceptEntityInput(prop, "kill");

							//Refund for prop
							new propParam = g_engineerParam[iPropNo[i]];
							decl String:prop_choice[255];
							GetMenuItem(om_public_prop_menu, propParam, prop_choice, sizeof(prop_choice));
							decl String:name[255];
							GetClientName(client, name, sizeof(name));

							decl String:modelname[255];
							new Price;
							decl String:file[255];
							BuildPath(Path_SM, file, 255, "configs/om_public_props.txt");
							new Handle:kv = CreateKeyValues("Props");
							FileToKeyValues(kv, file);
							KvJumpToKey(kv, prop_choice);
							KvGetString(kv, "model", modelname, sizeof(modelname),"");
							Price = KvGetNum(kv, "price", 0);
							new ClientCredits = iCredits[client];
							decl String:textToPrintChat[64];

							if (Price > 0)
							{

									//ClientCredits = ClientCredits + Price;
									//iCredits[client] = ClientCredits;
									//PrintToChat(client, "Your \x04%s has been destroyed. Refunded \x03%d credits!", prop_choice, Price);
									PrintToChat(client, "Your \x04%s has been destroyed. Points refund on capture", prop_choice);
							}

							g_propIntegrity[i] = 0;
							i = -1;
						}
					}
				}
			}
		}
		//All units
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client))
		{

			//PrintToServer("DEBUG 5");

			for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
			{

				if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
				{

					//PrintToServer("DEBUG 6");
					for(new i=0; i<=iPropNo[engineerCheck]; i++)
					{
						decl String:EntName[MAX_NAME_LENGTH+5];
						Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", engineerCheck, i);
						new prop = Entity_FindByName(EntName);
						//Need another engineer to test
						if(prop != -1)
						{	
							
							//PrintToServer("DEBUG 7");
							//Get position of bot and prop
							new Float:plyrOrigin[3];
							new Float:propOrigin[3];
							new Float:fDistance;
					
							GetClientAbsOrigin(client,plyrOrigin);
							GetEntPropVector(prop, Prop_Send, "m_vecOrigin", propOrigin);
							
							//determine distance from the two
							fDistance = GetVectorDistance(propOrigin,plyrOrigin);

							// Target is prop
							new tPropTarget = GetClientAimTarget(client, false);
							if (tPropTarget != -1)
							{
								new iPropRef = EntIndexToEntRef(tPropTarget);
								new mPropRef = EntIndexToEntRef(prop);

								new propIntegrity = GetEntProp(mPropRef, Prop_Data, "m_iHealth");//g_propIntegrity[i];
								//PrintToChatAll("EngineerProp: %S, TargetProp: %S", mPropRef, iPropRef);
								if (iPropRef == mPropRef && fDistance <= 400 && !(StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
								{

									decl String:sBuf[255];
									Format(sBuf, 255,"Deployable Owner: [%N] | Integrity: %d", client, propIntegrity);
									PrintHintText(client, "%s", sBuf);	
										//PrintToServer("DEBUG 9");					
								}

								new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
								if (ActiveWeapon < 0)
									continue;
								// Get weapon class name
								decl String:sWeapon[32];
								GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

								if (iPropRef == mPropRef && fDistance <= 120 && (StrContains(g_client_last_classstring[client], "engineer") > -1))
								{
									if ((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_wrench") > -1))
									{
										//PrintToServer("g_integrityRepair: %d | propIntegrity %d", g_integrityRepair, propIntegrity);
										propIntegrity = propIntegrity + g_integrityRepair;
										g_propIntegrity[i] = propIntegrity;

										SetEntProp(mPropRef, Prop_Data, "m_iHealth", propIntegrity);
										//PrintToServer("g_propIntegrity[iPropNo[i]]_Repair: %d", g_propIntegrity[i]);
									}

									new propType = GetPropType(prop);
									if (propType == 3) //Max health 500 for antenna / ramp
									{
										if (propIntegrity > 3750)
										{
											propIntegrity = 3750;
											g_propIntegrity[i] = 3750;
										}
									}
									else if (propType == 4) //Max health 250 for ammoboxes
									{
										if (propIntegrity > 1875)
										{
											propIntegrity = 1875;
											g_propIntegrity[i] = 1875;
										}
									}
									else if (propType == 5) //ramp
									{
										if (propIntegrity > 7500)
										{
											propIntegrity = 7500;
											g_propIntegrity[i] = 7500;
										}
									}
									else
									{
										if (propIntegrity > 12000)
										{
											propIntegrity = 12000;
											g_propIntegrity[i] = 12000;
										}
									}
									decl String:sBuf[255];
									Format(sBuf, 255,"Deployable Owner[%N] | Integrity: %d", engineerCheck, propIntegrity);
									PrintHintText(client, "%s", sBuf);	
										//PrintToServer("DEBUG 9");					
								}
							}
						}
					}
				}
			}
		}

	}

}

// Trace client's view entity
stock TraceClientViewEntity(client)
{
	new Float:m_vecOrigin[3];
	new Float:m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	new Handle:tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
	new pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		CloseHandle(tr);
		return pEntity;
	}

	if(tr != INVALID_HANDLE)
	{
		CloseHandle(tr);
	}
	
	return -1;
}
// Check is hit self
public bool:TRDontHitSelf(entity, mask, any:data) // Don't ray trace ourselves -_-"
{
	return (1 <= entity <= MaxClients) && (entity != data);
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//									Stuck Detection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
stock bool:IsStuckInEnt(client, ent){
    decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
    
    GetClientMins(client, vecMin);
    GetClientMaxs(client, vecMax);
    
    GetClientAbsOrigin(client, vecOrigin);
    
    TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
    return TR_DidHit();
}

bool:CheckStuckInEntity(entity) 
{ 
    for (new i=0;i<=MaxClients;i++) 
    { 
    	if (i > 0)
    	{
	        if (IsClientInGame(i) && IsPlayerAlive(i) && IsStuckInEnt(i, entity))// && !IsFakeClient(i) 
	            return true; 
    	}
    } 
    return false; 
} 
public bool:TraceRayHitOnlyEnt(entityhit, mask, any:data) {
    return entityhit==data;
}
stock bool:CheckIfPlayerIsStuck(iClient)
{
	decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
	
	GetClientMins(iClient, vecMin);
	GetClientMaxs(iClient, vecMax);
	GetClientAbsOrigin(iClient, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();	// head in wall ?
}

public bool:TraceEntityFilterSolid(entity, contentsMask) 
{
	return entity > 1;
}

public Check_NearbyBots(builtProp)
{
	for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
	{
		if (IsClientConnected(enemyBot) && IsClientInGame(enemyBot)) 
		{
			new team = GetClientTeam(enemyBot); 
			if (IsFakeClient(enemyBot) && IsPlayerAlive(enemyBot))// && team == TEAM_2_INS)
			{
				//Get position of bot and prop
				new Float:botOrigin[3];
				new Float:propOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(enemyBot,botOrigin);
				GetEntPropVector(builtProp, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(propOrigin,botOrigin);
				
				new propType = GetPropType(builtProp);
				if (propType == 3 || propType == 4) // lower degrade range if antenna or ammobox
				{
					//return false; //debug disable after
					if (fDistance <= 70)
					{
						return true;
					}
				}
				else
				{
					if (fDistance <= 260)
					{
						return true;
					}

				}
			}
		}
	}
	return false;
}
public Hurt_NearbyBots(builtProp, client)
{
	for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
	{
		if (IsClientConnected(enemyBot) && IsClientInGame(enemyBot)) 
		{
			new team = GetClientTeam(enemyBot); 
			if (IsFakeClient(enemyBot) && IsPlayerAlive(enemyBot))// && team == TEAM_2_INS)
			{
				//Get position of bot and prop
				new Float:botOrigin[3];
				new Float:propOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(enemyBot,botOrigin);
				GetEntPropVector(builtProp, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(propOrigin,botOrigin);
				
				if (fDistance <= 300)
				{
					
					new fRandomDamage = GetRandomInt(10, 25);
					//Hurt bot
					DealDamage(enemyBot,fRandomDamage,client,DMG_GENERIC,"");
					//PrintToServer("Deal damage to: %N for %d", enemyBot, fRandomDamage);
					// new iHealth = GetClientHealth(client);
					// iHealth = iHealth - fRandomDamage;
					// SetEntityHealth(client, iHealth);
				}
			}
		}
	}
	return false;
}
DealDamage(victim,damage,attacker=0,dmg_type=DMG_GENERIC,String:weapon[]="")
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0)
	{
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}
public Check_NearbyPlayers(builtProp)
{
	for (new friendlyPlayer = 1; friendlyPlayer <= MaxClients; friendlyPlayer++)
	{
		if (IsClientConnected(friendlyPlayer) && IsClientInGame(friendlyPlayer))
		{
			new team = GetClientTeam(friendlyPlayer);
			if (!IsFakeClient(friendlyPlayer) && IsPlayerAlive(friendlyPlayer) && team == TEAM_1_SEC)
			{
				//Get position of bot and prop
				new Float:plyrOrigin[3];
				new Float:propOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(friendlyPlayer,plyrOrigin);
				GetEntPropVector(builtProp, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(propOrigin,plyrOrigin);
				
				if (fDistance <= 210)
				{
					return true;
				}
			}
		}
	}
	return false;
}

public Event_PlayerSpawn(Handle: event , const String: name[] , bool: dontBroadcast)
{

	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	//iCredits[client] = iDefCredits;
	if ((StrContains(g_client_last_classstring[client], "engineer") > -1))
	{
		g_engInMenu[client] = false;
		g_ConstructRemainingTime[client] = g_ConstructDeployTime;
	}
}

public Event_PlayerDeath(Handle: event , const String: name[] , bool: dontBroadcast)
{
	new victimuserid = GetEventInt(event, "userid");
	new victim = GetClientOfUserId(victimuserid);
	new attackeruserid = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(attackeruserid);
	
	if(!Client_IsValid(attacker))
	{
		return;
	}
	if ((StrContains(g_client_last_classstring[victim], "engineer") > -1))
	{
		g_engInMenu[victim] = false;
		g_ConstructRemainingTime[victim] = g_ConstructDeployTime;
	}
	// if(bCreditsOnDeath)
	// {
	// 	PrintToChat(attacker, "You have been given \x03%d\x01 credits for killing someone!", iDeathCreditNo);
	// 	iCredits[attacker] += iDeathCreditNo;
	// }
	
	// if(bRemoveProps)
	// {
	// 	KillProps(victim);
	// }
}
// When player picked squad, initialize variables
public Action:Event_PlayerPickSquad( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//PrintToServer("##########PLAYER IS PICKING SQUAD!############");
	
	// Get client ID
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// Init variable
	if (client > 0 && !IsFakeClient(client))
	{	
		// Get class name
		new String:class_template[64];
		GetEventString(event, "class_template", class_template, sizeof(class_template));
		
		// Set class string
		g_client_last_classstring[client] = class_template;
		KillProps(client);
	}

	//ScaleBuildPoints();
	//iCredits[client] = iDefCredits;
}
public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	KillProps(client);
	g_LastButtons[client] = 0;
	RemoveCooldown(client);
	g_engInMenu[client] = false;
	g_ConstructRemainingTime[client] = g_ConstructDeployTime;
	
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

	ScaleBuildPoints();
	for(new i=0; i<=MaxClients; i++)
	{
		iPropNo[i] = 0;
		iCredits[i] = iDefCredits;
	}

	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
}
public Action:YellOut(client) {

	switch(GetRandomInt(1, 3))
	{
		case 1: EmitSoundToAll("player/voice/security/command/subordinate/cover1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 2: EmitSoundToAll("player/voice/security/command/subordinate/cover2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 3: EmitSoundToAll("player/voice/security/command/subordinate/cover3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
	return Plugin_Continue;
}

public Action:SetCooldown(client) {
	// remove the existing timedone
	RemoveCooldown(client);

	// set timedone for client
	new Float:timedone = GetGameTime() + GetConVarFloat(CooldownPeriod);
	PlayerTimedone[client] = timedone;
	PlayerCooldown[client] = true;

}

public Action:RemoveCooldown(client) {
	PlayerCooldown[client] = false;
	PlayerTimedone[client] = 0.0;

}
stock KillProps(client)
{
	for(new i=0; i<=MaxClients; i++)
	{
		g_propIntegrity[i] = 0;
		new String:EntName[MAX_NAME_LENGTH+5];
		Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, i);
		new prop = Entity_FindByName(EntName);
		if(prop != -1)
			AcceptEntityInput(prop, "kill");
		iPropNo[i] = 0;
	}
	iPropNo[client] = 0;
	return Plugin_Handled;
}
stock KillPropSingle(client)
{
	new iAimTarget = GetClientAimTarget(client, false);
	if (iAimTarget < MaxClients && FindDataMapInfo(iAimTarget, "m_ModelName") == -1)
		return Plugin_Handled;

	new String:targetname[64];
	GetEntPropString(iAimTarget, Prop_Data, "m_iName", targetname, sizeof(targetname));
	if(plug_debug)
	{
		PrintToChatAll("targetname %s | iAimTarget %d", targetname, iAimTarget);
	}

	new targetNum = StringToInt(targetname);
	
	if((StrEqual(targetname, "OMPropSpawnProp", true) != 0) || targetNum == iAimTarget)
	{
		new Float:vOrigin[3], Float:vTargetOrigin[3];
		GetEntPropVector(iAimTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
		GetClientAbsOrigin(client, vTargetOrigin);
		if (GetVectorDistance(vOrigin, vTargetOrigin) <= 100.0)
		{
			if((StrEqual(targetname, "OMPropSpawnProp", true) != 0) || targetNum == iAimTarget)
			{

				AcceptEntityInput(iAimTarget, "kill");

				iPropNo[client] = iPropNo[client] - 1;
				PrintHintText(client, "Deployable deconstructed");
				return Plugin_Handled;
			}
		}
		else
			PrintHintText(client, "Too far to deconstruct");
		
	}
	else
	{
		PrintHintText(client, "You're not aiming at a valid prop!");
	}
	return Plugin_Handled;

}

public Action:AdminRemovePropAim(client, args)
{
	new prop = GetClientAimTarget(client, false);
	new String:EntName[256];
	Entity_GetName(prop, EntName, sizeof(EntName));
	if(plug_debug)
	{
		//PrintToChatAll(EntName);
	}
	
	new validProp = StrContains(EntName, "OMPropSpawnProp");
	
	if(validProp > -1)
	{
		//Remove the prop
		/* Find the client index in the string */
		new String:tempInd[3];
		tempInd[0] = EntName[15];
		tempInd[1] = EntName[16];
		tempInd[2] = EntName[17];
		
		if(plug_debug)
		{
			PrintToChat(client, tempInd);
		}
		
		/* We should now have the numbers somewhere, let's find out where */
		ReplaceString(tempInd, sizeof(tempInd), "_", "");
		if(plug_debug)
		{
			PrintToChat(client, tempInd);
		}
		new clientIndex = StringToInt(tempInd);
		AcceptEntityInput(prop, "kill");
		iPropNo[clientIndex] = iPropNo[clientIndex] - 1;
	}
	else
	{
		PrintToChat(client, "You can't delete this prop! It wasn't created by the plugin!");
	}
	
	return Plugin_Handled;
}

public Action:AdminCreditControl(client, args)
{
	if (args < 1)
	{
		PrintToConsole(client, "Usage: om_admin_credits <name> <credits>");
		return Plugin_Handled;
	}
 
	new String:targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));
	
	new String:SteamID[256];
	GetClientAuthId(client, AuthId_SteamID64, SteamID, sizeof(SteamID));
	
	new target = Client_FindByName(targetName);
	
	if (target == -1)
	{
		PrintToConsole(client, "Could not find any player with the name: \"%s\"", targetName);
		return Plugin_Handled;
	}

	new String:NewCredits[32];
	GetCmdArg(2, NewCredits, sizeof(NewCredits));
	new ModCredits = StringToInt(NewCredits);
	iCredits[target] += ModCredits;
	PrintToChat(target, "You now have %d credits!", iCredits[target]);
	LogAction(client, -1, "\"%s\" added %d credits to \"%s\"", SteamID, ModCredits, targetName);
	
	return Plugin_Handled;

}

public Action:PropCommand(client, args)
{
	if(!Client_IsValid(client))
		return Plugin_Handled;
		
	// if(iTeam > 0)
	// {
	// 	if(GetClientTeam(client) != iTeam+1)
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	// if(bAdminOnly)
	// {
	// 	if(!Client_IsAdmin(client))
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	
	// if(!IsPlayerAlive(client))
	// {
	// 	if(!Client_IsAdmin(client))
	// 	{
	// 		PrintToChat(client, "%s Sorry you can't use this command while dead!", sPrefix);
	// 		return Plugin_Handled;
	// 	}
	// }
	
	decl String:textPath[255];
	BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
	new Handle:kv = CreateKeyValues("Props");
	FileToKeyValues(kv, textPath);
	om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
	SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
	PopLoop(kv, client);
	DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Make sure you populate the menu, Runs through the keyvalues.
PopLoop(Handle:kv, client)
{

	AddMenuItem(om_public_prop_menu, "deconstruct_prop", "Deconstruct Prop (no refund)");
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			decl String:buffer[256];
			KvGetSectionName(kv, buffer, sizeof(buffer));
			new admin = KvGetNum(kv, "adminonly", 0);	//New, Allows for admin only props
			if(admin == 1)
			{
				if(Client_IsAdmin(client))
				{
					decl String:price[256];
					KvGetString(kv, "price", price, sizeof(price), "0");
					decl String:MenuItem[256];
					Format(MenuItem, sizeof(MenuItem), "%s - Cost: %s", buffer, price);
					AddMenuItem(om_public_prop_menu, buffer, MenuItem);
				}
			}
			else
			{
				decl String:price[256];
				KvGetString(kv, "price", price, sizeof(price), "0");
				decl String:MenuItem[256];
				Format(MenuItem, sizeof(MenuItem), "%s - Cost: %s", buffer, price);
				AddMenuItem(om_public_prop_menu, buffer, MenuItem);
			}
		}
		while (KvGotoNextKey(kv));
		CloseHandle(kv);
	}
	//AddMenuItem(om_public_prop_menu, "fastexit", "Fast-Exit Menu");
	AddMenuItem(om_public_prop_menu, "deconstruct", "Deconstruct All (no refund)");
}

public Action:Timer_Construct(Handle timer, Handle pack)
{
	int client;
	new target;
 	
	/* Set to the beginning and unpack it */
	ResetPack(pack);
	client = ReadPackCell(pack);
	target = ReadPackCell(pack);

	// Get current position
	decl Float:vecPos[3];
	GetClientAbsOrigin(client, vecPos);
	new Float:vectDist;
	new Float:EngCurrentPos[3];
	EngCurrentPos = vecPos;
	vectDist = GetVectorDistance(EngCurrentPos, g_engineerPos[client]);
	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (ActiveWeapon < 0)
		return Plugin_Stop;
	// Get weapon class name
	decl String:sWeapon[32];
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

	if (client > 0 && vectDist < 0 || vectDist > 0 || !IsPlayerAlive(client) || IsClientTimingOut(client) || (!(StrContains(sWeapon, "weapon_knife") > -1) && !(StrContains(sWeapon, "weapon_wrench") > -1)))
	{
		decl String:textPrintChat[64];
		Format(textPrintChat, sizeof(textPrintChat), "(Deploy Canceled) - You moved and or put knife away");
		PrintHintText(client, textPrintChat);
		PrintToChat(client, textPrintChat);
		g_engInMenu[client] = false;
		return Plugin_Stop;
	}
	if (client > 0 && g_ConstructRemainingTime[client] <= 0 && IsPlayerAlive(client) && !IsClientTimingOut(client) && ((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_wrench") > -1)))
	{
		g_ConstructRemainingTime[client] = g_ConstructDeployTime;
		PropSpawn(client, target);
		decl String:textPath[255];
		BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, textPath);
		om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
		SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
		PopLoop(kv, client);
		DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
		new Float:CurrentTime = GetGameTime();
		if (PlayerCooldown[client]) {
			if (CurrentTime < PlayerTimedone[client]) {
				//return Plugin_Continue;
			} else {
				RemoveCooldown(client);
			}
		}
		else
		{
			// play sound at the player if RNG passes
			//new Float:rn = GetRandomFloat(0.0, 1.0);
			//if (rn <= g_CvarYellChance) {
				YellOut(client);
				SetCooldown(client);
			//}
		}
		return Plugin_Stop;
	}
	g_ConstructRemainingTime[client]--;
	decl String:textToPrint[64];
	decl String:prop_choice[255];
	
	GetMenuItem(om_public_prop_menu, target, prop_choice, sizeof(prop_choice));
	Format(textToPrint, sizeof(textToPrint), "Deploying %s in %d seconds\n(Move to cancel deploy)", prop_choice, g_ConstructRemainingTime[client]);
	PrintHintText(client, textToPrint);
	//g_engInMenu[client] = false;
	return Plugin_Continue;
}

public Public_Prop_Menu_Handler(Handle:menu, MenuAction:action, client, param2)
{
	// Note to self: param1 is client, param2 is choice.
	if (action == MenuAction_Select)
	{

		if (StrContains(g_client_last_classstring[client], "engineer") == -1)
		{
			PrintHintText(client, "Only engineers can build");
			return Plugin_Stop;
		}
		//char info[32];
 
		/* Get item info */
		//menu.GetItem(param2, info, sizeof(info))
		if (param2 == 0)
		{	
			new iAimTarget = GetClientAimTarget(client, false);
			if (iAimTarget != -1 && iAimTarget > MaxClients && FindDataMapInfo(iAimTarget, "m_ModelName") != -1)
			{

				KillPropSingle(client);
			
				g_ConstructRemainingTime[client] = g_ConstructDeployTime;

				g_engInMenu[client] = false;
				// decl String:textPath[255];
				// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
				// new Handle:kv = CreateKeyValues("Props");
				// FileToKeyValues(kv, textPath);
				// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
				// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
				// PopLoop(kv, client);
				DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
			}
			else
			{
				g_ConstructRemainingTime[client] = g_ConstructDeployTime;

				g_engInMenu[client] = false;
				// decl String:textPath[255];
				// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
				// new Handle:kv = CreateKeyValues("Props");
				// FileToKeyValues(kv, textPath);
				// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
				// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
				// PopLoop(kv, client);
				DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
				PrintHintText(client, "Invalid deployable, target only items deployed by you.");
				PrintToChat(client, "Invalid deployable, target only items deployed by you.");
			}

			return Plugin_Continue;
		}
		if (param2 == 7)
		{
			KillProps(client);
			PrintHintText(client, "Deployables Deconstructed");
			PrintToChat(client, "Deployables Deconstructed");
			 g_ConstructRemainingTime[client] = g_ConstructDeployTime;

			g_engInMenu[client] = false;
			// decl String:textPath[255];
			// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
			// new Handle:kv = CreateKeyValues("Props");
			// FileToKeyValues(kv, textPath);
			// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
			// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
			// PopLoop(kv, client);
			 DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
			return Plugin_Handled;
		}
		// if (param2 == 6)
		// {
		// 	g_engInMenu[client] = false;
		// 	return Plugin_Stop;
		// }
		
		decl String:prop_choice[255];
	
		GetMenuItem(om_public_prop_menu, param2, prop_choice, sizeof(prop_choice));

		decl String:modelname[255];
		new Price;
		decl String:file[255];
		BuildPath(Path_SM, file, 255, "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, file);
		KvJumpToKey(kv, prop_choice);
		KvGetString(kv, "model", modelname, sizeof(modelname),"");
		Price = KvGetNum(kv, "price", 0);
		new ClientCredits = iCredits[client];
		decl String:textToPrintChat[64];

		if (Price > 0)
		{
			if (ClientCredits >= Price)
			{
				//Check for sound cooldown
				new Float:CurrentTime = GetGameTime();
				if (PlayerCooldown[client]) {
					if (CurrentTime < PlayerTimedone[client]) {
						//return Plugin_Continue;
					} else {
						RemoveCooldown(client);
					}
				}
				else
				{
					// play sound at the player if RNG passes
					//new Float:rn = GetRandomFloat(0.0, 1.0);
					//if (rn <= g_CvarYellChance) {
						YellOut(client);
						SetCooldown(client);
					//}
				}
				// Get current position
				decl Float:vecPos[3];
				GetClientAbsOrigin(client, vecPos);
				g_engineerPos[client] = vecPos;
				g_ConstructRemainingTime[client] = g_ConstructDeployTime;
				// Initiate the Prop Spawning using Client and Choice as the parameters.
				DataPack pack;
				ConstructTimers[client] = CreateDataTimer(1.0, Timer_Construct, pack, TIMER_REPEAT);
				pack.WriteCell(client);
				pack.WriteCell(param2);
				//CreateTimer(1.0, Timer_Construct, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				PrintToChat(client, "You do not have enough credits to deploy that!"); 
				PrintHintText(client, "You do not have enough credits to deploy that!");
				// new String:textPath[255];
				// BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
				// new Handle:kv = CreateKeyValues("Props");
				// FileToKeyValues(kv, textPath);
				// om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
				// SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
				// PopLoop(kv, client);
				// DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
				g_engInMenu[client] = false;
				return Plugin_Stop;
			}
		}
	}
	if (action == MenuAction_Cancel)
	{
		g_engInMenu[client] = false;
		if (ConstructTimers[client] != null)
		{
			KillTimer(ConstructTimers[client]);
			ConstructTimers[client] = null;
		}
	}
}

// Prop Spawning! This does all the calculations and spawning.
public PropSpawn(client, param2)
{
	new String:prop_choice[255];
	
	GetMenuItem(om_public_prop_menu, param2, prop_choice, sizeof(prop_choice));
	
	new String:name[255];
	GetClientName(client, name, sizeof(name));
	
	new String:modelname[255];
	new Price;
	new String:file[255];
	BuildPath(Path_SM, file, 255, "configs/om_public_props.txt");
	new Handle:kv = CreateKeyValues("Props");
	FileToKeyValues(kv, file);
	KvJumpToKey(kv, prop_choice);
	KvGetString(kv, "model", modelname, sizeof(modelname),"");
	Price = KvGetNum(kv, "price", 0);
	new ClientCredits = iCredits[client];
	new String:textToPrintChat[64];

	if (Price > 0)
	{
		if (ClientCredits >= Price)
		{
			if(bAdminOnly)
			{
				PrintToChat(client, "You have deployed a \x04%s", prop_choice);
				PrintHintText(client, "You have deployed a %s", prop_choice);
				LogAction(client, -1, "\"%s\" deployed a %s", name, prop_choice);
				PrintToChat(client, "You have deployed a \x04%s for \x03%d credits!", prop_choice, Price);
				Format(textToPrintChat, 255,"\x05%N\x01 deployed a \x04%s", client, prop_choice);
				PrintToChatAll("%s", textToPrintChat);
			}
			else
			{
			
				ClientCredits = ClientCredits - Price;
				iCredits[client] = ClientCredits;
				PrintToChat(client, "You have deployed a \x04%s for \x03%d credits!", prop_choice, Price);
				PrintHintText(client, "You have deployed a %s for %d credits!", prop_choice, Price);
				Format(textToPrintChat, 255,"\x05%N\x01 deployed a \x04%s", client, prop_choice);
				PrintToChatAll("%s", textToPrintChat);
			}
		}
		else
		{
			PrintToChat(client, "You do not have enough credits to deploy that!");
			PrintHintText(client, "You do not have enough credits to deploy that!");


			return;
		}
	}
	
	else
	{
		PrintToChat(client, "You have deployed a \x04%s and your credits have not been reduced!", prop_choice);
	}
	decl Ent;   
	PrecacheModel(modelname,true);
	Ent = CreateEntityByName("prop_dynamic_override"); 
	
	new String:EntName[64];
	Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", client, iPropNo[client]);
	
	DispatchKeyValue(Ent, "physdamagescale", "0.0");
	DispatchKeyValue(Ent, "model", modelname);
	DispatchKeyValue(Ent, "targetname", "OMPropSpawnProp");
	DispatchKeyValue(Ent, "Solid", "6");  
	//g_isSolid[iPropNo[client]] = true;
	//AcceptEntityInput(Ent, "DisableCollision");
	DispatchSpawn(Ent);
	
	decl Float:FurnitureOrigin[3];
	//decl Float:FurnitureOriginBackup[3];
	decl Float:ClientOrigin[3];
	decl Float:EyeAngles[3];
	decl FLoat:PropDistGround;
	GetClientEyeAngles(client, EyeAngles);
	GetClientAbsOrigin(client, ClientOrigin);
	//EyeAngles[0] = EyeAngles[0] - 10;
	//TR_TraceRayFilter(ClientOrigin, EyeAngles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);

	//TR_GetEndPosition(FurnitureOrigin, INVALID_HANDLE);
	
	

	new Health = KvGetNum(kv, "health", 0);
	//Health = (Health / 2);
	if(Health > 0)
	{
		SetEntProp(Ent, Prop_Data, "m_takedamage", DAMAGE_YES);
		SetEntProp(Ent, Prop_Data, "m_iHealth", Health);
		SetEntProp(Ent, Prop_Data, "m_iMaxHealth", Health);
	}


	new String:propModelName[128];
	GetEntPropString(Ent, Prop_Data, "m_ModelName", propModelName, 128);
	//PrintToServer("MODEL NAME: %s", propModelName);

	//FurnitureOriginBackup = FurnitureOrigin;
    if (StrEqual(propModelName, "models/static_afghan/prop_panj_stairs.mdl"))
    {
    	FurnitureOrigin[0] = (ClientOrigin[0] + (1 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (1 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
    }
    else if (StrEqual(propModelName, "models/fortifications/barbed_wire_02b.mdl"))
    {
    	FurnitureOrigin[0] = (ClientOrigin[0] + (60 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (60 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
    }
	else if (StrEqual(propModelName, "models/static_fortifications/sandbagwall01.mdl") || StrEqual(propModelName, "models/static_fortifications/sandbagwall02.mdl"))
	{
    	FurnitureOrigin[0] = (ClientOrigin[0] + (45 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (45 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);

	}
	else if (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl"))
	{
    	FurnitureOrigin[0] = (ClientOrigin[0] + (60 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (60 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);

		new Float:ammoStock = RoundFloat(GetTeamSecCount() / 6.0);

		if (plug_debug)
			PrintToChatAll("ammoStock %d", ammoStock);

		if (ammoStock <= 0)
			ammoStock = 1.0;

		if (plug_debug)
			PrintToChatAll("ammoStockafter %f", ammoStock);

		SetEntPropFloat(Ent, Prop_Data, "m_flLocalTime", ammoStock);
		SetVariantColor({255, 255, 102, 255});
		SetEntityRenderMode(Ent, RENDER_NORMAL);
		SetEntityRenderColor(Ent, 255, 255, 255, 255);
		AcceptEntityInput(Ent, "SetGlowColor");
		SetEntProp(Ent, Prop_Send, "m_bShouldGlow", true);
		SetEntPropFloat(Ent, Prop_Send, "m_flGlowMaxDist", 1600.0);

	}
	else if (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
	{
    	FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);

		SetVariantColor({80, 210, 255, 255});
		SetEntityRenderMode(Ent, RENDER_NORMAL);
		//SetEntityRenderColor(Ent, 10, 120, 245, 255);
		AcceptEntityInput(Ent, "SetGlowColor");
		SetEntProp(Ent, Prop_Send, "m_bShouldGlow", true);
		SetEntPropFloat(Ent, Prop_Send, "m_flGlowMaxDist", 600.0);

	}
    else
    {
    	FurnitureOrigin[0] = (ClientOrigin[0] + (50 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (50 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + KvGetNum(kv, "height", 100));
		EyeAngles[0] = 0;
		TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
    }


	//Check if ent is stuck in a player prop, kill
	// if (CheckStuckInEntity(Ent))
	// {
	// 	PrintToChat(client, "A person is in the way!");
	// 	PrintHintText(client, "A player in the way!");
	// 	if(Ent != -1)
	// 		AcceptEntityInput(Ent, "kill");

	// 	//Refund
	// 	ClientCredits = ClientCredits + Price;
	// 	iCredits[client] = ClientCredits;
	// }

	// PropDistGround = GetPropDistanceToGround(Ent);
	// if (PropDistGround >= 50)
	// {
	// 	FurnitureOrigin[2] = FurnitureOrigin[2] - PropDistGround;
	// 	TeleportEntity(Ent, FurnitureOrigin, EyeAngles, NULL_VECTOR);
	// }
	SetEntityMoveType(Ent, MOVETYPE_NONE);  
	//Add onTouch hook for when bots damage deployable
	SetEntProp(Ent, Prop_Data, "m_takedamage", DAMAGE_YES);
	SDKHook(Ent, SDKHook_OnTakeDamage, SHook_OnTakeDamageGear);
	//HookSingleEntityOutput(Ent, "OnHealthChanged", OnGearDamaged, false);  //This is more for status glow of object
	SDKHook(Ent, SDKHook_Touch, SHook_OnTouch); 
	CloseHandle(kv);
	g_propIntegrity[iPropNo[client]] = GetEntProp(Ent, Prop_Data, "m_iHealth");
	//PrintToServer("g_propIntegrity[iPropNo[client]]: %d",g_propIntegrity[iPropNo[client]]);
	//SetEntProp(Ent, Prop_Data, "m_CollisionGroup", 17);  
	g_engineerParam[iPropNo[client]] = param2;
	iPropNo[client] += 1;
												
	return;
}
public bool:TraceRayDontHitSelf(entityhit, mask, any:client) 
{ 
	return (entityhit != client); 

} //is the trace filter so the trace doesn't hit the player's own model
stock GetPropDistanceToGround(prop)
{
    
    new Float:fOrigin[3], Float:fGround[3];
    GetEntPropVector(prop, Prop_Send, "m_vecOrigin", fOrigin);

    fOrigin[2] += 10.0;
    
    TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_SOLID, RayType_Infinite, TraceFilterNoPlayers, prop);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        fOrigin[2] -= 10.0;
        return GetVectorDistance(fOrigin, fGround);
    }
    return 0.0;
}

public bool:TraceRayNoPlayers(entity, mask, any:data)
{
    if(entity == data || (entity >= 1 && entity <= MaxClients))
    {
        return false;
    }
    return true;
}  

public bool:TraceFilterNoPlayers(iEnt, iMask, any:Other)
{
    return (iEnt != Other && iEnt > MaxClients); 
}
public Action:Event_PlayerDisconnect_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_LastButtons[client] = 0;
}

public bool:Tracer_FilterBlocks(iEntity, contentsMask, any:data)
{
	if(iEntity > MaxClients)
		return true;

	return false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
  if (!IsFakeClient(client))
  {
    //PrintToServer("BUTTON PRESS DEBUG RUNCMD");
    for (new i = 0; i < MAX_BUTTONS; i++)
    {
        new button = (1 << i);
        if ((buttons & button)) { 
        //     if (!(g_LastButtons[client] & button)) { 
        //         OnButtonPress(client, button); 
        //     } 
        // } else if ((g_LastButtons[client] & button)) { 
        //     OnButtonRelease(client, button); 
        // }  
          OnButtonPress(client, button, buttons); 
        }
    }
      
      g_LastButtons[client] = buttons;
  }
    return Plugin_Continue;
}

OnButtonPress(client, button, buttons)
{
    new Float:eyepos[3];
    GetClientEyePosition(client, eyepos); // Position of client's eyes.
  	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (ActiveWeapon < 0)
		return Plugin_Handled;
	// Get weapon class name
	decl String:sWeapon[32];
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
	////PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);

    ////PrintToServer("Client Eye Height %f",eyepos[2]);    
   if(GetClientMenu(client, INVALID_HANDLE) == MenuSource_None && button == INS_SPRINT && buttons & INS_DUCK && buttons & INS_USE && (StrContains(g_client_last_classstring[client], "engineer") > -1) && g_engInMenu[client] == false && ((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_wrench") > -1)))// && !(buttons & IN_FORWARD) && !(buttons & IN_ATTACK2) && !(buttons & IN_ATTACK))// & !IN_ATTACK2) 
   {
      //PrintToServer("DEBUG PRESSING BUTTONS");    
    
      if(!Client_IsValid(client))
		return Plugin_Handled;
	
		g_engInMenu[client] = true;

		decl String:textPath[255];
		BuildPath(Path_SM, textPath, sizeof(textPath), "configs/om_public_props.txt");
		new Handle:kv = CreateKeyValues("Props");
		FileToKeyValues(kv, textPath);
		om_public_prop_menu = CreateMenu(Public_Prop_Menu_Handler);
		SetMenuTitle(om_public_prop_menu, "Construct | Credits: %d", iCredits[client]);
		PopLoop(kv, client);
		DisplayMenu(om_public_prop_menu, client, MENU_TIME_FOREVER);
		
		return Plugin_Handled;
   }

   //if (GetGameTime()-g_fPlayerLastChat[client] < 1.0)
   //	return Plugin_Handled;

	new iAimTarget = GetClientAimTarget(client, false);
	if (iAimTarget > MaxClients) //Not a client?
	{
		if (iAimTarget > MaxClients && FindDataMapInfo(iAimTarget, "m_ModelName") != -1) //Verify if part of map data?
		{
			decl String:sWeapon[32];
			GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
			//new String:sModelPath[128];
			//GetEntPropString(iAimTarget, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));
			new propType = GetPropType(iAimTarget);
			if (buttons & INS_USE &&  (StrContains(g_client_last_classstring[client], "engineer") > -1) && 
				((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_wrench") > -1))) //Repair barricades only
			{

				if ((propType != 1 && propType != 2 && (propType == 3 || propType == 4 || propType == 5 || propType == -1)))
				{
					PrintCenterText(client, "You can only repair barricade deployables!\nDeployable Health: %d", iAimTarget);
					return Plugin_Handled;
				}

				new Float:vOrigin[3], Float:vTargetOrigin[3];
				GetEntPropVector(iAimTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
				GetClientAbsOrigin(client, vTargetOrigin);
				if (GetVectorDistance(vOrigin, vTargetOrigin) <= 80.0)
				{
					new iHp = GetEntProp(iAimTarget, Prop_Data, "m_iHealth");
					new iMaxHp = GetEntProp(iAimTarget, Prop_Data, "m_iMaxHealth");
					iHp += g_integrityRepair;
					new Float:fDirection[3];
					fDirection[0] = GetRandomFloat(-1.0, 1.0);
					fDirection[1] = GetRandomFloat(-1.0, 1.0);
					fDirection[2] = GetRandomFloat(-1.0, 1.0);
					new Float:vMaxs[3];
					GetEntPropVector(iAimTarget, Prop_Data, "m_vecMaxs", vMaxs);
					vOrigin[2] += vMaxs[2]/2;
					TE_SetupSparks(vOrigin, fDirection, 1, 1);
					TE_SendToAll();
					if (iHp < iMaxHp) PrintCenterText(client, "Repairing... [%d  /  %d]", iHp, iMaxHp);
					else
					{
						if (iHp >= iMaxHp)
						{
							//LogToGame("%N is fixed barricade %d", client, iAimTarget);
							//SetEntPropFloat(iAimTarget, Prop_Data, "m_flLocalTime", 0.0);
							PrintCenterText(client, "Barricade Repaired!");
							iHp = iMaxHp;
							//PrintCenterText(client, " ");
						}
					}
					//new iColor = RoundToNearest((float(iHp) / 2000.0) * 255.0);
					//SetEntityRenderColor(iAimTarget, iColor, iColor, iColor, 255);
					//decl iColors[4] = {255, 255, 255, 255};
					//iColors[1] = iColors[2] = iColor;
					//SetVariantColor(iColors);
					//AcceptEntityInput(iAimTarget, "SetGlowColor");
					SetEntProp(iAimTarget, Prop_Data, "m_iHealth", iHp);

					g_fPlayerLastChat[client] = GetGameTime();

					return Plugin_Handled;
					//DispatchKeyValue(iAimTarget, "targetname", "LuaCustomModel");
				
					//else PrintCenterText(client, "Press \"USE (F) with Knife\" to Repair  Barricade");		
				}
			}
		}
	}
   	
}

OnButtonRelease(client, button)
{
  ////PrintToServer("BUTTON RELEASE");
  
    // do stuff
}




//(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
public Action:OnTakeDamagePre(victim, &attacker, &inflictor, &Float:damage, &damagetype) {

	new Float:damageReduction = (damage * 0.5); //Reduce damage here so its a blanket reduction

	if (victim > 0 && IsClientConnected(victim) && IsClientInGame(victim) && !IsFakeClient(victim) && IsPlayerAlive(victim))
	{
		
		//PrintToServer("DEBUG 5");
		for (new engineerCheck = 1; engineerCheck <= MaxClients; engineerCheck++)
		{

			if (IsClientConnected(engineerCheck) && IsClientInGame(engineerCheck) && !IsFakeClient(engineerCheck) && (StrContains(g_client_last_classstring[engineerCheck], "engineer") > -1))
			{

				new loopCount = 0; // Stack damage reduction up to two.
				//PrintToServer("DEBUG 6");
				for(new i=0; i<=iPropNo[engineerCheck]; i++)
				{
					decl String:EntName[MAX_NAME_LENGTH+5];
					Format(EntName, sizeof(EntName), "OMPropSpawnProp%d_number%d", engineerCheck, i);
					new prop = Entity_FindByName(EntName);
					//Need another engineer to test
					if(prop != -1)
					{	

						new propType = GetPropType(prop);
						if (propType == 1) //Damage reduction on Sandbags/Defense only
						{
							//PrintToServer("DEBUG 7");
							//Get position of player and prop
							new Float:plyrOrigin[3];
							new Float:propOrigin[3];
					
							GetClientAbsOrigin(victim,plyrOrigin);
							GetEntPropVector(prop, Prop_Send, "m_vecOrigin", propOrigin);
							
							//determine distance from the two
							//new isNearProp = Check_NearbyPlayers(prop);

							new Float:fDistance;
							fDistance = GetVectorDistance(propOrigin,plyrOrigin);
							if (fDistance <= 140 && damagetype == DMG_BLAST)
							{
								loopCount++;
								damage -= damageReduction; // Reduce damage by 35%
								//PrintToChat(victim, "DAMAGE REDUCED by 35%");
								if(plug_debug)
									PrintToChatAll("PROP: damage = %d | damageReduction = %d", damage, damageReduction);
								if (damage <= 0)
									damage = 10;

								if (loopCount >= 2)
									break;
							}
						}
						
					}
				}
			}
		}
		return Plugin_Changed;
	}
}



//LUA Functions Starts

public Action:SHook_OnTouch(entity, touch)
{
	if (touch > 0 && touch <= MaxClients)
	{
/*		new String:sClassName[64];
		GetEntPropString(entity, Prop_Data, "m_iName", sClassName, sizeof(sClassName));
		if (StrEqual(sClassName, "LuaCustomModel", true))
			SDKHooks_TakeDamage(entity, client, client, 10.0, DMG_SLASH, -1, NULL_VECTOR, NULL_VECTOR);	*/
		if (GetClientTeam(touch) == TEAM_2_INS)
		{
			new propIntegrity = GetEntProp(entity, Prop_Data, "m_iHealth");

			if (plug_debug)
				PrintToChatAll("PropHealth = %d", propIntegrity);

			new propType = GetPropType(entity);
			new Float:propDamage = hIntegDegrade;

			//PrintToServer("g_integrityDegrade %d", g_integrityDegrade);
			if (propType == 2) //Degrade 2x as slow for barbwire
			{
				SDKHooks_TakeDamage(entity, touch, touch, g_integrityDegrade, DMG_SLASH, -1, NULL_VECTOR, NULL_VECTOR);
			}
			else
				SDKHooks_TakeDamage(entity, touch, touch, g_integrityDegrade, DMG_SLASH, -1, NULL_VECTOR, NULL_VECTOR);

			if (propIntegrity <= 0)
			{
				PlayProp_DestroySound(entity, propType);
			}
		}
	}
}


public Action:SHook_OnTakeDamageGear(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
//	PrintToChatAll("Equipment %d damaged %0.1f (%d) by %d (%d) with %d weapon id", victim, damage, damagetype, attacker, inflictor, weapon);
	if (GetEntPropEnt(victim, Prop_Data, "m_hOwnerEntity") == MaxClients+2)
		return Plugin_Continue;

	new aTeam = (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) ? GetClientTeam(attacker) : -1);
	if (aTeam == TEAM_1_SEC)
	{
		damage /= 4.0;
	}
	new propType = GetPropType(victim);
	if (propType == 2) //StrEqual(propModelName, "models/fortifications/barbed_wire_02b.mdl"))
	{
		if (damagetype & DMG_BURN)
		{
			damage *= 2.0;
			return Plugin_Changed;
		}
		else if (damagetype & DMG_BLAST)
		{
			damage *= 4.0;
			return Plugin_Changed;
		}
	}
	else if (propType == 1) //StrEqual(propModelName, "models/static_fortifications/sandbagwall01.mdl") || StrEqual(propModelName, "models/static_fortifications/sandbagwall02.mdl"))
	{

	}
	else if (propType == 3) // (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
	{
		if (damagetype & DMG_BURN)
		{
			damage *= 2.0;
			return Plugin_Changed;
		}
		else if (damagetype & DMG_BLAST)
		{
			damage *= 3.0;
			return Plugin_Changed;
		}

	}
	else if (propType == 4) // (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl"))
	{
		if (damagetype & DMG_BURN)
		{
			damage *= 2.0;
			return Plugin_Changed;
		}
		else if (damagetype & DMG_BLAST)
		{
			damage *= 3.0;
			return Plugin_Changed;
		}
	}
	else if (propType == 5) // (StrEqual(propModelName, "models/static_afghan/prop_panj_stairs.mdl")) //Ramp
	{
		if (damagetype & DMG_BURN)
		{
			damage *= 2.0;
			return Plugin_Changed;
		}
		else if (damagetype & DMG_BLAST)
		{
			damage *= 3.0;
			return Plugin_Changed;
		}
	}
	//new aTeam = (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) ? GetClientTeam(attacker) : -1);
	//if (aTeam == TEAM_1_SEC)
	//{
	//	if (damagetype == 268435456 && damage == 1000.0)
	//		return Plugin_Handled;
	//	if (damagetype & DMG_SLASH)
	//	{
	//		damage = float(GetEntProp(victim, Prop_Data, "m_iMaxHealth"))/5.0;
	//		if (damage < 200.0 || damage > 1000.0)
	//			damage = 200.0;
	//	}
	//	else damage /= 2.0;
	//	return Plugin_Changed;
	//}
	
	return Plugin_Continue;
}


stock void PlayProp_DestroySound(prop, propType)
{
		new Float:vOrigin[3];
		GetEntPropVector(prop, Prop_Data, "m_vecAbsOrigin", vOrigin);
		if (propType == 2) //StrEqual(propModelName, "models/fortifications/barbed_wire_02b.mdl"))
		{
			
		}
		else if (propType == 1) //StrEqual(propModelName, "models/static_fortifications/sandbagwall01.mdl") || StrEqual(propModelName, "models/static_fortifications/sandbagwall02.mdl"))
		{

		}
		else if (propType == 3) // (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
		{
			switch(GetRandomInt(0, 2))
			{
				case 0: EmitAmbientSound("soundscape/emitters/oneshot/broken_tv_01.ogg", vOrigin);
				case 1: EmitAmbientSound("soundscape/emitters/oneshot/broken_tv_02.ogg", vOrigin);
				case 2: EmitAmbientSound("soundscape/emitters/oneshot/broken_tv_03.ogg", vOrigin);
			}

		}
		else if (propType == 4) // (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl"))
		{
			EmitAmbientSound("ui/sfx/crate_01.wav", vOrigin);
		}
		else if (propType == 5) // (StrEqual(propModelName, "models/static_afghan/prop_panj_stairs.mdl")) //Ramp
		{

		}
}


// Get tesm2 player count
stock GetTeamSecCount() {
	new float:clients = 0;
	new iTeam;
	for( new i = 1; i <= GetMaxClients(); i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i))
		{
			iTeam = GetClientTeam(i);
			if(iTeam == TEAM_1_SEC)
				clients++;
		}
	}
	return clients;
}




stock void DisplayInstructorHint(int iTargetEntity, float fTime, float fHeight, float fRange, bool bFollow, bool bShowOffScreen, char[] sIconOnScreen, char[] sIconOffScreen, char[] sCmd, bool bShowTextAlways, int iColor[3], char[] sText)
{
	int iEntity = CreateEntityByName("env_instructor_hint");
	if(iEntity <= 0)
		return;
		
	char sBuffer[32];
	FormatEx(sBuffer, sizeof(sBuffer), "%d", iTargetEntity);
	
	// Target
	DispatchKeyValue(iTargetEntity, "targetname", sBuffer);
	DispatchKeyValue(iEntity, "hint_target", sBuffer);
	
	// Static
	FormatEx(sBuffer, sizeof(sBuffer), "%d", !bFollow);
	DispatchKeyValue(iEntity, "hint_static", sBuffer);
	
	// Timeout
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fTime));
	DispatchKeyValue(iEntity, "hint_timeout", sBuffer);
	
	// Height
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fHeight));
	DispatchKeyValue(iEntity, "hint_icon_offset", sBuffer);
	
	// Range
	FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fRange));
	DispatchKeyValue(iEntity, "hint_range", sBuffer);
	
	// Show off screen
	FormatEx(sBuffer, sizeof(sBuffer), "%d", !bShowOffScreen);
	DispatchKeyValue(iEntity, "hint_nooffscreen", sBuffer);
	
	// Icons
	DispatchKeyValue(iEntity, "hint_icon_onscreen", sIconOnScreen);
	DispatchKeyValue(iEntity, "hint_icon_offscreen", sIconOffScreen);
	
	// Command binding
	DispatchKeyValue(iEntity, "hint_binding", sCmd);
	
	// Show text behind walls
	FormatEx(sBuffer, sizeof(sBuffer), "%d", bShowTextAlways);
	DispatchKeyValue(iEntity, "hint_forcecaption", sBuffer);
	
	// Text color
	FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d", iColor[0], iColor[1], iColor[2]);
	DispatchKeyValue(iEntity, "hint_color", sBuffer);
	
	//Text
	ReplaceString(sText, 254, "\n", " ");
	Format(sText, 254, "%s", sText);
	DispatchKeyValue(iEntity, "hint_caption", sText);

	if (fTime > 0.0)
	{
		Format(sBuffer, sizeof(sBuffer), "OnUser1 !self:kill::%f:1", fTime);
		SetVariantString(sBuffer);
		AcceptEntityInput(iEntity, "AddOutput");
		AcceptEntityInput(iEntity, "FireUser1");
	}
	
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "ShowHint");
}



//LUA Functions END


// public OnEntityDestroyed(entity)
// {
// 	g_propIntegrity[entity] = 0;
// 	entity = -1;
// }


//gency2\insurgency\insurgency_models.vpk\models\static_military\prop_aldis_lamp_stand.mdl
//insurgency_models.vpk\models\static_fittings\antenna02a.mdl //use this

//insurgency_models.vpk\models\static_fittings\antenna02b.mdl

//ency_models.vpk\models\fortifications\barbed_wire_02.mdl // use this
//ency_models.vpk\models\fortifications\barbed_wire_01.mdl