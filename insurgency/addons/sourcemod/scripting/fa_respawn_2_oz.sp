 /*
 *	[INS] Player Respawn Script - Player and BOT respawn script for sourcemod plugin.
 *	
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma dynamic 131072 // Increase heap size
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <insurgencydy>
#include <smlib>
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <tf2>
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

// Define grenade index value
#define Gren_M67 68
#define Gren_Incen 73
#define Gren_Molot 74
#define Gren_M18 70
#define Gren_Flash 71
#define Gren_F1 69
#define Gren_IED 72
#define Gren_C4 72
#define Gren_AT4 67
#define Gren_RPG7 61
#define Revive_Indicator_Radius	100.0

// This will be used for checking which team the player is on before repsawning them
#define SPECTATOR_TEAM	0
#define TEAM_SPEC 	1
#define TEAM_1_SEC	2
#define TEAM_2_INS	3

// Navmesh Init 
#define MAX_OBJECTIVES 13
#define MAX_HIDING_SPOTS 4096
#define MIN_PLAYER_DISTANCE 128.0
#define MAX_ENTITIES 2048

#define MAX_LINE_WIDTH 60
#define PLUGIN_VERSION "4.6"

// Counter-Attack Music
#define COUNTER_ATTACK_MUSIC_DURATION 68.0

// KOLOROWE KREDKI 
#define YELLOW 0x01
#define GREEN 0x04

// STATS TIME (SET DAYS AFTER STATS ARE DELETE OF NONACTIVE PLAYERS)
#define PLAYER_STATSOLD 30

#define PLUGIN_DESCRIPTION "Respawn dead players via admincommand or by queues"
#define UPDATE_URL	"http://ins.jballou.com/sourcemod/update-respawn.txt"

// Handle for revive
Handle 	g_hForceRespawn,
		g_hGameConfig;

// Init global variables
int g_iCvar_respawn_enable,
	g_elite_counter_attacks,
	g_finale_counter_spec_enabled,
	g_finale_counter_spec_percent,
	g_iCvar_revive_enable,
	g_counterAttack_min_dur_sec,
	g_counterAttack_max_dur_sec,
	g_iCvar_respawn_type_team_ins,
	g_iCvar_respawn_type_team_sec,
	g_iCvar_respawn_reset_type,
	g_iCvar_enable_track_ammo,
	g_iCvar_counterattack_type,
	g_iCvar_counterattack_vanilla,
	g_iCvar_final_counterattack_type;
float g_fCvar_respawn_delay_team_ins,
	g_respawn_counter_chance,
	g_fCvar_respawn_delay_team_ins_spec;


//Dynamic Respawn cvars
int g_DynamicRespawn_Distance_mult,
	g_dynamicSpawnCounter_Perc,
	g_dynamicSpawn_Perc;

// Fatal dead
float g_fCvar_fatal_chance,
	g_fCvar_fatal_head_chance;
int g_iCvar_fatal_limb_dmg,
	g_iCvar_fatal_head_dmg,
	g_iCvar_fatal_burn_dmg,
	g_iCvar_fatal_explosive_dmg,
	g_iCvar_fatal_chest_stomach,

//Respawn Mode (wave based)
	g_respawn_mode_team_sec,
	g_cacheObjActive = 0,
	//g_checkStaticAmt,
	//g_checkStaticAmtCntr,
	//g_checkStaticAmtAway, - Not being used as commented function out on 10/10
	//g_checkStaticAmtCntrAway, - Not being used as commented function out on 10/10
	g_iReinforceTime,
	g_iReinforceTime_AD_Temp,
	g_iReinforceTimeSubsequent_AD_Temp,
	g_iReinforce_Mult,
	g_iReinforce_Mult_Base,
	g_iRemaining_lives_team_sec,
	g_iRemaining_lives_team_ins,
	g_iRespawn_lives_team_sec,
	g_iRespawn_lives_team_ins,
	g_iRespawnSeconds,
	g_secWave_Timer,
	g_iHeal_amount_paddles,
	g_iHeal_amount_medPack,
	g_nonMedicHeal_amount,
	g_nonMedicRevive_hp,
	g_minorWoundRevive_hp,
	g_modWoundRevive_hp,
	g_critWoundRevive_hp,
	g_minorWound_dmg,
	g_moderateWound_dmg,
	g_medicHealSelf_max,
	g_nonMedicHealSelf_max,
	g_nonMedic_maxHealOther,
	g_minorRevive_time,
	g_modRevive_time,
	g_critRevive_time,
	g_nonMedRevive_time,
	g_botsReady,
	g_isCheckpoint;
float g_flMinPlayerDistance,
	g_flBackSpawnIncrease,
	g_flMaxPlayerDistance,
	g_flCanSeeVectorMultiplier,
	g_flMinObjectiveDistance,
	g_flSpawnAttackDelay;

//Elite bots Counters
int	g_ins_bot_count_checkpoint_max_org,
	g_mp_player_resupply_coop_delay_max_org,
	g_mp_player_resupply_coop_delay_penalty_org,
	g_mp_player_resupply_coop_delay_base_org,
	g_bot_attack_aimpenalty_amt_close_org,
	g_bot_attack_aimpenalty_amt_far_org,
	g_bot_attack_aimpenalty_amt_close_mult,
	g_bot_attack_aimpenalty_amt_far_mult,
	g_coop_delay_penalty_base,
	g_isEliteCounter,
	m_hMyWeapons,
	m_flNextPrimaryAttack,
	m_flNextSecondaryAttack;
 float g_bot_attack_aimpenalty_time_close_org,
	 g_bot_attack_aimpenalty_time_far_org,
	 g_bot_aim_aimtracking_base_org,
	 g_bot_aim_aimtracking_frac_impossible_org,
	 g_bot_aim_angularvelocity_frac_impossible_org,
	 g_bot_aim_angularvelocity_frac_sprinting_target_org,
	 g_bot_aim_attack_aimtolerance_frac_impossible_org,
	 g_bot_attackdelay_frac_difficulty_impossible_org,
	 g_bot_attack_aimtolerance_newthreat_amt_org,
	 g_bot_attack_aimtolerance_newthreat_amt_mult,
	 g_bot_attackdelay_frac_difficulty_impossible_mult,
	 g_bot_attack_aimpenalty_time_close_mult,
	 g_bot_attack_aimpenalty_time_far_mult,
	 g_bot_aim_aimtracking_base,
	 g_bot_aim_aimtracking_frac_impossible,
	 g_bot_aim_angularvelocity_frac_impossible,
	 g_bot_aim_angularvelocity_frac_sprinting_target,
	 g_bot_aim_attack_aimtolerance_frac_impossible;



// STATS DEFINATION FOR PLAYERS
int g_iStatKills[MAXPLAYERS+1],
	g_iStatDeaths[MAXPLAYERS+1],
	g_iStatHeadShots[MAXPLAYERS+1],
	g_iStatSuicides[MAXPLAYERS+1],
	g_iStatRevives[MAXPLAYERS+1],
	g_iStatHeals[MAXPLAYERS+1];

int g_iBeaconBeam,
	g_iBeaconHalo;

// AI Director Variables
int g_AIDir_TeamStatus = 50,
	g_AIDir_TeamStatus_min = 0,
	g_AIDir_TeamStatus_max = 100,
	g_AIDir_BotsKilledReq_mult = 4,
	g_AIDir_BotsKilledCount = 0,
	g_AIDir_AnnounceCounter = 0,
	g_AIDir_ChangeCond_Counter = 0,
	g_AIDir_ChangeCond_Min = 60,
	g_AIDir_ChangeCond_Max = 180,
	g_AIDir_AmbushCond_Counter = 0,
	g_AIDir_AmbushCond_Min = 120,
	g_AIDir_AmbushCond_Max = 300,
	g_AIDir_AmbushCond_Rand = 240,
	g_AIDir_AmbushCond_Chance = 10,
	g_AIDir_ChangeCond_Rand = 180,
	g_AIDir_ReinforceTimer_Orig,
	g_AIDir_ReinforceTimer_SubOrig,
	g_AIDir_DiffChanceBase = 0;
bool g_AIDir_BotReinforceTriggered = false,

// Player respawn
	g_playersReady = false;
float g_fRespawnPosition[3],
	g_badSpawnPos_Track[MAXPLAYERS+1][3],
	g_fDeadPosition[MAXPLAYERS+1][3],
	g_fRagdollPosition[MAXPLAYERS+1][3],
	g_vecOrigin[MAXPLAYERS+1][3];
int g_iEnableRevive = 0,
	g_GiveBonusLives = 0,
	g_iRespawnTimeRemaining[MAXPLAYERS+1],
	g_iReviveRemainingTime[MAXPLAYERS+1],
	g_iReviveNonMedicRemainingTime[MAXPLAYERS+1],
	g_iPlayerRespawnTimerActive[MAXPLAYERS+1],
	g_iSpawnTokens[MAXPLAYERS+1],
	g_iHurtFatal[MAXPLAYERS+1],
	g_iClientRagdolls[MAXPLAYERS+1],
	g_iNearestBody[MAXPLAYERS+1],
	g_botStaticGlobal[MAXPLAYERS+1],
	g_resupplyCounter[MAXPLAYERS+1],
	g_trackKillDeaths[MAXPLAYERS+1],
	g_iRespawnCount[4],
	g_removeBotGrenadeChance = 50,
	g_iPlayerBGroups[MAXPLAYERS+1],
	g_spawnFrandom[MAXPLAYERS+1],
	g_squadSpawnEnabled[MAXPLAYERS+1] = 0,
	g_squadLeader[MAXPLAYERS+1],
	g_LastButtons[MAXPLAYERS+1],

//Ammo Amounts
// Track primary and secondary ammo
	playerClip[MAXPLAYERS + 1][2],

// track player ammo based on weapon slot 0 - 4
	playerAmmo[MAXPLAYERS + 1][4],
	playerPrimary[MAXPLAYERS + 1],
	playerSecondary[MAXPLAYERS + 1],

// Navmesh Init
// Handle g_hHidingSpots = null,
// g_iHidingSpotCount,
// m_iNumControlPoints,
// g_iCPHidingSpots[MAX_OBJECTIVES][MAX_HIDING_SPOTS],
	g_iCPHidingSpotCount[MAX_OBJECTIVES];
// g_iCPLastHidingSpot[MAX_OBJECTIVES],
float m_vCPPositions[MAX_OBJECTIVES][3];

// Status
int g_isMapInit,

//0 is over, 1 is active
	g_iRoundStatus = 0,
	g_clientDamageDone[MAXPLAYERS+1],
	playerPickSquad[MAXPLAYERS + 1],
	g_playerMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerMedicRevivessAccumulated[MAXPLAYERS+1],
	g_playerNonMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerNonMedicRevive[MAXPLAYERS+1],
	g_playerWoundType[MAXPLAYERS+1],
	g_playerWoundTime[MAXPLAYERS+1],
	g_playerActiveWeapon[MAXPLAYERS + 1];
	g_playerFirstJoin[MAXPLAYERS+1];
bool playerRevived[MAXPLAYERS + 1],
	playerInRevivedState[MAXPLAYERS + 1],
	g_preRoundInitial = false,
	g_hintsEnabled[MAXPLAYERS+1] = true;
char g_client_last_classstring[MAXPLAYERS+1][64],
	g_client_org_nickname[MAXPLAYERS+1][64];
//float g_enemyTimerPos[MAXPLAYERS+1][3],	// Kill Stray Enemy Bots Globals - - Not being used as commented function out on 10/10
//	g_enemyTimerAwayPos[MAXPLAYERS+1][3], // Kill Stray Enemy Bots Globals - - Not being used as commented function out on 10/10
 //float g_fPlayerLastChat[MAXPLAYERS+1] = {0.0, ...}; - Commented out on 10/10 due to tag mismatch and suspect may not be needed



// Player Distance Plugin //Credits to author = "Popoklopsi", url = "http://popoklopsi.de"
// unit to use 1 = feet, 0 = meters
int g_iUnitMetric;

ArrayList g_playerArrayList;

// Handle for config
ConVar sm_respawn_enabled;
ConVar sm_revive_enabled;

//AI Director Specific
ConVar sm_ai_director_setdiff_chance_base;

// Respawn delay time
ConVar sm_respawn_delay_team_ins;
ConVar sm_respawn_delay_team_ins_special;
ConVar sm_respawn_delay_team_sec;
ConVar sm_respawn_delay_team_sec_player_count_01;
ConVar sm_respawn_delay_team_sec_player_count_02;
ConVar sm_respawn_delay_team_sec_player_count_03;
ConVar sm_respawn_delay_team_sec_player_count_04;
ConVar sm_respawn_delay_team_sec_player_count_05;
ConVar sm_respawn_delay_team_sec_player_count_06;
ConVar sm_respawn_delay_team_sec_player_count_07;
ConVar sm_respawn_delay_team_sec_player_count_08;
ConVar sm_respawn_delay_team_sec_player_count_09;
ConVar sm_respawn_delay_team_sec_player_count_10;
ConVar sm_respawn_delay_team_sec_player_count_11;
ConVar sm_respawn_delay_team_sec_player_count_12;
ConVar sm_respawn_delay_team_sec_player_count_13;
ConVar sm_respawn_delay_team_sec_player_count_14;
ConVar sm_respawn_delay_team_sec_player_count_15;
ConVar sm_respawn_delay_team_sec_player_count_16;
ConVar sm_respawn_delay_team_sec_player_count_17;
ConVar sm_respawn_delay_team_sec_player_count_18;
ConVar sm_respawn_delay_team_sec_player_count_19;
	
// Respawn Mode (individual or wave based)
ConVar sm_respawn_mode_team_sec;
ConVar sm_respawn_mode_team_ins;

//Wave interval
//Handle sm_respawn_wave_int_team_sec = null,
ConVar sm_respawn_wave_int_team_ins;

// Respawn type
ConVar sm_respawn_type_team_ins;
ConVar sm_respawn_type_team_sec;

// Respawn lives
ConVar sm_respawn_lives_team_sec;
ConVar sm_respawn_lives_team_ins;
ConVar sm_respawn_lives_team_ins_player_count_01;
ConVar sm_respawn_lives_team_ins_player_count_02;
ConVar sm_respawn_lives_team_ins_player_count_03;
ConVar sm_respawn_lives_team_ins_player_count_04;
ConVar sm_respawn_lives_team_ins_player_count_05;
ConVar sm_respawn_lives_team_ins_player_count_06;
ConVar sm_respawn_lives_team_ins_player_count_07;
ConVar sm_respawn_lives_team_ins_player_count_08;
ConVar sm_respawn_lives_team_ins_player_count_09;
ConVar sm_respawn_lives_team_ins_player_count_10;
ConVar sm_respawn_lives_team_ins_player_count_11;
ConVar sm_respawn_lives_team_ins_player_count_12;
ConVar sm_respawn_lives_team_ins_player_count_13;
ConVar sm_respawn_lives_team_ins_player_count_14;
ConVar sm_respawn_lives_team_ins_player_count_15;
ConVar sm_respawn_lives_team_ins_player_count_16;
ConVar sm_respawn_lives_team_ins_player_count_17;
ConVar sm_respawn_lives_team_ins_player_count_18;
ConVar sm_respawn_lives_team_ins_player_count_19;

// Fatal dead
ConVar sm_respawn_fatal_chance;
ConVar sm_respawn_fatal_head_chance;
ConVar sm_respawn_fatal_limb_dmg;
ConVar sm_respawn_fatal_head_dmg;
ConVar sm_respawn_fatal_burn_dmg;
ConVar sm_respawn_fatal_explosive_dmg;
ConVar sm_respawn_fatal_chest_stomach;

// Counter-attack
ConVar sm_respawn_counterattack_type;
ConVar sm_respawn_counterattack_vanilla;
ConVar sm_respawn_final_counterattack_type;
ConVar sm_respawn_security_on_counter;
ConVar sm_respawn_counter_chance;
ConVar sm_respawn_min_counter_dur_sec;
ConVar sm_respawn_max_counter_dur_sec;
ConVar sm_respawn_final_counter_dur_sec;

//Dynamic Respawn Mechanics
ConVar sm_respawn_dynamic_distance_multiplier;
ConVar sm_respawn_dynamic_spawn_counter_percent;
ConVar sm_respawn_dynamic_spawn_percent;

// Misc
ConVar sm_respawn_reset_type;
ConVar sm_respawn_enable_track_ammo;

// Reinforcements
ConVar sm_respawn_reinforce_time;
ConVar sm_respawn_reinforce_time_subsequent;
ConVar sm_respawn_reinforce_multiplier;
ConVar sm_respawn_reinforce_multiplier_base;

// Monitor static enemy
//ConVar sm_respawn_check_static_enemy;//= null,
//ConVar sm_respawn_check_static_enemy_counter;//= null;

// Donor tag
ConVar sm_respawn_enable_donor_tag;

// Medic specific
ConVar sm_revive_seconds;
ConVar sm_revive_distance_metric;
ConVar sm_heal_cap_for_bonus;
ConVar sm_revive_cap_for_bonus;
ConVar sm_reward_medics_enabled;
ConVar sm_heal_amount_medpack;
ConVar sm_heal_amount_paddles;
ConVar sm_non_medic_heal_amt;
ConVar sm_non_medic_revive_hp;
ConVar sm_medic_minor_revive_hp;
ConVar sm_medic_moderate_revive_hp;
ConVar sm_medic_critical_revive_hp;
ConVar sm_minor_wound_dmg;
ConVar sm_moderate_wound_dmg;
ConVar sm_medic_heal_self_max;
ConVar sm_non_medic_max_heal_other;
ConVar sm_minor_revive_time;
ConVar sm_moderate_revive_time;
ConVar sm_critical_revive_time;
ConVar sm_non_medic_revive_time;
ConVar sm_non_medic_heal_self_max;
ConVar sm_elite_counter_attacks;
ConVar sm_enable_bonus_lives;
ConVar sm_finale_counter_spec_enabled;
ConVar sm_finale_counter_spec_percent;

// NAV MESH SPECIFIC CVARS
//1 = Spawn in ins_spawnpoints, 2 = any spawnpoints that meets criteria, 0 = only at normal spawnpoints at next objective
ConVar cvarSpawnMode;
//Min/max distance from players to spawn
ConVar cvarMinPlayerDistance;
//Adds to the minplayerdistance cvar when spawning behind player.
ConVar cvarBackSpawnIncrease;
//Attack delay for spawning bots
ConVar cvarSpawnAttackDelay;
//Min/max distance from next objective to spawn
ConVar cvarMinObjectiveDistance;
//Min/max distance from next objective to spawn
ConVar cvarMaxObjectiveDistance;
//Min/max distance from next objective to spawn using nav
ConVar cvarMaxObjectiveDistanceNav;
//CanSeeVector Multiplier divide this by cvarMaxPlayerDistance
ConVar cvarCanSeeVectorMultiplier;
//Delay to resupply
ConVar sm_resupply_delay;
//Min/max distance from players to spawn
ConVar cvarMaxPlayerDistance;

// Plugin info
public Plugin myinfo =
{
	name = "[INS] Player Respawn",
	author = "Jared Ballou (Contributor: Daimyo, naong, ozzy and community members)",
	version = PLUGIN_VERSION,
	description = PLUGIN_DESCRIPTION,
	url = "http://jballou.com"
};

// Start plugin
public void OnPluginStart()
{
	//Create player array list
	g_playerArrayList = new ArrayList();	

	CreateConVar("sm_respawn_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_respawn_enabled = CreateConVar("sm_respawn_enabled", "1", "Automatically respawn players when they die; 0 - disabled, 1 - enabled");
	sm_revive_enabled = CreateConVar("sm_revive_enabled", "1", "Reviving enabled from medics?  This creates revivable ragdoll after death; 0 - disabled, 1 - enabled");
	
	// Nav Mesh Botspawn specific START
	cvarSpawnMode = CreateConVar("sm_botspawns_spawn_mode", "1", "Only normal spawnpoints at the objective, the old way (0), spawn in hiding spots following rules (1)", FCVAR_NOTIFY);
	//cvarMinCounterattackDistance = CreateConVar("sm_botspawns_min_counterattack_distance", "3600.0", "Min distance from counterattack objective to spawn", FCVAR_NOTIFY);
	cvarMinPlayerDistance = CreateConVar("sm_botspawns_min_player_distance", "240.0", "Min distance from players to spawn", FCVAR_NOTIFY);
	cvarMaxPlayerDistance = CreateConVar("sm_botspawns_max_player_distance", "16000.0", "Max distance from players to spawn", FCVAR_NOTIFY);
	cvarCanSeeVectorMultiplier = CreateConVar("sm_botpawns_can_see_vect_mult", "1.5", "Divide this with sm_botspawns_max_player_distance to get CanSeeVector allowed distance for bot spawning in LOS", FCVAR_NOTIFY);
	cvarMinObjectiveDistance = CreateConVar("sm_botspawns_min_objective_distance", "240", "Min distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistance = CreateConVar("sm_botspawns_max_objective_distance", "12000", "Max distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistanceNav = CreateConVar("sm_botspawns_max_objective_distance_nav", "2000", "Max distance from next objective to spawn", FCVAR_NOTIFY);
	cvarBackSpawnIncrease = CreateConVar("sm_botspawns_backspawn_increase", "1400.0", "Whenever bot spawn on last point, this is added to minimum player respawn distance to avoid spawning too close to player.", FCVAR_NOTIFY);	
	cvarSpawnAttackDelay = CreateConVar("sm_botspawns_spawn_attack_delay", "2", "Delay in seconds for spawning bots to wait before firing.", FCVAR_NOTIFY);
	// Nav Mesh Botspawn specific END

	// Respawn delay time
	sm_respawn_delay_team_ins = CreateConVar("sm_respawn_delay_team_ins", 
		"1.0", "How many seconds to delay the respawn (bots)");
	sm_respawn_delay_team_ins_special = CreateConVar("sm_respawn_delay_team_ins_special", 
		"20.0", "How many seconds to delay the respawn (special bots)");
	sm_respawn_delay_team_sec = CreateConVar("sm_respawn_delay_team_sec", 
		"30.0", "How many seconds to delay the respawn (If not set 'sm_respawn_delay_team_sec_player_count_XX' uses this value)");
	sm_respawn_delay_team_sec_player_count_01 = CreateConVar("sm_respawn_delay_team_sec_player_count_01", 
		"5.0", "How many seconds to delay the respawn (when player count is 1)");
	sm_respawn_delay_team_sec_player_count_02 = CreateConVar("sm_respawn_delay_team_sec_player_count_02", 
		"10.0", "How many seconds to delay the respawn (when player count is 2)");
	sm_respawn_delay_team_sec_player_count_03 = CreateConVar("sm_respawn_delay_team_sec_player_count_03", 
		"20.0", "How many seconds to delay the respawn (when player count is 3)");
	sm_respawn_delay_team_sec_player_count_04 = CreateConVar("sm_respawn_delay_team_sec_player_count_04", 
		"30.0", "How many seconds to delay the respawn (when player count is 4)");
	sm_respawn_delay_team_sec_player_count_05 = CreateConVar("sm_respawn_delay_team_sec_player_count_05", 
		"60.0", "How many seconds to delay the respawn (when player count is 5)");
	sm_respawn_delay_team_sec_player_count_06 = CreateConVar("sm_respawn_delay_team_sec_player_count_06",
		"60.0", "How many seconds to delay the respawn (when player count is 6)");
	sm_respawn_delay_team_sec_player_count_07 = CreateConVar("sm_respawn_delay_team_sec_player_count_07", 
		"70.0", "How many seconds to delay the respawn (when player count is 7)");
	sm_respawn_delay_team_sec_player_count_08 = CreateConVar("sm_respawn_delay_team_sec_player_count_08", 
		"70.0", "How many seconds to delay the respawn (when player count is 8)");
	sm_respawn_delay_team_sec_player_count_09 = CreateConVar("sm_respawn_delay_team_sec_player_count_09", 
		"80.0", "How many seconds to delay the respawn (when player count is 9)");
	sm_respawn_delay_team_sec_player_count_10 = CreateConVar("sm_respawn_delay_team_sec_player_count_10", 
		"80.0", "How many seconds to delay the respawn (when player count is 10)");
	sm_respawn_delay_team_sec_player_count_11 = CreateConVar("sm_respawn_delay_team_sec_player_count_11", 
		"90.0", "How many seconds to delay the respawn (when player count is 11)");
	sm_respawn_delay_team_sec_player_count_12 = CreateConVar("sm_respawn_delay_team_sec_player_count_12", 
		"90.0", "How many seconds to delay the respawn (when player count is 12)");
	sm_respawn_delay_team_sec_player_count_13 = CreateConVar("sm_respawn_delay_team_sec_player_count_13", 
		"100.0", "How many seconds to delay the respawn (when player count is 13)");
	sm_respawn_delay_team_sec_player_count_14 = CreateConVar("sm_respawn_delay_team_sec_player_count_14", 
		"100.0", "How many seconds to delay the respawn (when player count is 14)");
	sm_respawn_delay_team_sec_player_count_15 = CreateConVar("sm_respawn_delay_team_sec_player_count_15", 
		"110.0", "How many seconds to delay the respawn (when player count is 15)");
	sm_respawn_delay_team_sec_player_count_16 = CreateConVar("sm_respawn_delay_team_sec_player_count_16", 
		"110.0", "How many seconds to delay the respawn (when player count is 16)");
	sm_respawn_delay_team_sec_player_count_17 = CreateConVar("sm_respawn_delay_team_sec_player_count_17", 
		"120.0", "How many seconds to delay the respawn (when player count is 17)");
	sm_respawn_delay_team_sec_player_count_18 = CreateConVar("sm_respawn_delay_team_sec_player_count_18", 
		"120.0", "How many seconds to delay the respawn (when player count is 18)");
	sm_respawn_delay_team_sec_player_count_19 = CreateConVar("sm_respawn_delay_team_sec_player_count_19", 
		"130.0", "How many seconds to delay the respawn (when player count is 19)");
	
	// Respawn type
	sm_respawn_type_team_sec = CreateConVar("sm_respawn_type_team_sec", 
		"1", "1 - individual lives, 2 - each team gets a pool of lives used by everyone, sm_respawn_lives_team_sec must be > 0");
	sm_respawn_type_team_ins = CreateConVar("sm_respawn_type_team_ins", 
		"2", "1 - individual lives, 2 - each team gets a pool of lives used by everyone, sm_respawn_lives_team_ins must be > 0");
	
	// Respawn lives
	sm_respawn_lives_team_sec = CreateConVar("sm_respawn_lives_team_sec", 
		"-1", "Respawn players this many times (-1: Disables player respawn)");
	sm_respawn_lives_team_ins = CreateConVar("sm_respawn_lives_team_ins", 
		"10", "If 'sm_respawn_type_team_ins' set 1, respawn bots this many times. If 'sm_respawn_type_team_ins' set 2, total bot count (If not set 'sm_respawn_lives_team_ins_player_count_XX' uses this value)");
	sm_respawn_lives_team_ins_player_count_01 = CreateConVar("sm_respawn_lives_team_ins_player_count_01", 
		"5", "Total bot count (when player count is 1)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_02 = CreateConVar("sm_respawn_lives_team_ins_player_count_02", 
		"10", "Total bot count (when player count is 2)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_03 = CreateConVar("sm_respawn_lives_team_ins_player_count_03", 
		"15", "Total bot count (when player count is 3)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_04 = CreateConVar("sm_respawn_lives_team_ins_player_count_04", 
		"20", "Total bot count (when player count is 4)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_05 = CreateConVar("sm_respawn_lives_team_ins_player_count_05", 
		"25", "Total bot count (when player count is 5)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_06 = CreateConVar("sm_respawn_lives_team_ins_player_count_06", 
		"30", "Total bot count (when player count is 6)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_07 = CreateConVar("sm_respawn_lives_team_ins_player_count_07", 
		"35", "Total bot count (when player count is 7)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_08 = CreateConVar("sm_respawn_lives_team_ins_player_count_08", 
		"40", "Total bot count (when player count is 8)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_09 = CreateConVar("sm_respawn_lives_team_ins_player_count_09", 
		"45", "Total bot count (when player count is 9)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_10 = CreateConVar("sm_respawn_lives_team_ins_player_count_10", 
		"50", "Total bot count (when player count is 10)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_11 = CreateConVar("sm_respawn_lives_team_ins_player_count_11", 
		"55", "Total bot count (when player count is 11)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_12 = CreateConVar("sm_respawn_lives_team_ins_player_count_12", 
		"60", "Total bot count (when player count is 12)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_13 = CreateConVar("sm_respawn_lives_team_ins_player_count_13", 
		"65", "Total bot count (when player count is 13)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_14 = CreateConVar("sm_respawn_lives_team_ins_player_count_14", 
		"70", "Total bot count (when player count is 14)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_15 = CreateConVar("sm_respawn_lives_team_ins_player_count_15", 
		"75", "Total bot count (when player count is 15)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_16 = CreateConVar("sm_respawn_lives_team_ins_player_count_16", 
		"80", "Total bot count (when player count is 16)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_17 = CreateConVar("sm_respawn_lives_team_ins_player_count_17", 
		"85", "Total bot count (when player count is 17)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_18 = CreateConVar("sm_respawn_lives_team_ins_player_count_18", 
		"90", "Total bot count (when player count is 18)(sm_respawn_type_team_ins must be 2)");
	sm_respawn_lives_team_ins_player_count_19 = CreateConVar("sm_respawn_lives_team_ins_player_count_19", 
		"90", "Total bot count (when player count is 19)(sm_respawn_type_team_ins must be 2)");
	
	// Fatally death
	sm_respawn_fatal_chance = CreateConVar("sm_respawn_fatal_chance", "0.20", "Chance for a kill to be fatal, 0.6 default = 60% chance to be fatal (To disable set 0.0)");
	sm_respawn_fatal_head_chance = CreateConVar("sm_respawn_fatal_head_chance", "0.30", "Chance for a headshot kill to be fatal, 0.6 default = 60% chance to be fatal");
	sm_respawn_fatal_limb_dmg = CreateConVar("sm_respawn_fatal_limb_dmg", "80", "Amount of damage to fatally kill player in limb");
	sm_respawn_fatal_head_dmg = CreateConVar("sm_respawn_fatal_head_dmg", "100", "Amount of damage to fatally kill player in head");
	sm_respawn_fatal_burn_dmg = CreateConVar("sm_respawn_fatal_burn_dmg", "50", "Amount of damage to fatally kill player in burn");
	sm_respawn_fatal_explosive_dmg = CreateConVar("sm_respawn_fatal_explosive_dmg", "200", "Amount of damage to fatally kill player in explosive");
	sm_respawn_fatal_chest_stomach = CreateConVar("sm_respawn_fatal_chest_stomach", "100", "Amount of damage to fatally kill player in chest/stomach");
	
	// Counter attack
	sm_respawn_counter_chance = CreateConVar("sm_respawn_counter_chance", "0.5", "Percent chance that a counter attack will happen def: 50%");
	sm_respawn_counterattack_type = CreateConVar("sm_respawn_counterattack_type", "2", "Respawn during counterattack? (0: no, 1: yes, 2: infinite)");
	sm_respawn_final_counterattack_type = CreateConVar("sm_respawn_final_counterattack_type", "2", "Respawn during final counterattack? (0: no, 1: yes, 2: infinite)");
	sm_respawn_security_on_counter = CreateConVar("sm_respawn_security_on_counter", "1", "0/1 When a counter attack starts, spawn all dead players and teleport them to point to defend");
	sm_respawn_min_counter_dur_sec = CreateConVar("sm_respawn_min_counter_dur_sec", "66", "Minimum randomized counter attack duration");
	sm_respawn_max_counter_dur_sec = CreateConVar("sm_respawn_max_counter_dur_sec", "126", "Maximum randomized counter attack duration");
	sm_respawn_final_counter_dur_sec = CreateConVar("sm_respawn_final_counter_dur_sec", "180", "Final counter attack duration");
	sm_respawn_counterattack_vanilla = CreateConVar("sm_respawn_counterattack_vanilla", "0", "Use vanilla counter attack mechanics? (0: no, 1: yes)");
	
	//Dynamic respawn mechanics
	sm_respawn_dynamic_distance_multiplier = CreateConVar("sm_respawn_dynamic_distance_multiplier", "2", "This multiplier is used to make bot distance from points on/off counter attacks more dynamic by making distance closer/farther when bots respawn");
	sm_respawn_dynamic_spawn_counter_percent = CreateConVar("sm_respawn_dynamic_spawn_counter_percent", "40", "Percent of bots that will spawn farther away on a counter attack (basically their more ideal normal spawns)");
	sm_respawn_dynamic_spawn_percent = CreateConVar("sm_respawn_dynamic_spawn_percent", "5", "Percent of bots that will spawn farther away NOT on a counter (basically their more ideal normal spawns)");
	
	// Misc
	sm_respawn_reset_type = CreateConVar("sm_respawn_reset_type", "0", "Set type of resetting player respawn counts: each round or each objective (0: each round, 1: each objective)");
	sm_respawn_enable_track_ammo = CreateConVar("sm_respawn_enable_track_ammo", "1", "0/1 Track ammo on death to revive (may be buggy if using a different theatre that modifies ammo)");
	
	// Reinforcements
	sm_respawn_reinforce_time = CreateConVar("sm_respawn_reinforce_time", "200", "When enemy forces are low on lives, how much time til they get reinforcements?");
	sm_respawn_reinforce_time_subsequent = CreateConVar("sm_respawn_reinforce_time_subsequent", "140", "When enemy forces are low on lives and already reinforced, how much time til they get reinforcements on subsequent reinforcement?");
	sm_respawn_reinforce_multiplier = CreateConVar("sm_respawn_reinforce_multiplier", "4", "Division multiplier to determine when to start reinforce timer for bots based on team pool lives left over");
	sm_respawn_reinforce_multiplier_base = CreateConVar("sm_respawn_reinforce_multiplier_base", "10", "This is the base int number added to the division multiplier, so (10 * reinforce_mult + base_mult)");

	// Control static enemy
	//sm_respawn_check_static_enemy = CreateConVar("sm_respawn_check_static_enemy", "120", "Seconds amount to check if an AI has moved probably stuck");
	//sm_respawn_check_static_enemy_counter = CreateConVar("sm_respawn_check_static_enemy_counter", "10", "Seconds amount to check if an AI has moved during counter");
	
	// Donor tag
	sm_respawn_enable_donor_tag = CreateConVar("sm_respawn_enable_donor_tag", "1", "If player has an access to reserved slot, add [DONOR] tag.");
		
	// Medic Revive
	sm_revive_seconds = CreateConVar("sm_revive_seconds", "5", "Time in seconds medic needs to stand over body to revive");
	sm_revive_distance_metric = CreateConVar("sm_revive_distance_metric", "1", "Distance metric (0: meters / 1: feet)");
	sm_heal_cap_for_bonus = CreateConVar("sm_heal_cap_for_bonus", "5000", "Amount of health given to other players to gain a life");
	sm_revive_cap_for_bonus = CreateConVar("sm_revive_cap_for_bonus", "50", "Amount of revives before medic gains a life");
	sm_reward_medics_enabled = CreateConVar("sm_reward_medics_enabled", "1", "Enabled rewarding medics with lives? 0 = no, 1 = yes");
	sm_heal_amount_medpack = CreateConVar("sm_heal_amount_medpack", "5", "Heal amount per 0.5 seconds when using medpack");
	sm_heal_amount_paddles = CreateConVar("sm_heal_amount_paddles", "3", "Heal amount per 0.5 seconds when using paddles");
	sm_non_medic_heal_amt = CreateConVar("sm_non_medic_heal_amt", "2", "Heal amount per 0.5 seconds when non-medic");
	sm_non_medic_revive_hp = CreateConVar("sm_non_medic_revive_hp", "10", "Health given to target revive when non-medic reviving");
	sm_medic_minor_revive_hp = CreateConVar("sm_medic_minor_revive_hp", "75", "Health given to target revive when medic reviving minor wound");
	sm_medic_moderate_revive_hp = CreateConVar("sm_medic_moderate_revive_hp", "50", "Health given to target revive when medic reviving moderate wound");
	sm_medic_critical_revive_hp = CreateConVar("sm_medic_critical_revive_hp", "25", "Health given to target revive when medic reviving critical wound");
	sm_minor_wound_dmg = CreateConVar("sm_minor_wound_dmg", "100", "Any amount of damage <= to this is considered a minor wound when killed");
	sm_moderate_wound_dmg = CreateConVar("sm_moderate_wound_dmg", "200", "Any amount of damage <= to this is considered a minor wound when killed.  Anything greater is CRITICAL");
	sm_medic_heal_self_max = CreateConVar("sm_medic_heal_self_max", "75", "Max medic can heal self to with med pack");
	sm_non_medic_heal_self_max = CreateConVar("sm_non_medic_heal_self_max", "25", "Max non-medic can heal self to with med pack");
	sm_non_medic_max_heal_other = CreateConVar("sm_non_medic_max_heal_other", "25", "Heal amount per 0.5 seconds when using paddles");
	sm_minor_revive_time = CreateConVar("sm_minor_revive_time", "4", "Seconds it takes medic to revive minor wounded");
	sm_moderate_revive_time = CreateConVar("sm_moderate_revive_time", "7", "Seconds it takes medic to revive moderate wounded");
	sm_critical_revive_time = CreateConVar("sm_critical_revive_time", "10", "Seconds it takes medic to revive critical wounded");
	sm_non_medic_revive_time = CreateConVar("sm_non_medic_revive_time", "30", "Seconds it takes non-medic to revive minor wounded, requires medpack");
	sm_resupply_delay = CreateConVar("sm_resupply_delay", "5", "Delay loop for resupply ammo");
	sm_elite_counter_attacks = CreateConVar("sm_elite_counter_attacks", "1", "Enable increased bot skills, numbers on counters?");
	sm_enable_bonus_lives = CreateConVar("sm_enable_bonus_lives", "1", "Give bonus lives based on X condition? 0|1 ");
	
	//Specialized Counter
	sm_finale_counter_spec_enabled = CreateConVar("sm_finale_counter_spec_enabled", "0", "Enable specialized finale spawn percent? 1|0");
	sm_finale_counter_spec_percent = CreateConVar("sm_finale_counter_spec_percent", "40", "What specialized finale counter percent for this map?");

	//AI Director cvars
	sm_ai_director_setdiff_chance_base = CreateConVar("sm_ai_director_setdiff_chance_base", "10", "Base AI Director Set Hard Difficulty Chance");

	//Respawn Modes
	sm_respawn_mode_team_sec = CreateConVar("sm_respawn_mode_team_sec", "1", "Security: 0 = Individual spawning | 1 = Wave based spawning");
	sm_respawn_mode_team_ins = CreateConVar("sm_respawn_mode_team_ins", "0", "Insurgents: 0 = Individual spawning | 1 = Wave based spawning");

	//Wave interval for insurgents only
	sm_respawn_wave_int_team_ins = CreateConVar("sm_respawn_wave_int_team_ins", "1", "Time in seconds bots will respawn in waves");
	
	if ((m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1)	
		SetFailState("Fatal Error: Unable to find property offset \"CBasePlayer::m_hMyWeapons\" !");
	
	if ((m_flNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack")) == -1) 
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextPrimaryAttack\" !");
	
	if ((m_flNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack")) == -1) 	
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextSecondaryAttack\" !");

	// Add admin respawn console command
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "sm_respawn <#userid|name>");
	// Add reload config console command for admin
	RegAdminCmd("sm_respawn_reload", Command_Reload, ADMFLAG_SLAY, "sm_respawn_reload");
	// register roundend admin commands
	//RegAdminCmd("!discord", Discord_Info, "!discord");

	// Event hooking
	//For ins_spawnpoint spawning
	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_spawn", Event_SpawnPost, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt_Pre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_end", Event_RoundEnd_Pre, EventHookMode_Pre);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("object_destroyed", Event_ObjectDestroyed_Pre, EventHookMode_Pre);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("object_destroyed", Event_ObjectDestroyed_Post, EventHookMode_Post);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured_Pre, EventHookMode_Pre);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured_Post, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect);
	HookEvent("weapon_reload", Event_PlayerReload_Pre, EventHookMode_Pre);

	// NavMesh Botspawn Specific Start
	cvarSpawnMode.AddChangeHook(CvarChange);
	// NavMesh Botspawn Specific End
	
	// Revive/Heal specific
	sm_revive_seconds.AddChangeHook(CvarChange);
	sm_heal_amount_medpack.AddChangeHook(CvarChange);
	sm_non_medic_heal_amt.AddChangeHook(CvarChange);
	sm_non_medic_revive_hp.AddChangeHook(CvarChange);
	sm_medic_minor_revive_hp.AddChangeHook(CvarChange);
	sm_medic_moderate_revive_hp.AddChangeHook(CvarChange);
	sm_medic_critical_revive_hp.AddChangeHook(CvarChange);
	sm_minor_wound_dmg.AddChangeHook(CvarChange);
	sm_moderate_wound_dmg.AddChangeHook(CvarChange);
	sm_medic_heal_self_max.AddChangeHook(CvarChange);
	sm_non_medic_heal_self_max.AddChangeHook(CvarChange);
	sm_non_medic_max_heal_other.AddChangeHook(CvarChange);
	sm_minor_revive_time.AddChangeHook(CvarChange);
	sm_moderate_revive_time.AddChangeHook(CvarChange);
	sm_critical_revive_time.AddChangeHook(CvarChange);
	sm_non_medic_revive_time.AddChangeHook(CvarChange);
	
	// Respawn specific
	sm_respawn_enabled.AddChangeHook(EnableChanged);
	sm_revive_enabled.AddChangeHook(EnableChanged);
	sm_respawn_delay_team_sec.AddChangeHook(CvarChange);
	sm_respawn_delay_team_ins.AddChangeHook(CvarChange);
	sm_respawn_delay_team_ins_special.AddChangeHook(CvarChange);
	sm_respawn_lives_team_sec.AddChangeHook(CvarChange);
	sm_respawn_lives_team_ins.AddChangeHook(CvarChange);
	sm_respawn_reset_type.AddChangeHook(CvarChange);
	sm_respawn_type_team_sec.AddChangeHook(CvarChange);
	sm_respawn_type_team_ins.AddChangeHook(CvarChange);
	cvarMinPlayerDistance.AddChangeHook(CvarChange);
	cvarBackSpawnIncrease.AddChangeHook(CvarChange);
	cvarMaxPlayerDistance.AddChangeHook(CvarChange);
	cvarCanSeeVectorMultiplier.AddChangeHook(CvarChange);
	cvarMinObjectiveDistance.AddChangeHook(CvarChange);
	cvarMaxObjectiveDistance.AddChangeHook(CvarChange);
	cvarMaxObjectiveDistanceNav.AddChangeHook(CvarChange);
	sm_enable_bonus_lives.AddChangeHook(CvarChange);

	//Dynamic respawning
	sm_respawn_dynamic_distance_multiplier.AddChangeHook(CvarChange);
	sm_respawn_dynamic_spawn_counter_percent.AddChangeHook(CvarChange);
	sm_respawn_dynamic_spawn_percent.AddChangeHook(CvarChange);

	 //Reinforce Timer
	sm_respawn_reinforce_time.AddChangeHook(CvarChange);
	sm_respawn_reinforce_time_subsequent.AddChangeHook(CvarChange);
	sm_respawn_reinforce_multiplier.AddChangeHook(CvarChange);
	sm_respawn_reinforce_multiplier_base.AddChangeHook(CvarChange);

	// Tags
	FindConVar("sv_tags").AddChangeHook(TagsChanged);

	//Other
	sm_elite_counter_attacks.AddChangeHook(CvarChange);
	sm_finale_counter_spec_enabled.AddChangeHook(CvarChange);
	sm_ai_director_setdiff_chance_base.AddChangeHook(CvarChange);
	sm_respawn_mode_team_sec.AddChangeHook(CvarChange);
	sm_respawn_mode_team_ins.AddChangeHook(CvarChange);
	sm_respawn_wave_int_team_ins.AddChangeHook(CvarChange);
	sm_finale_counter_spec_percent.AddChangeHook(CvarChange);
	
	// Init respawn function
	// Next 14 lines of text are taken from Andersso's DoDs respawn plugin. Thanks :)
	
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	
	if (g_hGameConfig == null)
		SetFailState("Fatal Error: Missing File \"insurgency.games\"!");

	StartPrepSDKCall(SDKCall_Player);
	char game[40];
	GetGameFolderName(game, sizeof(game));

	if (StrEqual(game, "insurgency"))
	{
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	}
	
	g_hForceRespawn = EndPrepSDKCall();
	if (g_hForceRespawn == INVALID_HANDLE)
	{
		SetFailState("Fatal Error: Unable to find signature for \"ForceRespawn\"!");
	}

	//Load localization file
	LoadTranslations("common.phrases");
	LoadTranslations("respawn.phrases");
	LoadTranslations("nearest_player.phrases.txt");
	AutoExecConfig(true, "respawn");
}

// When cvar changed
void EnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int intNewValue = StringToInt(newValue);
	int intOldValue = StringToInt(oldValue);

	if(intNewValue == 1 && intOldValue == 0)
	{
		TagsCheck("respawntimes");
	}
	else if(intNewValue == 0 && intOldValue == 1)
	{
		TagsCheck("respawntimes", true);
	}
}

// When cvar changed
void CvarChange(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	UpdateRespawnCvars();
}

// Update cvars
void UpdateRespawnCvars()
{
	//Counter attack chance based on number of points
	g_respawn_counter_chance = sm_respawn_counter_chance.FloatValue;
	g_counterAttack_min_dur_sec = sm_respawn_min_counter_dur_sec.IntValue;
	g_counterAttack_max_dur_sec = sm_respawn_max_counter_dur_sec.IntValue;

	// The number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	if (ncp < 6)
	{
		//Add to minimum dur as well.
		int fRandomInt = GetRandomInt(15, 30);
		int fRandomInt2 = GetRandomInt(6, 12);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.2;
	}
	else if (ncp >= 6 && ncp <= 8)
	{
		//Add to minimum dur as well.
		int fRandomInt = GetRandomInt(10, 20);
		int fRandomInt2 = GetRandomInt(4, 8);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.1;
	}

	g_elite_counter_attacks = sm_elite_counter_attacks.IntValue;
	g_finale_counter_spec_enabled = sm_finale_counter_spec_enabled.IntValue;
	g_finale_counter_spec_percent = sm_finale_counter_spec_percent.IntValue;

	//Ai Director UpdateCvar
	g_AIDir_DiffChanceBase = sm_ai_director_setdiff_chance_base.IntValue;

	//Wave Based Spawning
	g_respawn_mode_team_sec = sm_respawn_mode_team_sec.IntValue;
	
	// Respawn type 1 //TEAM_1_SEC == Index 2 and TEAM_2_INS == Index 3
	g_iRespawnCount[2] = sm_respawn_lives_team_sec.IntValue;
	g_iRespawnCount[3] = sm_respawn_lives_team_ins.IntValue;
	g_GiveBonusLives = sm_enable_bonus_lives.IntValue;

	//Give bonus lives if lives are added per round
	if (g_GiveBonusLives && g_iCvar_respawn_reset_type == 0)
		SecTeamLivesBonus();
	
	
	// Type of resetting respawn token, Non-checkpoint modes get set to 0 automatically
	g_iCvar_respawn_reset_type = sm_respawn_reset_type.IntValue;

	if (g_isCheckpoint == 0) 
		g_iCvar_respawn_reset_type = 0;
	

	// Update Cvars
	g_iCvar_respawn_enable = sm_respawn_enabled.IntValue;
	g_iCvar_revive_enable = sm_revive_enabled.IntValue;
	// Bot spawn mode

	g_iReinforce_Mult = sm_respawn_reinforce_multiplier.IntValue;
	g_iReinforce_Mult_Base = sm_respawn_reinforce_multiplier_base.IntValue;

	// Tracking ammo
	g_iCvar_enable_track_ammo = sm_respawn_enable_track_ammo.IntValue;

	// Respawn type
	g_iCvar_respawn_type_team_ins = sm_respawn_type_team_ins.IntValue;
	g_iCvar_respawn_type_team_sec = sm_respawn_type_team_sec.IntValue;


	//Dynamic Respawns
	g_DynamicRespawn_Distance_mult = sm_respawn_dynamic_distance_multiplier.IntValue;
	g_dynamicSpawnCounter_Perc = sm_respawn_dynamic_spawn_counter_percent.IntValue;
	g_dynamicSpawn_Perc = sm_respawn_dynamic_spawn_percent.IntValue;

	//Revive counts

	// Heal Amount
	g_iHeal_amount_medPack = sm_heal_amount_medpack.IntValue;
	g_iHeal_amount_paddles = sm_heal_amount_paddles.IntValue;
	g_nonMedicHeal_amount = sm_non_medic_heal_amt.IntValue;

	//HP when revived from wound
	g_nonMedicRevive_hp = sm_non_medic_revive_hp.IntValue;
	g_minorWoundRevive_hp = sm_medic_minor_revive_hp.IntValue;
	g_modWoundRevive_hp = sm_medic_moderate_revive_hp.IntValue;
	g_critWoundRevive_hp = sm_medic_critical_revive_hp.IntValue;

	//New Revive Mechanics
	g_minorWound_dmg = sm_minor_wound_dmg.IntValue;
	g_moderateWound_dmg = sm_moderate_wound_dmg.IntValue;
	g_medicHealSelf_max = sm_medic_heal_self_max.IntValue;
	g_nonMedicHealSelf_max = sm_non_medic_heal_self_max.IntValue;
	g_nonMedic_maxHealOther = sm_non_medic_max_heal_other.IntValue;
	g_minorRevive_time = sm_minor_revive_time.IntValue;
	g_modRevive_time = sm_moderate_revive_time.IntValue;
	g_critRevive_time = sm_critical_revive_time.IntValue;
	g_nonMedRevive_time = sm_non_medic_revive_time.IntValue;

	// Fatal dead
	g_fCvar_fatal_chance = sm_respawn_fatal_chance.FloatValue;
	g_fCvar_fatal_head_chance = sm_respawn_fatal_head_chance.FloatValue;
	g_iCvar_fatal_limb_dmg = sm_respawn_fatal_limb_dmg.IntValue;
	g_iCvar_fatal_head_dmg = sm_respawn_fatal_head_dmg.IntValue;
	g_iCvar_fatal_burn_dmg = sm_respawn_fatal_burn_dmg.IntValue;
	g_iCvar_fatal_explosive_dmg = sm_respawn_fatal_explosive_dmg.IntValue;
	g_iCvar_fatal_chest_stomach = sm_respawn_fatal_chest_stomach.IntValue;

	// Nearest body distance metric
	g_iUnitMetric = sm_revive_distance_metric.IntValue;
	
	// Set respawn delay time
	g_iRespawnSeconds = -1;
	switch (GetTeamSecCount())
	{
		case 0: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_01.IntValue;
		case 1: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_01.IntValue;
		case 2: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_02.IntValue;
		case 3: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_03.IntValue;
		case 4: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_04.IntValue;
		case 5: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_05.IntValue;
		case 6: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_06.IntValue;
		case 7: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_07.IntValue;
		case 8: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_08.IntValue;
		case 9: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_09.IntValue;
		case 10: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_10.IntValue;
		case 11: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_11.IntValue;
		case 12: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_12.IntValue;
		case 13: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_13.IntValue;
		case 14: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_14.IntValue;
		case 15: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_15.IntValue;
		case 16: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_16.IntValue;
		case 17: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_17.IntValue;
		case 18: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_18.IntValue;
		case 19: g_iRespawnSeconds = sm_respawn_delay_team_sec_player_count_19.IntValue;
	}
	// If not set use default
	if (g_iRespawnSeconds == -1)
		g_iRespawnSeconds = sm_respawn_delay_team_sec.IntValue;
	
	// Respawn type 2 for players
	if (g_iCvar_respawn_type_team_sec == 2)
	{
		g_iRespawn_lives_team_sec = sm_respawn_lives_team_sec.IntValue;
	}

	// Respawn type 2 for bots
	else if (g_iCvar_respawn_type_team_ins == 2)
	{
		// Set base value of remaining lives for team insurgent
		g_iRespawn_lives_team_ins = -1;
		switch (GetTeamSecCount())
		{
			case 0: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_01.IntValue;
			case 1: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_01.IntValue;
			case 2: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_02.IntValue;
			case 3: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_03.IntValue;
			case 4: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_04.IntValue;
			case 5: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_05.IntValue;
			case 6: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_06.IntValue;
			case 7: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_07.IntValue;
			case 8: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_08.IntValue;
			case 9: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_09.IntValue;
			case 10: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_10.IntValue;
			case 11: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_11.IntValue;
			case 12: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_12.IntValue;
			case 13: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_13.IntValue;
			case 14: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_14.IntValue;
			case 15: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_15.IntValue;
			case 16: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_16.IntValue;
			case 17: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_17.IntValue;
			case 18: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_18.IntValue;
			case 19: g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins_player_count_19.IntValue;
		}
		
		// If not set, use default
		if (g_iRespawn_lives_team_ins == -1)
			g_iRespawn_lives_team_ins = sm_respawn_lives_team_ins.IntValue;
		
	}
	
	// Counter attack
	g_flCanSeeVectorMultiplier = cvarCanSeeVectorMultiplier.FloatValue;
	g_iCvar_counterattack_type = sm_respawn_counterattack_type.IntValue;
	g_iCvar_counterattack_vanilla = sm_respawn_counterattack_vanilla.IntValue;
	g_iCvar_final_counterattack_type = sm_respawn_final_counterattack_type.IntValue;
	g_flMinPlayerDistance = cvarMinPlayerDistance.FloatValue;
	g_flBackSpawnIncrease = cvarBackSpawnIncrease.FloatValue;
	g_flMaxPlayerDistance = cvarMaxPlayerDistance.FloatValue;
	g_flMinObjectiveDistance = cvarMinObjectiveDistance.FloatValue;
	g_flSpawnAttackDelay = cvarSpawnAttackDelay.FloatValue;
}

// When tags changed
void TagsChanged(ConVar convar, const char[] oldValue, const char[] newValue) 
{
	if (sm_respawn_enabled.BoolValue) 
		TagsCheck("respawntimes");
	else
		TagsCheck("respawntimes", true);
}

// On map starts, call initalizing function
public void OnMapStart()
{	
	//Clear player array
	ClearArray(g_playerArrayList);
	
	//Materials for Medic Beams
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/halo01.vmt");
	
	//Wait until players ready to enable spawn checking
	g_playersReady = false;
	g_botsReady = 0;

	// Wait for navmesh
	CreateTimer(2.0, Timer_MapStart);
	g_preRoundInitial = true;
}

// Init config
public void OnConfigsExecuted()
{
	ServerCommand("exec betterbots.cfg");
	if (sm_respawn_enabled.BoolValue)
	{
		TagsCheck("respawntimes");
	}
	else
	{
		TagsCheck("respawntimes", true);
	}
}

public void OnMapEnd()
{
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	(g_isMapInit = 0) && (g_botsReady = 0) && (g_iRoundStatus = 0) && (g_iEnableRevive = 0);
}

//End Plugin
public void OnPluginEnd()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
		AcceptEntityInput(ent, "Kill");
}

// When player connected server, intialize variable
public void OnClientPutInServer(int client)
{
		playerPickSquad[client] = 0;
		g_trackKillDeaths[client] = 0;
		g_iHurtFatal[client] = -1;
		g_playerFirstJoin[client] = 1;
		g_iPlayerRespawnTimerActive[client] = 0;

	//SDKHook(client, SDKHook_PreThinkPost, SHook_OnPreThink);
		char sNickname[64];
		Format(sNickname, sizeof(sNickname), "%N", client);
		g_client_org_nickname[client] = sNickname;
}

// Initializing

public Action Timer_MapStart(Handle Timer)
{
	// Check is map initialized
	if (g_isMapInit == 1) return;
	g_isMapInit = 1;

	//AI Directory Reset
	g_AIDir_ReinforceTimer_Orig = FindConVar("sm_respawn_reinforce_time").IntValue;
	g_AIDir_ReinforceTimer_SubOrig = sm_respawn_reinforce_time_subsequent.IntValue;

	// Bot Reinforce Times
	g_iReinforceTime = sm_respawn_reinforce_time.IntValue;

	// Update cvars
	UpdateRespawnCvars();
	g_isCheckpoint = 0;
	
	// Reset hiding spot
	int iEmptyArray[MAX_OBJECTIVES];
	g_iCPHidingSpotCount = iEmptyArray;	
	
	// Check gamemode
	char sGameMode[32];
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));

	if (StrEqual(sGameMode,"checkpoint"))
	{
		g_isCheckpoint = 1;
	}

	g_iEnableRevive = 0;
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	// Enemy reinforcement announce timer
	CreateTimer(1.0, Timer_EnemyReinforce, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Enemy remaining announce timer
	CreateTimer(30.0, Timer_Enemies_Remaining, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Revive monitor
	CreateTimer(1.0, Timer_ReviveMonitor, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Heal monitor
	CreateTimer(0.5, Timer_MedicMonitor, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Display nearest body for medics
	CreateTimer(0.1, Timer_NearestBody, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Display nearest body for medics
	CreateTimer(60.0, Timer_AmbientRadio, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Monitor ammo resupply
	//CreateTimer(1.0, Timer_AmmoResupply, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// AI Director Tick
	CreateTimer(1.0, Timer_AIDirector_Main, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Squad Spawn Notify Leader
	//if (GetConVarInt(sm_enable_squad_spawning) == 1)
	//CreateTimer(1.0, Timer_SquadSpawn_Notify, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Elite Period
	//CreateTimer(1.0, Timer_ElitePeriodTick, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Static enemy check timer
	//g_checkStaticAmt = sm_respawn_check_static_enemy.IntValue;
	//g_checkStaticAmtCntr = sm_respawn_check_static_enemy_counter.IntValue;
	
	//Elite Bot cvar multipliers (used to minus off top of original cvars)
	g_bot_attack_aimtolerance_newthreat_amt_mult = 0.8;
	g_bot_attack_aimpenalty_amt_close_mult = 15;
	g_bot_attack_aimpenalty_amt_far_mult = 40;
	g_bot_attackdelay_frac_difficulty_impossible_mult = 0.03;
	g_bot_attack_aimpenalty_time_close_mult = 0.15;
	g_bot_attack_aimpenalty_time_far_mult = 2.0;
	g_coop_delay_penalty_base = 800;
	g_bot_aim_aimtracking_base = 0.05;
	g_bot_aim_aimtracking_frac_impossible =  0.05;
	g_bot_aim_angularvelocity_frac_impossible =  0.05;
	g_bot_aim_angularvelocity_frac_sprinting_target =  0.05;
	g_bot_aim_attack_aimtolerance_frac_impossible =  0.05;

	//Get Originals
	g_ins_bot_count_checkpoint_max_org = FindConVar("ins_bot_count_checkpoint_max").IntValue;
	g_mp_player_resupply_coop_delay_max_org = FindConVar("mp_player_resupply_coop_delay_max").IntValue;
	g_mp_player_resupply_coop_delay_penalty_org = FindConVar("mp_player_resupply_coop_delay_penalty").IntValue;
	g_mp_player_resupply_coop_delay_base_org = FindConVar("mp_player_resupply_coop_delay_base").IntValue;
	g_bot_attack_aimpenalty_amt_close_org = FindConVar("bot_attack_aimpenalty_amt_close").IntValue;
	g_bot_attack_aimpenalty_amt_far_org = FindConVar("bot_attack_aimpenalty_amt_far").IntValue;
	g_bot_attack_aimpenalty_time_close_org = FindConVar("bot_attack_aimpenalty_time_close").FloatValue;
	g_bot_attack_aimpenalty_time_far_org = FindConVar("bot_attack_aimpenalty_time_far").FloatValue;
	g_bot_attack_aimtolerance_newthreat_amt_org = FindConVar("bot_attack_aimtolerance_newthreat_amt").FloatValue;
	g_bot_attackdelay_frac_difficulty_impossible_org = FindConVar("bot_attackdelay_frac_difficulty_impossible").FloatValue;
	g_bot_aim_aimtracking_base_org = FindConVar("bot_aim_aimtracking_base").FloatValue;
	g_bot_aim_aimtracking_frac_impossible_org = FindConVar("bot_aim_aimtracking_frac_impossible").FloatValue;
	g_bot_aim_angularvelocity_frac_impossible_org = FindConVar("bot_aim_angularvelocity_frac_impossible").FloatValue;
	g_bot_aim_angularvelocity_frac_sprinting_target_org = FindConVar("bot_aim_angularvelocity_frac_sprinting_target").FloatValue;
	g_bot_aim_attack_aimtolerance_frac_impossible_org = FindConVar("bot_aim_attack_aimtolerance_frac_impossible").FloatValue;

//  Commented below two lines out as those functions are commented out
//	CreateTimer(1.0, Timer_CheckEnemyStatic, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
//	CreateTimer(1.0, Timer_CheckEnemyAway, _ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

// When player connected server, intialize variables
public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	playerPickSquad[client] = 0;
	g_iHurtFatal[client] = -1;
	g_playerFirstJoin[client] = 1;
	g_iPlayerRespawnTimerActive[client] = 0;

	//g_fPlayerLastChat[client] = GetGameTime();

	//Update RespawnCvars when players join
	UpdateRespawnCvars();
}

// When player disconnected server, intialize variables
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0) 
	{
		g_squadSpawnEnabled[client] = 0;
		playerPickSquad[client] = 0;
	
		// Reset player status
		//reset his class model
		g_client_last_classstring[client] = "";
	
		// Remove network ragdoll associated with player
		int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if (playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag)) 
		{
			RemoveRagdoll(client);
		}

		// Update cvar
		UpdateRespawnCvars();
	}
	g_LastButtons[client] = 0;
	return Plugin_Continue;
}

// Console command for reload config
public Action Command_Reload(int client, int args)
{
	ServerCommand("exec sourcemod/respawn.cfg");

	//Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	//PrintToServer("[RESPAWN] %N reloaded respawn config.", client);
	ReplyToCommand(client, "[SM] Reloaded 'sourcemod/respawn.cfg' file.");
}

/*public Action Discord_Info(int client, int args)
{
	char textToPrint[32];
 	Format(textToPrint, sizeof(textToPrint), "https://discord.gg/3BbGmZR");
	PrintHintTextToAll(textToPrint);
}*/

// Respawn function for console command
public Action Command_Respawn(int client, int args) 
{
	// Check argument
	if (args < 1) 
	{
		ReplyToCommand(client, "[SM] Usage: sm_player_respawn <#userid|name>");
		return Plugin_Handled;
	}

	// Retrive argument
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients];
	int target_count;
	bool tn_is_ml;

	// Get target count
	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_DEAD,
					target_name,
					sizeof(target_name),
					tn_is_ml);

	// Check target count
	// If we don't have dead players
	if (target_count <= COMMAND_TARGET_NONE)  
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Team filter dead players, re-order target_list array with new_target_count
	int target;
	int team;
	int new_target_count;

	// Check team
	for (int i = 0; i < target_count; i++) 
	{
		target = target_list[i];
		team = GetClientTeam(target);

		if (team >= 2) 
		{
			// re-order
			target_list[new_target_count] = target;
			new_target_count++;
		}
	}

	// Check target count
	// No dead players from  team 2 and 3
	if (new_target_count == COMMAND_TARGET_NONE) 
	{
		ReplyToTargetError(client, new_target_count);
		return Plugin_Handled;
	}

	// re-set new value.
	target_count = new_target_count;

	// If target exists
	if (tn_is_ml) 
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", target_name);
	else 
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", "_s", target_name);

	// Process respawn
	for (int i = 0; i < target_count; i++) 
		RespawnPlayer(client, target_list[i]);
		
	return Plugin_Handled;
}

/*Action Timer_EliteBots(Handle Timer)
{
	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	if (Ins_InCounterAttack())
	{		
		if ((acp+1) == ncp)
			g_isEliteCounter = 1;
		else
			g_isEliteCounter = 1;
	}
}*/

// Respawn player
void RespawnPlayer(int client, int target)
{
	int team = GetClientTeam(target);
	if(IsClientInGame(target) && !IsFakeClient(target) && !IsClientTimingOut(target) && g_client_last_classstring[target][0] 
		&& playerPickSquad[target] == 1 && !IsPlayerAlive(target) && team == TEAM_1_SEC)
	
	// Write a log
	{
		LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);

		// Call force respawn function
		SDKCall(g_hForceRespawn, target);
	}
}

// ForceRespawnPlayer player
public void ForceRespawnPlayer(int client, int target)
{
	int team = GetClientTeam(target);
	if(IsClientInGame(target) && !IsClientTimingOut(target) && g_client_last_classstring[target][0]
		&& playerPickSquad[target] == 1 && team == TEAM_1_SEC)
	{
		// Write a log
		LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
		
		// Call force respawn fucntion
		SDKCall(g_hForceRespawn, target);
	}
}

// Announce enemies remaining
Action Timer_Enemies_Remaining(Handle Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;

	// Check enemy count
	int alive_insurgents;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i))
			alive_insurgents++;
	}
	//sm_medpack_health_amount new validAntenna = -1;
	//validAntenna = FindValid_Antenna();
	//if (validAntenna != -1 || g_jammerRequired == 0)
	// Announce
	//decl String:textToPrintChat[64];
	char textToPrint[32];
	//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemies alive: %d | Enemy reinforcements left: %d", alive_insurgents, g_iRemaining_lives_team_ins);
	Format(textToPrint, sizeof(textToPrint), "Total Enemies: %d", alive_insurgents);
	PrintHintTextToAll(textToPrint);
		//PrintToChatAll(textToPrintChat);

	int timeReduce = (GetTeamSecCount() / 3);
	if (timeReduce <= 0)
		timeReduce = 3;
	return Plugin_Continue;
}

//Check Min/Max AD
stock int AI_Director_SetMinMax(int t_AIDir_TeamStatus, int t_AIDir_TeamStatus_min, int t_AIDir_TeamStatus_max)
{
	if (t_AIDir_TeamStatus < t_AIDir_TeamStatus_min)
	t_AIDir_TeamStatus = t_AIDir_TeamStatus_min;
	else if (t_AIDir_TeamStatus > t_AIDir_TeamStatus_max)
	t_AIDir_TeamStatus = t_AIDir_TeamStatus_max;
	return t_AIDir_TeamStatus;
}

Action AI_Director_RandomEnemyReinforce()
{
	char textToPrint[64];
	//Only add more reinforcements if under certain amount so its not endless.
	if (g_iRemaining_lives_team_ins > 0)
	{
			// Get bot count
			int minBotCount = (g_iRespawn_lives_team_ins / 5);
			g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
			Format(textToPrint, sizeof(textToPrint), "[INTEL]Ambush Reinforcements Added to Existing Reinforcements!");
			
			//AI Director Reinforcement START
			g_AIDir_BotReinforceTriggered = true;
			g_AIDir_TeamStatus -= 5;
			g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
			//AI Director Reinforcement END

			PrintHintTextToAll(textToPrint);
			g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;

			//Lower Bot Flank spawning on reinforcements
			g_dynamicSpawn_Perc = 0;

			// Add bots
			for (int client = 1; client <= MaxClients; client++)
			{
				if (client > 0 && IsClientInGame(client))
				{
					int m_iTeam = GetClientTeam(client);
					if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
					{
						g_iRemaining_lives_team_ins++;
						CreateBotRespawnTimer(client);
					}
				}
			}
			
			//Reset bot back spawning to default
			CreateTimer(45.0, Timer_ResetBotFlankSpawning, _);
	}
	else
	{
		// Get bot count
		int minBotCount = (g_iRespawn_lives_team_ins / 5);
		g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;

		//Lower Bot Flank spawning on reinforcements
		g_dynamicSpawn_Perc = 0;

		// Add bots
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client > 0 && IsClientInGame(client))
			{
				int m_iTeam = GetClientTeam(client);
				if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
				{
					g_iRemaining_lives_team_ins++;
					CreateBotRespawnTimer(client);
				}
			}
		}
		g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;

		//Reset bot back spawning to default
		CreateTimer(45.0, Timer_ResetBotFlankSpawning, _);

		// Get random duration
		//new fRandomInt = GetRandomInt(1, 4);

		Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemy Ambush Reinforcement Incoming!");

		//AI Director Reinforcement START
		g_AIDir_BotReinforceTriggered = true;
		g_AIDir_TeamStatus -= 5;
		g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

		//AI Director Reinforcement END

		PrintHintTextToAll(textToPrint);
	}
}

// This timer reinforces bot team if you do not capture point
Action Timer_EnemyReinforce(Handle timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Check enemy remaining
	if (g_iRemaining_lives_team_ins <= (g_iRespawn_lives_team_ins / g_iReinforce_Mult) + g_iReinforce_Mult_Base)
	{
		g_iReinforceTime--;
		char textToPrint[64];
		// Announce every 10 seconds
		if (g_iReinforceTime % 10 == 0 && g_iReinforceTime > 10)
		{
				Format(textToPrint, sizeof(textToPrint), "Allied forces spawn on counter-attacks, capture the point!");
				PrintHintTextToAll(textToPrint);
		}
		// Announce every 1 second
		if (g_iReinforceTime <= 10)
		{
			Format(textToPrint, sizeof(textToPrint), "Enemies reinforce in %d seconds | capture point soon!", g_iReinforceTime);
			PrintHintTextToAll(textToPrint);
		}
		// Process reinforcement
		if (g_iReinforceTime <= 0)
		{
			// If enemy reinforcement is not over, add it
			if (g_iRemaining_lives_team_ins > 0)
			{
				//Only add more reinforcements if under certain amount so its not endless.
				if (g_iRemaining_lives_team_ins < (g_iRespawn_lives_team_ins / g_iReinforce_Mult) + g_iReinforce_Mult_Base)
				{
					// Get bot count
					int minBotCount = (g_iRespawn_lives_team_ins / 4);
					g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
					Format(textToPrint, sizeof(textToPrint), "Terrorists have arrived!");
					
					//AI Director Reinforcement START
					g_AIDir_BotReinforceTriggered = true;
					g_AIDir_TeamStatus -= 5;
					g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
					//AI Director Reinforcement END

					PrintHintTextToAll(textToPrint);
					g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;

					//Lower Bot Flank spawning on reinforcements
					g_dynamicSpawn_Perc = 0;

					// Add bots
					for (int client = 1; client <= MaxClients; client++)
					{
						if (client > 0 && IsClientInGame(client))
						{
							int m_iTeam = GetClientTeam(client);
							if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
							{
								g_iRemaining_lives_team_ins++;
								CreateBotRespawnTimer(client);
							}
						}
					}
					
					//Reset bot back spawning to default
					CreateTimer(45.0, Timer_ResetBotFlankSpawning, _);
				}
				else
				{
				
					// Reset reinforce time
					g_iReinforceTime = g_iReinforceTime_AD_Temp;
				}
			}

			// Respawn enemies
			else
			{
				// Get bot count
				int minBotCount = (g_iRespawn_lives_team_ins / 4);
				g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
				
				//Lower Bot Flank spawning on reinforcements
				g_dynamicSpawn_Perc = 0;

				// Add bots
				for (int client = 1; client <= MaxClients; client++)
				{
					if (client > 0 && IsClientInGame(client))
					{
						int m_iTeam = GetClientTeam(client);
						if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
						{
							g_iRemaining_lives_team_ins++;
							CreateBotRespawnTimer(client);
						}
					}
				}
				g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;

				//Reset bot back spawning to default
				CreateTimer(45.0, Timer_ResetBotFlankSpawning, _);

				// Get random duration
				//new fRandomInt = GetRandomInt(1, 4);
				
				Format(textToPrint, sizeof(textToPrint), "ISIS terrorists have now arrived!");

				//AI Director Reinforcement START
				g_AIDir_BotReinforceTriggered = true;
				g_AIDir_TeamStatus -= 5;
				g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

				//AI Director Reinforcement END
				PrintHintTextToAll(textToPrint);
			}
		}
	}
	return Plugin_Continue;
}

//Reset bot flank spawning X seconds after reinforcement
Action Timer_ResetBotFlankSpawning(Handle timer)
{
	//Reset bot back spawning to default
	g_dynamicSpawn_Perc = sm_respawn_dynamic_spawn_percent.IntValue;
	return Plugin_Continue;
}

/*
Commented out Timer_CheckEnemyStatic and Timer_CheckEnemyAway on 10/10 to troubleshoot SM errors spamming and see if there is consequences


// Check enemy is stuck
Action Timer_CheckEnemyStatic(Handle timer) 
{
	//Remove bot weapons when static killed to reduce server performance on dropped items.
	int primaryRemove = 1;
	int secondaryRemove ;
 	int grenadesRemove = 1;

	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;

	if (Ins_InCounterAttack()) 
	{
		g_checkStaticAmtCntr = g_checkStaticAmtCntr - 1;
		if (g_checkStaticAmtCntr <= 0) 
		{
			for (int enemyBot = 1; enemyBot <= MaxClients; enemyBot++) 
			{
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot)) 
				{
					int m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS) 
					{
						// Get current position
						float enemyPos[3];
						GetClientAbsOrigin(enemyBot, enemyPos);

						// Get distance
						float tDistance;
						float capDistance;

						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);
						int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
						if (0 <= m_nActivePushPointIndex < sizeof(m_vCPPositions))
						Ins_ObjectiveResource_GetPropVector(" ", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
						capDistance = GetVectorDistance(enemyPos, m_vCPPositions[m_nActivePushPointIndex]);
						
						// If enemy position is static, kill him
						if (tDistance <= 150 && Check_NearbyPlayers(enemyBot) && (capDistance > 800 || g_botStaticGlobal[enemyBot] > 120)) 
						{
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
							//PrintToServer("ENEMY STATIC - KILLING");
							g_badSpawnPos_Track[enemyBot] = enemyPos;
						}

						// Update current position
						else 
						{
							g_enemyTimerPos[enemyBot] = enemyPos;
							g_botStaticGlobal[enemyBot]++;
						}
					}
				}
			}
			g_checkStaticAmtCntr = sm_respawn_check_static_enemy_counter.IntValue;
		}
	}
	else 
	{
		g_checkStaticAmt = g_checkStaticAmt - 1;
		if (g_checkStaticAmt <= 0) 
		{
			for (int enemyBot = 1; enemyBot <= MaxClients; enemyBot++) 
			{
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot)) 
				{
					int m_iTeam = GetClientTeam(enemyBot);
					if (enemyBot > 0 && IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS) 
					{
						// Get current position
						float enemyPos[3];
						GetClientAbsOrigin(enemyBot, enemyPos);

						// Get distance
						float tDistance;
						float capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);

						//Check point distance
						
						int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
						if (0 <= m_nActivePushPointIndex < sizeof(m_vCPPositions))
						Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
						capDistance = GetVectorDistance(enemyPos, m_vCPPositions[m_nActivePushPointIndex]);

						// If enemy position is static, kill him
						if (tDistance <= 150 && (capDistance > 800) && Check_NearbyPlayers(enemyBot))  
						{
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						
						// Update current position
						else 
						{
							g_enemyTimerPos[enemyBot] = enemyPos;
						}
					}
				}
			}
			g_checkStaticAmt = sm_respawn_check_static_enemy.IntValue;
		}
	}
	return Plugin_Continue;
}

// Check enemy is stuck
public Action Timer_CheckEnemyAway(Handle timer)
{
	//Remove bot weapons when static killed to reduce server performance on dropped items.
	int primaryRemove = 1;
	int secondaryRemove ;
	int grenadesRemove = 1;
	// Check round state
	if (g_iRoundStatus == 0) 
	{
		return Plugin_Continue;
	}

	if (Ins_InCounterAttack()) 
	{
		g_checkStaticAmtCntrAway = g_checkStaticAmtCntrAway - 1;
		if (g_checkStaticAmtCntrAway <= 0) 
		{
			for (int enemyBot = 1; enemyBot <= MaxClients; enemyBot++) 
			{
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot)) 
				{
					int m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS) 
					{
						// Get current position
						float enemyPos[3];
						GetClientAbsOrigin(enemyBot, enemyPos);

						// Get distance
						float tDistance;
						float capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);

						int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
						Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
						capDistance = GetVectorDistance(enemyPos, m_vCPPositions[m_nActivePushPointIndex]);
						
						// If enemy position is static, kill him
						if (tDistance <= 150 && capDistance > 2500) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}

						// Update current position
						else 
						{
							g_enemyTimerAwayPos[enemyBot] = enemyPos;
						}
					}
				}
			}
			g_checkStaticAmtCntrAway = 12;
		}
	}
	else 
	{
		g_checkStaticAmtAway = g_checkStaticAmtAway - 1;
		if (g_checkStaticAmtAway <= 0) 
		{
			for (int enemyBot = 1; enemyBot <= MaxClients; enemyBot++) 
			{
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot)) 
				{
					int m_iTeam = GetClientTeam(enemyBot);
					if (enemyBot > 0 && IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS) 
					{
						// Get current position
						float enemyPos[3];
						GetClientAbsOrigin(enemyBot, enemyPos);

						// Get distance
						float tDistance;
						float capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);
						//Check point distance
						if (g_isCheckpoint == 1) 
						{
							int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							if (0 <= m_nActivePushPointIndex < sizeof(m_vCPPositions))
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos, m_vCPPositions[m_nActivePushPointIndex]);
						}
						// If enemy position is static, kill him
						if (tDistance <= 150 && capDistance > 1200) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else 
						{
							g_enemyTimerAwayPos[enemyBot] = enemyPos;
						}
					}
				}
			}
			g_checkStaticAmtAway = 30;
		}
	}
	return Plugin_Continue;
}

*/

//Commenting out on 10/10 as function is not called upon

/*
void AddLifeForStaticKilling(int client) 
{
	// Respawn type 1
	int team = GetClientTeam(client);
	if (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS && g_iRespawn_lives_team_ins > 0) 
	{
		g_iSpawnTokens[client]++;
	}
	else if (g_iCvar_respawn_type_team_ins == 2 && team == TEAM_2_INS && g_iRespawn_lives_team_ins > 0) 
	{
		g_iRemaining_lives_team_ins++;
	}
}
*/

// Update player's gear
void SetPlayerAmmo(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		int primaryWeapon = GetPlayerWeaponSlot(client, 0);
		int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
		int playerGrenades = GetPlayerWeaponSlot(client, 3);
	
		//Check primary weapon
		if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
		{
			SetPrimaryAmmo(client, primaryWeapon, playerClip[client][0], 0); //primary clip
			Client_SetWeaponPlayerAmmoEx(client, primaryWeapon, playerAmmo[client][0]); //primary
		}
		
		// Check secondary weapon
		if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
		{
			SetPrimaryAmmo(client, secondaryWeapon, playerClip[client][1], 1); //secondary clip
			Client_SetWeaponPlayerAmmoEx(client, secondaryWeapon, playerAmmo[client][1]); //secondary
		}
		
		// Check grenades
		if (playerGrenades != -1 && IsValidEntity(playerGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
		{
			while (playerGrenades != -1 && IsValidEntity(playerGrenades)) // since we only have 3 slots in current theate
			{
				playerGrenades = GetPlayerWeaponSlot(client, 3);
				if (playerGrenades != -1 && IsValidEntity(playerGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
				{
					// Remove grenades but not pistols
					char weapon[32];
					GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client,playerGrenades);
					AcceptEntityInput(playerGrenades, "kill");
				}
			}
		}
		if (!IsFakeClient(client))
			playerRevived[client] = false;
	}
}

public Action Event_PlayerReload_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsFakeClient(client) && playerInRevivedState[client] == false) return Plugin_Continue;
	g_playerActiveWeapon[client] = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	return Plugin_Continue;
}

/*
#####################################################################
#####################################################################
#####################################################################
# Jballous INS_SPAWNPOINT SPAWNING START ############################
# Jballous INS_SPAWNPOINT SPAWNING START ############################
#####################################################################
#####################################################################
#####################################################################
*/

stock float GetInsSpawnGround(int spawnPoint, float vecSpawn[3]) 
{
	float fGround[3];
	vecSpawn[2] += 15.0;
	TR_TraceRayFilter(vecSpawn, view_as<float>({90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite, TRDontHitSelf, spawnPoint);
	if (TR_DidHit()) 
	{
		TR_GetEndPosition(fGround);
		return fGround;
	}
	return vecSpawn;
}

int CheckSpawnPoint(float vecSpawn[3], int client, float tObjectiveDistance, int m_nActivePushPointIndex) 
{
//Ins_InCounterAttack
	int m_iTeam = GetClientTeam(client);
	float distance;
	float furthest;
	float closest=-1.0;
	float vecOrigin[3];
	//float tBadPos[3];

	GetClientAbsOrigin(client, vecOrigin);
	float tMinPlayerDistMult = 0.0;

	int acp = (Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex") - 1);
	int acp2 = m_nActivePushPointIndex;
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	if (acp == acp2 && !Ins_InCounterAttack()) 
	{
		tMinPlayerDistMult = g_flBackSpawnIncrease;
		//PrintToServer("INCREASE SPAWN DISTANCE | acp: %d acp2 %d", acp, acp2);
	}

	//Update player spawns before we check against them
	UpdatePlayerOrigins();
	//Lets go through checks to find a valid spawn point
	for (int iTarget = 1; iTarget < MaxClients; iTarget++) 
	{
		if (!IsValidClient(iTarget)) continue;
		
		if (!IsClientInGame(iTarget)) continue;
		if (!IsPlayerAlive(iTarget)) 
		{
			continue;
		}
		int tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1_SEC) 
		{
			continue;
		}
		////InsLog(DEBUG, "Distance from %N to iSpot %d is %f", iTarget, iSpot, distance);
		distance = GetVectorDistance(vecSpawn, g_vecOrigin[iTarget]);
		if (distance > furthest) 
		{
			furthest = distance;
		}
		if ((distance < closest) || (closest < 0)) 
		{
			closest = distance;
		}

		if (GetClientTeam(iTarget) != m_iTeam) 
		{
			// If we are too close
			if (distance < (g_flMinPlayerDistance + tMinPlayerDistMult)) 
			{
				 return 0;
			}
			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier)))
			{
				return 0;
			}
			//If any player is too far
			if (closest > g_flMaxPlayerDistance) 
			{
				return 0;
			}
			else if (closest > 2000 && g_cacheObjActive == 1 && Ins_InCounterAttack()) 
				return 0;
		}
	}

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
	distance = GetVectorDistance(vecSpawn, m_vCPPositions[m_nActivePushPointIndex]);
	if (distance > (tObjectiveDistance) && (((acp+1) != ncp) || !Ins_InCounterAttack())) 
		return 0;
	else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) &&
	(((acp+1) != ncp) || !Ins_InCounterAttack())) 
		return 0;



//	if ((0 >= client || client > MaxClients) || !IsClientInGame(client)) return 0;
	if ((0 < client <= MaxClients) || !IsClientInGame(client)) return 0;

	int fRandomInt = GetRandomInt(1, 100);
	//If final point respawn around last point, not final point
	if ((((acp+1) == ncp) || Ins_InCounterAttack()) && fRandomInt <= 10) 
	{
		int m_nActivePushPointIndexFinal = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
		m_nActivePushPointIndexFinal -= 1;
		distance = GetVectorDistance(vecSpawn, m_vCPPositions[m_nActivePushPointIndexFinal]);
		if (distance > (tObjectiveDistance)) return 0;
		else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) return 0;
	}
	return 1;
}


int CheckSpawnPointPlayers(float vecSpawn[3], int client, float tObjectiveDistance) 
{
//Ins_InCounterAttack
	int m_iTeam = GetClientTeam(client);
	float distance;
	float furthest;
	float closest=-1.0;
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	//Update player spawns before we check against them
	UpdatePlayerOrigins();

	int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	float objDistance;

	//Lets go through checks to find a valid spawn point
	for (int iTarget = 1; iTarget < MaxClients; iTarget++) 
	{
		if (!IsValidClient(iTarget)) 
		{
			continue;
		}
		if (!IsClientInGame(iTarget)) 
		{
			continue;
		}
		if (!IsPlayerAlive(iTarget)) 
		{
			continue;
		}
		int tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1_SEC) 
		{
			continue;
		}

		m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

		//If in counter
		if (Ins_InCounterAttack() && m_nActivePushPointIndex > 0) 
		{
			m_nActivePushPointIndex -= 1;
		}

		Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);

		objDistance = GetVectorDistance(g_vecOrigin[iTarget], m_vCPPositions[m_nActivePushPointIndex]);
		distance = GetVectorDistance(vecSpawn, g_vecOrigin[iTarget]);
		if (distance > furthest) 
		{
			furthest = distance;
		}
		if ((distance < closest) || (closest < 0)) 
		{
			closest = distance;
		}

		if (GetClientTeam(iTarget) != m_iTeam) 
		{
			// If we are too close
			if (distance < g_flMinPlayerDistance) 
			{
				 return 0;
			}
			int fRandomInt = GetRandomInt(1, 100);

			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) 
			{
				return 0;
			}

			//Check if players are getting close to point when assaulting
			if (objDistance < 2500 && fRandomInt < 30 && !Ins_InCounterAttack()) 
			{
				return 0;
			}
		}
	}


	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	//If any player is too far
	if (closest > g_flMaxPlayerDistance)  return 0;

	else if (closest > 2000 && g_cacheObjActive == 1 && Ins_InCounterAttack()) return 0;

	m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	int fRandomInt = GetRandomInt(1, 100);

	//Check against back spawn if in counter
	if (Ins_InCounterAttack() && m_nActivePushPointIndex > 0) m_nActivePushPointIndex -= 1;

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
	objDistance = GetVectorDistance(vecSpawn, m_vCPPositions[m_nActivePushPointIndex]);
	// && (fRandomFloat <= g_dynamicSpawn_Perc))
	if (objDistance > (tObjectiveDistance) && (((acp+1) != ncp) || !Ins_InCounterAttack()) && fRandomInt < 25) return 0;
	else if (objDistance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) && (((acp+1) != ncp) || !Ins_InCounterAttack()) && fRandomInt < 25) return 0;

	fRandomInt = GetRandomInt(1, 100);
	
	if ((0 < client <= MaxClients) || !IsClientInGame(client)) return 0;

	//If final point respawn around last point, not final point
	if ((((acp+1) == ncp) || Ins_InCounterAttack()) && fRandomInt < 25) 
	{
		int m_nActivePushPointIndexFinal = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
		if (m_nActivePushPointIndexFinal < 0) return 0;
		
		m_nActivePushPointIndexFinal -= 1;
		objDistance = GetVectorDistance(vecSpawn, m_vCPPositions[m_nActivePushPointIndexFinal]);
		
		if (objDistance > (tObjectiveDistance)) return 0;
		if (objDistance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) return 0;
	}
	return 1;
}

int GetPushPointIndex(float fRandomFloat, int client) 
{
	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	//Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
	//float distance = GetVectorDistance(vecSpawn, m_vCPPositions[m_nActivePushPointIndex]);
	//Check last point

	if (((acp+1) == ncp && Ins_InCounterAttack()) || g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc ||
		(Ins_InCounterAttack()) || (m_nActivePushPointIndex > 1)) {
		//PrintToServer("###POINT_MOD### | fRandomFloat: %f | g_dynamicSpawnCounter_Perc %f ", fRandomFloat, g_dynamicSpawnCounter_Perc);
		if ((acp+1) == ncp && Ins_InCounterAttack()) 
		{
			if (g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc) 
			{
				m_nActivePushPointIndex--;
			}
		}
		else
		{
			if (Ins_InCounterAttack() && (acp+1) != ncp) 
			{
				if (fRandomFloat <= 0.5 && m_nActivePushPointIndex > 0) 
				{
					m_nActivePushPointIndex--;
				}
				else
				{
					m_nActivePushPointIndex++;
				}
			}
			else if (!Ins_InCounterAttack()) 
			{
				if (m_nActivePushPointIndex > 0) 
				{
					if (g_spawnFrandom[client] < g_dynamicSpawn_Perc) 
					{
						m_nActivePushPointIndex--;
					}
				}
			}
		}

	}
	return m_nActivePushPointIndex;
}



float GetSpawnPoint_SpawnPoint(int client) 
{
	float vecSpawn[3];
	float vecOrigin[3];

	GetClientAbsOrigin(client, vecOrigin);
	float fRandomFloat = GetRandomFloat(0.0, 1.0);

	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	int m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	if (((acp+1) == ncp) || (Ins_InCounterAttack() &&
		g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc) ||
		(!Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawn_Perc &&
		acp > 1))
		m_nActivePushPointIndex = GetPushPointIndex(fRandomFloat, client);

	int point = FindEntityByClassname(-1, "ins_spawnpoint");
	float tObjectiveDistance = g_flMinObjectiveDistance;

	if ((0 < client <= MaxClients) || !IsClientInGame(client))
	while (point != -1)
	{
		GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
		Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);

		if (CheckSpawnPoint(vecSpawn, client, tObjectiveDistance, m_nActivePushPointIndex)) 
		{
			vecSpawn = GetInsSpawnGround(point, vecSpawn);
			return vecSpawn;
		}
		else 
		{
			tObjectiveDistance += 4.0;
		}
		point = FindEntityByClassname(point, "ins_spawnpoint");
	}

	//Lets try again but wider range
	int point2 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 4);
	while (point2 != -1) 
	{
		GetEntPropVector(point2, Prop_Send, "m_vecOrigin", vecSpawn);

		Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
		if (CheckSpawnPoint(vecSpawn, client, tObjectiveDistance, m_nActivePushPointIndex)) 
		{
			vecSpawn = GetInsSpawnGround(point2, vecSpawn);
			return vecSpawn;
		}
		else
		{
			tObjectiveDistance += 4.0;
		}
		point2 = FindEntityByClassname(point2, "ins_spawnpoint");
	}
	//Lets try again but wider range
	int point3 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 10);
	while (point3 != -1) 
	{
		GetEntPropVector(point3, Prop_Send, "m_vecOrigin", vecSpawn);
		Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
		if (CheckSpawnPoint(vecSpawn, client, tObjectiveDistance, m_nActivePushPointIndex)) 
		{
			vecSpawn = GetInsSpawnGround(point3, vecSpawn);
			return vecSpawn;
		}
		else 
		{
			tObjectiveDistance += 4.0;
		}
		point3 = FindEntityByClassname(point3, "ins_spawnpoint");
	}
	int pointFinal = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 4);
	m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	if (m_nActivePushPointIndex > 1) 
	{
		if ((acp+1) >= ncp) 
		{
			m_nActivePushPointIndex--;
		}
		else 
		{
			m_nActivePushPointIndex++;
		}
	}

	while (pointFinal != -1) 
	{
		GetEntPropVector(pointFinal, Prop_Send, "m_vecOrigin", vecSpawn);
		Ins_ObjectiveResource_GetPropVector("m_vCPPositions", m_vCPPositions[m_nActivePushPointIndex], m_nActivePushPointIndex);
		if (CheckSpawnPoint(vecSpawn, client, tObjectiveDistance, m_nActivePushPointIndex)) 
		{
			vecSpawn = GetInsSpawnGround(pointFinal, vecSpawn);
			return vecSpawn;
		}
		else 
		{
			tObjectiveDistance += 4.0;
		}
		pointFinal = FindEntityByClassname(pointFinal, "ins_spawnpoint");
	}
	return vecOrigin;
}

float GetSpawnPoint(int client) 
{

	float vecSpawn[3];
	vecSpawn = GetSpawnPoint_SpawnPoint(client);
	return vecSpawn;
}

//Lets begin to find a valid spawnpoint after spawned
void TeleportClient(int client) 
{
	float vecSpawn[3];
	vecSpawn = GetSpawnPoint(client);
	if ((0 < client <= MaxClients) && IsClientInGame(client)) 
	{
		TeleportEntity(client, vecSpawn, NULL_VECTOR, NULL_VECTOR);
		SetNextAttack(client);
	}
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client))
	{
		if (!IsFakeClient(client)) 
		{
			g_iPlayerRespawnTimerActive[client] = 0;

			//remove network ragdoll associated with player
			int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
			if (playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag)) RemoveRagdoll(client);
			g_iHurtFatal[client] = 0;
		}
	}

	g_resupplyCounter[client] = sm_resupply_delay.IntValue;

	//For first joining players
	if (g_playerFirstJoin[client] == 1 && !IsFakeClient(client)) 
	{
		g_playerFirstJoin[client] = 0;
	
		// Get SteamID to verify is player has connected before.
		char steamId[64];
	
		//GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		int isPlayerNew = g_playerArrayList.FindString(steamId);
		if (isPlayerNew == -1) 
		{
			g_playerArrayList.PushString(steamId);
		}
	}
	if (!g_iCvar_respawn_enable) 
	{
		return Plugin_Continue;
	}
	if (!IsClientConnected(client)) 
	{
		return Plugin_Continue;
	}
	if (!IsClientInGame(client)) 
	{
		return Plugin_Continue;
	}
	if (!IsValidClient(client)) 
	{
		return Plugin_Continue;
	}
	if (!IsFakeClient(client)) 
	{
		return Plugin_Continue;
	}
	if (g_isCheckpoint == 0) 
	{
		return Plugin_Continue;
	}

	g_botStaticGlobal[client] = 0;

	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);

	if ((0 < client <= MaxClients) || !IsClientInGame(client))
	if  (g_playersReady && g_botsReady == 1) 
	{
		float vecSpawn[3];
		GetClientAbsOrigin(client, vecOrigin);
		int point = FindEntityByClassname(-1, "ins_spawnpoint");
		float tObjectiveDistance = g_flMinObjectiveDistance;
		int iCanSpawn = CheckSpawnPointPlayers(vecOrigin, client, tObjectiveDistance);
		while (point != -1) 
		{
				if (iCanSpawn < 0) 
				{
					return Plugin_Continue;
				}
				GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
				iCanSpawn = CheckSpawnPointPlayers(vecOrigin, client, tObjectiveDistance);
				if (iCanSpawn == 1) 
				{
					break;
				}
				else 
				{
					tObjectiveDistance += 6.0;
				}
				point = FindEntityByClassname(point, "ins_spawnpoint");
		}
		//Global random for spawning
		g_spawnFrandom[client] = GetRandomInt(0, 100);
		if (iCanSpawn == 0 || (Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc) ||
			(!Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawn_Perc && acp > 1)) 
		{
			TeleportClient(client);
			if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) 
			{
				StuckCheck[client] = 0;
				StartStuckDetection(client);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_SpawnPost(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	//Bots only below this
	if (!IsFakeClient(client)) 
		return Plugin_Continue;
	
	SetNextAttack(client);
	int fRandom = GetRandomInt(1, 100);
	
	//Check grenades
	if (fRandom < g_removeBotGrenadeChance && !Ins_InCounterAttack()) 
	{
		int botGrenades = GetPlayerWeaponSlot(client, 3);
	
		// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
		if (botGrenades != -1 && IsValidEntity(botGrenades))  
		{
			// since we only have 3 slots in current theate
			while (botGrenades != -1 && IsValidEntity(botGrenades))  
			{
				botGrenades = GetPlayerWeaponSlot(client, 3);
	
				// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
				if (botGrenades != -1 && IsValidEntity(botGrenades))  
				{
					// Remove grenades but not pistols
					char weapon[32];
					GetEntityClassname(botGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client, botGrenades);
					AcceptEntityInput(botGrenades, "kill");
				}
			}
		}
	}
	if (!g_iCvar_respawn_enable) 
	{
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

void UpdatePlayerOrigins() 
{
	for (int i = 1; i < MaxClients; i++) 
	{
		if (IsValidClient(i)) 
		{
			GetClientAbsOrigin(i, g_vecOrigin[i]);
		}
	}
}

//This delays bot from attacking once spawned
void SetNextAttack(int client)
{
	float flTime = GetGameTime();
	float flDelay = g_flSpawnAttackDelay;

// Loop through entries in m_hMyWeapons.
	for (int offset = 0; offset < 128; offset += 4)
	{
		int weapon = GetEntDataEnt2(client, m_hMyWeapons + offset);
		if (weapon < 0)
		{
			continue;
		}
//		//InsLog(DEBUG, "SetNextAttack weapon %d", weapon);
		SetEntDataFloat(weapon, m_flNextPrimaryAttack, flTime + flDelay);
		SetEntDataFloat(weapon, m_flNextSecondaryAttack, flTime + flDelay);
	}
}



/*
#####################################################################
#####################################################################
#####################################################################
# Jballous INS_SPAWNPOINT SPAWNING END ##############################
# Jballous INS_SPAWNPOINT SPAWNING END ##############################
#####################################################################
#####################################################################
#####################################################################
*/

public void NullMenuHandler(Handle menu, MenuAction action, int param1, int param2) {}

// When round starts, intialize variables
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Respawn delay for team ins
	g_fCvar_respawn_delay_team_ins = sm_respawn_delay_team_ins.FloatValue;
	g_fCvar_respawn_delay_team_ins_spec = sm_respawn_delay_team_ins_special.FloatValue;
	g_AIDir_TeamStatus = 50;
	g_AIDir_BotReinforceTriggered = false;
	g_iReinforceTime = sm_respawn_reinforce_time.IntValue;
	//g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy); - Not being used as commented function out on 10/10
	//g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter); - Not being used as commented function out on 10/10
	g_secWave_Timer = g_iRespawnSeconds;
	//Round_Start CVAR Sets ------------------ END -- vs using HookConVarChange

	//Elite Bots Reset
	if (g_elite_counter_attacks == 1)
	{
		g_isEliteCounter = 0;
		EnableDisableEliteBotCvars(0, 0);
	}

	// Reset respawn position
	g_fRespawnPosition[0] = 0.0;
	g_fRespawnPosition[1] = 0.0;
	g_fRespawnPosition[2] = 0.0;

	
	// Reset remaining life
	// ConVar hCvar = null;
	// ConVar hCvar = FindConVar("sm_remaininglife");
	// hCvar.SetInt(-1);

	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();

	// Check gamemode
	char sGameMode[32];
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	//PrintToServer("[REVIVE_DEBUG] ROUND STARTED");
	
	// Warming up revive
	g_iEnableRevive = 0;
	int iPreRoundFirst = FindConVar("mp_timer_preround_first").IntValue;
	int iPreRound = FindConVar("mp_timer_preround").IntValue;
	if (g_preRoundInitial == true)
	{
		CreateTimer(float(iPreRoundFirst), PreReviveTimer);
		iPreRoundFirst = iPreRoundFirst + 5;
		CreateTimer(float(iPreRoundFirst), BotsReady_Timer);
		g_preRoundInitial = false;
	}
	else
	{
		CreateTimer(float(iPreRound), PreReviveTimer);
		iPreRoundFirst = iPreRound + 5;
		CreateTimer(float(iPreRound), BotsReady_Timer);
	}
	return Plugin_Continue;
}

void SecTeamLivesBonus()
{
	int secTeamCount = GetTeamSecCount();
	if (secTeamCount <= 9)
	{
		g_iRespawnCount[2] += 1;
	}
}

//Adjust Lives Per Point Based On Players
void SecDynLivesPerPoint()
{
	int secTeamCount = GetTeamSecCount();
	if (secTeamCount <= 9)
	{
		g_iRespawnCount[2] += 1;
	}
}

// Round starts
Action PreReviveTimer(Handle timer)
{
	g_iRoundStatus = 1;
	g_iEnableRevive = 1;

	// Update remaining life cvar
	//Handle hCvar = null;
	//int iRemainingLife = GetRemainingLife();
	//hCvar = FindConVar("sm_remaininglife");
	//SetConVarInt(hCvar, iRemainingLife);
}

// Botspawn trigger
Action BotsReady_Timer(Handle timer)
{
	g_botsReady = 1;
}

// When round ends, intialize variables
public Action Event_RoundEnd_Pre(Event event, const char[] name, bool dontBroadcast)
{
	//for (int client = 1; client <= MaxClients; client++)
	//{
		//if (!IsValidClient(client) || !IsClientInGame(client) || IsFakeClient(client)) continue;
		//int tTeam = GetClientTeam(client);
		//if (tTeam != TEAM_1_SEC) continue;
		//if ((g_iStatRevives[client] > 0 || g_iStatHeals[client] > 0) && StrContains(g_client_last_classstring[client], "medic") > -1)
		//{
			//char sBuf[255];
			// Hint to iMedic
			//Format(sBuf, 255,"[MEDIC STATS] for %N: HEALS: %d | REVIVES: %d", client, g_iStatHeals[client], g_iStatRevives[client]);
			//PrintHintText(client, "%s", sBuf);
		//}

		//playerInRevivedState[client] = false;
	//}

	//Reset Variables
	g_removeBotGrenadeChance = 50;
}

// When round ends, intialize variables
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	//Elite Bots Reset
	if (g_elite_counter_attacks == 1)
	{
		g_isEliteCounter = 0;
		EnableDisableEliteBotCvars(0, 0);
	}

	// Reset respawn position
	g_fRespawnPosition[0] = 0.0;
	g_fRespawnPosition[1] = 0.0;
	g_fRespawnPosition[2] = 0.0;

	// Cooldown revive
	g_iEnableRevive = 0;
	g_iRoundStatus = 0;
	g_botsReady = 0;

	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();
}

// Check occuring counter attack when control point captured
public Action Event_ControlPointCaptured_Pre(Event event, const char[] name, bool dontBroadcast)
{
	//Clear bad spawn array
	for (int client = 0; client < MaxClients; client++) 
	{
		if (!IsValidClient(client) || client <= 0)
				continue;
		if (!IsClientInGame(client))
			continue;
		int m_iTeam = GetClientTeam(client);
		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
		{
			g_badSpawnPos_Track[client][0] = 0.0;
			g_badSpawnPos_Track[client][1] = 0.0;
			g_badSpawnPos_Track[client][2] = 0.0;
		}
	}

//	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy); - Not being used as commented function out on 10/10
//	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter); - Not being used as commented function out on 10/10

	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints"); // Get the number of control points
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex"); // Get active push point

	//AI Director Status ###START###
	int secTeamCount = GetTeamSecCount();
	int secTeamAliveCount = Team_CountAlivePlayers(TEAM_1_SEC);
	if (g_iRespawn_lives_team_ins > 0)
		g_AIDir_TeamStatus += 10;
	if (secTeamAliveCount >= (secTeamCount * 0.8)) // If Alive Security >= 80%
		g_AIDir_TeamStatus += 10;
	else if (secTeamAliveCount >= (secTeamCount * 0.5)) // If Alive Security >= 50%
		g_AIDir_TeamStatus += 5;
	else if (secTeamAliveCount <= (secTeamCount * 0.2)) // If Dead Security <= 20%
		g_AIDir_TeamStatus -= 10;
	else if (secTeamAliveCount <= (secTeamCount * 0.5)) // If Dead Security <= 50%
		g_AIDir_TeamStatus -= 5;

	if (g_AIDir_BotReinforceTriggered)
		g_AIDir_TeamStatus -= 5;
	else
		g_AIDir_TeamStatus += 10;

	g_AIDir_BotReinforceTriggered = false;
	//AI Director Status ###END###

	// Init variables
	ConVar cvar;

	// Set minimum and maximum counter attack duration time
	g_counterAttack_min_dur_sec = sm_respawn_min_counter_dur_sec.IntValue;
	g_counterAttack_max_dur_sec = sm_respawn_max_counter_dur_sec.IntValue;
	int final_ca_dur = sm_respawn_final_counter_dur_sec.IntValue;

	// Get random duration
	int fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	int fRandomIntCounterLarge = GetRandomInt(1, 100);
	int largeCounterEnabled = false;
	if (fRandomIntCounterLarge <= 15)
	{
		fRandomInt = (fRandomInt * 2);
		int fRandomInt2 = GetRandomInt(60, 90);
		final_ca_dur = (final_ca_dur + fRandomInt2);
		largeCounterEnabled = true;
	}

	// Set counter attack duration to server
	ConVar cvar_ca_dur;

	// Final counter attack
	if ((acp+1) == ncp)
	{
		g_iRemaining_lives_team_ins = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i > 0 && IsClientInGame(i))
			{
				if(IsFakeClient(i)) 		
					ForcePlayerSuicide(i);
			}
		}

		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		cvar_ca_dur.SetInt(final_ca_dur, true, false);
		g_dynamicSpawnCounter_Perc += 10;

		if (g_finale_counter_spec_enabled == 1)
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;

		//If endless spawning on final counter attack, add lives on finale counter on a delay
		if (g_iCvar_final_counterattack_type == 2)
		{
			float tCvar_CounterDelayValue = FindConVar("mp_checkpoint_counterattack_delay_finale").FloatValue;
			CreateTimer((tCvar_CounterDelayValue),Timer_FinaleCounterAssignLives);
		}
	}

	// Normal counter attack
	else
	{
		g_AIDir_TeamStatus -= 5;
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		cvar_ca_dur.SetInt(fRandomInt, true, false);
	}

	// Get random value for occuring counter attack
	float fRandom = GetRandomFloat(0.0, 1.0);

	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && ((acp+1) != ncp))
	{
		cvar = null;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		cvar.SetInt(1, true, false);
		if (largeCounterEnabled)
		{
			PrintHintTextToAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
		}
		g_AIDir_TeamStatus -= 5;

		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer(cvar_ca_dur.FloatValue + 1.0, Timer_CounterAttackEnd);
		if (g_elite_counter_attacks == 1) 
		{
			EnableDisableEliteBotCvars(1, 0);
			ConVar tCvar = FindConVar("ins_bot_count_checkpoint_max");
			int tCvarIntValue = FindConVar("ins_bot_count_checkpoint_max").IntValue;
			tCvarIntValue += 3;
			tCvar.SetInt(tCvarIntValue, true, false);
		}
	}
	// If last capture point
	else if (g_isCheckpoint == 1 && ((acp+1) == ncp)) 
	{
		cvar = null;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		cvar.SetInt(1, true, false);

		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer((cvar_ca_dur.FloatValue + 1.0), Timer_CounterAttackEnd);

		if (g_elite_counter_attacks == 1) 
		{
			EnableDisableEliteBotCvars(1, 1);
			ConVar tCvar = FindConVar("ins_bot_count_checkpoint_max");
			int tCvarIntValue = FindConVar("ins_bot_count_checkpoint_max").IntValue;
			tCvarIntValue += 3;
			tCvar.SetInt(tCvarIntValue, true, false);
		}
	}
	// Not occurs counter attack
	else
	{
		cvar = null;
		//PrintToServer("COUNTER NO");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(1, true, false);
	}
	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
	
	return Plugin_Continue;
}

// When control point captured, reset variables
public Action Event_ControlPointCaptured(Event event, const char[] name, bool dontBroadcast)
{
	// Reset reinforcement time
	g_iReinforceTime = g_iReinforceTime_AD_Temp;
	
	// Reset respawn tokens
	ResetInsurgencyLives();
	if (g_iCvar_respawn_reset_type && g_isCheckpoint)
		ResetSecurityLives();
	
	return Plugin_Continue;
}

// When control point captured, update respawn point and respawn all players
public Action Event_ControlPointCaptured_Post(Event event, const char[] name, bool dontBroadcast)
{
	if (sm_respawn_security_on_counter.IntValue == 1)
	{
		// Get client who captured control point.
		char cappers[512];
		event.GetString("cappers", cappers, sizeof(cappers));
		int cappersLength = strlen(cappers);
		for (int i = 0 ; i < cappersLength; i++) 
		{
			int clientCapper = cappers[i];
			if (clientCapper > 0 && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper)) 
			{
				// Get player's position
				float capperPos[3];
				GetClientAbsOrigin(clientCapper, capperPos);

				// Update respawn position
				g_fRespawnPosition = capperPos;

				break;
			}
		}

		// Respawn all players
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				int team = GetClientTeam(client);
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if (playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1_SEC)
				{
					if (!IsFakeClient(client))
					{
						if (!IsClientTimingOut(client))
							CreateCounterRespawnTimer(client);
					}
					else
					{
						CreateCounterRespawnTimer(client);
					}
				}
			}
		}
	}

	// Update cvars
	UpdateRespawnCvars();

	//Reset security team wave counter
	g_secWave_Timer = g_iRespawnSeconds;

	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	// If last capture point
	if (((acp+1) == ncp))
	{
		g_secWave_Timer = g_iRespawnSeconds;
		g_secWave_Timer += (GetTeamSecCount() * 4);
	}
	else if (Ins_InCounterAttack())
			g_secWave_Timer += (GetTeamSecCount() * 3);
	return Plugin_Continue;
}

// When ammo cache destroyed, update respawn position and reset variables
public Action Event_ObjectDestroyed_Pre(Event event, const char[] name, bool dontBroadcast)
{
	//Clear bad spawn array
	for (int client = 0; client < MaxClients; client++)
	{
		if (!IsValidClient(client) || client <= 0 || !IsClientInGame(client)) continue;
		int m_iTeam = GetClientTeam(client);
		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
		{
			g_badSpawnPos_Track[client][0] = 0.0;
			g_badSpawnPos_Track[client][1] = 0.0;
			g_badSpawnPos_Track[client][2] = 0.0;
		}
	}

	
	//Commenting out below two lines as functions not used as commented out on 10/10
//	g_checkStaticAmt = sm_respawn_check_static_enemy.IntValue;
//	g_checkStaticAmtCntr = sm_respawn_check_static_enemy_counter.IntValue;

	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints"); // Get the number of control points	
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex"); // Get active push point

	//AI Director Status ###START###
	int secTeamCount = GetTeamSecCount();
	int secTeamAliveCount = Team_CountAlivePlayers(TEAM_1_SEC);

	if (g_iRespawn_lives_team_ins > 0)
		g_AIDir_TeamStatus += 10;
	if (secTeamAliveCount >= (secTeamCount * 0.8)) // If Alive Security >= 80%
		g_AIDir_TeamStatus += 10;
	else if (secTeamAliveCount >= (secTeamCount * 0.5)) // If Alive Security >= 50%
		g_AIDir_TeamStatus += 5;
	else if (secTeamAliveCount <= (secTeamCount * 0.2)) // If Dead Security <= 20%
		g_AIDir_TeamStatus -= 10;
	else if (secTeamAliveCount <= (secTeamCount * 0.5)) // If Dead Security <= 50%
		g_AIDir_TeamStatus -= 5;

	if (g_AIDir_BotReinforceTriggered)
		g_AIDir_TeamStatus += 10;
	else
		g_AIDir_TeamStatus -= 5;

	g_AIDir_BotReinforceTriggered = false;

	//AI Director Status ###END###

	// Get gamemode
	char sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	// Init variables
	ConVar cvar;
	
	// Set minimum and maximum counter attack duration time
	g_counterAttack_min_dur_sec = sm_respawn_min_counter_dur_sec.IntValue;
	g_counterAttack_max_dur_sec = sm_respawn_max_counter_dur_sec.IntValue;
	int final_ca_dur = sm_respawn_final_counter_dur_sec.IntValue;

	// Get random duration
	int fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	int fRandomIntCounterLarge = GetRandomInt(1, 100);
	int largeCounterEnabled = false;
	if (fRandomIntCounterLarge <= 15)
	{
		fRandomInt = (fRandomInt * 2);
		int fRandomInt2 = GetRandomInt(90, 180);
		final_ca_dur = (final_ca_dur + fRandomInt2);
		largeCounterEnabled = true;
	}
	// Set counter attack duration to server
	ConVar cvar_ca_dur;

	// Final counter attack
	if ((acp+1) == ncp)
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		cvar_ca_dur.SetInt(final_ca_dur, true, false);
		g_dynamicSpawnCounter_Perc += 10;
		//g_AIDir_TeamStatus -= 10;
		if (g_finale_counter_spec_enabled == 1)
		{
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;
		}
	}
	// Normal counter attack
	else
	{
		g_AIDir_TeamStatus -= 5;
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		cvar_ca_dur.SetInt(fRandomInt, true, false);
	}

	//Are we using vanilla counter attack?
	if (g_iCvar_counterattack_vanilla == 1) return Plugin_Continue;

	// Get random value for occuring counter attack
	float fRandom = GetRandomFloat(0.0, 1.0);
	//PrintToServer("Counter Chance = %f", g_respawn_counter_chance);

	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && ((acp+1) != ncp))
	{
		cvar = null;
		//PrintToServer("COUNTER YES");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		cvar.SetInt(1, true, false);
		if (largeCounterEnabled)
		{
			PrintHintTextToAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
			//PrintToChatAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
		}
		g_AIDir_TeamStatus -= 5;
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);

		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer(cvar_ca_dur.FloatValue + 1.0, Timer_CounterAttackEnd);
		if (g_elite_counter_attacks == 1)
		{
			EnableDisableEliteBotCvars(1, 0);
			ConVar tCvar = FindConVar("ins_bot_count_checkpoint_max");
			int tCvarIntValue = FindConVar("ins_bot_count_checkpoint_max").IntValue;
			tCvarIntValue += 3;
			tCvar.SetInt(tCvarIntValue, true, false);
		}
	}
	// If last capture point
	else if (((acp+1) == ncp))
	{
		cvar = null;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		cvar.SetInt(1, true, false);

		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer(cvar_ca_dur.FloatValue + 1.0, Timer_CounterAttackEnd);

		if (g_elite_counter_attacks == 1) 
		{
			EnableDisableEliteBotCvars(1, 1);
			ConVar tCvar = FindConVar("ins_bot_count_checkpoint_max");
			int tCvarIntValue = FindConVar("ins_bot_count_checkpoint_max").IntValue;
			tCvarIntValue += 3;
			tCvar.SetInt(tCvarIntValue, true, false);
		}
	}
	
	// Not occurs counter attack
	else
	{
		cvar = null;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		cvar.SetInt(1, true, false);
	}

	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
	
	return Plugin_Continue;
}

// When ammo cache destroyed, update respawn position and reset variables
public Action Event_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	// Reset reinforcement time
	g_iReinforceTime = g_iReinforceTime_AD_Temp;

	// Reset respawn token
	ResetInsurgencyLives();
	if (g_iCvar_respawn_reset_type)
		ResetSecurityLives();
	return Plugin_Continue;
}

// When control point captured, update respawn point and respawn all players
public Action Event_ObjectDestroyed_Post(Event event, const char[] name, bool dontBroadcast)
{

	if (sm_respawn_security_on_counter.IntValue == 1) 
	{
		// Get client who captured control point.
		char cappers[512];
		event.GetString("cappers", cappers, sizeof(cappers));
		int cappersLength = strlen(cappers);
		for (int i = 0 ; i < cappersLength; i++) 
		{
			int clientCapper = cappers[i];
			if (clientCapper > 0 && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper)) 
			{
				// Get player's position
				float capperPos[3];
				GetClientAbsOrigin(clientCapper, capperPos);

				// Update respawn position
				g_fRespawnPosition = capperPos;
				break;
			}
		}

		// Respawn all players
		for (int client = 1; client <= MaxClients; client++) 
		{
			if (IsClientInGame(client)) 
			{
				int team = GetClientTeam(client);
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if (playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1_SEC) 
				{
					if (!IsFakeClient(client)) 
					{
						if (!IsClientTimingOut(client)) 
						{
							CreateCounterRespawnTimer(client);
						}
					}
					else
					{
						CreateCounterRespawnTimer(client);
					}
				}
			}
		}
	}

	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// If last capture point
	if (((acp+1) == ncp))
	{
		g_secWave_Timer = g_iRespawnSeconds;
		g_secWave_Timer += (GetTeamSecCount() * 4);
	}
	else if (Ins_InCounterAttack())
		g_secWave_Timer += (GetTeamSecCount() * 3);
	return Plugin_Continue;
}

//Enable/Disable Elite Bots
void EnableDisableEliteBotCvars(int tEnabled, int isFinale) 
{
	float tCvarFloatValue;
	int tCvarIntValue;
	ConVar tCvar;
	if (tEnabled == 1) 
	{
		//PrintToServer("BOT_SETTINGS_APPLIED");
		if (isFinale == 1) 
		{
			tCvar = FindConVar("mp_player_resupply_coop_delay_max");
			tCvar.SetInt(g_coop_delay_penalty_base, true, false);
			tCvar = FindConVar("mp_player_resupply_coop_delay_penalty");
			tCvar.SetInt(g_coop_delay_penalty_base, true, false);
			tCvar = FindConVar("mp_player_resupply_coop_delay_base");
			tCvar.SetInt(g_coop_delay_penalty_base, true, false);
		}

		tCvar = FindConVar("bot_attackdelay_frac_difficulty_impossible");
		tCvarFloatValue = FindConVar("bot_attackdelay_frac_difficulty_impossible").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_attackdelay_frac_difficulty_impossible_mult;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_amt_close");
		tCvarIntValue = FindConVar("bot_attack_aimpenalty_amt_close").IntValue;
		tCvarIntValue = tCvarIntValue - g_bot_attack_aimpenalty_amt_close_mult;
		tCvar.SetInt(tCvarIntValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_amt_far");
		tCvarIntValue = FindConVar("bot_attack_aimpenalty_amt_far").IntValue;
		tCvarIntValue = tCvarIntValue - g_bot_attack_aimpenalty_amt_far_mult;
		tCvar.SetInt(tCvarIntValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_time_close");
		tCvarFloatValue = FindConVar("bot_attack_aimpenalty_time_close").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_attack_aimpenalty_time_close_mult;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_time_far");
		tCvarFloatValue = FindConVar("bot_attack_aimpenalty_time_far").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_attack_aimpenalty_time_far_mult;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		ConVar cv = FindConVar("bot_attack_aimtolerance_newthreat_amt");
		cv.FloatValue -= cv.FloatValue - g_bot_attack_aimtolerance_newthreat_amt_mult;

		tCvar = FindConVar("bot_aim_aimtracking_base");
		tCvarFloatValue = FindConVar("bot_aim_aimtracking_base").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_aimtracking_base;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_aimtracking_frac_impossible");
		tCvarFloatValue = FindConVar("bot_aim_aimtracking_frac_impossible").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_aimtracking_frac_impossible;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_angularvelocity_frac_impossible");
		tCvarFloatValue = FindConVar("bot_aim_angularvelocity_frac_impossible").FloatValue;
		tCvarFloatValue = tCvarFloatValue + g_bot_aim_angularvelocity_frac_impossible;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_angularvelocity_frac_sprinting_target");
		tCvarFloatValue = FindConVar("bot_aim_angularvelocity_frac_sprinting_target").FloatValue;
		tCvarFloatValue = tCvarFloatValue + g_bot_aim_angularvelocity_frac_sprinting_target;
		tCvar.SetFloat(tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_attack_aimtolerance_frac_impossible");
		tCvarFloatValue = FindConVar("bot_aim_attack_aimtolerance_frac_impossible").FloatValue;
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_attack_aimtolerance_frac_impossible;
		tCvar.SetFloat(tCvarFloatValue, true, false);
		//Make sure to check for FLOATS vs INTS and +/-!
	}
	else 
	{
		tCvar = FindConVar("ins_bot_count_checkpoint_max");
		tCvar.SetInt(g_ins_bot_count_checkpoint_max_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_max");
		tCvar.SetInt(g_mp_player_resupply_coop_delay_max_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_penalty");
		tCvar.SetInt(g_mp_player_resupply_coop_delay_penalty_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_base");
		tCvar.SetInt(g_mp_player_resupply_coop_delay_base_org, true, false);
		tCvar = FindConVar("bot_attackdelay_frac_difficulty_impossible");
		tCvar.SetFloat(g_bot_attackdelay_frac_difficulty_impossible_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_amt_close");
		tCvar.SetInt(g_bot_attack_aimpenalty_amt_close_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_amt_far");
		tCvar.SetInt(g_bot_attack_aimpenalty_amt_far_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_time_close");
		tCvar.SetFloat(g_bot_attack_aimpenalty_time_close_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_time_far");
		tCvar.SetFloat(g_bot_attack_aimpenalty_time_far_org, true, false);
		tCvar = FindConVar("bot_attack_aimtolerance_newthreat_amt");
		tCvar.SetFloat(g_bot_attack_aimtolerance_newthreat_amt_org, true, false);
		tCvar = FindConVar("bot_aim_aimtracking_base");
		tCvar.SetFloat(g_bot_aim_aimtracking_base_org, true, false);
		tCvar = FindConVar("bot_aim_aimtracking_frac_impossible");
		tCvar.SetFloat(g_bot_aim_aimtracking_frac_impossible_org, true, false);
		tCvar = FindConVar("bot_aim_angularvelocity_frac_impossible");
		tCvar.SetFloat(g_bot_aim_angularvelocity_frac_impossible_org, true, false);
		tCvar = FindConVar("bot_aim_angularvelocity_frac_sprinting_target");
		tCvar.SetFloat(g_bot_aim_angularvelocity_frac_sprinting_target_org, true, false);
		tCvar = FindConVar("bot_aim_attack_aimtolerance_frac_impossible");
		tCvar.SetFloat(g_bot_aim_attack_aimtolerance_frac_impossible_org, true, false);
	}
}

// On finale counter attack, add lives back to insurgents to trigger unlimited respawns (this is redundant code now and may use for something else)
Action Timer_FinaleCounterAssignLives(Handle timer) 
{
	if (g_iCvar_final_counterattack_type == 2) 
	{
			// Reset remaining lives for bots
			g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins;
	}
}

// When counter-attack end, reset reinforcement time
Action Timer_CounterAttackEnd(Handle timer) 
{
	//Disable elite bots when not in counter
	if (g_isEliteCounter == 1 && g_elite_counter_attacks == 1) 
	{
		g_isEliteCounter = 0;
		EnableDisableEliteBotCvars(0, 0);
	}

	ResetInsurgencyLives();
	if (g_iCvar_respawn_reset_type && g_isCheckpoint) 
	{
			ResetSecurityLives();
	}

	// Reset variable
	ConVar cvar = null;
	cvar = FindConVar("mp_checkpoint_counterattack_always");
	cvar.SetInt(0, true, false);

	for (int client = 0; client < MaxClients; client++) 
	{
			if (!IsValidClient(client) || client <= 0) 
			{
				continue;
			}
			if (!IsClientInGame(client)) 
			{
				continue;
			}
			int m_iTeam = GetClientTeam(client);
			if (IsFakeClient(client) && m_iTeam == TEAM_2_INS) 
			{
				g_badSpawnPos_Track[client][0] = 0.0;
				g_badSpawnPos_Track[client][1] = 0.0;
				g_badSpawnPos_Track[client][2] = 0.0;
			}
	}
	return Plugin_Stop;
}

//Run this to mark a bot as ready to spawn. Add tokens if you want them to be able to spawn.
void ResetSecurityLives() 
{
	// Disable if counquer
	//if (g_isConquer == 1 || g_isOutpost == 1) return;
		// The number of control points
	//new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Active control poin
	//new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");


	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) 
		return;

	// Update cvars
	UpdateRespawnCvars();

	//If spawned per point, give more per-point lives based on team count.
	if (g_iCvar_respawn_reset_type == 1) 
	{
			SecDynLivesPerPoint();
	}
	
	// Individual lives
	if (g_iCvar_respawn_type_team_sec == 1) 
	{
		for (int client = 1; client <= MaxClients; client++) 
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				//Reset Medic Stats:
				g_playerMedicRevivessAccumulated[client] = 0;
				g_playerMedicHealsAccumulated[client] = 0;
				g_playerNonMedicHealsAccumulated[client] = 0;

				// Check Team
				int iTeam = GetClientTeam(client);
				if (iTeam != TEAM_1_SEC) continue;

				/*// Individual SEC lives
				if (g_iCvar_respawn_type_team_sec == 1) 
				{
				// Reset remaining lives for player
					g_iSpawnTokens[client] = g_iRespawnCount[iTeam];
				}*/
			}
		}
	}

	// Team lives
	if (g_iCvar_respawn_type_team_sec == 2) 
	{
		// Reset remaining lives for player
		g_iRemaining_lives_team_sec = g_iRespawn_lives_team_sec;
	}
}

//Run this to mark a bot as ready to spawn. Add tokens if you want them to be able to spawn.
void ResetInsurgencyLives()
{
	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) return;

	// Update cvars
	UpdateRespawnCvars();

	// Individual lives
	if (g_iCvar_respawn_type_team_ins == 1)
	{
		for (int client=1; client<=MaxClients; client++)
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				// Check Team
				int iTeam = GetClientTeam(client);
				if (iTeam != TEAM_2_INS) continue;
				g_iSpawnTokens[client] = g_iRespawnCount[iTeam];
			}
		}
	}

	// Team lives
	if (g_iCvar_respawn_type_team_ins == 2)
	{
		// Reset remaining lives for bots
		g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins;
	}
}

// When player picked squad, initialize variables
public Action Event_PlayerPickSquad_Post(Event event, const char[] name, bool dontBroadcast)
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//PrintToServer("##########PLAYER IS PICKING SQUAD!############");

	// Get client ID
	int client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if( client == 0 || !IsClientInGame(client) || IsFakeClient(client)) return;
	
	// Init variable
	playerPickSquad[client] = 1;

	// Get class name
	char class_template[64];
	event.GetString("class_template", class_template, sizeof(class_template));

	// Set class string
	g_client_last_classstring[client] = class_template;
	g_hintsEnabled[client] = true;

	// If player changed squad and remain ragdoll
	int team = GetClientTeam(client);
	if (client > 0 && IsClientInGame(client) && IsClientObserver(client) && !IsPlayerAlive(client) && g_iHurtFatal[client] == 0 && team == TEAM_1_SEC)
	{
		// Remove ragdoll
		int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);

		// Init variable
		g_iHurtFatal[client] = -1;
	}

	//g_fPlayerLastChat[client] = GetGameTime(); - Commented out on 10/10 due to tag mismatch and suspect may not be needed

	// Get player nickname
	char sNewNickname[64];
	if (IsClientConnected(client) && team == TEAM_1_SEC)
	//if (StrContains(g_client_last_classstring[client], "medic") > -1)
	{
		// Admin player
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM3))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN] %s", g_client_org_nickname[client]);
		// LDR player
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM2))
			Format(sNewNickname, sizeof(sNewNickname), "[LDR] %s", g_client_org_nickname[client]);
		// Donor player
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM1))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR] %s", g_client_org_nickname[client]);
		// Normal player
		else
			Format(sNewNickname, sizeof(sNewNickname), "%s", g_client_org_nickname[client]);
	}

	// Set player nickname
	char sCurNickname[64];
	Format(sCurNickname, sizeof(sCurNickname), "%N", client);
	if (!StrEqual(sCurNickname, sNewNickname))
		SetClientName(client, sNewNickname);

	g_playersReady = true;

	//Allow new players to use lives to respawn on join
	if (g_iRoundStatus == 1 && g_playerFirstJoin[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1_SEC)
	{
		// Get SteamID to verify is player has connected before.
		char steamId[64];
		GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		int isPlayerNew = g_playerArrayList.FindString(steamId);

		if (isPlayerNew != -1)
		{
			//PrintToServer("Player %N has reconnected! | SteamID: %s | Index: %d", client, steamId, isPlayerNew);
		}
		else
		{
			g_playerArrayList.PushString(steamId);
			//PrintToServer("Player %N is new! | SteamID: %s | PlayerArrayList Size: %d", client, steamId, g_playerArrayList.Length);
			// Give individual lives to new player (no longer just at beginning of round)
			if (g_iCvar_respawn_type_team_sec == 1) {
				if (g_isCheckpoint && g_iCvar_respawn_reset_type == 0) {
					// The number of control points
					int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
					// Active control poin
					int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
					int tLiveSec = sm_respawn_lives_team_sec.IntValue;

					if (acp <= (ncp / 2)) {
						g_iSpawnTokens[client] = tLiveSec;
					}
					else {
						g_iSpawnTokens[client] = (tLiveSec / 2);
					}

					if (tLiveSec < 1) {
						tLiveSec = 1;
						g_iSpawnTokens[client] = tLiveSec;
					}
				}
				else {
					g_iSpawnTokens[client] = sm_respawn_lives_team_sec.IntValue;
				}

			}
			CreatePlayerRespawnTimer(client);
		}
	}

	//Update RespawnCvars when player picks squad
	UpdateRespawnCvars();
}

// Triggers when player hurt
public Action Event_PlayerHurt_Pre(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (IsClientInGame(victim) && IsFakeClient(victim)) {
		return Plugin_Continue;
	}

	int victimHealth = event.GetInt("health");
	int dmg_taken = event.GetInt("dmg_health");
	//PrintToServer("victimHealth: %d, dmg_taken: %d", victimHealth, dmg_taken);
	if (g_fCvar_fatal_chance > 0.0 && dmg_taken > victimHealth) {
		// Get information for event structure
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		int hitgroup = event.GetInt("hitgroup");

		// Update last damege (related to 'hurt_fatal')
		g_clientDamageDone[victim] = dmg_taken;

		// Get weapon
		char weapon[32];
		event.GetString("weapon", weapon, sizeof(weapon));

		//PrintToServer("[DAMAGE TAKEN] Weapon used: %s, Damage done: %i", weapon, dmg_taken);

		// Check is team attack
		int attackerTeam;
		if (attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker)) {
			attackerTeam = GetClientTeam(attacker);
		}

		// Get fatal chance
		float fRandom = GetRandomFloat(0.0, 1.0);

		// Is client valid
		if (IsClientInGame(victim)) {

			// Explosive
			if (hitgroup == 0) {
				//explosive list
				//incens
				//grenade_molotov, grenade_anm14
				//PrintToServer("[HITGROUP HURT BURN]");
				//grenade_m67, grenade_f1, grenade_ied, grenade_c4, rocket_rpg7, rocket_at4, grenade_gp25_he, grenade_m203_he
				// flame
				if (StrEqual(weapon, "grenade_anm14", false) || StrEqual(weapon, "grenade_molotov", false)) {
					//PrintToServer("[SUICIDE] incen/molotov DETECTED!");
					if (dmg_taken >= g_iCvar_fatal_burn_dmg && (fRandom <= g_fCvar_fatal_chance)) {
						// Hurt fatally
						g_iHurtFatal[victim] = 1;

						//PrintToServer("[PLAYER HURT BURN]");
					}
				}
				// explosive
				else if (StrEqual(weapon, "grenade_m67", false) ||
					StrEqual(weapon, "grenade_f1", false) ||
					StrEqual(weapon, "grenade_ied", false) ||
					StrEqual(weapon, "grenade_c4", false) ||
					StrEqual(weapon, "rocket_rpg7", false) ||
					StrEqual(weapon, "rocket_at4", false) ||
					StrEqual(weapon, "grenade_gp25_he", false) ||
					StrEqual(weapon, "grenade_m203_he", false)) {
					//PrintToServer("[HITGROUP HURT EXPLOSIVE]");
					if (dmg_taken >= g_iCvar_fatal_explosive_dmg && (fRandom <= g_fCvar_fatal_chance)) {
						// Hurt fatally
						g_iHurtFatal[victim] = 1;

						//PrintToServer("[PLAYER HURT EXPLOSIVE]");
					}
				}
				//PrintToServer("[SUICIDE] HITRGOUP 0 [GENERIC]");
			}
			// Headshot
			else if (hitgroup == 1) {
				//PrintToServer("[PLAYER HURT HEAD]");
				if (dmg_taken >= g_iCvar_fatal_head_dmg && (fRandom <= g_fCvar_fatal_head_chance) && attackerTeam != TEAM_1_SEC) {
					// Hurt fatally
					g_iHurtFatal[victim] = 1;

					//PrintToServer("[BOTSPAWNS] BOOM HEADSHOT");
				}
			}
			// Chest
			else if (hitgroup == 2 || hitgroup == 3) {
				//PrintToServer("[HITGROUP HURT CHEST]");
				if (dmg_taken >= g_iCvar_fatal_chest_stomach && (fRandom <= g_fCvar_fatal_chance)) {
					// Hurt fatally
					g_iHurtFatal[victim] = 1;

					//PrintToServer("[PLAYER HURT CHEST]");
				}
			}
			// Limbs
			else if (hitgroup == 4 || hitgroup == 5  || hitgroup == 6 || hitgroup == 7) {
				//PrintToServer("[HITGROUP HURT LIMBS]");
				if (dmg_taken >= g_iCvar_fatal_limb_dmg && (fRandom <= g_fCvar_fatal_chance)) {
					// Hurt fatally
					g_iHurtFatal[victim] = 1;

					//PrintToServer("[PLAYER HURT LIMBS]");
				}
			}
		}
	}
	//Track wound type (minor, moderate, critical)
	if (g_iHurtFatal[victim] != 1) {
		if (dmg_taken <= g_minorWound_dmg) {
			g_playerWoundTime[victim] = g_minorRevive_time;
			g_playerWoundType[victim] = 0;
		}
		else if (dmg_taken > g_minorWound_dmg && dmg_taken <= g_moderateWound_dmg) {
			g_playerWoundTime[victim] = g_modRevive_time;
			g_playerWoundType[victim] = 1;
		}
		else if (dmg_taken > g_moderateWound_dmg) {
			g_playerWoundTime[victim] = g_critRevive_time;
			g_playerWoundType[victim] = 2;
		}
	}
	else {
		g_playerWoundTime[victim] = -1;
		g_playerWoundType[victim] = -1;
	}

	////////////////////////
	// Rank System
	int attackerId = event.GetInt("attacker");
	int hitgroup = event.GetInt("hitgroup");

	int attacker = GetClientOfUserId(attackerId);

	if (hitgroup == 1) {
		g_iStatHeadShots[attacker]++;
	}
	////////////////////////

	return Plugin_Continue;
}

// Triggered when player die PRE
public Action Event_PlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast) 
{
		int client = GetClientOfUserId(event.GetInt("userid"));
		// Tracking ammo
		if (g_iEnableRevive == 1 && g_iRoundStatus == 1 && g_iCvar_enable_track_ammo == 1)
		{
			//PrintToChatAll("### GET PLAYER WEAPONS ###");
			//CONSIDER IF PLAYER CHOOSES DIFFERENT CLASS
			// Get weapons
			int primaryWeapon = GetPlayerWeaponSlot(client, 0);
			int secondaryWeapon = GetPlayerWeaponSlot(client, 1);

			// Set weapons to variables
			playerPrimary[client] = primaryWeapon;
			playerSecondary[client] = secondaryWeapon;

			//Get ammo left in clips for primary and secondary
			playerClip[client][0] = GetPrimaryAmmo(client, primaryWeapon, 0);
			playerClip[client][1] = GetPrimaryAmmo(client, secondaryWeapon, 1); // m_iClip2 for secondary if this doesnt work? would need GetSecondaryAmmo

			if (!playerInRevivedState[client])
			{
				//Get Magazines left on player
				if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
					 Client_GetWeaponPlayerAmmoEx(client, primaryWeapon, playerAmmo[client][0]); //primary
				if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
					 Client_GetWeaponPlayerAmmoEx(client, secondaryWeapon, playerAmmo[client][1]); //secondary	
			}
			playerInRevivedState[client] = false;
		}
}

//Thanks to Headline for fixing part of this function
// Trigged when player die
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	////////////////////////
	// Rank System
	int victimId = event.GetInt("userid");
	int attackerId = event.GetInt("attacker");
	int victim = GetClientOfUserId(victimId);
	int attacker = GetClientOfUserId(attackerId);

	if (victim != attacker) 
	{
		g_iStatKills[attacker]++;
		g_iStatDeaths[victim]++;
	}
	else 
	{
		g_iStatSuicides[victim]++;
		g_iStatDeaths[victim]++;
	}

	// Get player ID
	int client = GetClientOfUserId(event.GetInt("userid"));
	// Check client valid
	if (!(0 < attacker <= MaxClients) || !IsClientInGame(client)) 
	{
		return Plugin_Continue;
	} 
	g_iPlayerBGroups[client] = GetEntProp(client, Prop_Send, "m_nBody");

	// Set variable
	int dmg_taken = event.GetInt("damagebits");
	if (dmg_taken <= 0) 
	{
		g_playerWoundTime[client] = g_minorRevive_time;
		g_playerWoundType[client] = 0;
	}

	int team = GetClientTeam(client);
	int attackerTeam = GetClientTeam(attacker);

	//AI Director START
	//Bot Team AD Status
	if (team == TEAM_2_INS && g_iRoundStatus == 1 && attackerTeam == TEAM_1_SEC) 
	{
		//Bonus point for specialty bots
		if (AI_Director_IsSpecialtyBot(client)) 
		{
			g_AIDir_TeamStatus += 1;
		}
		g_AIDir_BotsKilledCount++;
		if (g_AIDir_BotsKilledCount > (GetTeamSecCount() / g_AIDir_BotsKilledReq_mult)) 
		{
			g_AIDir_BotsKilledCount = 0;
			g_AIDir_TeamStatus += 1;
		}
	}
		//Player Team AD STATUS
	if (team == TEAM_1_SEC && g_iRoundStatus == 1) 
	{
		if (g_iHurtFatal[client] == 1) 
		{
			g_AIDir_TeamStatus -= 3;
		}
		else 
		{
			g_AIDir_TeamStatus -= 2;
		}
		if ((StrContains(g_client_last_classstring[client], "medic") > -1)) 
		{
			g_AIDir_TeamStatus -= 3;
		}
	}
	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

	//AI Director END
	if (g_iCvar_revive_enable) 
	{
		// Convert ragdoll
		if (team == TEAM_1_SEC) 
		{
			// Get current position
			float vecPos[3];
			GetClientAbsOrigin(client, vecPos);
			g_fDeadPosition[client] = vecPos;

				// Call ragdoll timer
			if (g_iEnableRevive == 1 && g_iRoundStatus == 1) 
			{
				CreateTimer(5.0, ConvertDeleteRagdoll, client);
			}
		}
	}
	// Check enables
	if (g_iCvar_respawn_enable) 
	{
		// Client should be TEAM_1_SEC = HUMANS or TEAM_2_INS = BOTS
		if ((team == TEAM_1_SEC) || (team == TEAM_2_INS)) 
		{
			// The number of control points
			int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

			// Active control point
			int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

			// Do not decrease life in counterattack
			if (g_isCheckpoint == 1 && Ins_InCounterAttack() &&
				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) ||
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))) 
			{
				// Respawn type 1 bots
				if ((g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS) &&
				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) ||
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))) 
				{
					if ((g_iSpawnTokens[client] < g_iRespawnCount[team])) 
					{
						g_iSpawnTokens[client] = (g_iRespawnCount[team] + 1);
					}

					// Call respawn timer
					CreateBotRespawnTimer(client);
				}
				// Respawn type 1 player (individual lives)
				else if (g_iCvar_respawn_type_team_sec == 1 && team == TEAM_1_SEC) 
				{
					if (g_iSpawnTokens[client] > 0) 
					{
						if (team == TEAM_1_SEC) 
						{
							CreatePlayerRespawnTimer(client);
						}
					}
					else if (g_iSpawnTokens[client] <= 0 && g_iRespawnCount[team] > 0) 
					{
						// Cannot respawn anymore
						char sChat[128];
						Format(sChat, 128,"You cannot be respawned anymore. (out of lives)");
						PrintToChat(client, "%s", sChat);
					}
				}
				// Respawn type 2 for players
				else if (team == TEAM_1_SEC && g_iCvar_respawn_type_team_sec == 2 && g_iRespawn_lives_team_sec > 0) 
				{
					g_iRemaining_lives_team_sec = g_iRespawn_lives_team_sec + 1;

					// Call respawn timer
					CreateCounterRespawnTimer(client);
				}
				// Respawn type 2 for bots
				else if (team == TEAM_2_INS && g_iCvar_respawn_type_team_ins == 2 &&
				(g_iRespawn_lives_team_ins > 0 ||
				((acp+1) == ncp && g_iCvar_final_counterattack_type == 2) ||
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))) 
				{
					g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins + 1;

					// Call respawn timer
					CreateBotRespawnTimer(client);
				}
			}
			// Normal respawn
			else if ((g_iCvar_respawn_type_team_sec == 1 && team == TEAM_1_SEC) ||
				(g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS)) 
			{
				if (g_iSpawnTokens[client] > 0) 
				{
					if (team == TEAM_1_SEC) 
					{
						CreatePlayerRespawnTimer(client);
					}
					else if (team == TEAM_2_INS) 
					{
						CreateBotRespawnTimer(client);
					}
				}
				else if (g_iSpawnTokens[client] <= 0 && g_iRespawnCount[team] > 0) 
				{
					// Cannot respawn anymore
					char sChat[128];
					Format(sChat, 128,"You cannot be respawned anymore. (out of lives)");
					PrintToChat(client, "%s", sChat);
				}
			}
			// Respawn type 2 for players
			else if (g_iCvar_respawn_type_team_sec == 2 && team == TEAM_1_SEC) 
			{
				if (g_iRemaining_lives_team_sec > 0) 
				{
					CreatePlayerRespawnTimer(client);
				}
				else if (g_iRemaining_lives_team_sec <= 0 && g_iRespawn_lives_team_sec > 0) 
				{
					// Cannot respawn anymore
					char sChat[128];
					Format(sChat, 128,"You cannot be respawned anymore. (out of team lives)");
					PrintToChat(client, "%s", sChat);
				}
			}
			// Respawn type 2 for bots
			else if (g_iCvar_respawn_type_team_ins == 2 && g_iRemaining_lives_team_ins >  0 && team == TEAM_2_INS) 
			{
				CreateBotRespawnTimer(client);
			}
		}
	}

	// Init variables
	char wound_hint[64];
	char fatal_hint[64];
	char woundType[64];
	if (g_playerWoundType[client] == 0) 
	{
		woundType = "MINORLY WOUNDED";
	}
	else if (g_playerWoundType[client] == 1) 
	{
		woundType = "MODERATELY WOUNDED";
	}
	else if (g_playerWoundType[client] == 2) 
	{
		woundType = "CRITCALLY WOUNDED";
	}

	// Display death message
	if (g_fCvar_fatal_chance > 0.0) 
	{
		if (g_iHurtFatal[client] == 1 && !IsFakeClient(client)) 
		{
				Format(fatal_hint, 255,"You were fatally killed for %i damage", g_clientDamageDone[client]);
				PrintHintText(client, "%s", fatal_hint);
				PrintToChat(client, "%s", fatal_hint);
		}
		else 
		{
				Format(wound_hint, 255,"You're %s for %i damage, call a medic for revive!", woundType, g_clientDamageDone[client]);
				PrintHintText(client, "%s", wound_hint);
				PrintToChat(client, "%s", wound_hint);
		}
	}
		else 
		{
			Format(wound_hint, 255,"You're %s for %i damage, call a medic for revive!", woundType, g_clientDamageDone[client]);
			PrintHintText(client, "%s", wound_hint);
			PrintToChat(client, "%s", wound_hint);
		}


		// Update remaining life
		// ConVar hCvar = null;
		// new iRemainingLife = GetRemainingLife();
		// ConVar hCvar = FindConVar("sm_remaininglife");
		// hCvar.SetInt(iRemainingLife);

	return Plugin_Continue;
}

// Convert dead body to new ragdoll
public Action ConvertDeleteRagdoll(Handle timer, any client)
{	
	if (IsClientInGame(client) && g_iRoundStatus == 1 && !IsPlayerAlive(client)) 
	{
		
		// Get dead body
		int clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		
		//This timer safely removes client-side ragdoll
		if(clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && g_iEnableRevive == 1)
		{
			// Get dead body's entity
			int ref = EntIndexToEntRef(clientRagdoll);
			int entity = EntRefToEntIndex(ref);
			if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
			{
				// Remove dead body's entity
				AcceptEntityInput(entity, "Kill");
				clientRagdoll = INVALID_ENT_REFERENCE;
			}
		}
		
		// Check is fatally dead
		if (g_iHurtFatal[client] != 1)
		{
			// Create new ragdoll
			int tempRag = CreateEntityByName("prop_ragdoll");
			
			// Set client's new ragdoll
			g_iClientRagdolls[client]  = EntIndexToEntRef(tempRag);
			
			// Set position
			g_fDeadPosition[client][2] = g_fDeadPosition[client][2] + 50;
			
			// If success initialize ragdoll
			if(tempRag != -1)
			{
				// Get model name
				char sModelName[64];
				GetClientModel(client, sModelName, sizeof(sModelName));
				
				// Set model
				SetEntityModel(tempRag, sModelName);
				DispatchSpawn(tempRag);
				
				// Set collisiongroup
				SetEntProp(tempRag, Prop_Send, "m_CollisionGroup", 17);
				
				//Set bodygroups for ragdoll
				SetEntProp(tempRag, Prop_Send, "m_nBody", g_iPlayerBGroups[client]);
				
				// Teleport to current position
				TeleportEntity(tempRag, g_fDeadPosition[client], NULL_VECTOR, NULL_VECTOR);
				
				// Set vector
				GetEntPropVector(tempRag, Prop_Send, "m_vecOrigin", g_fRagdollPosition[client]);
				
				// Set revive time remaining
				g_iReviveRemainingTime[client] = g_playerWoundTime[client];
				g_iReviveNonMedicRemainingTime[client] = g_nonMedRevive_time;
				// Start revive checking timer
				/*
				Handle revivePack;
				CreateDataTimer(1.0 , Timer_RevivePeriod, revivePack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				revivePack.WriteCell(client);
				revivePack.WriteCell(tempRag);
				*/
			}
			else
			{
				// If failed to create ragdoll, remove entity
				if(tempRag > 0 && IsValidEdict(tempRag) && IsValidEntity(tempRag))
				{
					RemoveRagdoll(client);
				}
			}
		}
	}
}

// Remove ragdoll
void RemoveRagdoll(int client)
{
	//new ref = EntIndexToEntRef(g_iClientRagdolls[client]);
	int entity = EntRefToEntIndex(g_iClientRagdolls[client]);
	if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
		g_iClientRagdolls[client] = INVALID_ENT_REFERENCE;
	}	
}

// This handles revives by medics
void CreateReviveTimer(int client)
{
	CreateTimer(0.0, RespawnPlayerRevive, client);
}

// Handles spawns when counter attack starts
void CreateCounterRespawnTimer(int client)
{
	CreateTimer(0.0, RespawnPlayerCounter, client);
}

// Respawn bot
void CreateBotRespawnTimer(int client)
{	
	CreateTimer(g_fCvar_respawn_delay_team_ins, RespawnBot, client);
}

// Respawn player
void CreatePlayerRespawnTimer(int client)
{
	// Check is respawn timer active
	if (g_iPlayerRespawnTimerActive[client] == 0)
	{
		// Set timer active
		g_iPlayerRespawnTimerActive[client] = 1;
		int timeReduce = (GetTeamSecCount() / 3);
		if (timeReduce <= 0)
		{
			timeReduce = 3;
		}

		int jammerSpawnReductionAmt = (g_iRespawnSeconds / timeReduce);
		g_iRespawnTimeRemaining[client] = (g_iRespawnSeconds - jammerSpawnReductionAmt);
		if (g_iRespawnTimeRemaining[client] < 5)
				g_iRespawnTimeRemaining[client] = 5;
		else
			g_iRespawnTimeRemaining[client] = g_iRespawnSeconds;
		
		//Sync wave based timer if enabled
		if (g_respawn_mode_team_sec)
		{
			g_iRespawnTimeRemaining[client] = g_secWave_Timer;
		}

		// Call respawn timer
		CreateTimer(1.0, Timer_PlayerRespawn, client, TIMER_REPEAT);
	}
}

// Revive player
Action RespawnPlayerRevive(Handle timer, any client)
{
	// Exit if client is not in game
	if (IsPlayerAlive(client) || !IsClientInGame(client) || g_iRoundStatus == 0) return;
	
	// Call forcerespawn function
	SDKCall(g_hForceRespawn, client);
	
	// If set 'sm_respawn_enable_track_ammo', restore player's ammo
	if (playerRevived[client] == true && g_iCvar_enable_track_ammo == 1)
	{
		playerInRevivedState[client] = true;
		SetPlayerAmmo(client); //AmmoResupply_Player(client, 0, 0, 1);
	}
	
	//Set wound health
	int iHealth = GetClientHealth(client);
	if (g_playerNonMedicRevive[client] == 0)
	{
		if (g_playerWoundType[client] == 0)
			iHealth = g_minorWoundRevive_hp;
		else if (g_playerWoundType[client] == 1)
			iHealth = g_modWoundRevive_hp;
		else if (g_playerWoundType[client] == 2)
			iHealth = g_critWoundRevive_hp;
	}
	else if (g_playerNonMedicRevive[client] == 1)
	{
		//NonMedic Revived
		iHealth = g_nonMedicRevive_hp;
	}

	SetEntityHealth(client, iHealth);
	
	// Get player's ragdoll
	int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	//CreateTimer(0.0, RespawnPlayerRevivePost, client);
	RespawnPlayerRevivePost(null, client);
	if ((StrContains(g_client_last_classstring[client], "medic") > -1))
		g_AIDir_TeamStatus += 2;
	else
		g_AIDir_TeamStatus += 1;
	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
}

// Do post revive stuff
public Action RespawnPlayerRevivePost(Handle timer, any client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	TeleportEntity(client, g_fRagdollPosition[client], NULL_VECTOR, NULL_VECTOR);
	
	//Check if player is connected and is alive and player team is security
	int m_iTeam = GetClientTeam(client);
	if((IsClientConnected(client)) && (IsPlayerAlive(client)) && m_iTeam == TEAM_1_SEC)
	{	
		//Set health 100 percent if resupplying
		int iHealth = GetClientHealth(client);
		if (iHealth < 100)
			SetEntityHealth(client, 100);
		playerInRevivedState[client] = false;
	}
	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}

// Respawn player in counter attack
Action RespawnPlayerCounter(Handle timer, any client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	if (IsPlayerAlive(client) || g_iRoundStatus == 0) return;
	
	//PrintToServer("[Counter Respawn] Respawning client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);

	// Get player's ragdoll
	int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
	// If set 'sm_respawn_enable_track_ammo', restore player's ammo
	// Get the number of control points
	//new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	//new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	//Remove grenades if not final
	//if ((acp+1) != ncp)
	//RemoveWeapons(client, 0, 0, 1);

	// Teleport to active counter attack point
	//PrintToServer("[REVIVE_DEBUG] called RespawnPlayerPost for client %N (%d)",client,client);
	if (g_fRespawnPosition[0] != 0.0 && g_fRespawnPosition[1] != 0.0 && g_fRespawnPosition[2] != 0.0)
		TeleportEntity(client, g_fRespawnPosition, NULL_VECTOR, NULL_VECTOR);

	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}


// Respawn bot
public Action RespawnBot(Handle timer, any client)
{

	// Exit if client is not in game
	//if (IsPlayerAlive(client) || !IsClientInGame(client) || g_iRoundStatus == 0) return;
	//if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2 && owner > 0 && GetClientTeam(owner) == 3)
	
	//if (client > 0 && !IsClientInGame(client) || IsPlayerAlive(client) || g_iRoundStatus == 0) 

	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsPlayerAlive(client) || g_iRoundStatus == 0) return;	
	char sModelName[64];
	GetClientModel(client, sModelName, sizeof(sModelName));
	if (StrEqual(sModelName, "")) return;	
	
	// Check respawn type
	if (g_iCvar_respawn_type_team_ins == 1 && g_iSpawnTokens[client] > 0)
		g_iSpawnTokens[client]--;
	else if (g_iCvar_respawn_type_team_ins == 2)
	{
		if (g_iRemaining_lives_team_ins > 0)
		{
			g_iRemaining_lives_team_ins--;
			if (g_iRemaining_lives_team_ins <= 0)
				g_iRemaining_lives_team_ins = 0;
			//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
		}
	}
	//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
	//PrintToServer("######################TEAM 2 LIVES REMAINING %i", g_iRemaining_lives_team_ins);
	//PrintToServer("[RESPAWN] Respawning client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	
	// Call forcerespawn function
	
	//if (client !=0) SDKCall(g_hForceRespawn, client);

	//if ((0 >= client || client > MaxClients) || !IsClientInGame(client))
	if ((0 < client <= MaxClients) || !IsClientInGame(client))
	{
		
		SDKCall(g_hForceRespawn, client); 	
	}
}

// Monitor player reload and set ammo after each reload
public Action Timer_ForceReload(Handle timer, any client)
{
	bool isReloading = Client_IsReloading(client);
	int primaryWeapon = GetPlayerWeaponSlot(client, 0);
	int secondaryWeapon = GetPlayerWeaponSlot(client, 1);

	if (IsPlayerAlive(client) && g_iRoundStatus == 1 && !isReloading && g_playerActiveWeapon[client] == primaryWeapon)
	{
		playerAmmo[client][0] -= 1;
		SetPlayerAmmo(client);
		return Plugin_Stop;
	}

	if (IsPlayerAlive(client) && g_iRoundStatus == 1 && !isReloading && g_playerActiveWeapon[client] == secondaryWeapon)
	{
		playerAmmo[client][1] -= 1;
		SetPlayerAmmo(client);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

// Player respawn timer
Action Timer_PlayerRespawn(Handle timer, any client)
{
    char sRemainingTime[256];

    // Exit if client is not in game
    if (!IsClientInGame(client)) return Plugin_Stop; // empty class name
    if (!IsPlayerAlive(client) && g_iRoundStatus == 1)
    {
        if (g_iRespawnTimeRemaining[client] > 0)
        {   
            if (g_playerFirstJoin[client] == 1)
            {
                char woundType[128];
                int tIsFatal = false;
                if (g_iHurtFatal[client] == 1)
                {
                    woundType = "fatally killed";
                    tIsFatal = true;
                }
                else
                {
                    woundType = "WOUNDED";
                    if (g_playerWoundType[client] == 0)
                        woundType = "MINORLY WOUNDED";
                    else if (g_playerWoundType[client] == 1)
                        woundType = "MODERATELY WOUNDED";
                    else if (g_playerWoundType[client] == 2)
                        woundType = "CRITCALLY WOUNDED";
                }
                // Print remaining time to center text area
                if (!IsFakeClient(client))
                {
                    if (tIsFatal)
                    {
                        Format(sRemainingTime, sizeof(sRemainingTime),"Reinforcing in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
                    }
                    else
                    {
                        Format(sRemainingTime, sizeof(sRemainingTime),"%s for %d damage | wait patiently for a medic\n\n reinforcing in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
                    }
                    PrintCenterText(client, sRemainingTime);
                }
            }
            
            // Decrease respawn remaining time
            g_iRespawnTimeRemaining[client]--;
        }
        else
        {
            // Decrease respawn token
            if (g_iCvar_respawn_type_team_sec == 1)
                g_iSpawnTokens[client]--;
            else if (g_iCvar_respawn_type_team_sec == 2)
                g_iRemaining_lives_team_sec--;
            
            // Call forcerespawn function
            SDKCall(g_hForceRespawn, client);

            //AI Director START
            if ((StrContains(g_client_last_classstring[client], "medic") > -1))
                g_AIDir_TeamStatus += 2;
            else
                g_AIDir_TeamStatus += 1;

            g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
                
            //AI Director STOP

            // Print remaining time to center text area
            if (!IsFakeClient(client))
                PrintCenterText(client, "You reinforced! (%d lives left)", g_iSpawnTokens[client]);

            
            bool tSquadSpawned = false;             //Lets confirm squad spawn
            int playerRag = EntRefToEntIndex(g_iClientRagdolls[client]); // Get ragdoll position
            
            // Remove network ragdoll
            if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
                RemoveRagdoll(client);
            
            // Do the post-spawn stuff like moving to final "spawnpoint" selected
            //CreateTimer(0.0, RespawnPlayerPost, client);
            //RespawnPlayerPost(null, client);
                    
            // Reset ragdoll position
            g_fRagdollPosition[client][0] = 0.0;
            g_fRagdollPosition[client][1] = 0.0;
            g_fRagdollPosition[client][2] = 0.0;

            // Announce respawn if not wave based (to avoid spam)
            if (!g_respawn_mode_team_sec)
            {
            if (g_squadSpawnEnabled[client] == 1 && tSquadSpawned == true)
                    PrintToChatAll("\x05%N\x01 squad-reinforced on %N", client, g_squadLeader[client]);
                else
                    PrintToChatAll("\x05%N\x01 reinforced..", client);
            }
            // Reset variable
            g_iPlayerRespawnTimerActive[client] = 0;
            return Plugin_Stop;
        }
    }
    else
    {
        // Reset variable
        g_iPlayerRespawnTimerActive[client] = 0; 
        return Plugin_Stop;
    }
    return Plugin_Continue;
}


// Handles reviving for medics and non-medics
public Action Timer_ReviveMonitor(Handle timer, any data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Init variables
	float fReviveDistance = 65.0;
	int iInjured;
	int iInjuredRagdoll;
	float fRagPos[3];
	float fMedicPos[3];
	float fDistance;
	
	// Search medics
	for (int iMedic = 1; iMedic <= MaxClients; iMedic++)
	{
		if (!IsClientInGame(iMedic) || IsFakeClient(iMedic))
			continue;
		
		// Is valid iMedic?
		if (IsPlayerAlive(iMedic) && (StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		//if (IsPlayerAlive(iMedic)) 
		{
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured))
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll))
				{
					// Get player's ragdoll position
					GetEntPropVector(iInjuredRagdoll, Prop_Send, "m_vecOrigin", fRagPos);
					
					// Update ragdoll position
					g_fRagdollPosition[iInjured] = fRagPos;
					
					// Get distance from iMedic
					fDistance = GetVectorDistance(fRagPos,fMedicPos);
				}
				else
					// Ragdoll is not valid
					continue;
				
				// Jareds pistols only code to verify iMedic is carrying knife
				int ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				char sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If iMedic can see ragdoll and using defib or knife
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance)) 
					&& ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1)))
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveRemainingTime[iInjured]);		
					char sBuf[255];
					
					// Need more time to revive
					if (g_iReviveRemainingTime[iInjured] > 0)
					{

						char woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "Minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "Moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "Critical wound";

						// Hint to iMedic
						Format(sBuf, 255,"Reviving %N in: %i seconds (%s)", iInjured, g_iReviveRemainingTime[iInjured], woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N is reviving you in: %i seconds (%s)", iMedic, g_iReviveRemainingTime[iInjured], woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Decrease revive remaining time
						g_iReviveRemainingTime[iInjured]--;
						
						//prevent respawn while reviving
						g_iRespawnTimeRemaining[iInjured]++;
					}
					// Revive player
					else if (g_iReviveRemainingTime[iInjured] <= 0)
					{	
						char woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						//Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						//PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						g_iStatRevives[iMedic]++;
			
						//Accumulate a revive
						g_playerMedicRevivessAccumulated[iMedic]++;
						int iReviveCap = sm_revive_cap_for_bonus.IntValue;

						// Hint to iMedic
						Format(sBuf, 255,"You revived %N ", iInjured, woundType, (iReviveCap - g_playerMedicRevivessAccumulated[iMedic]));
						PrintHintText(iMedic, "%s", sBuf);
						if (g_playerMedicRevivessAccumulated[iMedic] >= iReviveCap)
						{
							g_playerMedicRevivessAccumulated[iMedic] = 0;
							g_iSpawnTokens[iMedic]++;
						}

						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;
						
						// Reset revive counter
						playerRevived[iInjured] = true;
						
						// Call revive function
						g_playerNonMedicRevive[iInjured] = 0;
						CreateReviveTimer(iInjured);
						continue;
					}
				}
			}
		}
		//Non Medics with Medic Pack
		else if (IsPlayerAlive(iMedic) && !(StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		//else if (IsPlayerAlive(iMedic))
		{
			//PrintToServer("Non-Medic Reviving..");
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured))
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll))
				{
					// Get player's ragdoll position
					GetEntPropVector(iInjuredRagdoll, Prop_Send, "m_vecOrigin", fRagPos);
					
					// Update ragdoll position
					g_fRagdollPosition[iInjured] = fRagPos;
					
					// Get distance from iMedic
					fDistance = GetVectorDistance(fRagPos,fMedicPos);
				}
				else
					// Ragdoll is not valid
					continue;
				
				// Jareds pistols only code to verify iMedic is carrying knife
				int ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				char sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If NON Medic can see ragdoll and using healthkit
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance))
					&& ((StrContains(sWeapon, "weapon_healthkit") > -1)))
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveNonMedicRemainingTime[iInjured]);		
					char sBuf[255];
					
					// Need more time to reviving
					if (g_iReviveNonMedicRemainingTime[iInjured] > 0)
					{

						//PrintToServer("NONMEDIC HAS TIME");
						if (g_playerWoundType[iInjured] == 0 || g_playerWoundType[iInjured] == 1 || g_playerWoundType[iInjured] == 2)
						{
							char woundType[64];
							if (g_playerWoundType[iInjured] == 0)
								woundType = "Minor wound";
							else if (g_playerWoundType[iInjured] == 1)
								woundType = "Moderate wound";
							else if (g_playerWoundType[iInjured] == 2)
								woundType = "Critical wound";
							// Hint to NonMedic
							Format(sBuf, 255,"Reviving %N in: %i seconds (%s)", iInjured, g_iReviveNonMedicRemainingTime[iInjured], woundType);
							PrintHintText(iMedic, "%s", sBuf);
							
							// Hint to victim
							Format(sBuf, 255,"%N is reviving you in: %i seconds (%s)", iMedic, g_iReviveNonMedicRemainingTime[iInjured], woundType);
							PrintHintText(iInjured, "%s", sBuf);
							
							// Decrease revive remaining time
							g_iReviveNonMedicRemainingTime[iInjured]--;
						}

						//prevent respawn while reviving
						g_iRespawnTimeRemaining[iInjured]++;
					}

					// Revive player
					else if (g_iReviveNonMedicRemainingTime[iInjured] <= 0)
					{	
						char woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						//PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you from a %s", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Add kill bonus to iMedic
						//int iBonus = sm_revive_bonus.IntValue;
						//int iScore = GetClientFrags(iMedic) + iBonus;
						//SetEntProp(iMedic, Prop_Data, "m_iFrags", iScore);
						
						// Rank System
						g_iStatRevives[iMedic]++;
						
						//Accumulate a revive
						g_playerMedicRevivessAccumulated[iMedic]++;
						int iReviveCap = sm_revive_cap_for_bonus.IntValue;

						// Hint to iMedic
						if (g_playerMedicRevivessAccumulated[iMedic] >= iReviveCap)
						{
							g_playerMedicRevivessAccumulated[iMedic] = 0;
							g_iSpawnTokens[iMedic]++;
						}

						
						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;
						
						//Reward nearby medics who asssisted
						//Check_NearbyMedicsRevive(iMedic, iInjured);

						// Reset revive counter
						playerRevived[iInjured] = true;
						
						g_playerNonMedicRevive[iInjured] = 1;
						// Call revive function
						CreateReviveTimer(iInjured);
						RemovePlayerItem(iMedic,ActiveWeapon);
						//Switch to knife after removing kit
						ChangePlayerWeaponSlot(iMedic, 2);
						//PrintToServer("##########PLAYER REVIVED %s ############", playerRevived[iInjured]);
						continue;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

// Handles medic functions (Inspecting health, healing)
public Action Timer_MedicMonitor(Handle timer, any data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Search medics
	for(int medic = 1; medic <= MaxClients; medic++)
	{
		if (!IsClientInGame(medic) || IsFakeClient(medic)) continue;
		
		
		// Medic only can inspect health.
		int iTeam = GetClientTeam(medic);
		if (iTeam == TEAM_1_SEC && IsPlayerAlive(medic) && StrContains(g_client_last_classstring[medic], "medic") > -1)
		{
			// Target is teammate and alive.
			int iTarget = TraceClientViewEntity(medic);
			if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
			{
				// Check distance
				bool bCanHealPaddle = false;
				bool bCanHealMedpack = false;
				float fReviveDistance = 80.0;
				float vecMedicPos[3];
				float vecTargetPos[3];
				float tDistance;
				GetClientAbsOrigin(medic, vecMedicPos);
				GetClientAbsOrigin(iTarget, vecTargetPos);
				tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
				
				if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
				{
					// Check weapon
					int ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
					if (ActiveWeapon < 0)
						continue;
					char sWeapon[32];
					GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
					
					if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))
					{
						bCanHealPaddle = true;
					}
					if ((StrContains(sWeapon, "weapon_healthkit") > -1))
					{
						bCanHealMedpack = true;
					}
				}

				// Check heal
				int iHealth = GetClientHealth(iTarget);

				if (tDistance < 750.0)
				{
					PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
				}

				if (bCanHealPaddle)
				{
					if (iHealth < 100)
					{
						iHealth += g_iHeal_amount_paddles;
						g_playerMedicHealsAccumulated[medic] += g_iHeal_amount_paddles;
						int iHealthCap = sm_heal_cap_for_bonus.IntValue;
						int iRewardMedicEnabled = sm_reward_medics_enabled.IntValue;

						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							g_iSpawnTokens[medic]++;
						}
						
						if (iHealth >= 100)
						{
							g_iStatHeals[medic]++;
							iHealth = 100;
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
							char sBuf[255];
							Format(sBuf, 255,"You fully healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerMedicHealsAccumulated[medic]));
							PrintHintText(medic, "%s", sBuf);
						}
						else
						{
							PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
						}
						
						SetEntityHealth(iTarget, iHealth);
						PrintHintText(medic, "%N\nHP: %i\n\nHealing with paddles for: %i", iTarget, iHealth, g_iHeal_amount_paddles);
					}
					else
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
				}
				else if (bCanHealMedpack)
				{
					if (iHealth < 100)
					{
						iHealth += g_iHeal_amount_medPack;
						g_playerMedicHealsAccumulated[medic] += g_iHeal_amount_medPack;
						int iHealthCap = sm_heal_cap_for_bonus.IntValue;
						int iRewardMedicEnabled = sm_reward_medics_enabled.IntValue;
						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							g_iSpawnTokens[medic]++;
						}
						if (iHealth >= 100)
						{
							g_iStatHeals[medic]++;
							iHealth = 100;
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
							char sBuf[255];
							Format(sBuf, 255,"You fully healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerMedicHealsAccumulated[medic]));
							PrintHintText(medic, "%s", sBuf);
						}
						else
						{
							PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
						}
						SetEntityHealth(iTarget, iHealth);
						PrintHintText(medic, "%N\nHP: %i\n\nHealing with medpack for: %i", iTarget, iHealth, g_iHeal_amount_medPack);
					}
					else
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
				}
			}
			else //Heal Self
			{
				// Check distance
				bool bCanHealMedpack = false;
				bool bCanHealPaddle = false;
				
				// Check weapon
				int ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0) continue;
				char sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

				if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))
				{
					bCanHealPaddle = true;
				}
				if ((StrContains(sWeapon, "weapon_healthkit") > -1))
				{
					bCanHealMedpack = true;
				}
				
				// Check heal
				int iHealth = GetClientHealth(medic);
				if (bCanHealMedpack || bCanHealPaddle)
				{
					if (iHealth < g_medicHealSelf_max)
					{
						if (bCanHealMedpack)
							iHealth += g_iHeal_amount_medPack;
						else
							iHealth += g_iHeal_amount_paddles;

						if (iHealth >= g_medicHealSelf_max)
						{
							iHealth = g_medicHealSelf_max;
							PrintHintText(medic, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
						}
						else 
						{
							PrintHintText(medic, "Healing Self (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
						}
						SetEntityHealth(medic, iHealth);
					}
				}
			}
		}
		else if (iTeam == TEAM_1_SEC && IsPlayerAlive(medic) && !(StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Check weapon for non medics outside
			int ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
			if (ActiveWeapon < 0)
				continue;
			char checkWeapon[32];
			GetEdictClassname(ActiveWeapon, checkWeapon, sizeof(checkWeapon));
			if ((StrContains(checkWeapon, "weapon_healthkit") > -1))
			{
				// Target is teammate and alive.
				int iTarget = TraceClientViewEntity(medic);
				if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
				{
					// Check distance
					bool bCanHealMedpack = false;
					float fReviveDistance = 80.0;
					float vecMedicPos[3];
					float vecTargetPos[3];
					float tDistance;
					GetClientAbsOrigin(medic, vecMedicPos);
					GetClientAbsOrigin(iTarget, vecTargetPos);
					tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
					
					if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
					{
						// Check weapon
						if (ActiveWeapon < 0) continue;
						char sWeapon[32];
						GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
						if ((StrContains(sWeapon, "weapon_healthkit") > -1))
							bCanHealMedpack = true;
					}
					// Check heal
					int iHealth = GetClientHealth(iTarget);
					if (tDistance < 750.0) 
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					if (bCanHealMedpack)
					{
						if (iHealth < g_nonMedic_maxHealOther)
						{
							iHealth += g_nonMedicHeal_amount;
							g_playerNonMedicHealsAccumulated[medic] += g_nonMedicHeal_amount;
							int iHealthCap = sm_heal_cap_for_bonus.IntValue;
							int iRewardMedicEnabled = sm_reward_medics_enabled.IntValue;
							//Reward player for healing
							if (g_playerNonMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
							{
								g_playerNonMedicHealsAccumulated[medic] = 0;
								g_iSpawnTokens[medic]++;
							}

							if (iHealth >= g_nonMedic_maxHealOther)
							{
								g_iStatHeals[medic]++;
								iHealth = g_nonMedic_maxHealOther;
								PrintHintText(iTarget, "Non-Medic %N can only heal you for %i HP!)", medic, iHealth);
								char sBuf[255];
								Format(sBuf, 255,"You max healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerNonMedicHealsAccumulated[medic]));
								PrintHintText(medic, "%s", sBuf);
							}
							else
							{
								PrintHintText(iTarget, "DON'T MOVE! %N is healing you.(HP: %i)", medic, iHealth);
							}
							SetEntityHealth(iTarget, iHealth);
							PrintHintText(medic, "%N\nHP: %i\n\nHealing.", iTarget, iHealth);
						}
						else
						{
							if (iHealth < g_nonMedic_maxHealOther)
							{
								PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
							}
							else if (iHealth >= g_nonMedic_maxHealOther)
								PrintHintText(medic, "%N\nHP: %i (MAX YOU CAN HEAL)", iTarget, iHealth);
						}
					}
				}
				else //Heal Self
				{
					// Check distance
					bool bCanHealMedpack = false;
					
					// Check weapon
					if (ActiveWeapon < 0) continue;
					char sWeapon[32];
					GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
					if ((StrContains(sWeapon, "weapon_healthkit") > -1))
						bCanHealMedpack = true;

					// Check heal
					int iHealth = GetClientHealth(medic);
					if (bCanHealMedpack)
					{
						if (iHealth < g_nonMedicHealSelf_max)
						{
							iHealth += g_nonMedicHeal_amount;
							if (iHealth >= g_nonMedicHealSelf_max)
							{
								iHealth = g_nonMedicHealSelf_max;
								PrintHintText(medic, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
							}
							else
							{
								PrintHintText(medic, "Healing Self (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
							}
							
							SetEntityHealth(medic, iHealth);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue; 
}

//Main AI Director Tick
public Action Timer_AIDirector_Main(Handle timer, any data)
{
	g_AIDir_AnnounceCounter++;
	g_AIDir_ChangeCond_Counter++;
	g_AIDir_AmbushCond_Counter++;
	
	//Ambush Reinforcement Chance
	int tAmbushChance = GetRandomInt(0, 100);

	//AI Director Set Difficulty
	if (g_AIDir_ChangeCond_Counter >= g_AIDir_ChangeCond_Rand)
	{
		g_AIDir_ChangeCond_Counter = 0;
		g_AIDir_ChangeCond_Rand = GetRandomInt(g_AIDir_ChangeCond_Min, g_AIDir_ChangeCond_Max);
		//PrintToServer("[AI_DIRECTOR] STATUS: %i | SetDifficulty CALLED", g_AIDir_TeamStatus);
		AI_Director_SetDifficulty();
	}

	if (g_AIDir_AmbushCond_Counter >= g_AIDir_AmbushCond_Rand)
	{
		if (tAmbushChance <= g_AIDir_AmbushCond_Chance)
		{
			g_AIDir_AmbushCond_Counter = 0;
			g_AIDir_AmbushCond_Rand = GetRandomInt(g_AIDir_AmbushCond_Min, g_AIDir_AmbushCond_Max);
			AI_Director_RandomEnemyReinforce();
		}
		else
		{
			//PrintToServer("[AI_DIRECTOR]: tAmbushChance: %d | g_AIDir_AmbushCond_Chance %d", tAmbushChance, g_AIDir_AmbushCond_Chance);
			//Reset
			g_AIDir_AmbushCond_Counter = 0;
			g_AIDir_AmbushCond_Rand = GetRandomInt(g_AIDir_AmbushCond_Min, g_AIDir_AmbushCond_Max);
		}
	}

	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	//Confirm percent finale
	if ((acp+1) == ncp)
	{
		if (g_finale_counter_spec_enabled == 1)
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;
	}
	return Plugin_Continue;
}


/*public Action Timer_AmmoResupply(Handle timer, any data) {
	if (g_iRoundStatus == 0) {
		return Plugin_Continue;
	}
	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client)) {
			continue;
		}
		int team = GetClientTeam(client);
		// Valid medic?
		if (IsPlayerAlive(client) && team == TEAM_1_SEC) {
			int ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if (ActiveWeapon < 0) {
				continue;
			}

			// Get weapon class name
			char sWeapon[32];
			GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
			//if (GetClientButtons(client) & //INS_RELOAD  && ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1)))
			if (((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))) 
			{
				int validAmmoCache = -1;
				validAmmoCache = FindValidProp_InDistance(client);
				//PrintToServer("validAmmoCache: %d", validAmmoCache);
				if (validAmmoCache != -1) {
					g_resupplyCounter[client] -= 1;
					if (g_ammoResupplyAmt[validAmmoCache] <= 0) {
						int secTeamCount = GetTeamSecCount();
						g_ammoResupplyAmt[validAmmoCache] = (secTeamCount / 6);
						if (g_ammoResupplyAmt[validAmmoCache] <= 1) {
							g_ammoResupplyAmt[validAmmoCache] = 1;
						}

					}
					char sBuf[255];
					// Hint to client
					Format(sBuf, 255,"Resupplying ammo in %d seconds | Supply left: %d", g_resupplyCounter[client], g_ammoResupplyAmt[validAmmoCache]);
					PrintHintText(client, "%s", sBuf);
					if (g_resupplyCounter[client] <= 0) {
						g_resupplyCounter[client] = sm_resupply_delay.IntValue;
						//Spawn player again
						AmmoResupply_Player(client, 0, 0, 0);


						g_ammoResupplyAmt[validAmmoCache] -= 1;
						if (g_ammoResupplyAmt[validAmmoCache] <= 0) {
							if (validAmmoCache != -1) {
								AcceptEntityInput(validAmmoCache, "kill");
							}
						}
						Format(sBuf, 255,"Rearmed! Ammo Supply left: %d", g_ammoResupplyAmt[validAmmoCache]);

						PrintHintText(client, "%s", sBuf);
						PrintToChat(client, "%s", sBuf);

					}
				}
			}
		}
	}
	return Plugin_Continue;
}*/

/*public int AmmoResupply_Player(int client, int primaryRemove, int secondaryRemove, int grenadesRemove) {

	float plyrOrigin[3];
	float tempOrigin[3];
	GetClientAbsOrigin(client, plyrOrigin);
	tempOrigin = plyrOrigin;
	tempOrigin[2] = -5000.0;

	//TeleportEntity(client, tempOrigin, NULL_VECTOR, NULL_VECTOR);
	//ForcePlayerSuicide(client);
	// Get dead body
	int clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

	//This timer safely removes client-side ragdoll
	if (clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll)) {
		// Get dead body's entity
		int ref = EntIndexToEntRef(clientRagdoll);
		int entity = EntRefToEntIndex(ref);
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity)) {
			// Remove dead body's entity
			AcceptEntityInput(entity, "Kill");
			clientRagdoll = INVALID_ENT_REFERENCE;
		}
	}

	ForceRespawnPlayer(client, client);
	TeleportEntity(client, plyrOrigin, NULL_VECTOR, NULL_VECTOR);
	RemoveWeapons(client, primaryRemove, secondaryRemove, grenadesRemove);
	PrintHintText(client, "Ammo Resupplied");
	playerInRevivedState[client] = false;
	// //Give back life
	// new iDeaths = GetClientDeaths(client) - 1;
	// SetEntProp(client, Prop_Data, "m_iDeaths", iDeaths);
}*/

//Find Valid Prop
public void RemoveWeapons(int client, int primaryRemove, int secondaryRemove, int grenadesRemove)
{

	int primaryWeapon = GetPlayerWeaponSlot(client, 0);
	int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
	int playerGrenades = GetPlayerWeaponSlot(client, 3);

	// Check and remove primaryWeapon
	// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	if (primaryWeapon != -1 && IsValidEntity(primaryWeapon) && primaryRemove == 1)  
	{
		// Remove primaryWeapon
		char weapon[32];
		GetEntityClassname(primaryWeapon, weapon, sizeof(weapon));
		RemovePlayerItem(client, primaryWeapon);
		AcceptEntityInput(primaryWeapon, "kill");
	}
	// Check and remove secondaryWeapon
	// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon) && secondaryRemove == 1)  
	{
		// Remove primaryWeapon
		char weapon[32];
		GetEntityClassname(secondaryWeapon, weapon, sizeof(weapon));
		RemovePlayerItem(client, secondaryWeapon);
		AcceptEntityInput(secondaryWeapon, "kill");
	}
	// Check and remove grenades
	// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	if (playerGrenades != -1 && IsValidEntity(playerGrenades) && grenadesRemove == 1)  
	{
		// since we only have 3 slots in current theate
		while (playerGrenades != -1 && IsValidEntity(playerGrenades))  
		{
			playerGrenades = GetPlayerWeaponSlot(client, 3);
			// We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
			if (playerGrenades != -1 && IsValidEntity(playerGrenades))  
			{
				// Remove grenades
				char weapon[32];
				GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
				RemovePlayerItem(client, playerGrenades);
				AcceptEntityInput(playerGrenades, "kill");

			}
		}
	}
}



stock bool AI_Director_IsSpecialtyBot(int client)
{
		return false;
}

stock float GetEntitiesDistance(int ent1, int ent2) 
{
	float orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);

	float orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);

	return GetVectorDistance(orig1, orig2);
}

public Action Timer_AmbientRadio(Handle timer, any data)
{
	if (g_iRoundStatus == 0) return Plugin_Continue;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client)) continue;
		int team = GetClientTeam(client); 
		
		// Valid medic?
		if (IsPlayerAlive(client) && ((StrContains(g_client_last_classstring[client], "squadleader") > -1) || (StrContains(g_client_last_classstring[client], "teamleader") > -1)) && team == TEAM_1_SEC)
		{
			int fRandomChance = GetRandomInt(1, 100);
			if (fRandomChance < 50)
			{	
				Handle hDatapack;
				float fRandomFloat = GetRandomFloat(1.0, 30.0);
				//CreateTimer(fRandomFloat, Timer_PlayAmbient);
				CreateDataTimer(fRandomFloat, Timer_PlayAmbient, hDatapack);
				WritePackCell(hDatapack, client);
			}
		}
	}
	return Plugin_Continue;

}
public Action Timer_PlayAmbient(Handle timer, DataPack hDatapack) 
{

	hDatapack.Reset();
	int client = hDatapack.ReadCell();

	//PrintToServer("PlaySound");
	switch(GetRandomInt(1, 10)) 
	{
		case 1: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_01.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 2: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_02.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 3: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_03.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 4: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_04.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 5: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_01.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 6: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_02.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 7: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_03.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 8: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_04.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 9: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_05.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 10: EmitSoundToAll("soundscape/emitters/oneshot/mil_radio_oneshot_06.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
	return Plugin_Continue;
}



// Check for nearest player
Action Timer_NearestBody(Handle timer, any data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Variables to store
	float fMedicPosition[3];
	float fMedicAngles[3];
	float fInjuredPosition[3];
	float fNearestDistance;
	float fTempDistance;

	// iNearest Injured client
	char iNearestInjured;
	char sDirection[64];
	char sDistance[64];
	char sHeight[6];

	// Client loop
	for (int medic = 1; medic <= MaxClients; medic++)
	{
		if (!IsClientInGame(medic) || IsFakeClient(medic))
			continue;
		
		// Valid medic?
		if (IsPlayerAlive(medic) && (StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Reset variables
			iNearestInjured = 0;
			fNearestDistance = 0.0;
			
			// Get medic position
			GetClientAbsOrigin(medic, fMedicPosition);

			//PrintToServer("MEDIC DETECTED ********************");
			// Search dead body
			for (int search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search)) continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					int clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
					if (clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && clientRagdoll != INVALID_ENT_REFERENCE)
					{
						// Get ragdoll's position
						fInjuredPosition = g_fRagdollPosition[search];
						
						// Get distance from ragdoll
						fTempDistance = GetVectorDistance(fMedicPosition, fInjuredPosition);

						// Is he more fNearestDistance to the player as the player before?
						if (fNearestDistance == 0.0)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
						// Set new distance and new iNearestInjured player
						else if (fTempDistance < fNearestDistance)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
					}
				}
			}
			
			// Found a dead body?
			if (iNearestInjured != 0)
			{
				// Set iNearestInjured body
				g_iNearestBody[medic] = iNearestInjured;
				
				// Get medic angle
				GetClientAbsAngles(medic, fMedicAngles);
				
				// Get direction string (if it cause server lag, remove this)
				sDirection = GetDirectionString(fMedicAngles, fMedicPosition, fInjuredPosition);
				
				// Get distance string
				sDistance = GetDistanceString(fNearestDistance);

				// Get height string
				sHeight = GetHeightString(fMedicPosition, fInjuredPosition);
				
				// Print iNearestInjured dead body's distance and direction text
				//PrintCenterText(medic, "Nearest dead: %N (%s)", iNearestInjured, sDistance);
				PrintCenterText(medic, "Nearest dead: %N ( %s | %s | %s )", iNearestInjured, sDistance, sDirection, sHeight);
				float beamPos[3];
				beamPos = fInjuredPosition;
				beamPos[2] += 0.3;
				if (fTempDistance >= 140)
				{
					//Attack markers option
					//Effect_SetMarkerAtPos(medic,beamPos,1.0,{255, 0, 0, 255}); 

					//Beam dead when farther
					TE_SetupBeamRingPoint(beamPos, 1.0, Revive_Indicator_Radius, g_iBeaconBeam, g_iBeaconHalo, 0, 15, 5.0, 3.0, 5.0, {255, 0, 0, 255}, 1, (FBEAM_FADEIN, FBEAM_FADEOUT));
					//void TE_SetupBeamRingPoint(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
					TE_SendToClient(medic);
				}
			}
			else
			{
				// Reset iNearestInjured body
				g_iNearestBody[medic] = -1;
			}
		}
		else if (IsPlayerAlive(medic) && !(StrContains(g_client_last_classstring[medic], "medic") > -1))
		{
			// Reset variables
			iNearestInjured = 0;
			fNearestDistance = 0.0;
			
			// Get medic position
			GetClientAbsOrigin(medic, fMedicPosition);

			//PrintToServer("MEDIC DETECTED ********************");
			// Search dead body
			for (int search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search))
					continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					int clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
					if (clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && clientRagdoll != INVALID_ENT_REFERENCE)
					{
						// Get ragdoll's position
						fInjuredPosition = g_fRagdollPosition[search];
						
						// Get distance from ragdoll
						fTempDistance = GetVectorDistance(fMedicPosition, fInjuredPosition);

						// Is he more fNearestDistance to the player as the player before?
						if (fNearestDistance == 0.0)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
						// Set new distance and new iNearestInjured player
						else if (fTempDistance < fNearestDistance)
						{
							fNearestDistance = fTempDistance;
							iNearestInjured = search;
						}
					}
				}
			}
			
			// Found a dead body?
			if (iNearestInjured != 0)
			{
				// Set iNearestInjured body
				g_iNearestBody[medic] = iNearestInjured;
				
			}
			else
			{
				// Reset iNearestInjured body
				g_iNearestBody[medic] = -1;
			}
		}
	}
	
	return Plugin_Continue;
}

public bool Check_NearbyPlayers(int enemyBot)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		{
			if (IsPlayerAlive(client))
			{
				float botOrigin[3];
				float clientOrigin[3];
				float fDistance;
				
				GetClientAbsOrigin(enemyBot,botOrigin);
				GetClientAbsOrigin(client,clientOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(botOrigin,clientOrigin);
				
				if (fDistance <= 600) return true;
			}
		}
	}
	return false;
}

/**
 * Get direction string for nearest dead body
 *
 * @param fClientAngles[3]		Client angle
 * @param fClientPosition[3]	Client position
 * @param fTargetPosition[3]	Target position
 * @Return						direction string.
 */
char[] GetDirectionString(float fClientAngles[3], float fClientPosition[3], float fTargetPosition[3])
{
	float fTempAngles[3], fTempPoints[3];
	char sDirection[64];

	// Angles from origin
	MakeVectorFromPoints(fClientPosition, fTargetPosition, fTempPoints);
	GetVectorAngles(fTempPoints, fTempAngles);
	
	// Difference
	float fDiff = fClientAngles[1] - fTempAngles[1];
	
	// Correct it
	if (fDiff < -180)
		fDiff = 360 + fDiff;

	if (fDiff > 180)
		fDiff = 360 - fDiff;
	
	// Now get the direction
	// Up
	if (fDiff >= -22.5 && fDiff < 22.5)
		Format(sDirection, sizeof(sDirection), "FWD");//"\xe2\x86\x91");
	// right up
	else if (fDiff >= 22.5 && fDiff < 67.5)
		Format(sDirection, sizeof(sDirection), "FWD-RIGHT");//"\xe2\x86\x97");
	// right
	else if (fDiff >= 67.5 && fDiff < 112.5)
		Format(sDirection, sizeof(sDirection), "RIGHT");//"\xe2\x86\x92");
	// right down
	else if (fDiff >= 112.5 && fDiff < 157.5)
		Format(sDirection, sizeof(sDirection), "BACK-RIGHT");//"\xe2\x86\x98");
	// down
	else if (fDiff >= 157.5 || fDiff < -157.5)
		Format(sDirection, sizeof(sDirection), "BACK");//"\xe2\x86\x93");
	// down left
	else if (fDiff >= -157.5 && fDiff < -112.5)
		Format(sDirection, sizeof(sDirection), "BACK-LEFT");//"\xe2\x86\x99");
	// left
	else if (fDiff >= -112.5 && fDiff < -67.5)
		Format(sDirection, sizeof(sDirection), "LEFT");//"\xe2\x86\x90");
	// left up
	else if (fDiff >= -67.5 && fDiff < -22.5)
		Format(sDirection, sizeof(sDirection), "FWD-LEFT");//"\xe2\x86\x96");
	
	return sDirection;
}

// Return distance string
char GetDistanceString(float fDistance)
{
	// Distance to meters
	float fTempDistance = fDistance * 0.01905;
	char sResult[64];

	// Distance to feet?
	if (g_iUnitMetric == 1)
	{
		fTempDistance = fTempDistance * 3.2808399;

		// Feet
		Format(sResult, sizeof(sResult), "%.0f feet", fTempDistance);
	}
	else
	{
		// Meter
		Format(sResult, sizeof(sResult), "%.0f meter", fTempDistance);
	}
	
	return sResult;
}

/**
 * Get height string for nearest dead body
 *
 * @param fClientPosition[3]    Client position
 * @param fTargetPosition[3]    Target position
 * @Return                      height string.
 */
char[] GetHeightString(float fClientPosition[3], float fTargetPosition[3]) 
{
	char s[6];

	if (fClientPosition[2]+64 < fTargetPosition[2]) 
	{
		s = "ABOVE";
	}
	else if (fClientPosition[2]-64 > fTargetPosition[2]) 
	{
		s = "BELOW";
	}
	else 
	{
		s = "LEVEL";
	}

	return s;
}

// Check tags
stock void TagsCheck(const char[] tag, bool remove = false) 
{
	ConVar hTags = FindConVar("sv_tags");
	char tags[255];
	hTags.GetString(tags, sizeof(tags));

	if (StrContains(tags, tag, false) == -1 && !remove) 
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		ReplaceString(newTags, sizeof(newTags), ",,", ",", false);
		hTags.SetString(newTags);
		hTags.GetString(tags, sizeof(tags));
	}
	else if (StrContains(tags, tag, false) > -1 && remove) 
	{
		ReplaceString(tags, sizeof(tags), tag, "", false);
		ReplaceString(tags, sizeof(tags), ",,", ",", false);
		hTags.SetString(tags);
	}
}

// Get team2 player count
stock int GetTeamSecCount() {
	int clients = 0;
	int iTeam;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsClientConnected(i)) {
			iTeam = GetClientTeam(i);
			if (iTeam == TEAM_1_SEC) {
				clients++;
			}
		}
	}
	return clients;
}

// Get real client count
stock int GetRealClientCount(bool inGameOnly = true)
{
	int clients = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (((inGameOnly)?IsClientInGame(i):IsClientConnected(i)) && !IsFakeClient(i)) 
			clients++;
	}
	return clients;
}

//Get insurgent team bot count
stock int GetTeamInsCount()
{
	int clients;
	for(int i = 1; i <= MaxClients; i++ )
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			clients++;
		}
	}
	return clients;
}

/*
LUA Version
stock GetRemainingLife()
{
	Handle hCvar = null;
	int iRemainingLife;
	hCvar = FindConVar("sm_remaininglife");
	iRemainingLife = GetConVarInt(hCvar);
	return iRemainingLife;
}*/

// Get remaining life
stock int GetRemainingLife()
{
	int iResult;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i > 0 && IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (g_iSpawnTokens[i] > 0)
			{
				iResult = iResult + g_iSpawnTokens[i];
			}
		}
	}
	return iResult;
}

// Trace client's view entity
int TraceClientViewEntity(int client) 
{
	float m_vecOrigin[3];
	float m_angRotation[3];
	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);
	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
	int pEntity = -1;

	if (TR_DidHit(tr)) 
	{
		pEntity = TR_GetEntityIndex(tr);
		delete tr;
		return pEntity;
	}
	delete tr;
	return -1;
}

// Check is hit self
public bool TRDontHitSelf(int entity, int mask, any data) // Don't ray trace ourselves -_-"
{
	return (1 <= entity <= MaxClients) && (entity != data);
}

//############# AI DIRECTOR In-Script Functions START #######################


void AI_Director_ResetReinforceTimers() 
{
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = (g_AIDir_ReinforceTimer_Orig);
		g_iReinforceTimeSubsequent_AD_Temp = (g_AIDir_ReinforceTimer_SubOrig);
}

void AI_Director_SetDifficulty()
{
	AI_Director_ResetReinforceTimers();

		//AI Director Local Scaling Vars
	//AID_ReinfAdj_low = 10, AID_ReinfAdj_med = 20, AID_ReinfAdj_high = 30, AID_ReinfAdj_pScale = 0,
	int AID_ReinfAdj_med = 20;
	int AID_ReinfAdj_high = 30;
	int AID_ReinfAdj_pScale = 0;
	float AID_SpecDelayAdj_low = 10.0;
	float AID_SpecDelayAdj_med = 20.0;
	float AID_SpecDelayAdj_high = 30.0;
	float AID_SpecDelayAdj_pScale_Pro = 0.0;
	float AID_SpecDelayAdj_pScale_Con = 0.0;
	int AID_AmbChance_vlow = 10;
	int AID_AmbChance_low = 15;
	int AID_AmbChance_med = 20;
	int AID_AmbChance_high = 25;
	int AID_AmbChance_pScale = 0;
	int AID_SetDiffChance_pScale = 0;

	//Scale based on team count
	int tTeamSecCount = GetTeamSecCount();
	if (tTeamSecCount <= 6) {
		AID_ReinfAdj_pScale = 8;
		AID_SpecDelayAdj_pScale_Pro = 30.0;
		AID_SpecDelayAdj_pScale_Con = 10.0;
	}
	else if (tTeamSecCount >= 7 && tTeamSecCount <= 12) {
		AID_ReinfAdj_pScale = 4;
		AID_SpecDelayAdj_pScale_Pro = 20.0;
		AID_SpecDelayAdj_pScale_Con = 20.0;
		AID_AmbChance_pScale = 5;
		AID_SetDiffChance_pScale = 5;
	}
	else if (tTeamSecCount >= 13) {
		AID_ReinfAdj_pScale = 8;
		AID_SpecDelayAdj_pScale_Pro = 10.0;
		AID_SpecDelayAdj_pScale_Con = 30.0;
		AID_AmbChance_pScale = 10;
		AID_SetDiffChance_pScale = 10;
	}

	// Get the number of control points
	int ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	// Get active push point
	int acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	int tAmbScaleMult = 2;
	if (ncp <= 5)
	{
		tAmbScaleMult = 3;
		AID_SetDiffChance_pScale += 5;
	}
	//Add More to Ambush chance based on what point we are at. 
	AID_AmbChance_pScale += (acp * tAmbScaleMult);
	AID_SetDiffChance_pScale += (acp * tAmbScaleMult);

	float cvarSpecDelay = sm_respawn_delay_team_ins_special.FloatValue;
	int fRandomInt = GetRandomInt(0, 100);


	//Set Difficulty Based On g_AIDir_TeamStatus and adjust per player scale g_SernixMaxPlayerCount
	if (fRandomInt <= (g_AIDir_DiffChanceBase + AID_SetDiffChance_pScale))
	{
		AI_Director_ResetReinforceTimers();
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = ((g_AIDir_ReinforceTimer_Orig - AID_ReinfAdj_high) - AID_ReinfAdj_pScale);
		g_iReinforceTimeSubsequent_AD_Temp = ((g_AIDir_ReinforceTimer_SubOrig - AID_ReinfAdj_high) - AID_ReinfAdj_pScale);

		//Mod specialized bot spawn interval
		g_fCvar_respawn_delay_team_ins_spec = ((cvarSpecDelay - AID_SpecDelayAdj_high) - AID_SpecDelayAdj_pScale_Con);
		if (g_fCvar_respawn_delay_team_ins_spec <= 0)
			g_fCvar_respawn_delay_team_ins_spec = 1.0;

		//DEBUG: Track Current Difficulty setting
		//g_AIDir_CurrDiff = 5;

		//Set Ambush Chance
		g_AIDir_AmbushCond_Chance = AID_AmbChance_high + AID_AmbChance_pScale;
	}
	// < 25% DOING BAD >> MAKE EASIER //Scale variables should be lower with higher player counts
	else if (g_AIDir_TeamStatus < (g_AIDir_TeamStatus_max / 4))
	{
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = ((g_AIDir_ReinforceTimer_Orig + AID_ReinfAdj_high) + AID_ReinfAdj_pScale);
		g_iReinforceTimeSubsequent_AD_Temp = ((g_AIDir_ReinforceTimer_SubOrig + AID_ReinfAdj_high) + AID_ReinfAdj_pScale);

		//Mod specialized bot spawn interval
		g_fCvar_respawn_delay_team_ins_spec = ((cvarSpecDelay + AID_SpecDelayAdj_high) + AID_SpecDelayAdj_pScale_Pro);

		//DEBUG: Track Current Difficulty setting
		//g_AIDir_CurrDiff = 1;

		//Set Ambush Chance
		g_AIDir_AmbushCond_Chance = AID_AmbChance_vlow + AID_AmbChance_pScale;
	}
	// >= 25% and < 50% NORMAL >> No Adjustments
	else if (g_AIDir_TeamStatus >= (g_AIDir_TeamStatus_max / 4) && g_AIDir_TeamStatus < (g_AIDir_TeamStatus_max / 2))
	{
		AI_Director_ResetReinforceTimers();

		// >= 25% and < 33% Ease slightly if <= half the team alive which is 9 right now.
		if (g_AIDir_TeamStatus >= (g_AIDir_TeamStatus_max / 4) && g_AIDir_TeamStatus < (g_AIDir_TeamStatus_max / 3) && GetTeamSecCount() <= 9)
		{
			//Set Reinforce Time
			g_iReinforceTime_AD_Temp = ((g_AIDir_ReinforceTimer_Orig + AID_ReinfAdj_med) + AID_ReinfAdj_pScale);
			g_iReinforceTimeSubsequent_AD_Temp = ((g_AIDir_ReinforceTimer_SubOrig + AID_ReinfAdj_med) + AID_ReinfAdj_pScale);

			//Mod specialized bot spawn interval
			g_fCvar_respawn_delay_team_ins_spec = ((cvarSpecDelay + AID_SpecDelayAdj_low) + AID_SpecDelayAdj_pScale_Pro);

			//DEBUG: Track Current Difficulty setting
			//g_AIDir_CurrDiff = 2;

			//Set Ambush Chance
			g_AIDir_AmbushCond_Chance = AID_AmbChance_low + AID_AmbChance_pScale;
		}
		else
		{
			//Set Reinforce Time
			g_iReinforceTime_AD_Temp = (g_AIDir_ReinforceTimer_Orig);
			g_iReinforceTimeSubsequent_AD_Temp = (g_AIDir_ReinforceTimer_SubOrig);

			//Mod specialized bot spawn interval
			g_fCvar_respawn_delay_team_ins_spec = cvarSpecDelay;

			//DEBUG: Track Current Difficulty setting
			//g_AIDir_CurrDiff = 2;

			//Set Ambush Chance
			g_AIDir_AmbushCond_Chance = AID_AmbChance_low + AID_AmbChance_pScale;

		}
	}
	// >= 50% and < 75% DOING GOOD
	else if (g_AIDir_TeamStatus >= (g_AIDir_TeamStatus_max / 2) && g_AIDir_TeamStatus < ((g_AIDir_TeamStatus_max / 4) * 3))
	{
		AI_Director_ResetReinforceTimers();
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = ((g_AIDir_ReinforceTimer_Orig - AID_ReinfAdj_med) - AID_ReinfAdj_pScale);
		g_iReinforceTimeSubsequent_AD_Temp = ((g_AIDir_ReinforceTimer_SubOrig - AID_ReinfAdj_med) - AID_ReinfAdj_pScale);

		//Mod specialized bot spawn interval
		g_fCvar_respawn_delay_team_ins_spec = ((cvarSpecDelay - AID_SpecDelayAdj_med) - AID_SpecDelayAdj_pScale_Con);
		if (g_fCvar_respawn_delay_team_ins_spec <= 0)
			g_fCvar_respawn_delay_team_ins_spec = 1.0;

		//DEBUG: Track Current Difficulty setting
		//g_AIDir_CurrDiff = 3;

		//Set Ambush Chance
		g_AIDir_AmbushCond_Chance = AID_AmbChance_med + AID_AmbChance_pScale;
	}
	// >= 75%  CAKE WALK
	else if (g_AIDir_TeamStatus >= ((g_AIDir_TeamStatus_max / 4) * 3))
	{
		AI_Director_ResetReinforceTimers();
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = ((g_AIDir_ReinforceTimer_Orig - AID_ReinfAdj_high) - AID_ReinfAdj_pScale);
		g_iReinforceTimeSubsequent_AD_Temp = ((g_AIDir_ReinforceTimer_SubOrig - AID_ReinfAdj_high) - AID_ReinfAdj_pScale);

		//Mod specialized bot spawn interval
		g_fCvar_respawn_delay_team_ins_spec = ((cvarSpecDelay - AID_SpecDelayAdj_high) - AID_SpecDelayAdj_pScale_Con);
		if (g_fCvar_respawn_delay_team_ins_spec <= 0)
			g_fCvar_respawn_delay_team_ins_spec = 1.0;

		//DEBUG: Track Current Difficulty setting
		//g_AIDir_CurrDiff = 4;

		//Set Ambush Chance
		g_AIDir_AmbushCond_Chance = AID_AmbChance_high + AID_AmbChance_pScale;
	}
	//return g_AIDir_TeamStatus; 
}
//############# AI DIRECTOR In-Script END #######################