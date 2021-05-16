/****************************************
 * http://ddhoward.com/sourcemod/updater/scripting/include/ddhoward_updater.inc
 * Version 18.0912.0
 * 
 * This file is used in Derek's plugins for Updater integration.
 * It is based on Dr. McKay's mckayupdater.sp
 * For more info on Updater, see:
 * 		https://forums.alliedmods.net/showthread.php?t=169095
 * For Dr. McKay's original file, see:
 * 		https://bitbucket.org/Doctor_McKay/public-plugins/src/default/scripting/mckayupdater.sp
 *
 *
 *
 * This file performs the following tasks:
 * 	- Adds the plugin to Updater's updating pool (using UPDATE)
 *
 * 	- Creates a _update cvar to control whether Updater is enabled
 * 		- 0 disables automatic updating entirely.
 * 		- 1 causes Updater to simply write to Updater.log if an update is available.
 * 		- 2 causes Updater to download the update, to be loaded next map change or server reboot.
 * 		- 3 will cause the plugin's update to be loaded immediately after download.
 *
 * 	- Creates and protects a _version cvar if UPDATER_DONT_CREATE_VERSION_CVAR is not defined
 *
 *	- Creates a new command listener for "ddhoward_updater_include_versions"
 *		All plugins running this include will respond to that command in the console,
 *		and will tell the command user what version of this include was used.
 * 		Default access is ROOT.
 *
 *
 *
 * REQUIREMENTS:
 *
 * 	-	Properly fill out your plugin's "public Plugin myinfo" section with a "version" that
 *			changes on every update.
 *
 * 	-	You must call UPD_OnAllPluginsLoaded() in OnAllPluginsLoaded()
 * 			Example: public void OnAllPluginsLoaded() { UPD_OnAllPluginsLoaded(); }
 * 			If you don't need OnAllPluginsLoaded, just #define UPD_OAPL before #including this
 *
 * 	-	You must call UPD_OnLibraryAdded(); in OnLibraryAdded()
 * 			Example: public void OnLibraryAdded(const char[] name) { UPD_OnLibraryAdded(); }
 * 			If you don't need OnAllPluginsLoaded, just #define UPD_OLA before #including this
 *
 * 	-	#define UPDATE_URL before including this file
 * 			This should contain the full URL to the Updater txt file.
 *
 *
 *
 * YOU ARE STRONGLY ENCOURAGED TO:
 *
 *	-	#define CONVAR_PREFIX before including this file.
 *			This determines what your plugin's cvars will be named. For example, #defining
 *			CONVAR_PREFIX to "sm_myplugin" will cause your cvars to be named "sm_myplugin_update"
 *			and "sm_myplugin_version". If you don't do this, the cvars will be based off of the
 *			filename of the plugin, relative to the plugins/ folder. E.g, a plugin named
 *			myplugin.smx will generate the cvar	myplugin_update.
 *
 *
 *
 * SUGGESTIONS:
 *
 * 	-	#define NEVER_RELOAD_ON_UPDATE before including this file and the plugin will NEVER reload
 * 		itself upon being updated. The "3" option for the _update cvar will be disabled. Updated
 *		plugins will instead be run on next map change or server restart. This is recommended if
 *		late loads for your plugin are problematic.
 *
 * 	-	#define DEFAULT_UPDATE_SETTING to "0" "1" "2" or "3" before including this file.
 * 		This sets the default value of the _update cvar for your plugin. If you don't do this, the
 * 		the default for the default is "2"
 *
 * 	-	#defining UPD_LIBFUNC works the same as defining both other UPD_ defines.
 *
 * 	-	If you want your plugin to create and manage its own _version cvar without help from this
 *		include, then #define UPDATER_DONT_CREATE_VERSION_CVAR
 *
 *
 *
 * PLANS FOR FUTURE VERSIONS
 *
 *	-	Enable checks for valid convar name characters in plugin authors' defines and plugin filenames
 */

//standard protection against double-including
//also doubles as include version information for use later
#if defined _ddhoward_updater_version
	#endinput
#endif
#define _ddhoward_updater_version "18.0430.0"

//if the plugin author hasn't picked a default setting for the _update cvar, pick it for them
#if !defined DEFAULT_UPDATE_SETTING
	#define DEFAULT_UPDATE_SETTING "2"
#endif


#if !defined CONVAR_PREFIX
//	this will be uncommented once 1.10 becomes the stable branch i guess
//	#warning CONVAR_PREFIX not defined, plugin will use filename to name cvars created by ddhoward_updater.inc
#endif


//never require Updater for the plugin to function
#if defined REQUIRE_PLUGIN
	#undef REQUIRE_PLUGIN
	#include <updater>
	#define REQUIRE_PLUGIN
#else
	#include <updater>
#endif


ConVar cvar_update;
ConVar cvar_version;
char upd_plugin_version[32];

//set to TRUE if an update was downloaded, but plugin hasn't been reloaded yet

public void UPD_OnAllPluginsLoaded() {
	
	AddCommandListener(print_ddhoward_updater_include_version, "ddhoward_updater_include_versions");	
	if (!GetPluginInfo(INVALID_HANDLE, PlInfo_Version, upd_plugin_version, sizeof(upd_plugin_version))) {
		LogError("Plugin version not properly set in myinfo section, Updater will not function for this plugin.");
		return;
	}


	//determine convar prefix
	char convarPrefix[56];
	#if defined CONVAR_PREFIX
		convarPrefix = CONVAR_PREFIX;
	#else
		GetPluginFilename(INVALID_HANDLE, convarPrefix, sizeof(convarPrefix));
		convarPrefix[strlen(convarPrefix)-4] = '\0'; //strip file extension
	#endif
	
	/* This is commented out because IsValidConVarChar() seems to return some false negatives
	char invalidConVarChar[2];
	for (int i = 0; i < strlen(convarPrefix);) {
		if (IsValidConVarChar(convarPrefix[i])) i++;
		else {
			invalidConVarChar[0] = convarPrefix[i];
			ReplaceString(convarPrefix, sizeof(convarPrefix), invalidConVarChar, "");
		}
	}
	*/	

	
	char cvarName[32]; //buffer for both cvar names

	//create a _version cvar if desired
	#if !defined UPDATER_DONT_CREATE_VERSION_CVAR
		Format(cvarName, sizeof(cvarName), "%s_version", convarPrefix);
		cvar_version = CreateConVar(cvarName, upd_plugin_version, "Plugin Version", FCVAR_DONTRECORD);
		cvar_version.SetString(upd_plugin_version);
		cvar_version.AddChangeHook(UPD_CheckUpdaterStatus);
	#endif

	//create the _update cvar, with range of options depending on whether or not NEVER_RELOAD_ON_UPDATE was defined
	Format(cvarName, sizeof(cvarName), "%s_update", convarPrefix);
	#if defined NEVER_RELOAD_ON_UPDATE
		cvar_update = CreateConVar(cvarName, DEFAULT_UPDATE_SETTING, "(0/1/2) Updater compatibility. 0 to disable, 1 to notify, 2 to download and install on map change", _, true, 0.0, true, 2.0);
	#else
		cvar_update = CreateConVar(cvarName, DEFAULT_UPDATE_SETTING, "(0/1/2/3) Updater compatibility. 0 to disable, 1 to notify, 2 to download and install next map change, 3 to auto-load new version", _, true, 0.0, true, 3.0);
	#endif
	cvar_update.AddChangeHook(UPD_CheckUpdaterStatus);
	
	
	UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
}

//plugin author doesn't need OnAllPluginsLoaded so they defined one of these two things
#if defined UPD_LIBFUNC || defined UPD_OAPL
	public void OnAllPluginsLoaded() { UPD_OnAllPluginsLoaded(); }
#endif


//called at the end of cvar creation, when the cvars are changed, and when libraries are added
public void UPD_CheckUpdaterStatus(Handle convar, const char[] oldValue, const char[] newValue) {
	if (cvar_update == null) return; // cvars not created yet

	if (convar == cvar_version) {
		cvar_version.SetString(upd_plugin_version);
	}
	else {
		//if _update cvar enabled, and Updater is loaded, add URL to Updater
		if (cvar_update.IntValue > 0 && LibraryExists("updater")) {
			Updater_AddPlugin(UPDATE_URL);
		}
	}
}

//called by Updater when an update check is about to run
public Action Updater_OnPluginChecking() {
	if (cvar_update.IntValue >= 1) {
		return Plugin_Continue; //go ahead and check for updates
	}
	else {
		return Plugin_Handled; //don't perform the check
	}
}

//called by Updater when an update is about to be downloaded
public Action Updater_OnPluginDownloading() {
	if (cvar_update.IntValue >= 2) {
		return Plugin_Continue; //go ahead and download it
	}
	else {
		return Plugin_Handled; //don't download the update
	}
}

//called by Updater when an update has been successfully downloaded
#if !defined NEVER_RELOAD_ON_UPDATE
	public int Updater_OnPluginUpdated() {
		if (cvar_update.IntValue >= 3) {
			ReloadPlugin();
		}
	}
#endif


//OnLibraryAdded() was called in the host plugin, and it called UPD_OnLibraryAdded()
public void UPD_OnLibraryAdded() {
	if (upd_plugin_version[0] != '\0') {
		UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
	}
}

//plugin author doesn't need OnLibraryAdded so they defined one of these two things
#if defined UPD_LIBFUNC || defined UPD_OLA
	public void OnLibraryAdded(const char[] name) {
		if (upd_plugin_version[0] != '\0' && StrEqual(name, "updater")) {
			//we can bypass UPD_OnLibraryAdded and go straight for UPD_CheckUpdaterStatus here
			UPD_CheckUpdaterStatus(INVALID_HANDLE, "", "");
		}
	}
#endif


//command listener which prints information to the chat, ALL plugins with this include will respond
public Action print_ddhoward_updater_include_version(int client, const char[] cmdname, int Args) {
	if (client == 0 || CheckCommandAccess(client, "ddhoward_updater_include_versions", ADMFLAG_ROOT, true)) {

		char pluginFilename[PLATFORM_MAX_PATH];
		GetPluginFilename(INVALID_HANDLE, pluginFilename, sizeof(pluginFilename));

		char pluginName[64];
		if (GetPluginInfo(INVALID_HANDLE, PlInfo_Name, pluginName, sizeof(pluginName))) {
			Format(pluginName, sizeof(pluginName), "%s%s", pluginName, " - ");
		}
		
		ReplyToCommand(client, "%s - %s%s %s", _ddhoward_updater_version, pluginName, pluginFilename, upd_plugin_version[0] == '\0' ? "INVALID_VERSION_CONFIGURATION" : upd_plugin_version);
	}
	return Plugin_Continue;
}