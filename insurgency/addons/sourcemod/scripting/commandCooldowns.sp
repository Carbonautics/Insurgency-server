#pragma semicolon 1
#define UPD_LIBFUNC
#define CONVAR_PREFIX "sm_commandcooldowns"
#include <morecolors>
#include <ddhoward_updater>
#pragma newdecls required;

public Plugin myinfo = {
	name = "[Any] Command Cooldowns",
	author = "Derek D. Howard",
	description = "Allows server ops to set a cooldown for almost any command without editing the command's code.",
	version = "18.0116.0",
	url = "https://forums.alliedmods.net/showthread.php?t=235539"

	/*	Changes since previous version:
		a bunch
	Plans for future:
		Natives and forwards
	*/
};

#define MAXIMUM_COMMAND_LENGTH 255+1
#define COOLDOWN_CONFIG_PATH "configs/commandCooldowns.txt"
#define DEFAULT_COOLDOWN_REPLY "You must wait {TIMELEFT} seconds!"

ArrayList g_alCooldowns;
/*	Each index in the array corresponds to a different cooldown.
	Blocks 0 thru MaxClients indicate a client's time at which they last used the command.
	All following blocks are defined as follows: */
	
StringMap g_smCommands;

#define	Block_CooldownTime 		MaxClients+1  //how long is the cooldown
#define	Block_Flags 			MaxClients+2  //default flags needed to bypass cooldown
#define	Block_Reset 			MaxClients+3  //should the cooldown reset upon attempted early use?
#define	Block_Shared 			MaxClients+4  //do all players share the cooldown?
#define	Block_Disabled 			MaxClients+5  //is the cooldown enabled? (will be used when natives are implemented)
#define	Block_Creator 			MaxClients+6  //handle to the plugin that created the cooldown, will be used when/if natives are implemented
#define	Block_Plugins 			MaxClients+7  //handle to the ArrayList containing the list of plugins
#define	Block_Strings 			MaxClients+8  //handle to the ArrayList containing the override and messages, defined below
#define	Block_BlockTotal 		MaxClients+9  //Total amount of blocks needed, should be previous line + 1 (since blocks are indexed starting at 0)

#define String_Override 		0 	//override required to bypass cooldown
#define String_FirstMessage 	1 	//index of the sub-array's first printable message if a cooldown blocks a command, should be same as next line
#define String_Reply 			1 	//message to be passed through CReplyToCommand(client) when command blocked
#define String_Activity 		2 	//message to be passed through CShowActivity2 when command blocked
#define String_ClientCmd 		3 	//command to be passed through FakeClientCommand when command blocked
#define String_ServerCmd 		4 	//command to be passed through ServerCommand when command blocked
#define String_LastMessage 		4 	//the sub-array's last printable message if a cooldown blocks a command, should be same as previous line
#define String_StringTotal 		5 	//total size of this sub-array, should be previous line + 1

ConVar cvar_reloadPlugins;
//Handle hfwd_reloadConfig;

public void OnPluginStart() {
	g_alCooldowns = new ArrayList(Block_BlockTotal);
	g_smCommands = new StringMap();

	cvar_reloadPlugins = CreateConVar("sm_commandcooldowns_reloadplugins", "1", "(0/1) Enable plugin reloading by default?");	
	//hfwd_reloadConfig = CreateGlobalForward("CommandCooldowns_ConfigReloaded", ET_Ignore);
	RegAdminCmd("sm_commandcooldowns_reload", UseReloadCmd, ADMFLAG_RCON, "Reloads commandCooldowns.txt");
	ParseCooldownsKVFile();
}

void ParseCooldownsKVFile() {

	//before adding cooldowns from the file, delete all existing cooldowns
	if (g_alCooldowns.Length > 0) {
		for (int i = 0; i < g_alCooldowns.Length; i++) {
			CloseHandle(g_alCooldowns.Get(i, Block_Strings));
			CloseHandle(g_alCooldowns.Get(i, Block_Plugins));
		}
		g_alCooldowns.Clear();
		StringMapSnapshot snapshot = g_smCommands.Snapshot();
		g_smCommands.Clear();
		if (snapshot.Length != 0) {
			char removeCommand[MAXIMUM_COMMAND_LENGTH];
			for (int s = 0; s < snapshot.Length; s++) {
				snapshot.GetKey(s, removeCommand, sizeof(removeCommand));
				RemoveCommandListener(CommandListener, removeCommand);
			}
		}
		delete snapshot;
	}

	KeyValues kv = new KeyValues("CommandCooldowns");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), COOLDOWN_CONFIG_PATH);
	if (!kv.ImportFromFile(path)) LogError("commandCooldowns.txt not found!!");
	else if (!kv.GotoFirstSubKey()) LogError("commandCooldowns.txt appears to be empty!!");
	else {
		char bigBuffer[MAXIMUM_COMMAND_LENGTH+1];
		char commandCooldownsFilename[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, commandCooldownsFilename, sizeof(commandCooldownsFilename));
		do {
			//get the cooldown info from the file
			float cooldown = kv.GetFloat("cooldown", -1.0);

			//no point if the cooldown time isn't over 0
			if (cooldown <= 0.0) continue;

			//get the command names
			kv.GetSectionName(bigBuffer, sizeof(bigBuffer));
			//change all whitespace to regular spaces, just in case
			for (int i; bigBuffer[i] != '\0'; i++) {
				if (IsCharSpace(bigBuffer[i])) bigBuffer[i] = ' ';
			}
			//aaand get rid of any double spaces
			while (StrContains(bigBuffer, "  ") >= 0) {
				ReplaceString(bigBuffer, sizeof(bigBuffer), "  ", " ");
			}
			//aaand make them all lowercase since ArrayList.FindString is always case sensitive
			for (int c = 0; c < strlen(bigBuffer); c++) {
				bigBuffer[c] = CharToLower(bigBuffer[c]);
			}
			//Count number of spaces
			//ExplodeString does not support dynamic arrays, and I'd
			//rather do this than create a giant array of strings
			int numSpaces;
			for (int i; bigBuffer[i] != '\0'; i++) {
				if (bigBuffer[i] == ' ') numSpaces++;
			}
			char[][] explodedString = new char[numSpaces + 1][MAXIMUM_COMMAND_LENGTH];
			int numberAliases = ExplodeString(bigBuffer, " ", explodedString, numSpaces+1, MAXIMUM_COMMAND_LENGTH);
			if (numberAliases == 0) continue; //no commands specified to apply the cooldown onto
				
			//create the new index in the array
			int index = g_alCooldowns.Push(0);
			
			//store the cooldown
			g_alCooldowns.Set(index, cooldown, Block_CooldownTime);
			
			//set everyone's last-used time to -1, so longer cooldowns don't
			//mistakenly block command use shortly after server boot
			for (int client = 0; client <= MaxClients; client++) {
				g_alCooldowns.Set(index, -1.0, client);
			}
			

			//Hook the commands and add them to the StringMap
			for (int a = 0; a < numberAliases; a++) {
				AddCommandListener(CommandListener, explodedString[a]);
				g_smCommands.SetValue(explodedString[a], index, false);
			}

			//parse and store the flags needed
			char flags[AdminFlags_TOTAL + 1];
			kv.GetString("flags", flags, sizeof(flags));
			AdminFlag useless;
			for (int i = 0; i < strlen(flags); i++) {
				flags[i] = CharToLower(flags[i]); //upper case flags don't work with ReadFlagString()
				if (!FindFlagByChar(flags[i], useless)) { //get rid of characters that aren't valid flags
					char temp[1];
					temp[0] = flags[i];
					ReplaceStringEx(flags, sizeof(flags), temp, "", 1, 0);
					i--;
				}
			}
			g_alCooldowns.Set(index, ReadFlagString(flags), Block_Flags);
			
			//store other information
			g_alCooldowns.Set(index, kv.GetNum("reset", 0), Block_Reset);
			g_alCooldowns.Set(index, kv.GetNum("shared", 0), Block_Shared);
			g_alCooldowns.Set(index, kv.GetNum("disabled", 0), Block_Disabled);
			g_alCooldowns.Set(index, GetMyHandle(), Block_Creator);

			//get the other strings
			ArrayList otherStrings = new ArrayList(ByteCountToCells(MAXIMUM_COMMAND_LENGTH), String_StringTotal);
			g_alCooldowns.Set(index, otherStrings, Block_Strings);
			for (int i = 0; i < String_StringTotal; i++) {
				switch (i) {
					case String_Override: kv.GetString("override", bigBuffer, sizeof(bigBuffer));
					case String_Reply: kv.GetString("reply", bigBuffer, sizeof(bigBuffer), DEFAULT_COOLDOWN_REPLY);
					case String_Activity: kv.GetString("showactivity", bigBuffer, sizeof(bigBuffer));
					case String_ServerCmd: kv.GetString("servercmd", bigBuffer, sizeof(bigBuffer));
					case String_ClientCmd: kv.GetString("clientcmd", bigBuffer, sizeof(bigBuffer));
				}
				otherStrings.SetString(i, bigBuffer);
			}


			//create and use array for plugin names
			ArrayList plugins = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH-7));
			g_alCooldowns.Set(index, plugins, Block_Plugins);
			kv.GetString("plugin", bigBuffer, sizeof(bigBuffer));
			if (bigBuffer[0] != '\0') {
				int numPipes;
				for (int i; bigBuffer[i] != '\0'; i++) {
					if (bigBuffer[i] == '|') numPipes++;
				}
				char[][] explodedString2 = new char[numPipes + 1][PLATFORM_MAX_PATH];
				int numberPlugins = ExplodeString(bigBuffer, "|", explodedString2, numPipes+1, PLATFORM_MAX_PATH);
				for (int a = 0; a < numberPlugins; a++) {
					if (!StrEqual(explodedString2[a], commandCooldownsFilename, false)) {
						//do not let idiots make this plugin reload itself
						plugins.PushString(explodedString2[a]);
					}
				}
			}
		} while (kv.GotoNextKey());
	}
	kv.Close();
	
//	if (GetForwardFunctionCount(hfwd_reloadConfig) > 0) {
//		Call_StartForward(hfwd_reloadConfig);
//		Call_Finish();
//	}
}

public Action CommandListener(int client, const char[] cmdname, int iArgs) {
	if (!CheckCommandAccess(client, cmdname, 0)) return Plugin_Continue; //client can't access the command anyway

	//normalize case
	char[] cmdnameLower = new char[strlen(cmdname)+1];
	for (int c = 0; c < strlen(cmdname); c++) {
		cmdnameLower[c] = CharToLower(cmdname[c]);
	}
	
	int index;

	//determine what cooldown affects this command
	if (!g_smCommands.GetValue(cmdnameLower, index)) {
		//something fucky happened, command not found
		RemoveCommandListener(CommandListener, cmdnameLower);
		return Plugin_Continue;
	}

	ArrayList alStrings = g_alCooldowns.Get(index, Block_Strings);
	bool shared = g_alCooldowns.Get(index, Block_Shared);
	float cooldown = g_alCooldowns.Get(index, Block_CooldownTime);
	float lastUsed = g_alCooldowns.Get(index, shared ? 0 : client);

	//calculate the time remaining until the command can be used again
	float timeRemaining = (lastUsed + cooldown) - GetEngineTime();

	char override[MAXIMUM_COMMAND_LENGTH];
	alStrings.GetString(String_Override, override, sizeof(override));
		
	int flags = g_alCooldowns.Get(index, Block_Flags);

	if (timeRemaining <= 0 //if cooldown has expired, OR...
	|| lastUsed < 0.0 //the command hasn't been used at all yet, OR...
	|| client == 0 //client is console, OR...
	|| g_alCooldowns.Get(index, Block_Disabled) //cooldown is disabled, OR...
	|| ((override[0] != '\0' || flags != 0) && CheckCommandAccess(client, override, flags))) { //client can bypass cooldown...
		g_alCooldowns.Set(index, GetEngineTime(), shared ? 0 : client); //set the new command used time
		return Plugin_Continue; //and let it go through
	}
	else { //haha, stop the command
		bool reset = g_alCooldowns.Get(index, Block_Reset);
		if (reset) {
			//"reset" key was set, so restart the cooldown
			g_alCooldowns.Set(index, GetEngineTime(), shared ? 0 : client);
		}

		char buffer[MAXIMUM_COMMAND_LENGTH];
		char str_timeleft[7]; //maximum printable cooldown length is over 11 days
		IntToString(RoundToCeil(reset ? cooldown : timeRemaining), str_timeleft, sizeof(str_timeleft));
		char str_cooldownlength[7];
		FloatToString(cooldown, str_cooldownlength, sizeof(str_cooldownlength));
		char str_userid[6]; //strlen(65535)+1
		IntToString(GetClientUserId(client), str_userid, sizeof(str_userid));
		char str_userName[MAX_NAME_LENGTH];
		GetClientName(client, str_userName, sizeof(str_userName));
		for (int r = String_FirstMessage; r <= String_LastMessage; r++) {
			alStrings.GetString(r, buffer, sizeof(buffer));
			if (buffer[0] != '\0') {
				ReplaceString(buffer, sizeof(buffer), "{COMMAND_NAME}", cmdname);
				ReplaceString(buffer, sizeof(buffer), "{TIMELEFT}", str_timeleft);
				ReplaceString(buffer, sizeof(buffer), "{COOLDOWN_TIME}", str_cooldownlength);
				ReplaceString(buffer, sizeof(buffer), "{USERID}", str_userid);
				ReplaceString(buffer, sizeof(buffer), "{USERNAME}", str_userName);
				switch (r) {
					case String_Reply: CReplyToCommand(client, buffer);
					case String_Activity: CShowActivity2(client, "[Cooldowns] ", buffer);
					case String_ServerCmd: ServerCommand(buffer);
					case String_ClientCmd: FakeClientCommand(client, buffer);
				}
			}
		}

		//note to self: put forward here in future update

		return Plugin_Stop;
	}
}

public Action UseReloadCmd(int client, int args) {
	ParseCooldownsKVFile();
	bool reloaded;
	if (GetCmdArgs() > 0) {
		char arg1[2]; GetCmdArg(1, arg1, sizeof(arg1));	int intarg = StringToInt(arg1);
		if (intarg == 1 || (intarg != 0 && cvar_reloadPlugins.BoolValue)) {
			reloaded = true;
		}
	}
	else if (cvar_reloadPlugins.BoolValue) {
		reloaded = true;
	}
	if (reloaded) {
		DoReloads();
	}
	ReplyToCommand(client, "Cooldowns have been reloaded.%s", reloaded ? " Any applicable plugins have also been reloaded." : "");
	return Plugin_Handled;
}

public void OnClientDisconnect(int client) {
	for (int i = 0; i < g_alCooldowns.Length; i++)
		g_alCooldowns.Set(i, 0.0, client);
}

void DoReloads() {
	char pluginname[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_alCooldowns.Length; i++) {
		ArrayList plugins = g_alCooldowns.Get(i, Block_Plugins);
		for (int p = 0; p < plugins.Length; p++) {
			plugins.GetString(p, pluginname, sizeof(pluginname));
			if (pluginname[0] != '\0') ServerCommand("sm plugins reload %s", pluginname);
		}
	}
}

public void OnConfigsExecuted() {
	if (cvar_reloadPlugins.BoolValue) DoReloads();
}