/**
 *	[INS] Player Respawn Script - Player and BOT respawn script for sourcemod plugin.
 *	Edited: Carbonautics (6-June-20)
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
//#pragma dynamic 32768	// Increase heap size
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <insurgencydy>
#include <insurgency_ad>
#include <smlib>
#undef REQUIRE_EXTENSIONS
#include <cstrike>
#include <tf2>
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

//#include <navmesh>
//#include <insurgency>

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
//LUA Healing define values
#define Healthkit_Timer_Tickrate			0.5		// Basic Sound has 0.8 loop
#define Healthkit_Timer_Timeout				360.0 //6 minutes
#define Healthkit_Radius					120.0
#define Revive_Indicator_Radius				100.0
#define Healthkit_Remove_Type				"1"
#define Healthkit_Healing_Per_Tick_Min		1
#define Healthkit_Healing_Per_Tick_Max		3

//Lua Healing Variables
new g_iBeaconBeam;
new g_iBeaconHalo;
new Float:g_fLastHeight[2048] = {0.0, ...};
new Float:g_fTimeCheck[2048] = {0.0, ...};
new g_iTimeCheckHeight[2048] = {0, ...};
new g_healthPack_Amount[2048] = {0, ...};

//Perks Variables
new g_nSunglasses_ID = 1;

new g_iPlayerEquipGear;

//Radio Self ID
new nRadio_ID = 5;

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

// Counter-Attack Music
#define COUNTER_ATTACK_MUSIC_DURATION 68.0

// Handle for revive
new Handle:g_hForceRespawn;
new Handle:g_hGameConfig;
new g_cqcMapsArray[][] = {"chateau_tunnels_v2","congress_coop","cargo_redux9","game_day_coopv1_3",
				"launch_control_coopv1_5","bunker_busting_coop_ws","gizab_b1_coop",
				"inferno_checkpoint_b2","nightfall_coopv1_1","caves_coop"};

// AI Director Variables
new
	g_AIDir_TeamStatus = 50,
	g_AIDir_TeamStatus_min = 0,
	g_AIDir_TeamStatus_max = 100,
	g_AIDir_BotsKilledReq_mult = 4, 
	g_AIDir_BotsKilledCount = 0,
	g_AIDir_AnnounceCounter = 0,
	g_AIDir_AnnounceTrig = 5,
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
	g_AIDir_CurrDiff = 0,
	g_AIDir_DiffChanceBase = 0,
	bool:g_AIDir_BotReinforceTriggered = false;

// Player respawn
new
	g_iEnableRevive = 0,
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
	g_ammoResupplyAmt[MAX_ENTITIES+1],
	g_trackKillDeaths[MAXPLAYERS+1],
	Float:g_badSpawnPos_Track[MAXPLAYERS+1][3],
	g_iRespawnCount[4],
	g_huntReinforceCacheAdd = 120,
	bool:g_huntCacheDestroyed = false,
	bool:g_playersReady = false,
	bool:g_easterEggRound = false,
	bool:g_easterEggFlag = false,
	g_removeBotGrenadeChance = 50,
	Float:g_fPlayerPosition[MAXPLAYERS+1][3],
	Float:g_fDeadPosition[MAXPLAYERS+1][3],
	Float:g_fRagdollPosition[MAXPLAYERS+1][3],
	Float:g_vecOrigin[MAXPLAYERS+1][3],
	g_iPlayerBGroups[MAXPLAYERS+1],
	g_spawnFrandom[MAXPLAYERS+1],
	g_squadSpawnEnabled[MAXPLAYERS+1] = 0,
	g_squadLeader[MAXPLAYERS+1],
	g_enemySpawnTimer[MAXPLAYERS+1],
	g_LastButtons[MAXPLAYERS+1],
	g_extendMapVote[MAXPLAYERS+1] = 0,
	Float:g_fRespawnPosition[3];

//Ammo Amounts
new
	playerClip[MAXPLAYERS + 1][2], // Track primary and secondary ammo
	playerAmmo[MAXPLAYERS + 1][4], // track player ammo based on weapon slot 0 - 4
	playerPrimary[MAXPLAYERS + 1],
	playerSecondary[MAXPLAYERS + 1];
//	playerGrenadeType[MAXPLAYERS + 1][10], //track player grenade types
//	playerRole[MAXPLAYERS + 1]; // tracks player role so if it changes while wounded, he dies

// These steam ids remove from having a donor tag on request
	//[1] = 1 STRING, [64] = 40 character limit per string

new Handle:g_donorTagRemove_Array;
new Handle:g_playerArrayList;

//Bot Spawning 
new Handle:g_badSpawnPos_Array;

// Navmesh Init
new
	Handle:g_hHidingSpots = INVALID_HANDLE,
	g_iHidingSpotCount,
	m_iNumControlPoints,
	g_iCPHidingSpots[MAX_OBJECTIVES][MAX_HIDING_SPOTS],
	g_iCPHidingSpotCount[MAX_OBJECTIVES],
	g_iCPLastHidingSpot[MAX_OBJECTIVES],
	Float:m_vCPPositions[MAX_OBJECTIVES][3];

// Status
new
	g_SernixMaxPlayerCount= 18, //This is our current theaters team count.
	g_isMapInit,
	g_iRoundStatus = 0, //0 is over, 1 is active
	bool:g_bIsCounterAttackTimerActive = false,
	g_clientDamageDone[MAXPLAYERS+1],
	playerPickSquad[MAXPLAYERS + 1],
	bool:playerRevived[MAXPLAYERS + 1],
	bool:playerInRevivedState[MAXPLAYERS + 1],
	bool:g_preRoundInitial = false,
	String:g_client_last_classstring[MAXPLAYERS+1][64],
	String:g_client_org_nickname[MAXPLAYERS+1][64],
	Float:g_enemyTimerPos[MAXPLAYERS+1][3],	// Kill Stray Enemy Bots Globals
	Float:g_enemyTimerAwayPos[MAXPLAYERS+1][3],	// Kill Stray Enemy Bots Globals
	g_playerActiveWeapon[MAXPLAYERS + 1],
	g_plyrGrenScreamCoolDown[MAXPLAYERS+1],
	g_plyrFireScreamCoolDown[MAXPLAYERS+1],
	g_playerMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerMedicRevivessAccumulated[MAXPLAYERS+1],
	g_playerNonMedicHealsAccumulated[MAXPLAYERS+1],
	g_playerNonMedicRevive[MAXPLAYERS+1],
	g_playerWoundType[MAXPLAYERS+1],
	g_playerWoundTime[MAXPLAYERS+1],
	g_hintCoolDown[MAXPLAYERS+1] = 30,
	bool:g_hintsEnabled[MAXPLAYERS+1] = true,
	Float:g_fPlayerLastChat[MAXPLAYERS+1] = {0.0, ...},

	//Wave Based Arrays 
	g_WaveSpawnActive[MAXPLAYERS+1],

	g_playerFirstJoin[MAXPLAYERS+1];

// Player Distance Plugin //Credits to author = "Popoklopsi", url = "http://popoklopsi.de"
// unit to use 1 = feet, 0 = meters
new g_iUnitMetric;

// Handle for config
new
	Handle:sm_respawn_enabled = INVALID_HANDLE,
	Handle:sm_revive_enabled = INVALID_HANDLE,
	
	//AI Director Specific
	Handle:sm_ai_director_setdiff_chance_base = INVALID_HANDLE,

	// Respawn delay time
	Handle:sm_respawn_delay_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_ins_special = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_01 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_02 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_03 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_04 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_05 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_06 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_07 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_08 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_09 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_10 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_11 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_12 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_13 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_14 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_15 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_16 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_17 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_18 = INVALID_HANDLE,
	Handle:sm_respawn_delay_team_sec_player_count_19 = INVALID_HANDLE,
	
	// Respawn Mode (individual or wave based)
	Handle:sm_respawn_mode_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_mode_team_ins = INVALID_HANDLE,
	//Wave interval
	//Handle:sm_respawn_wave_int_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_wave_int_team_ins = INVALID_HANDLE,

	//VIP Cvars
	Handle:sm_vip_obj_time = INVALID_HANDLE,
	Handle:sm_vip_min_sp_reward = INVALID_HANDLE,
	Handle:sm_vip_max_sp_reward = INVALID_HANDLE,
	Handle:sm_vip_enabled = INVALID_HANDLE,


	// Respawn type
	Handle:sm_respawn_type_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_type_team_sec = INVALID_HANDLE,
	
	// Respawn lives
	Handle:sm_respawn_lives_team_sec = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_01 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_02 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_03 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_04 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_05 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_06 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_07 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_08 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_09 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_10 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_11 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_12 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_13 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_14 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_15 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_16 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_17 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_18 = INVALID_HANDLE,
	Handle:sm_respawn_lives_team_ins_player_count_19 = INVALID_HANDLE,
	
	// Fatal dead
	Handle:sm_respawn_fatal_chance = INVALID_HANDLE,
	Handle:sm_respawn_fatal_head_chance = INVALID_HANDLE,
	Handle:sm_respawn_fatal_limb_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_head_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_burn_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_explosive_dmg = INVALID_HANDLE,
	Handle:sm_respawn_fatal_chest_stomach = INVALID_HANDLE,
	
	// Counter-attack
	Handle:sm_respawn_counterattack_type = INVALID_HANDLE,
	Handle:sm_respawn_counterattack_vanilla = INVALID_HANDLE,
	Handle:sm_respawn_final_counterattack_type = INVALID_HANDLE,
	Handle:sm_respawn_security_on_counter = INVALID_HANDLE,
	Handle:sm_respawn_counter_chance = INVALID_HANDLE,
	Handle:sm_respawn_min_counter_dur_sec = INVALID_HANDLE,
	Handle:sm_respawn_max_counter_dur_sec = INVALID_HANDLE,
	Handle:sm_respawn_final_counter_dur_sec = INVALID_HANDLE,
	
	//Dynamic Respawn Mechanics
	Handle:sm_respawn_dynamic_distance_multiplier = INVALID_HANDLE,
	Handle:sm_respawn_dynamic_spawn_counter_percent = INVALID_HANDLE,
	Handle:sm_respawn_dynamic_spawn_percent = INVALID_HANDLE,

	// Misc
	Handle:sm_respawn_reset_type = INVALID_HANDLE,
	Handle:sm_respawn_enable_track_ammo = INVALID_HANDLE,
	
	// Reinforcements
	Handle:sm_respawn_reinforce_time = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_time_subsequent = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_multiplier = INVALID_HANDLE,
	Handle:sm_respawn_reinforce_multiplier_base = INVALID_HANDLE,
	
	// Monitor static enemy
	Handle:sm_respawn_check_static_enemy = INVALID_HANDLE,
	Handle:sm_respawn_check_static_enemy_counter = INVALID_HANDLE,
	
	// Donor tag
	Handle:sm_respawn_enable_donor_tag = INVALID_HANDLE,
	
	// Related to 'RoundEnd_Protector' plugin
	Handle:sm_remaininglife = INVALID_HANDLE,

	// Medic specific
	Handle:sm_revive_seconds = INVALID_HANDLE,
	Handle:sm_revive_bonus = INVALID_HANDLE,
	Handle:sm_revive_distance_metric = INVALID_HANDLE,
	Handle:sm_heal_bonus = INVALID_HANDLE,
	Handle:sm_heal_cap_for_bonus = INVALID_HANDLE,
	Handle:sm_revive_cap_for_bonus = INVALID_HANDLE,
	Handle:sm_reward_medics_enabled = INVALID_HANDLE,
	Handle:sm_heal_amount_medpack = INVALID_HANDLE,
	Handle:sm_heal_amount_paddles = INVALID_HANDLE,
	Handle:sm_non_medic_heal_amt = INVALID_HANDLE,
	Handle:sm_non_medic_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_minor_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_moderate_revive_hp = INVALID_HANDLE,
	Handle:sm_medic_critical_revive_hp = INVALID_HANDLE,
	Handle:sm_minor_wound_dmg = INVALID_HANDLE,
	Handle:sm_moderate_wound_dmg = INVALID_HANDLE,
	Handle:sm_medic_heal_self_max = INVALID_HANDLE,
	Handle:sm_non_medic_max_heal_other = INVALID_HANDLE,
	Handle:sm_minor_revive_time = INVALID_HANDLE,
	Handle:sm_moderate_revive_time = INVALID_HANDLE,
	Handle:sm_critical_revive_time = INVALID_HANDLE,
	Handle:sm_non_medic_revive_time = INVALID_HANDLE,
	Handle:sm_medpack_health_amount = INVALID_HANDLE,
	Handle:sm_multi_loadout_enabled = INVALID_HANDLE,
	Handle:sm_bombers_only = INVALID_HANDLE,
	Handle:sm_non_medic_heal_self_max = INVALID_HANDLE,
	Handle:sm_elite_counter_attacks = INVALID_HANDLE,
	Handle:sm_enable_bonus_lives = INVALID_HANDLE,
	Handle:sm_finale_counter_spec_enabled = INVALID_HANDLE,
	Handle:sm_finale_counter_spec_percent = INVALID_HANDLE,
	Handle:sm_cqc_map_enabled = INVALID_HANDLE,
	Handle:sm_enable_squad_spawning = INVALID_HANDLE,

	// NAV MESH SPECIFIC CVARS
	Handle:cvarSpawnMode = INVALID_HANDLE, //1 = Spawn in ins_spawnpoints, 2 = any spawnpoints that meets criteria, 0 = only at normal spawnpoints at next objective
	Handle:cvarMinCounterattackDistance = INVALID_HANDLE, //Min distance from counterattack objective to spawn
	Handle:cvarMinPlayerDistance = INVALID_HANDLE, //Min/max distance from players to spawn
	Handle:cvarBackSpawnIncrease = INVALID_HANDLE, //Adds to the minplayerdistance cvar when spawning behind player.
	Handle:cvarSpawnAttackDelay = INVALID_HANDLE, //Attack delay for spawning bots
	Handle:cvarMinObjectiveDistance = INVALID_HANDLE, //Min/max distance from next objective to spawn
	Handle:cvarMaxObjectiveDistance = INVALID_HANDLE, //Min/max distance from next objective to spawn
	Handle:cvarMaxObjectiveDistanceNav = INVALID_HANDLE, //Min/max distance from next objective to spawn using nav
	Handle:cvarCanSeeVectorMultiplier = INVALID_HANDLE, //CanSeeVector Multiplier divide this by cvarMaxPlayerDistance
	Handle:sm_ammo_resupply_range = INVALID_HANDLE, //Range of ammo resupply
	Handle:sm_resupply_delay = INVALID_HANDLE, //Delay to resupply
	Handle:sm_jammer_required = INVALID_HANDLE, //Jammer required for intel messages?
	Handle:cvarMaxPlayerDistance = INVALID_HANDLE; //Min/max distance from players to spawn


// Init global variables
new
	g_iCvar_respawn_enable,
	g_jammerRequired,
	g_elite_counter_attacks,
	g_finale_counter_spec_enabled,
	g_finale_counter_spec_percent,
	g_cqc_map_enabled,
	g_elitePeriod,
	g_elitePeriod_min,
	g_elitePeriod_max,
	g_iCvar_revive_enable,
	Float:g_respawn_counter_chance,
	g_counterAttack_min_dur_sec,
	g_counterAttack_max_dur_sec,
	g_iCvar_respawn_type_team_ins,
	g_iCvar_respawn_type_team_sec,
	g_iCvar_respawn_reset_type,
	Float:g_fCvar_respawn_delay_team_ins,
	Float:g_fCvar_respawn_delay_team_ins_spec,
	g_iCvar_enable_track_ammo,
	g_iCvar_counterattack_type,
	g_iCvar_counterattack_vanilla,
	g_iCvar_final_counterattack_type,
	g_iCvar_SpawnMode,
	
	//Dynamic Respawn cvars 
	g_DynamicRespawn_Distance_mult,
	g_dynamicSpawnCounter_Perc,
	g_dynamicSpawn_Perc,

	// Fatal dead
	Float:g_fCvar_fatal_chance,
	Float:g_fCvar_fatal_head_chance,
	g_iCvar_fatal_limb_dmg,
	g_iCvar_fatal_head_dmg,
	g_iCvar_fatal_burn_dmg,
	g_iCvar_fatal_explosive_dmg,
	g_iCvar_fatal_chest_stomach,
	//Dynamic Loadouts
	g_iCvar_bombers_only,
	g_iCvar_multi_loadout_enabled,

	//Respawn Mode (wave based)
	g_respawn_mode_team_sec,
	g_respawn_mode_team_ins,
	g_respawn_wave_int_team_ins,

	//NEW Respawn system globals (temporary)
	//Grab directly from theater (3 scouts, 5 jugs, 4 bombers, All others 20)
	g_maxbots_std = 0,
	g_maxbots_light = 0,
	g_maxbots_jug = 0,
	g_maxbots_bomb = 0,
	//Template of bots AI Director uses
	g_bots_std = 0,
	g_bots_light = 0,
	g_bots_jug = 0,
	g_bots_bomb = 0,

	//VIP Globals
	g_iCvar_vip_obj_time,
	g_iCvar_vip_min_sp_reward,
	g_iCvar_vip_max_sp_reward,
	g_vip_enable,
	g_vip_obj_count,
	g_vip_obj_ready,
	g_vip_min_reward,
	g_vip_max_reward,
	g_nVIP_ID = 0,

	g_cacheObjActive = 0,
	g_checkStaticAmt,
	g_checkStaticAmtCntr,
	g_checkStaticAmtAway,
	g_checkStaticAmtCntrAway,
	g_iReinforceTime,
	g_iReinforceTimeSubsequent,
	g_iReinforceTime_AD_Temp,
	g_iReinforceTimeSubsequent_AD_Temp,
	g_iReinforce_Mult,
	g_iReinforce_Mult_Base,
	g_iRemaining_lives_team_sec,
	g_iRemaining_lives_team_ins,
	g_iRespawn_lives_team_sec,
	g_iRespawn_lives_team_ins,
	g_iReviveSeconds,
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
	g_medpack_health_amt,
	g_botsReady,
	g_isConquer,
	g_isOutpost,
	g_isCheckpoint,
	g_isHunt,
	Float:g_flMinPlayerDistance,
	Float:g_flBackSpawnIncrease,
	Float:g_flMaxPlayerDistance,
	Float:g_flCanSeeVectorMultiplier, 
	Float:g_flMinObjectiveDistance,
	Float:g_flMaxObjectiveDistance,
	Float:g_flMaxObjectiveDistanceNav,
	Float:g_flSpawnAttackDelay,
	Float:g_flMinCounterattackDistance,

	//Elite bots Counters
	g_ins_bot_count_checkpoint_max_org,
	g_mp_player_resupply_coop_delay_max_org,
	g_mp_player_resupply_coop_delay_penalty_org,
	g_mp_player_resupply_coop_delay_base_org,
	g_bot_attack_aimpenalty_amt_close_org,
	g_bot_attack_aimpenalty_amt_far_org,
	g_bot_attack_aimpenalty_time_close_org,
	g_bot_attack_aimpenalty_time_far_org,
	g_bot_aim_aimtracking_base_org,
	g_bot_aim_aimtracking_frac_impossible_org,
	g_bot_aim_angularvelocity_frac_impossible_org,
	g_bot_aim_angularvelocity_frac_sprinting_target_org,
	g_bot_aim_attack_aimtolerance_frac_impossible_org,
	Float:g_bot_attackdelay_frac_difficulty_impossible_org,
	Float:g_bot_attack_aimtolerance_newthreat_amt_org,
	Float:g_bot_attack_aimtolerance_newthreat_amt_mult,
	g_bot_attack_aimpenalty_amt_close_mult,
	g_bot_attack_aimpenalty_amt_far_mult,
	Float:g_bot_attackdelay_frac_difficulty_impossible_mult,
	Float:g_bot_attack_aimpenalty_time_close_mult,
	Float:g_bot_attack_aimpenalty_time_far_mult,
	Float:g_bot_aim_aimtracking_base,
	Float:g_bot_aim_aimtracking_frac_impossible,
	Float:g_bot_aim_angularvelocity_frac_impossible,
	Float:g_bot_aim_angularvelocity_frac_sprinting_target,
	Float:g_bot_aim_attack_aimtolerance_frac_impossible,
	g_coop_delay_penalty_base,
	g_isEliteCounter,

	//Track enemy wave spawners
	g_enemyStdMax = 4,
	g_enemyFighterMax = 5,
	g_enemyStrikerMax = 6,
	g_enemyScoutMax = 3,
	g_enemySapperMax = 4,
	g_enemyJuggerMax = 5,
	g_enemyBomberMax = 4,
	//Count enemy currently alive
	g_enemyStdAliveCount = 0,
	g_enemyFighterAliveCount = 0,
	g_enemyStrikerAliveCount = 0,
	g_enemyScoutAliveCount = 0,
	g_enemySapperAliveCount = 0,
	g_enemyJuggerAliveCount = 0,
	g_enemyBomberAliveCount = 0,

	// Insurgency implements
	g_iObjResEntity, String:g_iObjResEntityNetClass[32],
	g_iLogicEntity, String:g_iLogicEntityNetClass[32];



enum SpawnModes
{
	SpawnMode_Normal = 0,
	SpawnMode_HidingSpots,
	SpawnMode_SpawnPoints,
};


new m_hMyWeapons, m_flNextPrimaryAttack, m_flNextSecondaryAttack;
/////////////////////////////////////
// Rank System (Based on graczu's Simple CS:S Rank - https://forums.alliedmods.net/showthread.php?p=523601)
//
/*
MySQL Query:

CREATE TABLE `ins_rank`(
`rank_id` int(64) NOT NULL auto_increment,
`steamId` varchar(32) NOT NULL default '',
`nick` varchar(128) NOT NULL default '',
`score` int(12) NOT NULL default '0',
`kills` int(12) NOT NULL default '0',
`deaths` int(12) NOT NULL default '0',
`headshots` int(12) NOT NULL default '0',
`sucsides` int(12) NOT NULL default '0',
`revives` int(12) NOT NULL default '0',
`heals` int(12) NOT NULL default '0',
`last_active` int(12) NOT NULL default '0',
`played_time` int(12) NOT NULL default '0',
PRIMARY KEY  (`rank_id`)) ENGINE=INNODB  DEFAULT CHARSET=utf8;

database.cfg

	"insrank"
	{
		"driver"			"default"
		"host"				"127.0.0.1"
		"database"			"database_name"
		"user"				"database_user"
		"pass"				"PASSWORD"
		//"timeout"			"0"
		"port"			"3306"
	}
*/

// KOLOROWE KREDKI 
#define YELLOW 0x01
#define GREEN 0x04


// SOME DEFINES
#define MAX_LINE_WIDTH 60
#define PLUGIN_VERSION "1.4"

// STATS TIME (SET DAYS AFTER STATS ARE DELETE OF NONACTIVE PLAYERS)
#define PLAYER_STATSOLD 30

// STATS DEFINATION FOR PLAYERS
new g_iStatScore[MAXPLAYERS+1];
new g_iStatKills[MAXPLAYERS+1];
new g_iStatDeaths[MAXPLAYERS+1];
new g_iStatHeadShots[MAXPLAYERS+1];
new g_iStatSuicides[MAXPLAYERS+1];
new g_iStatRevives[MAXPLAYERS+1];
new g_iStatHeals[MAXPLAYERS+1];
new g_iUserInit[MAXPLAYERS+1];
new g_iUserFlood[MAXPLAYERS+1];
new g_iUserPtime[MAXPLAYERS+1];
new String:g_sSteamIdSave[MAXPLAYERS+1][255];
new g_iRank[MAXPLAYERS+1];

// HANDLE OF DATABASE
new Handle:g_hDB;
//
/////////////////////////////////////

#define PLUGIN_VERSION "1.7.0"
#define PLUGIN_DESCRIPTION "Respawn dead players via admincommand or by queues"
#define UPDATE_URL	"http://ins.jballou.com/sourcemod/update-respawn.txt"

// Plugin info
public Plugin:myinfo =
{
	name = "[INS] Player Respawn",
	author = "Jared Ballou (Contributor: Daimyo, naong, and community members)",
	version = PLUGIN_VERSION,
	description = PLUGIN_DESCRIPTION,
	url = "http://jballou.com"
};

// Start plugin
public OnPluginStart()
{
	//Find player gear offset
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	
	RegConsoleCmd("sm_emap", emap); 
	RegConsoleCmd("sm_test", test); 
	RegConsoleCmd("sm_hints", Toggle_Hints); 

    RegConsoleCmd("sm_serverhelp", serverhelp); 
	//Create player array list
	g_playerArrayList = CreateArray();
	//g_badSpawnPos_Array = CreateArray();
	RegConsoleCmd("kill", cmd_kill);


	CreateConVar("sm_respawn_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_respawn_enabled = CreateConVar("sm_respawn_enabled", "1", "Automatically respawn players when they die; 0 - disabled, 1 - enabled");
	sm_revive_enabled = CreateConVar("sm_revive_enabled", "1", "Reviving enabled from medics?  This creates revivable ragdoll after death; 0 - disabled, 1 - enabled");
	// Nav Mesh Botspawn specific START
	cvarSpawnMode = CreateConVar("sm_botspawns_spawn_mode", "1", "Only normal spawnpoints at the objective, the old way (0), spawn in hiding spots following rules (1)", FCVAR_NOTIFY);
	cvarMinCounterattackDistance = CreateConVar("sm_botspawns_min_counterattack_distance", "3600.0", "Min distance from counterattack objective to spawn", FCVAR_NOTIFY);
	cvarMinPlayerDistance = CreateConVar("sm_botspawns_min_player_distance", "240.0", "Min distance from players to spawn", FCVAR_NOTIFY);
	cvarMaxPlayerDistance = CreateConVar("sm_botspawns_max_player_distance", "16000.0", "Max distance from players to spawn", FCVAR_NOTIFY);
	cvarCanSeeVectorMultiplier = CreateConVar("sm_botpawns_can_see_vect_mult", "1.5", "Divide this with sm_botspawns_max_player_distance to get CanSeeVector allowed distance for bot spawning in LOS", FCVAR_NOTIFY);
	cvarMinObjectiveDistance = CreateConVar("sm_botspawns_min_objective_distance", "240", "Min distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistance = CreateConVar("sm_botspawns_max_objective_distance", "12000", "Max distance from next objective to spawn", FCVAR_NOTIFY);
	cvarMaxObjectiveDistanceNav = CreateConVar("sm_botspawns_max_objective_distance_nav", "2000", "Max distance from next objective to spawn", FCVAR_NOTIFY);
	cvarBackSpawnIncrease = CreateConVar("sm_botspawns_backspawn_increase", "1400.0", "Whenever bot spawn on last point, this is added to minimum player respawn distance to avoid spawning too close to player.", FCVAR_NOTIFY);	
	cvarSpawnAttackDelay = CreateConVar("sm_botspawns_spawn_attack_delay", "2", "Delay in seconds for spawning bots to wait before firing.", FCVAR_NOTIFY);

	
	// Nav Mesh Botspawn specific END
	//Total bot count
	RegConsoleCmd("totalb", Check_Total_Enemies, "Show the total alive enemies");
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
	sm_respawn_check_static_enemy = CreateConVar("sm_respawn_check_static_enemy", "120", "Seconds amount to check if an AI has moved probably stuck");
	sm_respawn_check_static_enemy_counter = CreateConVar("sm_respawn_check_static_enemy_counter", "10", "Seconds amount to check if an AI has moved during counter");
	
	// Donor tag
	sm_respawn_enable_donor_tag = CreateConVar("sm_respawn_enable_donor_tag", "1", "If player has an access to reserved slot, add [DONOR] tag.");
	
	// Related to 'RoundEnd_Protector' plugin
	sm_remaininglife = CreateConVar("sm_remaininglife", "-1", "Returns total remaining life.");
	
	// Medic Revive
	sm_revive_seconds = CreateConVar("sm_revive_seconds", "5", "Time in seconds medic needs to stand over body to revive");
	sm_revive_bonus = CreateConVar("sm_revive_bonus", "1", "Bonus revive score(kill count) for medic");
	sm_revive_distance_metric = CreateConVar("sm_revive_distance_metric", "1", "Distance metric (0: meters / 1: feet)");
	sm_heal_bonus = CreateConVar("sm_heal_bonus", "1", "Bonus heal score(kill count) for medic");
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
	sm_medpack_health_amount = CreateConVar("sm_medpack_health_amount", "500", "Amount of health a deployed healthpack has");
	sm_bombers_only = CreateConVar("sm_bombers_only", "0", "bombers ONLY?");
	sm_multi_loadout_enabled = CreateConVar("sm_multi_loadout_enabled", "0", "Use Sernix Variety Bot Loadout? - Default OFF");
	sm_ammo_resupply_range = CreateConVar("sm_ammo_resupply_range", "80", "Range to resupply near ammo cache");
	sm_resupply_delay = CreateConVar("sm_resupply_delay", "5", "Delay loop for resupply ammo");
	sm_jammer_required = CreateConVar("sm_jammer_required", "1", "Require deployable jammer for enemy reports? 0 = Disabled 1 = Enabled");
	sm_elite_counter_attacks = CreateConVar("sm_elite_counter_attacks", "1", "Enable increased bot skills, numbers on counters?");
	sm_enable_bonus_lives = CreateConVar("sm_enable_bonus_lives", "1", "Give bonus lives based on X condition? 0|1 ");
	

	//Specialized Counter
	sm_finale_counter_spec_enabled = CreateConVar("sm_finale_counter_spec_enabled", "0", "Enable specialized finale spawn percent? 1|0");
	sm_finale_counter_spec_percent = CreateConVar("sm_finale_counter_spec_percent", "40", "What specialized finale counter percent for this map?");
	sm_cqc_map_enabled = CreateConVar("sm_cqc_map_enabled", "0", "Is this a cqc map? 0|1 no|yes");

	sm_enable_squad_spawning = CreateConVar("sm_enable_squad_spawning", "0", "Enable squad spawning SERNIX SPECIFIC? 1|0");
	//AI Director cvars
	sm_ai_director_setdiff_chance_base = CreateConVar("sm_ai_director_setdiff_chance_base", "10", "Base AI Director Set Hard Difficulty Chance");

	//Respawn Modes
	sm_respawn_mode_team_sec = CreateConVar("sm_respawn_mode_team_sec", "1", "Security: 0 = Individual spawning | 1 = Wave based spawning");
	sm_respawn_mode_team_ins = CreateConVar("sm_respawn_mode_team_ins", "0", "Insurgents: 0 = Individual spawning | 1 = Wave based spawning");

	//Wave interval for insurgents only
	sm_respawn_wave_int_team_ins = CreateConVar("sm_respawn_wave_int_team_ins", "1", "Time in seconds bots will respawn in waves");
	
	//VIP Specific cvar
	sm_vip_obj_time = CreateConVar("sm_vip_obj_time", "300", "VIP must reach new CPs in this amount of seconds");
	sm_vip_min_sp_reward = CreateConVar("sm_vip_min_sp_reward", "1", "Minimum supply points awarded to team when VIP completes objective");
	sm_vip_max_sp_reward = CreateConVar("sm_vip_max_sp_reward", "3", "Maximum supply points awarded to team when VIP completes objective");
	sm_vip_enabled = CreateConVar("sm_vip_enabled", "1", "Disable or Enable VIP features 0/1");
	
	

	//if (GetConVarInt(sm_enable_squad_spawning) == 1)
    	RegConsoleCmd("sm_ss", SquadSpawn); 
    	RegConsoleCmd("vip", Cmd_VIP, "Check for info about VIP");

	CreateConVar("Lua_Ins_Healthkit", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD);
	

	if ((m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBasePlayer::m_hMyWeapons\" !");
	}

	if ((m_flNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextPrimaryAttack\" !");
	}

	if ((m_flNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack")) == -1) {
		SetFailState("Fatal Error: Unable to find property offset \"CBaseCombatWeapon::m_flNextSecondaryAttack\" !");
	}

	// Add admin respawn console command
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "sm_respawn <#userid|name>");
	
	// Add reload config console command for admin
	RegAdminCmd("sm_respawn_reload", Command_Reload, ADMFLAG_SLAY, "sm_respawn_reload");
	
	// Event hooking
	//Lua Specific
	HookEvent("grenade_thrown", Event_GrenadeThrown);

	// //For ins_spawnpoint spawning
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
	HookEvent("game_end", Event_GameEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	
	HookEvent("weapon_reload", Event_PlayerReload_Pre, EventHookMode_Pre);
	HookEvent("player_blind", Event_OnFlashPlayerPre, EventHookMode_Pre);
	AddCommandListener(ResupplyListener, "inventory_resupply");

	// NavMesh Botspawn Specific Start
	HookConVarChange(cvarSpawnMode,CvarChange);
	// NavMesh Botspawn Specific End
	
	// Revive/Heal specific
	HookConVarChange(sm_revive_seconds, CvarChange);
	HookConVarChange(sm_heal_amount_medpack, CvarChange);

	HookConVarChange(sm_non_medic_heal_amt, CvarChange);
	HookConVarChange(sm_non_medic_revive_hp, CvarChange);
	HookConVarChange(sm_medic_minor_revive_hp, CvarChange);
	HookConVarChange(sm_medic_moderate_revive_hp, CvarChange);
	HookConVarChange(sm_medic_critical_revive_hp, CvarChange);
	HookConVarChange(sm_minor_wound_dmg, CvarChange);
	HookConVarChange(sm_moderate_wound_dmg, CvarChange);
	HookConVarChange(sm_medic_heal_self_max, CvarChange);
	HookConVarChange(sm_non_medic_heal_self_max, CvarChange);
	HookConVarChange(sm_non_medic_max_heal_other, CvarChange);
	HookConVarChange(sm_minor_revive_time, CvarChange);
	HookConVarChange(sm_moderate_revive_time, CvarChange);
	HookConVarChange(sm_critical_revive_time, CvarChange);
	HookConVarChange(sm_non_medic_revive_time, CvarChange);
	HookConVarChange(sm_medpack_health_amount, CvarChange);
	// Respawn specific
	HookConVarChange(sm_respawn_enabled, EnableChanged);
	HookConVarChange(sm_revive_enabled, EnableChanged);
	HookConVarChange(sm_respawn_delay_team_sec, CvarChange);
	HookConVarChange(sm_respawn_delay_team_ins, CvarChange);
	HookConVarChange(sm_respawn_delay_team_ins_special, CvarChange);
	HookConVarChange(sm_respawn_lives_team_sec, CvarChange);
	HookConVarChange(sm_respawn_lives_team_ins, CvarChange);
	HookConVarChange(sm_respawn_reset_type, CvarChange);
	HookConVarChange(sm_respawn_type_team_sec, CvarChange);
	HookConVarChange(sm_respawn_type_team_ins, CvarChange);
	HookConVarChange(cvarMinPlayerDistance,CvarChange);
	HookConVarChange(cvarBackSpawnIncrease,CvarChange);
	HookConVarChange(cvarMaxPlayerDistance,CvarChange);
	HookConVarChange(cvarCanSeeVectorMultiplier,CvarChange);
	HookConVarChange(cvarMinObjectiveDistance,CvarChange);
	HookConVarChange(cvarMaxObjectiveDistance,CvarChange);
	HookConVarChange(cvarMaxObjectiveDistanceNav,CvarChange);
	HookConVarChange(sm_enable_bonus_lives, CvarChange);
	//Dynamic respawning
	HookConVarChange(sm_respawn_dynamic_distance_multiplier,CvarChange);
	HookConVarChange(sm_respawn_dynamic_spawn_counter_percent,CvarChange);
	HookConVarChange(sm_respawn_dynamic_spawn_percent,CvarChange);

	 //Reinforce Timer
	// HookConVarChange(sm_respawn_reinforce_time,CvarChange);
	// HookConVarChange(sm_respawn_reinforce_time_subsequent,CvarChange);
	HookConVarChange(sm_respawn_reinforce_multiplier,CvarChange);
	HookConVarChange(sm_respawn_reinforce_multiplier_base,CvarChange);

	//Dynamic Loadouts
	HookConVarChange(sm_bombers_only, CvarChange);
	HookConVarChange(sm_multi_loadout_enabled, CvarChange);

	// Tags
	HookConVarChange(FindConVar("sv_tags"), TagsChanged);
	//Other
	HookConVarChange(sm_jammer_required, CvarChange);
	HookConVarChange(sm_elite_counter_attacks, CvarChange);
	HookConVarChange(sm_finale_counter_spec_enabled, CvarChange);
	HookConVarChange(sm_ai_director_setdiff_chance_base, CvarChange);
	HookConVarChange(sm_respawn_mode_team_sec, CvarChange);
	HookConVarChange(sm_respawn_mode_team_ins, CvarChange);
	HookConVarChange(sm_respawn_wave_int_team_ins, CvarChange);
	HookConVarChange(sm_vip_obj_time, CvarChange);
	HookConVarChange(sm_vip_min_sp_reward, CvarChange);
	HookConVarChange(sm_vip_max_sp_reward, CvarChange);
	HookConVarChange(sm_vip_enabled, CvarChange);
	HookConVarChange(sm_finale_counter_spec_percent, CvarChange);
	// Init respawn function
	// Next 14 lines of text are taken from Andersso's DoDs respawn plugin. Thanks :)
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	
	if (g_hGameConfig == INVALID_HANDLE)
		SetFailState("Fatal Error: Missing File \"insurgency.games\"!");

	StartPrepSDKCall(SDKCall_Player);
	decl String:game[40];
	GetGameFolderName(game, sizeof(game));
	if (StrEqual(game, "insurgency")) {
		//PrintToServer("[RESPAWN] ForceRespawn for Insurgency");
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	}
	if (StrEqual(game, "doi")) {
		//PrintToServer("[RESPAWN] ForceRespawn for DoI");
		PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "ForceRespawn");
	}
	g_hForceRespawn = EndPrepSDKCall();
	if (g_hForceRespawn == INVALID_HANDLE) {
		SetFailState("Fatal Error: Unable to find signature for \"ForceRespawn\"!");
	}
	//Load localization file
	LoadTranslations("common.phrases");
	LoadTranslations("respawn.phrases");
	LoadTranslations("nearest_player.phrases.txt");
	
	
	// Init variables
	g_iLogicEntity = -1;
	g_iObjResEntity = -1;
	
	//Uncomment this code and SQL code below to utilize rank system (youll need to setup yourself.)
	/////////////////////////
	// Rank System
	//RegConsoleCmd("say", Command_Say);			// Monitor say 
	//SQL_TConnect(LoadMySQLBase, "insrank");		// Connect to DB
	//
	/////////////////////////
	
	AutoExecConfig(true, "respawn");
}

//End Plugin
public OnPluginEnd()
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		StopSound(ent, SNDCHAN_VOICE, "Lua_sounds/healthkit_healing.wav");
		AcceptEntityInput(ent, "Kill");
	}
}

// Init config
public OnConfigsExecuted()
{
	if (GetConVarBool(sm_respawn_enabled))
		TagsCheck("respawntimes");
	else
		TagsCheck("respawntimes", true);
}

// When cvar changed
public EnableChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new intNewValue = StringToInt(newValue);
	new intOldValue = StringToInt(oldValue);

	if(intNewValue == 1 && intOldValue == 0)
	{
		TagsCheck("respawntimes");
		//HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	}
	else if(intNewValue == 0 && intOldValue == 1)
	{
		TagsCheck("respawntimes", true);
		//UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	}
}

// When cvar changed
public CvarChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	UpdateRespawnCvars();
}

// Update cvars
void UpdateRespawnCvars()
{
	//Counter attack chance based on number of points
	g_respawn_counter_chance = GetConVarFloat(sm_respawn_counter_chance);

	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	// The number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");

	if (ncp < 6)
	{
		//Add to minimum dur as well.
		new fRandomInt = GetRandomInt(15, 30);
		new fRandomInt2 = GetRandomInt(6, 12);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.2;
	}
	else if (ncp >= 6 && ncp <= 8)
	{
		//Add to minimum dur as well.
		new fRandomInt = GetRandomInt(10, 20);
		new fRandomInt2 = GetRandomInt(4, 8);
		g_counterAttack_min_dur_sec += fRandomInt;
		g_counterAttack_max_dur_sec += fRandomInt2;
		g_respawn_counter_chance += 0.1;
	}

	g_jammerRequired = GetConVarInt(sm_jammer_required);
	g_elite_counter_attacks = GetConVarInt(sm_elite_counter_attacks);
	g_finale_counter_spec_enabled = GetConVarInt(sm_finale_counter_spec_enabled);
	g_finale_counter_spec_percent = GetConVarInt(sm_finale_counter_spec_percent);

	//Ai Director UpdateCvar
	g_AIDir_DiffChanceBase = GetConVarInt(sm_ai_director_setdiff_chance_base);

	//Wave Based Spawning
	g_respawn_mode_team_sec = GetConVarInt(sm_respawn_mode_team_sec);
	g_respawn_mode_team_ins = GetConVarInt(sm_respawn_mode_team_ins);
	g_respawn_wave_int_team_ins = GetConVarInt(sm_respawn_wave_int_team_ins);
	g_iCvar_vip_obj_time = GetConVarInt(sm_vip_obj_time);
	g_iCvar_vip_min_sp_reward = GetConVarInt(sm_vip_min_sp_reward);
	g_iCvar_vip_max_sp_reward = GetConVarInt(sm_vip_max_sp_reward);
	g_vip_enable = GetConVarInt(sm_vip_enabled);
	
	// Respawn type 1 //TEAM_1_SEC == Index 2 and TEAM_2_INS == Index 3
	g_iRespawnCount[2] = GetConVarInt(sm_respawn_lives_team_sec);
	g_iRespawnCount[3] = GetConVarInt(sm_respawn_lives_team_ins);

	g_GiveBonusLives = GetConVarInt(sm_enable_bonus_lives);

	//Give bonus lives if lives are added per round
	if (g_GiveBonusLives && g_iCvar_respawn_reset_type == 0)
		SecTeamLivesBonus();
	
	
	if (g_easterEggRound == true)
	{
		g_iRespawnCount[2] = g_iRespawnCount[2] + 10;
		g_iRespawnSeconds = (g_iRespawnSeconds / 2);
		new cvar_mp_maxrounds = FindConVar("mp_maxrounds");
		SetConVarInt(cvar_mp_maxrounds, 2, true, true);
		new cvar_sm_botspawns_min_player_distance = FindConVar("sm_botspawns_min_player_distance");
		SetConVarFloat(cvar_sm_botspawns_min_player_distance, 2000.0, true, true);
		PrintToChatAll("************EASTER EGG ROUND************");
		PrintToChatAll("******NO WHINING, BE NICE, HAVE FUN*****");
		PrintToChatAll("******MAX ROUNDS CHANGED TO 2!**********");
		PrintToChatAll("******WORK TOGETHER, ADAPT!*************");
		PrintToChatAll("************EASTER EGG ROUND************");
	}


	// Type of resetting respawn token, Non-checkpoint modes get set to 0 automatically
	g_iCvar_respawn_reset_type = GetConVarInt(sm_respawn_reset_type);

	if(g_isCheckpoint == 0)
		g_iCvar_respawn_reset_type = 0;

	// Update Cvars
	g_iCvar_respawn_enable = GetConVarInt(sm_respawn_enabled);
	g_iCvar_revive_enable = GetConVarInt(sm_revive_enabled);
	// Bot spawn mode
	g_iCvar_SpawnMode = GetConVarInt(cvarSpawnMode);

	g_iReinforce_Mult = GetConVarInt(sm_respawn_reinforce_multiplier);
	g_iReinforce_Mult_Base = GetConVarInt(sm_respawn_reinforce_multiplier_base);
	
	// Tracking ammo
	g_iCvar_enable_track_ammo = GetConVarInt(sm_respawn_enable_track_ammo);
	
	// Respawn type
	g_iCvar_respawn_type_team_ins = GetConVarInt(sm_respawn_type_team_ins);
	g_iCvar_respawn_type_team_sec = GetConVarInt(sm_respawn_type_team_sec);
	
	
	//Dynamic Respawns
	g_DynamicRespawn_Distance_mult = GetConVarFloat(sm_respawn_dynamic_distance_multiplier);
	g_dynamicSpawnCounter_Perc = GetConVarInt(sm_respawn_dynamic_spawn_counter_percent);
	g_dynamicSpawn_Perc = GetConVarInt(sm_respawn_dynamic_spawn_percent);
	
	//Revive counts
	g_iReviveSeconds = GetConVarInt(sm_revive_seconds);
	
	// Heal Amount
	g_iHeal_amount_medPack = GetConVarInt(sm_heal_amount_medpack);
	g_iHeal_amount_paddles = GetConVarInt(sm_heal_amount_paddles);
	g_nonMedicHeal_amount = GetConVarInt(sm_non_medic_heal_amt);
	
	//HP when revived from wound
	g_nonMedicRevive_hp = GetConVarInt(sm_non_medic_revive_hp);
	g_minorWoundRevive_hp = GetConVarInt(sm_medic_minor_revive_hp);
	g_modWoundRevive_hp = GetConVarInt(sm_medic_moderate_revive_hp);
	g_critWoundRevive_hp = GetConVarInt(sm_medic_critical_revive_hp);

	//New Revive Mechanics
	g_minorWound_dmg = GetConVarInt(sm_minor_wound_dmg);
	g_moderateWound_dmg = GetConVarInt(sm_moderate_wound_dmg);
	g_medicHealSelf_max = GetConVarInt(sm_medic_heal_self_max);
	g_nonMedicHealSelf_max = GetConVarInt(sm_non_medic_heal_self_max);
	g_nonMedic_maxHealOther = GetConVarInt(sm_non_medic_max_heal_other);
	g_minorRevive_time = GetConVarInt(sm_minor_revive_time);
	g_modRevive_time = GetConVarInt(sm_moderate_revive_time);
	g_critRevive_time = GetConVarInt(sm_critical_revive_time);
	g_nonMedRevive_time = GetConVarInt(sm_non_medic_revive_time);
	g_medpack_health_amt = GetConVarInt(sm_medpack_health_amount);
	// Fatal dead
	g_fCvar_fatal_chance = GetConVarFloat(sm_respawn_fatal_chance);
	g_fCvar_fatal_head_chance = GetConVarFloat(sm_respawn_fatal_head_chance);
	g_iCvar_fatal_limb_dmg = GetConVarInt(sm_respawn_fatal_limb_dmg);
	g_iCvar_fatal_head_dmg = GetConVarInt(sm_respawn_fatal_head_dmg);
	g_iCvar_fatal_burn_dmg = GetConVarInt(sm_respawn_fatal_burn_dmg);
	g_iCvar_fatal_explosive_dmg = GetConVarInt(sm_respawn_fatal_explosive_dmg);
	g_iCvar_fatal_chest_stomach = GetConVarInt(sm_respawn_fatal_chest_stomach);
	
	//Dynamic Loadouts
	g_iCvar_bombers_only = GetConVarInt(sm_bombers_only);
	g_iCvar_multi_loadout_enabled = GetConVarInt(sm_multi_loadout_enabled);
	

	// Nearest body distance metric
	g_iUnitMetric = GetConVarInt(sm_revive_distance_metric);
	
	// Set respawn delay time
	g_iRespawnSeconds = -1;
	switch (GetTeamSecCount())
	{
		case 0: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_01);
		case 1: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_01);
		case 2: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_02);
		case 3: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_03);
		case 4: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_04);
		case 5: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_05);
		case 6: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_06);
		case 7: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_07);
		case 8: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_08);
		case 9: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_09);
		case 10: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_10);
		case 11: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_11);
		case 12: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_12);
		case 13: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_13);
		case 14: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_14);
		case 15: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_15);
		case 16: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_16);
		case 17: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_17);
		case 18: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_18);
		case 19: g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec_player_count_19);
	}
	// If not set use default
	if (g_iRespawnSeconds == -1)
		g_iRespawnSeconds = GetConVarInt(sm_respawn_delay_team_sec);
	


	// Respawn type 2 for players
	if (g_iCvar_respawn_type_team_sec == 2)
	{
		g_iRespawn_lives_team_sec = GetConVarInt(sm_respawn_lives_team_sec);
	}
	// Respawn type 2 for bots
	else if (g_iCvar_respawn_type_team_ins == 2)
	{
		// Set base value of remaining lives for team insurgent
		g_iRespawn_lives_team_ins = -1;
		switch (GetTeamSecCount())
		{
			case 0: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_01);
			case 1: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_01);
			case 2: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_02);
			case 3: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_03);
			case 4: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_04);
			case 5: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_05);
			case 6: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_06);
			case 7: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_07);
			case 8: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_08);
			case 9: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_09);
			case 10: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_10);
			case 11: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_11);
			case 12: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_12);
			case 13: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_13);
			case 14: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_14);
			case 15: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_15);
			case 16: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_16);
			case 17: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_17);
			case 18: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_18);
			case 19: g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins_player_count_19);
		}
		
		// If not set, use default
		if (g_iRespawn_lives_team_ins == -1)
			g_iRespawn_lives_team_ins = GetConVarInt(sm_respawn_lives_team_ins);
	}
	
	// Counter attack
	

	g_flMinCounterattackDistance = GetConVarFloat(cvarMinCounterattackDistance);
	g_flCanSeeVectorMultiplier = GetConVarFloat(cvarCanSeeVectorMultiplier);
	g_iCvar_counterattack_type = GetConVarInt(sm_respawn_counterattack_type);
	g_iCvar_counterattack_vanilla = GetConVarInt(sm_respawn_counterattack_vanilla);
	g_iCvar_final_counterattack_type = GetConVarInt(sm_respawn_final_counterattack_type);
	g_flMinPlayerDistance = GetConVarFloat(cvarMinPlayerDistance);
	g_flBackSpawnIncrease = GetConVarFloat(cvarBackSpawnIncrease);
	g_flMaxPlayerDistance = GetConVarFloat(cvarMaxPlayerDistance);

	g_flMinObjectiveDistance = GetConVarFloat(cvarMinObjectiveDistance);
	g_flMaxObjectiveDistance = GetConVarFloat(cvarMaxObjectiveDistance);
	g_flMaxObjectiveDistanceNav = GetConVarFloat(cvarMaxObjectiveDistanceNav);
	g_flSpawnAttackDelay = GetConVarFloat(cvarSpawnAttackDelay);

	if (g_easterEggRound == true)
	{
		g_flMinPlayerDistance = (g_flMinPlayerDistance * 2);
		g_flMaxPlayerDistance = (g_flMaxPlayerDistance * 2);
	}
	//Disable on conquer
	if (g_isConquer || g_isOutpost)
		g_iCvar_SpawnMode = 0;

	//Hunt specific
	if (g_isHunt == 1)
	{
		
		new secTeamCount = GetTeamSecCount();
		g_iCvar_SpawnMode = 0;
		//Increase reinforcements
		g_iRespawn_lives_team_ins = ((g_iRespawn_lives_team_ins * secTeamCount) / 4);
	}
}

// When tags changed
public TagsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarBool(sm_respawn_enabled))
		TagsCheck("respawntimes");
	else
		TagsCheck("respawntimes", true);
}

// On map starts, call initalizing function
public OnMapStart()
{	
	//Supply points based on control points
	int tsupply_base = 2;
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	//tsupply_base += (ncp * 2);
	//new Handle:hSupplyBase = FindConVar("mp_supply_token_base");
	//SetConVarInt(hSupplyBase, tsupply_base, true, false);

	ServerCommand("exec betterbots.cfg");
	//g_easterEggRound = false;
	//Clear player array
	ClearArray(g_playerArrayList);
	//Dynamic Loadouts
	g_iCvar_bombers_only = GetConVarInt(sm_bombers_only);
	g_iCvar_multi_loadout_enabled = GetConVarInt(sm_multi_loadout_enabled);


	//Load Dynamic Loadouts?
	//if (g_iCvar_multi_loadout_enabled == 1)
		Dynamic_Loadouts();

	//Wait until players ready to enable spawn checking
	g_playersReady = false;
	g_botsReady = 0;
	//Lua onmap start
	g_iBeaconBeam = PrecacheModel("sprites/laserbeam.vmt");
	g_iBeaconHalo = PrecacheModel("sprites/halo01.vmt");

	// Destory, Flip sounds
	PrecacheSound("soundscape/emitters/oneshot/radio_explode.ogg");
	PrecacheSound("ui/sfx/cl_click.wav");
	// Deploying sounds
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup1.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup2.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/need_backup3.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/holdposition2.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/holdposition3.ogg");
	PrecacheSound("player/voice/radial/security/leader/unsuppressed/moving2.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/backup3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition1.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition2.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/holdposition4.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/moving3.ogg");
	PrecacheSound("player/voice/radial/security/leader/suppressed/ontheway1.ogg");
	PrecacheSound("player/voice/security/command/leader/located4.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint1.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint2.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint3.ogg");
	PrecacheSound("player/voice/security/command/leader/setwaypoint4.ogg");

	PrecacheSound("weapons/universal/uni_crawl_l_01.wav");
	PrecacheSound("weapons/universal/uni_crawl_l_04.wav");
	PrecacheSound("weapons/universal/uni_crawl_l_02.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_03.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_05.wav");
	PrecacheSound("weapons/universal/uni_crawl_r_06.wav");

	//Grenade Call Out
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade9.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade9.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade4.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade4.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade35.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade34.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade33.ogg");
	PrecacheSound("player/voice/botsurvival/subordinate/incominggrenade23.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade2.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade13.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade12.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade11.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade10.ogg");
	PrecacheSound("player/voice/botsurvival/leader/incominggrenade18.ogg");
	
	//Molotov/Incen Callout
	PrecacheSound("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated7.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated6.ogg");
	PrecacheSound("player/voice/responses/security/subordinate/damage/molotov_incendiary_detonated6.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated5.ogg");
	PrecacheSound("player/voice/responses/security/leader/damage/molotov_incendiary_detonated4.ogg");

	//Squad / Team Leader Ambient Radio Sounds
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_01.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_02.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_03.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_04.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_01.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_02.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_03.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_04.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_05.ogg");
	PrecacheSound("soundscape/emitters/oneshot/mil_radio_oneshot_06.ogg");

	PrecacheSound("sernx_lua_sounds/radio/radio1.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio2.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio3.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio4.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio5.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio6.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio7.ogg");
	PrecacheSound("sernx_lua_sounds/radio/radio8.ogg");


	// Wait for navmesh
	CreateTimer(2.0, Timer_MapStart);
	g_preRoundInitial = true;
}

//Dynamic Loadouts
void Dynamic_Loadouts()
{
	//new Float:fRandom = GetRandomFloat(0.0, 1.0);
	//new Handle:hTheaterOverride = FindConVar("mp_theater_override");
	//SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc", true, false);	
	
	//Occurs counter attack
	//if (fRandom >= 0.0 && fRandom < 0.5)
	//{
	//	SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_isis", true, false);
	//	g_easterEggFlag = false;
	//}
	// else if (fRandom >= 0.26 && fRandom < 0.50)
	// {
	// 	SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_isis", true, false);
	// 	g_easterEggFlag = false;
	// }
	// else if (fRandom >= 0.50 && fRandom < 0.74)
	// {
	// 	g_easterEggFlag = false;
	// 	//Desert is just diff skins
	// 	new Float:fRandom_mil = GetRandomFloat(0.0, 1.0);
	// 	if (fRandom >= 0.5)
	// 		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_military", true, false);
	// 	else
	// 		SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_military_des", true, false);
	// }
	// else if (fRandom >= 0.74 && fRandom < 0.98)
	// {
	// 	SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_rebels", true, false);
	// 	g_easterEggFlag = false;
	// }
	// else if (fRandom >= 0.98)
	// {
	// 	SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_bomber", true, false);
	// 	g_easterEggFlag = true;
	// }
	// //Its a good day to die
	// if (g_iCvar_bombers_only == 1)
	// {
	// 	SetConVarString(hTheaterOverride, "dy_gnalvl_coop_usmc_bomber", true, false);
	// 	g_easterEggFlag = true;
	// }
}

public Action:Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_easterEggFlag == true)
	{
		g_easterEggRound = true;
	}
	else
	{
		g_easterEggRound = false; 
	}
	g_iRoundStatus = 0;
	g_botsReady = 0;
	g_iEnableRevive = 0;
	g_nVIP_ID = 0;
}
// Initializing
public Action:Timer_MapStart(Handle:Timer)
{
	// Check is map initialized
	if (g_isMapInit == 1) 
	{
		//PrintToServer("[RESPPAWN] Prevented repetitive call");
		return;
	}
	g_isMapInit = 1;


	//AI Directory Reset
	g_AIDir_ReinforceTimer_Orig = GetConVarInt(FindConVar("sm_respawn_reinforce_time"));
	g_AIDir_ReinforceTimer_SubOrig = GetConVarInt(FindConVar("sm_respawn_reinforce_time_subsequent"));


	// Bot Reinforce Times
	g_iReinforceTime = GetConVarInt(sm_respawn_reinforce_time);
	g_iReinforceTimeSubsequent = GetConVarInt(sm_respawn_reinforce_time_subsequent);


	g_cqc_map_enabled = GetConVarInt(sm_cqc_map_enabled);


	// Update cvars
	UpdateRespawnCvars();
	
	g_isConquer = 0;
	g_isHunt = 0;
	g_isCheckpoint = 0;
	g_isOutpost = 0;
	// Reset hiding spot
	new iEmptyArray[MAX_OBJECTIVES];
	g_iCPHidingSpotCount = iEmptyArray;
	
	// Check gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	if (StrEqual(sGameMode,"hunt")) // if Hunt?
	{
		g_isHunt = 1;
		g_iCvar_SpawnMode = 0;

		//Lives given at beginning, change respawn type.
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.1, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.2, true, false);
	}
	if (StrEqual(sGameMode,"conquer")) // if conquer?
	{
		g_isConquer = 1;
		g_iCvar_SpawnMode = 0;

		//Lives given at beginning, change respawn type.
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.4, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.4, true, false);
	}
	if (StrEqual(sGameMode,"outpost")) // if conquer?
	{
		g_isOutpost = 1;
		g_iCvar_SpawnMode = 0;

		//Lives given at beginning, change respawn type.
	   	//SetConVarFloat(sm_respawn_fatal_chance, 0.4, true, false);
	   	//SetConVarFloat(sm_respawn_fatal_head_chance, 0.4, true, false);
	}
	if (StrEqual(sGameMode,"checkpoint")) // if Hunt?
	{
		g_isCheckpoint = 1;
	}
	
	g_iEnableRevive = 0;
	// BotSpawn Nav Mesh initialize #################### END
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	// Ammo tracking timer
	 //if (GetConVarInt(sm_respawn_enable_track_ammo) == 1)
	 	//CreateTimer(1.0, Timer_GearMonitor,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Enemy reinforcement announce timer
	if (g_isConquer != 1 && g_isOutpost != 1) 
		CreateTimer(1.0, Timer_EnemyReinforce,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Enemy remaining announce timer
	if (g_isConquer != 1 && g_isOutpost != 1) 
		CreateTimer(30.0, Timer_Enemies_Remaining,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	//Enable WAVE BASED SPAWNING
	if (g_respawn_mode_team_sec || g_respawn_mode_team_ins)
		CreateTimer(1.0, Timer_WaveSpawning,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Player status check timer
	CreateTimer(1.0, Timer_PlayerStatus,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Revive monitor
	CreateTimer(1.0, Timer_ReviveMonitor, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Heal monitor
	CreateTimer(0.5, Timer_MedicMonitor, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Display nearest body for medics
	CreateTimer(0.1, Timer_NearestBody, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Display nearest body for medics
	CreateTimer(60.0, Timer_AmbientRadio, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Monitor ammo resupply
	CreateTimer(1.0, Timer_AmmoResupply, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// AI Director Tick
	if (g_isCheckpoint)
		CreateTimer(1.0, Timer_AIDirector_Main, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	//Vip Check for reward/complete
	g_vip_obj_ready = 0;
	if (g_vip_enable)
		CreateTimer(1.0, Timer_VIPCheck_Main, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Elite Period
	//CreateTimer(1.0, Timer_ElitePeriodTick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Static enemy check timer
	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	//Temp testing
	g_checkStaticAmtAway = 30;
	g_checkStaticAmtCntrAway = 12;
	//Elite Bot cvar multipliers (used to minus off top of original cvars)
	g_bot_attack_aimtolerance_newthreat_amt_mult = 0.8;
	g_bot_attack_aimpenalty_amt_close_mult = 15;
	g_bot_attack_aimpenalty_amt_far_mult = 40;
	g_bot_attackdelay_frac_difficulty_impossible_mult = 0.03;
	g_bot_attack_aimpenalty_time_close_mult = 0.15;
	g_bot_attack_aimpenalty_time_far_mult = 2;
	g_coop_delay_penalty_base = 800;
	g_bot_aim_aimtracking_base = 0.05;
	g_bot_aim_aimtracking_frac_impossible =  0.05;
	g_bot_aim_angularvelocity_frac_impossible =  0.05;
	g_bot_aim_angularvelocity_frac_sprinting_target =  0.05;
	g_bot_aim_attack_aimtolerance_frac_impossible =  0.05;

	//Get Originals
	g_ins_bot_count_checkpoint_max_org = GetConVarInt(FindConVar("ins_bot_count_checkpoint_max"));
	g_mp_player_resupply_coop_delay_max_org = GetConVarInt(FindConVar("mp_player_resupply_coop_delay_max"));
	g_mp_player_resupply_coop_delay_penalty_org = GetConVarInt(FindConVar("mp_player_resupply_coop_delay_penalty"));
	g_mp_player_resupply_coop_delay_base_org = GetConVarInt(FindConVar("mp_player_resupply_coop_delay_base"));
	g_bot_attack_aimpenalty_amt_close_org = GetConVarInt(FindConVar("bot_attack_aimpenalty_amt_close"));
	g_bot_attack_aimpenalty_amt_far_org = GetConVarInt(FindConVar("bot_attack_aimpenalty_amt_far"));
	g_bot_attack_aimpenalty_time_close_org = GetConVarFloat(FindConVar("bot_attack_aimpenalty_time_close"));
	g_bot_attack_aimpenalty_time_far_org = GetConVarFloat(FindConVar("bot_attack_aimpenalty_time_far"));
	g_bot_attack_aimtolerance_newthreat_amt_org = GetConVarFloat(FindConVar("bot_attack_aimtolerance_newthreat_amt"));
	g_bot_attackdelay_frac_difficulty_impossible_org = GetConVarFloat(FindConVar("bot_attackdelay_frac_difficulty_impossible"));
	g_bot_aim_aimtracking_base_org = GetConVarFloat(FindConVar("bot_aim_aimtracking_base"));
	g_bot_aim_aimtracking_frac_impossible_org = GetConVarFloat(FindConVar("bot_aim_aimtracking_frac_impossible"));
	g_bot_aim_angularvelocity_frac_impossible_org = GetConVarFloat(FindConVar("bot_aim_angularvelocity_frac_impossible"));
	g_bot_aim_angularvelocity_frac_sprinting_target_org = GetConVarFloat(FindConVar("bot_aim_angularvelocity_frac_sprinting_target"));
	g_bot_aim_attack_aimtolerance_frac_impossible_org = GetConVarFloat(FindConVar("bot_aim_attack_aimtolerance_frac_impossible"));

	CreateTimer(1.0, Timer_CheckEnemyStatic,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	if (g_isCheckpoint)
		CreateTimer(1.0, Timer_CheckEnemyAway,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
}

public OnMapEnd()
{
	// Reset variable
	//PrintToServer("[REVIVE_DEBUG] MAP ENDED");	
	
	// Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	g_nVIP_ID = 0;
	g_isMapInit = 0;
	g_botsReady = 0;
	g_iRoundStatus = 0;
	g_iEnableRevive = 0;
}

// Console command for reload config
public Action:Command_Reload(client, args)
{
	ServerCommand("exec sourcemod/respawn.cfg");
	
	//Reset respawn token
	ResetSecurityLives();
	ResetInsurgencyLives();
	
	//PrintToServer("[RESPAWN] %N reloaded respawn config.", client);
	ReplyToCommand(client, "[SM] Reloaded 'sourcemod/respawn.cfg' file.");
}

// Respawn function for console command
public Action:Command_Respawn(client, args)
{
	// Check argument
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_player_respawn <#userid|name>");
		return Plugin_Handled;
	}

	// Retrive argument
	new String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MaxClients], target_count, bool:tn_is_ml;
	
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
	if(target_count <= COMMAND_TARGET_NONE) 	// If we don't have dead players
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	// Team filter dead players, re-order target_list array with new_target_count
	new target, team, new_target_count;

	// Check team
	for (new i = 0; i < target_count; i++)
	{
		target = target_list[i];
		team = GetClientTeam(target);

		if(team >= 2)
		{
			target_list[new_target_count] = target; // re-order
			new_target_count++;
		}
	}

	// Check target count
	if(new_target_count == COMMAND_TARGET_NONE) // No dead players from  team 2 and 3
	{
		ReplyToTargetError(client, new_target_count);
		return Plugin_Handled;
	}
	target_count = new_target_count; // re-set new value.

	// If target exists
	if (tn_is_ml)
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", target_name);
	else
		ShowActivity2(client, "[SM] ", "%t", "Toggled respawn on target", "_s", target_name);
	
	// Process respawn
	for (new i = 0; i < target_count; i++)
		RespawnPlayer(client, target_list[i]);

	return Plugin_Handled;
}

public Action:Timer_EliteBots(Handle:Timer)
{
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	//new counterAlwaysCvar = GetConVarInt(FindConVar("mp_checkpoint_counterattack_always"));
	if (Ins_InCounterAttack())
	{
		new validAntenna = -1;
		validAntenna = FindValid_Antenna();
		
		if ((acp+1) == ncp)
		{
			PrintToServer("ENABLE ELITE FINALE");
			g_isEliteCounter = 1;
			//EnableDisableEliteBotCvars(1, 1);
		}
		else
		{
			PrintToServer("ENABLE ELITE NORMAL");
			g_isEliteCounter = 1;
			//EnableDisableEliteBotCvars(1, 0);
		}
		if (g_isEliteCounter == 1)
		{
			//PrintHintTextToAll("[INTEL]ENEMY FORCES ARE SENDING ELITE UNITS TO COUNTER!");
			//PrintToChatAll("[INTEL]ENEMY FORCES ARE SENDING ELITE UNITS TO COUNTER!");
			// if (validAntenna != -1 || g_jammerRequired == 0)
			// {
			// 	// Announce
			// 	PrintHintTextToAll("[INTEL]ENEMY FORCES ARE SENDING ELITE UNITS TO COUNTER!");
			// 	PrintToChatAll("[INTEL]ENEMY FORCES ARE SENDING ELITE UNITS TO COUNTER!");
			// }
			// else
			// {
			// 	// Announce
			// 	decl String:textToPrintChat[64];
			// 	decl String:textToPrint[64];
			// 	Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
			// 	Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
			// 	PrintHintTextToAll(textToPrint);
			// 	PrintToChatAll(textToPrintChat);
			// }
		}

	}
}
// Respawn player
void RespawnPlayer(client, target)
{
	new team = GetClientTeam(target);
	if(IsClientInGame(target) && !IsClientTimingOut(target) && g_client_last_classstring[target][0] && playerPickSquad[target] == 1 && !IsPlayerAlive(target) && team == TEAM_1_SEC)
	{
		// Write a log
		LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
		
		// Call forcerespawn fucntion
		SDKCall(g_hForceRespawn, target);
	}
}
// ForceRespawnPlayer player
void ForceRespawnPlayer(client, target)
{
	new team = GetClientTeam(target);
	if(IsClientInGame(target) && !IsClientTimingOut(target) && g_client_last_classstring[target][0] && playerPickSquad[target] == 1 && team == TEAM_1_SEC)
	{
		// Write a log
		LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
		
		// Call forcerespawn fucntion
		SDKCall(g_hForceRespawn, target);
	}
}

// Wave Based Spawning Timer
public Action:Timer_WaveSpawning(Handle:Timer)
{
	if (g_iRoundStatus == 0) return Plugin_Continue;

	/*if (g_respawn_mode_team_sec)
	{
		g_secWave_Timer--;
		//Announce every X seconds
		if (g_secWave_Timer % 30 == 0 ||
			g_secWave_Timer == 10 ||
			g_secWave_Timer <= 3)
		{
			decl String:textToPrintChat[64];
			decl String:textToPrint[64];
			Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Team reinforce in %d seconds", g_secWave_Timer);
			//Format(textToPrint, sizeof(textToPrint), "[INTEL]Team wave reinforce in %d seconds", g_secWave_Timer);
			//PrintHintTextToAll(textToPrint);
			PrintToChatAll(textToPrintChat);
		}

		//Reset Wave SEC timer and announce respawn
		if (g_secWave_Timer <= 0)
		{
			PrintHintTextToAll("[INTEL]Team Reinforced!");
			PrintToChatAll("[INTEL]Team Reinforced!");

			new validAntenna = -1;
			validAntenna = FindValid_Antenna();

			// Reduce wave timer on valid antenna
			if (validAntenna != -1)
			{
				new timeReduce = (GetTeamSecCount() / 3);
				if (timeReduce <= 0)
					timeReduce = 3;

				new jammerSpawnReductionAmt = (g_iRespawnSeconds / timeReduce);

				if ((g_iRespawnSeconds - jammerSpawnReductionAmt) > 0)
					g_secWave_Timer = (g_iRespawnSeconds - jammerSpawnReductionAmt);
				else
					g_secWave_Timer = g_iRespawnSeconds;


				if (Ins_InCounterAttack())
					g_secWave_Timer += (GetTeamSecCount() * 3); 
			}
			else
			{
				g_secWave_Timer = g_iRespawnSeconds;
				// Get the number of control points
				new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
				
				// Get active push point
				new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				// If last capture point
				if (g_isCheckpoint == 1 && ((acp+1) == ncp))
				{
					g_secWave_Timer += (GetTeamSecCount() * 4);
				}
				else if (Ins_InCounterAttack())
					g_secWave_Timer += (GetTeamSecCount() * 3);
			}
		}
	}*/

	//Bots custom wave spawns
	if (g_respawn_mode_team_ins)
	{
		//for (new client = 1; client <= MaxClients; client++)
		//{
		//	new team = GetClientTeam(client);
		//	// Check enables
		//	if (g_iCvar_respawn_enable)
		//	{
				
		//		// The number of control points
		//		new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
				
		//		// Active control poin
		//		new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

		//		if (team == TEAM_2_INS && g_respawn_mode_team_ins)
		//		{
					
		//			// Do not decrease life in counterattack
		//			if (g_isCheckpoint == 1 && Ins_InCounterAttack() && 
		//				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) || 
		//				((acp+1) != ncp && g_iCvar_counterattack_type == 2))
		//			)
		//			{
		//				// Respawn type 1 bots
		//				if ((g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS))
		//				{
		//					if ((g_iSpawnTokens[client] < g_iRespawnCount[team]))
		//						g_iSpawnTokens[client] = (g_iRespawnCount[team] + 1);
							
		//					// Call respawn timer
		//					CreateBotRespawnTimer(client);
		//				}
		//				// Respawn type 2 for bots
		//				else if (team == TEAM_2_INS && g_iCvar_respawn_type_team_ins == 2 && g_iRespawn_lives_team_ins > 0)
		//				{
		//					g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins + 1;
							
		//					// Call respawn timer
		//					CreateBotRespawnTimer(client);
		//				}
		//			}
		//			// Normal respawn
		//			else if (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS)
		//			{
		//				if (g_iSpawnTokens[client] > 0)
		//				{
		//					if (team == TEAM_2_INS)
		//					{
		//						CreateBotRespawnTimer(client);
		//					}
		//				}
		//				else if (g_iSpawnTokens[client] <= 0 && g_iRespawnCount[team] > 0)
		//				{
		//					// Cannot respawn anymore
		//					decl String:sChat[128];
		//					Format(sChat, 128,"You cannot be respawned anymore. (out of lives)");
		//					PrintToChat(client, "%s", sChat);
		//				}
		//			}
		//			// Respawn type 2 for bots
		//			else if (g_iCvar_respawn_type_team_ins == 2 && g_iRemaining_lives_team_ins >  0 && team == TEAM_2_INS)
		//			{
		//				CreateBotRespawnTimer(client);
		//			}
		//		}
		//	}
		//}
	}
}

// Check and inform player status
public Action:Timer_PlayerStatus(Handle:Timer)
{
	if (g_iRoundStatus == 0) return Plugin_Continue;
	/*for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && playerPickSquad[client] == 1)
		{
			new team = GetClientTeam(client);
			g_plyrGrenScreamCoolDown[client]--;
			if (g_plyrGrenScreamCoolDown[client] <= 0)
				g_plyrGrenScreamCoolDown[client] = 0;

			g_plyrFireScreamCoolDown[client]--;
			if (g_plyrFireScreamCoolDown[client] <= 0)
				g_plyrFireScreamCoolDown[client] = 0;

			if (g_iPlayerRespawnTimerActive[client] == 0 && !IsPlayerAlive(client) && !IsClientTimingOut(client) && IsClientObserver(client) && team == TEAM_1_SEC && g_iEnableRevive == 1 && g_iRoundStatus == 1) //
			{
				// Player connected or changed squad
				if (g_iHurtFatal[client] == -1)
				{
					PrintCenterText(client, "You changed your role in the squad. You can no longer be revived and must wait til next respawn!");
				}

				new String:woundType[128];
				woundType = "WOUNDED";
				if (g_playerWoundType[client] == 0)
					woundType = "MINORLY WOUNDED";
				else if (g_playerWoundType[client] == 1)
					woundType = "MODERATELY WOUNDED";
				else if (g_playerWoundType[client] == 2)
					woundType = "CRITCALLY WOUNDED";

				if (!g_iCvar_respawn_enable || g_iRespawnCount[2] == -1 || g_iSpawnTokens[client] <= 0)
				{
					// Player was killed fatally
					if (g_iHurtFatal[client] == 1)
					{
						decl String:fatal_hint[255];
						Format(fatal_hint, 255,"You were fatally killed for %i damage and must wait til next objective to spawn (out of lives)", g_clientDamageDone[client]);
						PrintCenterText(client, "%s", fatal_hint);
					}
					// Player was killed
					else if (g_iHurtFatal[client] == 0 && !Ins_InCounterAttack())
					{
						decl String:wound_hint[255];
						Format(wound_hint, 255,"[You're %s for %d damage]..wait patiently for a medic..do NOT mic/chat spam! (out of lives)", woundType, g_clientDamageDone[client]);
						PrintCenterText(client, "%s", wound_hint);
					}
					// Player was killed during counter attack
					else if (g_iHurtFatal[client] == 0 && Ins_InCounterAttack())
					{
						decl String:wound_hint[255];
						Format(wound_hint, 255,"You're %s during a Counter-Attack for %d damage..if its close to ending..dont bother asking for a medic! (out of lives)", woundType, g_clientDamageDone[client]);
						PrintCenterText(client, "%s", wound_hint);
					}
				}
			}
		}
	}*/
	return Plugin_Continue;
}

// Announce enemies remaining
public Action:Timer_Enemies_Remaining(Handle:Timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Check enemy count
	new alive_insurgents;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i))
		{
			alive_insurgents++;
		}
	}
	new validAntenna = -1;
	validAntenna = FindValid_Antenna();
	if (validAntenna != -1 || g_jammerRequired == 0)
	{
		// Announce
		decl String:textToPrintChat[64];
		decl String:textToPrint[64];
		//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL] Total Enemies alive: %d ", alive_insurgents + g_iRemaining_lives_team_ins);
		Format(textToPrint, sizeof(textToPrint), "[INTEL] Total Enemies alive: %d ", alive_insurgents + g_iRemaining_lives_team_ins);
		PrintHintTextToAll(textToPrint);
		//PrintToChatAll(textToPrintChat);

		new timeReduce = (GetTeamSecCount() / 3);
		if (timeReduce <= 0)
			timeReduce = 3;

		//new jammerSpawnReductionAmt = (g_iRespawnSeconds / timeReduce);
		//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Jammer Active! | Reinforce time reduced by: %d seconds", jammerSpawnReductionAmt);
		//PrintToChatAll(textToPrintChat);

	}
	else if(MaxClients > 0)
	{
		for (new iclient = 1; iclient <= MaxClients; iclient++)
		{
			if(IsClientInGame(iclient) && IsFakeClient(iclient))
			{
				new userHealth = GetClientHealth(iclient);
				new nGearItemID= GetEntData(iclient, g_iPlayerEquipGear + (4 * 5));

				if((userHealth > 0) && nGearItemID == nRadio_ID)
				{
					// Announce
					decl String:textToPrint[64];
					Format(textToPrint, sizeof(textToPrint), "[INTEL] Total Enemies alive: %d", alive_insurgents + g_iRemaining_lives_team_ins);
					PrintHintText(iclient, "%s", textToPrint);
				}
			}
		}
	}
	else
	{
		// Announce
		decl String:textToPrintChat[64];
		decl String:textToPrint[64];
		Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
		//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
		//PrintHintTextToAll(textToPrint);
		PrintToChatAll(textToPrintChat);
		//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Jammer Inactive! | Reinforce time reduced by: %d seconds", 0);
		//PrintToChatAll(textToPrintChat);
	}
	return Plugin_Continue;
}
public Action:Check_Total_Enemies(client, args)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Check enemy count
	new alive_insurgents;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i))
		{
			alive_insurgents++;
		}
	}
	
	//Get user health
	//new userHealth = GetClientHealth(client);

	decl String:textToPrint[64];
	//new nTotalAliveEnemies = alive_insurgents + g_iRemaining_lives_team_ins;
	
	new AdminId:admin = GetUserAdmin(client);
	if((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Generic, Access_Effective) == true))
	{
		Format(textToPrint, sizeof(textToPrint), "Enemies alive: %d | Enemy reinforcements left: %d", alive_insurgents ,g_iRemaining_lives_team_ins);
		PrintHintText(client, "%s", textToPrint);
	}
	/*else if((client) && ((StrContains(g_client_last_classstring[client], "recon") > -1) && (userHealth > 0)))
	{
		Format(textToPrint, sizeof(textToPrint), "Total enemies alive: %d", nTotalAliveEnemies);
		PrintHintText(client, "%s", textToPrint);
	}*/
	
	return Plugin_Handled;
}
void AI_Director_RandomEnemyReinforce()
{
	new validAntenna = -1;
	validAntenna = FindValid_Antenna();
	decl String:textToPrint[64];
	decl String:textToPrintChat[64];
	//Only add more reinforcements if under certain amount so its not endless.
	if (g_iRemaining_lives_team_ins > 0)
	{
		// if (g_iRemaining_lives_team_ins < (g_iRespawn_lives_team_ins / g_iReinforce_Mult) + g_iReinforce_Mult_Base)
		// {
			// Get bot count
			new minBotCount = (g_iRespawn_lives_team_ins / 5);
			g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
			Format(textToPrint, sizeof(textToPrint), "[INTEL]Ambush Reinforcements Added to Existing Reinforcements!");
			Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Ambush Reinforcements Added to Existing Reinforcements!");
			
			//AI Director Reinforcement START
			g_AIDir_BotReinforceTriggered = true;
			g_AIDir_TeamStatus -= 5;
			g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

			//AI Director Reinforcement END
			if (validAntenna != -1 || g_jammerRequired == 0)
			{
				PrintHintTextToAll(textToPrint);
				PrintToChatAll(textToPrintChat);
			}
			else
			{
				new fCommsChance = GetRandomInt(1, 100);
				if (fCommsChance > 50)
				{
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
					//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
					//PrintHintTextToAll(textToPrint);
					PrintToChatAll(textToPrintChat);
				}
			}
			g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;
			PrintToServer("g_iReinforceTime %d, Ambush Reinforcements added to existing!",g_iReinforceTime);
			if (g_isHunt == 1)
				 g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp * g_iReinforce_Mult;
			//if (g_huntCacheDestroyed == true && g_isHunt == 1)
			//	 g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;

			//Lower Bot Flank spawning on reinforcements
			g_dynamicSpawn_Perc = 0;

			// Add bots
			for (new client = 1; client <= MaxClients; client++)
			{
				if (client > 0 && IsClientInGame(client))
				{
					new m_iTeam = GetClientTeam(client);
					if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
					{
						g_iRemaining_lives_team_ins++;
						CreateBotRespawnTimer(client);
					}
				}
			}
			
			//Reset bot back spawning to default
			CreateTimer(45, Timer_ResetBotFlankSpawning, _);
		//}
	}
	else
	{
		// Get bot count
		new minBotCount = (g_iRespawn_lives_team_ins / 5);
		g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;

		//Lower Bot Flank spawning on reinforcements
		g_dynamicSpawn_Perc = 0;

		// Add bots
		for (new client = 1; client <= MaxClients; client++)
		{
			if (client > 0 && IsClientInGame(client))
			{
				new m_iTeam = GetClientTeam(client);
				if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
				{
					g_iRemaining_lives_team_ins++;
					CreateBotRespawnTimer(client);
				}
			}
		}
		g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;
		PrintToServer("g_iReinforceTime %d, AMBUSH Reinforcements Arrived Normally!",g_iReinforceTime);


		//Reset bot back spawning to default
		CreateTimer(45, Timer_ResetBotFlankSpawning, _);

		// Get random duration
		//new fRandomInt = GetRandomInt(1, 4);

		Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemy Ambush Reinforcement Incoming!");
		Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Enemy Ambush Reinforcement Incoming!");

		//AI Director Reinforcement START
		g_AIDir_BotReinforceTriggered = true;
		g_AIDir_TeamStatus -= 5;
		g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

		//AI Director Reinforcement END

		if (validAntenna != -1 || g_jammerRequired == 0)
		{
			PrintHintTextToAll(textToPrint);
			PrintToChatAll(textToPrintChat);
		}
		else
		{
			new fCommsChance = GetRandomInt(1, 100);
			if (fCommsChance > 50)
			{
				Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
				//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
				//PrintHintTextToAll(textToPrint);
				PrintToChatAll(textToPrintChat);
			}
		}
	}
}

// This timer reinforces bot team if you do not capture point
public Action:Timer_EnemyReinforce(Handle:Timer)
{
	
	
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Check enemy remaining
	if (g_iRemaining_lives_team_ins <= (g_iRespawn_lives_team_ins / g_iReinforce_Mult) + g_iReinforce_Mult_Base)
	{
		g_iReinforceTime--;
		new validAntenna = -1;
		validAntenna = FindValid_Antenna();
		decl String:textToPrintChat[64];
		decl String:textToPrint[64];
		// Announce every 10 seconds
		if (g_iReinforceTime % 10 == 0 && g_iReinforceTime > 10)
		{
			
			if (validAntenna != -1 || g_jammerRequired == 0)
			{
				
				//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Friendlies spawn on Counter-Attacks, Capture the Point!");
				if (g_isHunt == 1)
				{
					//Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemies reinforce in %d seconds | Kill rest/blow cache!", g_iReinforceTime);
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemies reinforce in %d seconds | Kill rest/blow cache!", g_iReinforceTime);
				}
				else
				{
					//Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemies reinforce in %d seconds | Capture point soon!", g_iReinforceTime);
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemies reinforce in %d seconds | Capture point soon!", g_iReinforceTime);
				}

				PrintHintTextToAll(textToPrint);
				if (g_iReinforceTime <= 60)
				{
					PrintToChatAll(textToPrint);
				}
			}
			else
			{
				new fCommsChance = GetRandomInt(1, 100);
				if (fCommsChance > 50)
				{
					// Announce
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
					//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
					//rintHintTextToAll(textToPrint);
					PrintToChatAll(textToPrintChat);
				}
			}
		}
		// Anncount every 1 second
		if (g_iReinforceTime <= 10 && (validAntenna != -1 || g_jammerRequired == 0))
		{
			
			//Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Friendlies spawn on Counter-Attacks, Capture the Point!");
			if (g_isHunt == 1)
				Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemies reinforce in %d seconds | Kill remaining/blow cache!", g_iReinforceTime);
			else
				Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemies reinforce in %d seconds | Capture point soon!", g_iReinforceTime);

			PrintHintTextToAll(textToPrint);
			//PrintToChatAll(textToPrintChat);
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
					new minBotCount = (g_iRespawn_lives_team_ins / 4);
					g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
					Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemy Reinforcements Added to Existing Reinforcements!");
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemy Reinforcements Added to Existing Reinforcements!");
					
					//AI Director Reinforcement START
					g_AIDir_BotReinforceTriggered = true;
					g_AIDir_TeamStatus -= 5;
					g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

					//AI Director Reinforcement END
					if (validAntenna != -1 || g_jammerRequired == 0)
					{
						PrintHintTextToAll(textToPrint);
						PrintToChatAll(textToPrintChat);
					}
					else
					{
						new fCommsChance = GetRandomInt(1, 100);
						if (fCommsChance > 50)
						{
							Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
							//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
							//PrintHintTextToAll(textToPrint);
							PrintToChatAll(textToPrintChat);
						}
					}
					g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;
					PrintToServer("g_iReinforceTime %d, Reinforcements added to existing!",g_iReinforceTime);
					if (g_isHunt == 1)
						 g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp * g_iReinforce_Mult;
					//if (g_huntCacheDestroyed == true && g_isHunt == 1)
					//	 g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;

					//Lower Bot Flank spawning on reinforcements
					g_dynamicSpawn_Perc = 0;

					// Add bots
					for (new client = 1; client <= MaxClients; client++)
					{
						if (client > 0 && IsClientInGame(client))
						{
							new m_iTeam = GetClientTeam(client);
							if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
							{
								g_iRemaining_lives_team_ins++;
								CreateBotRespawnTimer(client);
							}
						}
					}
					
					//Reset bot back spawning to default
					CreateTimer(45, Timer_ResetBotFlankSpawning, _);

				}
				else
				{
					Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemy Reinforcements at Maximum Capacity");
					Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemy Reinforcements at Maximum Capacity");
					if (validAntenna != -1 || g_jammerRequired == 0)
					{
						PrintHintTextToAll(textToPrint);
						PrintToChatAll(textToPrintChat);
					}
					else
					{
						new fCommsChance = GetRandomInt(1, 100);
						if (fCommsChance > 50)
						{
							Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
							//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
							//PrintHintTextToAll(textToPrint);
							PrintToChatAll(textToPrintChat);
						}
					}
					// Reset reinforce time
					g_iReinforceTime = g_iReinforceTime_AD_Temp;
					PrintToServer("g_iReinforceTime %d, Reinforcements max capacity!",g_iReinforceTime);
					if (g_isHunt == 1)
						 g_iReinforceTime = g_iReinforceTime_AD_Temp * g_iReinforce_Mult;
					//if (g_huntCacheDestroyed == true && g_isHunt == 1)
					//	g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;
				}

			}
			// Respawn enemies
			else
			{
				// Get bot count
				new minBotCount = (g_iRespawn_lives_team_ins / 4);
				g_iRemaining_lives_team_ins = g_iRemaining_lives_team_ins + minBotCount;
				
				//Lower Bot Flank spawning on reinforcements
				g_dynamicSpawn_Perc = 0;

				// Add bots
				for (new client = 1; client <= MaxClients; client++)
				{
					if (client > 0 && IsClientInGame(client))
					{
						new m_iTeam = GetClientTeam(client);
						if (IsFakeClient(client) && !IsPlayerAlive(client) && m_iTeam == TEAM_2_INS)
						{
							g_iRemaining_lives_team_ins++;
							CreateBotRespawnTimer(client);
						}
					}
				}
				g_iReinforceTime = g_iReinforceTimeSubsequent_AD_Temp;
				PrintToServer("g_iReinforceTime %d, Reinforcements Arrived Normally!",g_iReinforceTime);


				//Reset bot back spawning to default
				CreateTimer(45, Timer_ResetBotFlankSpawning, _);

				// Get random duration
				//new fRandomInt = GetRandomInt(1, 4);
				
				Format(textToPrint, sizeof(textToPrint), "[INTEL]Enemy Reinforcements Have Arrived!");
				Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Enemy Reinforcements Have Arrived!");
				
				//AI Director Reinforcement START
				g_AIDir_BotReinforceTriggered = true;
				g_AIDir_TeamStatus -= 5;
				g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

				//AI Director Reinforcement END

				if (validAntenna != -1 || g_jammerRequired == 0)
				{
					PrintHintTextToAll(textToPrint);
					PrintToChatAll(textToPrintChat);
				}
				else
				{
					new fCommsChance = GetRandomInt(1, 100);
					if (fCommsChance > 50)
					{
						Format(textToPrintChat, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
						//Format(textToPrint, sizeof(textToPrintChat), "[INTEL]Comms are down, build jammer to get enemy reports.");
						//PrintHintTextToAll(textToPrint);
						PrintToChatAll(textToPrintChat);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

//Reset bot flank spawning X seconds after reinforcement
public Action:Timer_ResetBotFlankSpawning(Handle:Timer)
{
	//Reset bot back spawning to default
	g_dynamicSpawn_Perc = GetConVarInt(sm_respawn_dynamic_spawn_percent);
	return Plugin_Continue;
}

// Check enemy is stuck
public Action:Timer_CheckEnemyStatic(Handle:Timer)
{
	//Remove bot weapons when static killed to reduce server performance on dropped items.
	new primaryRemove = 1, secondaryRemove = 1, grenadesRemove = 1;

	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	if (Ins_InCounterAttack())
	{
		g_checkStaticAmtCntr = g_checkStaticAmtCntr - 1;
		if (g_checkStaticAmtCntr <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
						// If enemy position is static, kill him
						if (tDistance <= 150 && Check_NearbyPlayers(enemyBot) && (capDistance > 800 || g_botStaticGlobal[enemyBot] > 120)) 
						{
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
							PrintToServer("ENEMY STATIC - KILLING");
							g_badSpawnPos_Track[enemyBot] = enemyPos;
							//PrintToServer("Add to g_badSpawnPos_Array | enemyPos: (%f, %f, %f) | g_badSpawnPos_Array Size: %d", enemyPos[0],enemyPos[1],enemyPos[2], GetArraySize(g_badSpawnPos_Array));
							//PushArrayArray(g_badSpawnPos_Array, enemyPos, sizeof(enemyPos));
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
			g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
		}
	}
	else
	{
		g_checkStaticAmt = g_checkStaticAmt - 1;
		if (g_checkStaticAmt <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerPos[enemyBot]);
						//Check point distance
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
						// If enemy position is static, kill him
						if (tDistance <= 150 && (capDistance > 800) && Check_NearbyPlayers(enemyBot))// || g_botStaticGlobal[enemyBot] > 120)) 
						{
							//PrintToServer("ENEMY STATIC - KILLING");
							RemoveWeapons(enemyBot, primaryRemove, secondaryRemove, grenadesRemove);
							ForcePlayerSuicide(enemyBot);
							AddLifeForStaticKilling(enemyBot);
						}
						// Update current position
						else
						{ 
							g_enemyTimerPos[enemyBot] = enemyPos;
							//g_botStaticGlobal[enemyBot]++;
						}
					}
				}
			}
			g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy); 
		}
	}
	
	return Plugin_Continue;
}
// Check enemy is stuck
public Action:Timer_CheckEnemyAway(Handle:Timer)
{
	//Remove bot weapons when static killed to reduce server performance on dropped items.
	new primaryRemove = 1, secondaryRemove = 1, grenadesRemove = 1;
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	if (Ins_InCounterAttack())
	{
		g_checkStaticAmtCntrAway = g_checkStaticAmtCntrAway - 1;
		if (g_checkStaticAmtCntrAway <= 0)
		{
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
						}
						else 
							capDistance = 801;
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
			for (new enemyBot = 1; enemyBot <= MaxClients; enemyBot++)
			{	
				if (IsClientInGame(enemyBot) && IsFakeClient(enemyBot))
				{
					new m_iTeam = GetClientTeam(enemyBot);
					if (IsPlayerAlive(enemyBot) && m_iTeam == TEAM_2_INS)
					{
						// Get current position
						decl Float:enemyPos[3];
						GetClientAbsOrigin(enemyBot, Float:enemyPos);
						
						// Get distance
						new Float:tDistance;
						new Float:capDistance;
						tDistance = GetVectorDistance(enemyPos, g_enemyTimerAwayPos[enemyBot]);
						//Check point distance
						if (g_isCheckpoint == 1)
						{
							new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
							Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
							capDistance = GetVectorDistance(enemyPos,m_vCPPositions[m_nActivePushPointIndex]);
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
void AddLifeForStaticKilling(client)
{
	// Respawn type 1
	new team = GetClientTeam(client);
	if (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS && g_iRespawn_lives_team_ins > 0)
	{
		g_iSpawnTokens[client]++;
	}
	else if (g_iCvar_respawn_type_team_ins == 2 && team == TEAM_2_INS && g_iRespawn_lives_team_ins > 0)
	{
		g_iRemaining_lives_team_ins++;
	}
}

//
void CalculateBotCount()
{
	// Respawn type 1
	for (new client = 1; client <= MaxClients; client++)
	{
		new team = GetClientTeam(client);
		if (team == TEAM_2_INS && IsFakeClient(client))
		{

			if (StrContains(g_client_last_classstring[client], "bomber") > -1)
				g_maxbots_bomb += 1;
			else if (StrContains(g_client_last_classstring[client], "juggernaut") > -1)
				g_maxbots_jug += 1;
			else if (StrContains(g_client_last_classstring[client], "scout") > -1)
				g_maxbots_light += 1;
			else
				g_maxbots_std += 1;

		}
	}
}

// Monitor player's gear
//public Action:Timer_GearMonitor(Handle:Timer)
//{
//	PrintToChatAll("GEAR MONITOR");
//	//if (g_iRoundStatus == 0) return Plugin_Continue;
//	for (new client = 1; client <= MaxClients; client++)
//	{
//		if (client > 0 && !IsFakeClient(client))
//		{
//			new primaryWeapon = GetPlayerWeaponSlot(client, 0);
//			new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
//			new playerGrenades = GetPlayerWeaponSlot(client, 3);
			
//			//SetWeaponAmmo(client, primaryWeapon, 3, 0);

//			//SDKHook(primaryWeapon, SDKHook_ReloadPost, OnWeaponReload);
//			new bool:isReloading = Client_IsReloading(client);
//			PrintToChatAll("Reloading: %i", isReloading);
//			PrintToChatAll("Reloading: %d", isReloading);
			
//		   if (g_iEnableRevive == 1 && g_iRoundStatus == 1 && g_iCvar_enable_track_ammo == 1)
//			{	   
//				//GetPlayerAmmo(client);
//			}
//		}
//	}
//	return Plugin_Continue;
//}

// Update player's gear
void SetPlayerAmmo(client)
{
	if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		//PrintToServer("SETWEAPON ########");
		new primaryWeapon = GetPlayerWeaponSlot(client, 0);
		new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
		new playerGrenades = GetPlayerWeaponSlot(client, 3);
		//Lets get weapon classname, we need this to create weapon entity if primary does not fit secondary
		//Make sure IsValidEntity is not only for entities
		//decl String:weaponClassname[32];
		 //if (secondaryWeapon != playerSecondary[client] && playerSecondary[client] != -1 && IsValidEntity(playerSecondary[client]))
		 //{
		 //	GetEdictClassname(playerSecondary[client], weaponClassname, sizeof(weaponClassname));
		 //	RemovePlayerItem(client,secondaryWeapon);
		 //	AcceptEntityInput(secondaryWeapon, "kill");
		 //	GivePlayerItem(client, weaponClassname);
		 //	secondaryWeapon = playerSecondary[client];
		 //}
		 //if (primaryWeapon != playerPrimary[client] && playerPrimary[client] != -1 && IsValidEntity(playerPrimary[client]))
		 //{
		 //	GetEdictClassname(playerPrimary[client], weaponClassname, sizeof(weaponClassname));
		 //	RemovePlayerItem(client,primaryWeapon);
		 //	AcceptEntityInput(primaryWeapon, "kill");
		 //	GivePlayerItem(client, weaponClassname);
		 //	EquipPlayerWeapon(client, playerPrimary[client]); 
		 //	primaryWeapon = playerPrimary[client];
		 //}
		
		  //Check primary weapon
		 if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
		 {
		 	//PrintToServer("PlayerClip %i, playerAmmo %i, PrimaryWeapon %d",playerClip[client][0],playerAmmo[client][0], primaryWeapon); 
		 	SetPrimaryAmmo(client, primaryWeapon, playerClip[client][0], 0); //primary clip
		 	Client_SetWeaponPlayerAmmoEx(client, primaryWeapon, playerAmmo[client][0]); //primary
		 	//PrintToServer("SETWEAPON 1");
		 }
		
		 // Check secondary weapon
		 if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
		 {
		 	//PrintToServer("PlayerClip %i, playerAmmo %i, PrimaryWeapon %d",playerClip[client][1],playerAmmo[client][1], primaryWeapon); 
		 	SetPrimaryAmmo(client, secondaryWeapon, playerClip[client][1], 1); //secondary clip
		 	Client_SetWeaponPlayerAmmoEx(client, secondaryWeapon, playerAmmo[client][1]); //secondary
		 	//PrintToServer("SETWEAPON 2");
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
					decl String:weapon[32];
					GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client,playerGrenades);
					AcceptEntityInput(playerGrenades, "kill");
					
				}
			}
			
			/*
			If we need to track grenades (since they drop them on death, its a no)
			SetGrenadeAmmo(client, Gren_M67, playerGrenadeType[client][0]);
			SetGrenadeAmmo(client, Gren_Incen, playerGrenadeType[client][1]);
			SetGrenadeAmmo(client, Gren_Molot, playerGrenadeType[client][2]);
			SetGrenadeAmmo(client, Gren_M18, playerGrenadeType[client][3]);
			SetGrenadeAmmo(client, Gren_Flash, playerGrenadeType[client][4]);
			SetGrenadeAmmo(client, Gren_F1, playerGrenadeType[client][5]);
			SetGrenadeAmmo(client, Gren_IED, playerGrenadeType[client][6]);
			SetGrenadeAmmo(client, Gren_C4, playerGrenadeType[client][7]);
			SetGrenadeAmmo(client, Gren_AT4, playerGrenadeType[client][8]);
			SetGrenadeAmmo(client, Gren_RPG7, playerGrenadeType[client][9]);
			*/
			//PrintToServer("SETWEAPON 3");
		}
		if (!IsFakeClient(client))
			playerRevived[client] = false;
	}
}
// Retrive player's gear
void GetPlayerAmmo(client)
{
	if (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		//CONSIDER IF PLAYER CHOOSES DIFFERENT CLASS
		new primaryWeapon = GetPlayerWeaponSlot(client, 0);
		new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
		//new playerGrenades = GetPlayerWeaponSlot(client, 3);

		playerPrimary[client] = primaryWeapon;
		playerSecondary[client] = secondaryWeapon;
		//Get ammo left in clips for primary and secondary
		playerClip[client][0] = GetPrimaryAmmo(client, primaryWeapon, 0);
		playerClip[client][1] = GetPrimaryAmmo(client, secondaryWeapon, 1); // m_iClip2 for secondary if this doesnt work? would need GetSecondaryAmmo
		//Get Magazines left on player
		if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
			 Client_GetWeaponPlayerAmmoEx(client, primaryWeapon, playerAmmo[client][0], -1); //primary
		if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon))
			 Client_GetWeaponPlayerAmmoEx(client, secondaryWeapon, -1, playerAmmo[client][1]); //secondary	
		
		/*
		if (playerGrenades != -1 && IsValidEntity(playerGrenades))
		{
			 //PrintToServer("[GEAR] CLIENT HAS VALID GRENADES");
			 playerGrenadeType[client][0] = GetGrenadeAmmo(client, Gren_M67);
			 playerGrenadeType[client][1] = GetGrenadeAmmo(client, Gren_Incen);
			 playerGrenadeType[client][2] = GetGrenadeAmmo(client, Gren_Molot);
			 playerGrenadeType[client][3] = GetGrenadeAmmo(client, Gren_M18);
			 playerGrenadeType[client][4] = GetGrenadeAmmo(client, Gren_Flash);
			 playerGrenadeType[client][5] = GetGrenadeAmmo(client, Gren_F1);
			 playerGrenadeType[client][6] = GetGrenadeAmmo(client, Gren_IED);
			 playerGrenadeType[client][7] = GetGrenadeAmmo(client, Gren_C4);
			 playerGrenadeType[client][8] = GetGrenadeAmmo(client, Gren_AT4);
			 playerGrenadeType[client][9] = GetGrenadeAmmo(client, Gren_RPG7);
		}
		*/
		//PrintToServer("G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i, G: %i",playerGrenadeType[client][0], playerGrenadeType[client][1], playerGrenadeType[client][2],playerGrenadeType[client][3],playerGrenadeType[client][4],playerGrenadeType[client][5],playerGrenadeType[client][6],playerGrenadeType[client][7],playerGrenadeType[client][8],playerGrenadeType[client][9]); 
	}
}

public Action:Event_PlayerReload_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new m_iTeam = GetClientTeam(client);

	if (IsFakeClient(client) && playerInRevivedState[client] == false) {
		return Plugin_Continue;
	}

	g_playerActiveWeapon[client] = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	
	// Call respawn timer
	//if (playerInRevivedState[client])
	//	CreateTimer(0.01, Timer_ForceReload, client, TIMER_REPEAT);
}
public Action:Event_OnFlashPlayerPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new m_iTeam = GetClientTeam(client);
	//Check if player is connected and is alive and player team is security
	if((IsClientConnected(client)) && (IsPlayerAlive(client)) && m_iTeam == TEAM_1_SEC)
	{
		//Get player the 4th gear item which is accessory (3rd offset with a DWORD(4 bytes))
		new nAccessoryItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 3));
		
		//If accessory is sunglasses item ID)
		if(nAccessoryItemID == g_nSunglasses_ID)
		{
			//Set player flash alpha (Which is the opacity)
			SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.5);
		}
	}
	
	return Plugin_Continue;
}
public Action:ResupplyListener(client, const String:cmd[], argc)
{
	//Get current client team
	new m_iTeam = GetClientTeam(client);
	
	//Check if player is connected and is alive and player team is security
	if((IsClientConnected(client)) && (IsPlayerAlive(client)) && m_iTeam == TEAM_1_SEC)
	{	

		//Set health 100 percent if resupplying
		new iHealth = GetClientHealth(client);
		if (iHealth < 100)
		{
			
			SetEntityHealth(client, 100);
			PrintHintText(client, "Wounds healed via resupply");
		}
		playerInRevivedState[client] = false;
	}
	
	
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
stock GetInsSpawnGround(spawnPoint, Float:vecSpawn[3])
{
    new Float:fGround[3];
    vecSpawn[2] += 15.0;
    
    TR_TraceRayFilter(vecSpawn, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TRDontHitSelf, spawnPoint);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        return fGround;
    }
    return vecSpawn;
}
stock GetClientGround(client)
{
    
    new Float:fOrigin[3], Float:fGround[3];
	GetClientAbsOrigin(client,fOrigin);

    fOrigin[2] += 15.0;
    
    TR_TraceRayFilter(fOrigin, Float:{90.0,0.0,0.0}, MASK_PLAYERSOLID, RayType_Infinite, TRDontHitSelf, client);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fGround);
        fOrigin[2] -= 15.0;
        return fGround[2];
    }
    return 0.0;
}
 
CheckSpawnPoint(Float:vecSpawn[3],client,Float:tObjectiveDistance,Int:m_nActivePushPointIndex) {
//Ins_InCounterAttack
	new m_iTeam = GetClientTeam(client);
	new Float:distance,Float:furthest,Float:closest=-1.0;
	new Float:vecOrigin[3];
	new Float:tBadPos[3];

	GetClientAbsOrigin(client,vecOrigin);
	new Float:tMinPlayerDistMult = 0;

	new acp = (Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex") - 1);
	new acp2 = m_nActivePushPointIndex;
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	if (acp == acp2 && !Ins_InCounterAttack())
	{
		tMinPlayerDistMult = g_flBackSpawnIncrease;
		//PrintToServer("INCREASE SPAWN DISTANCE | acp: %d acp2 %d", acp, acp2);
	}

	//Update player spawns before we check against them
	UpdatePlayerOrigins();
	//Lets go through checks to find a valid spawn point
	for (new iTarget = 1; iTarget < MaxClients; iTarget++) {
		if (!IsValidClient(iTarget))
			continue;
		if (!IsClientInGame(iTarget))
			continue;
		if (!IsPlayerAlive(iTarget)) 
			continue;
		new tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1_SEC)
			continue;
		////InsLog(DEBUG, "Distance from %N to iSpot %d is %f",iTarget,iSpot,distance);
		distance = GetVectorDistance(vecSpawn,g_vecOrigin[iTarget]);
		if (distance > furthest)
			furthest = distance;
		if ((distance < closest) || (closest < 0))
			closest = distance;
		
		if (GetClientTeam(iTarget) != m_iTeam) {
			// If we are too close
			if (distance < (g_flMinPlayerDistance + tMinPlayerDistMult)) {
				 return 0;
			}
			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) {
				return 0; 
			}
			//If any player is too far
			if (closest > g_flMaxPlayerDistance) {
				return 0; 
			}
			else if (closest > 2000 && g_cacheObjActive == 1 && Ins_InCounterAttack())
			{
				return 0; 
			}
		}
	}

	
	 	

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
	if (distance > (tObjectiveDistance) && (((acp+1) != ncp) || !Ins_InCounterAttack())) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
		 return 0;
	} 
	else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) && (((acp+1) != ncp) || !Ins_InCounterAttack())) {
		 return 0;
	}


			new fRandomInt = GetRandomInt(1, 100);
	//If final point respawn around last point, not final point
	if ((((acp+1) == ncp) || Ins_InCounterAttack()) && fRandomInt <= 10)
	{
		new m_nActivePushPointIndexFinal = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
		m_nActivePushPointIndexFinal -= 1;
		distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndexFinal]);
		if (distance > (tObjectiveDistance)) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
			 return 0;
		} 
		else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) {
			 return 0;
		}
	}
	//Check against bad spawn positions
	// if (Ins_InCounterAttack())
	// {
	// 	for (new client = 0; client < MaxClients; client++) {
	// 		if (!IsValidClient(client) || client <= 0)
	// 			continue;
	// 		if (!IsClientInGame(client))
	// 			continue;
	// 		if (g_badSpawnPos_Track[client][0] == 0 && g_badSpawnPos_Track[client][1] == 0 && g_badSpawnPos_Track[client][2] == 0)
	// 			continue;

	// 		int m_iTeam = GetClientTeam(client);
	// 		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
	// 		{
	// 			distance = GetVectorDistance(vecSpawn,g_badSpawnPos_Track[client]);

	// 			//GetArrayArray(g_badSpawnPos_Array, badPos, tBadPos, sizeof(tBadPos));

	// 			if (distance <= 240) {
	// 					PrintToServer("BAD POS DETECTED: (%f, %f, %f)", g_badSpawnPos_Track[client][0], g_badSpawnPos_Track[client][1], g_badSpawnPos_Track[client][2]);
	// 					return 0;
	// 				}
	// 		}

	// 	} 
	// }
	//Check distance to point in counterattack
	// if (Ins_InCounterAttack() || ((acp+1) == ncp)) {
	// 	new m_nActivePushPointIndex2 = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// 	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex2],m_nActivePushPointIndex2);
		
	// 	if ((acp+1) != ncp)
	// 		m_nActivePushPointIndex2 += 1;
	// 	else
	// 		m_nActivePushPointIndex2--;

	// 	distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex2]);

	// Get the number of control points
	// new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// // Get active push point
	// new acp3 = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// if (Ins_InCounterAttack() || ((acp3+1) == ncp)) {
	// 	if (distance < g_flMinCounterattackDistance) {
	// 		 return 0;
	// 	}
	// }
	// 	if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) || (fRandomFloat <= g_dynamicSpawnCounter_Perc)) {
	// 		 return 0;

	// 	}  
	//  	else if (distance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) {
	//  		 return 0;
	//  	}
	//  }		
	PrintToServer("CHECKSPAWN | m_nActivePushPointIndex: %d",m_nActivePushPointIndex);
	return 1;
} 
CheckSpawnPointPlayers(Float:vecSpawn[3],client, tObjectiveDistance) {
//Ins_InCounterAttack
	new m_iTeam = GetClientTeam(client);
	new Float:distance,Float:furthest,Float:closest=-1.0;
	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);
	//Update player spawns before we check against them
	UpdatePlayerOrigins();

	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	new Float:objDistance;
	
	//Lets go through checks to find a valid spawn point
	for (new iTarget = 1; iTarget < MaxClients; iTarget++) {
		if (!IsValidClient(iTarget))
			continue;
		if (!IsClientInGame(iTarget))
			continue;
		if (!IsPlayerAlive(iTarget)) 
			continue;
		new tTeam = GetClientTeam(iTarget);
		if (tTeam != TEAM_1_SEC)
			continue;

		m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");


		//If in counter 
		if (Ins_InCounterAttack() && m_nActivePushPointIndex > 0)
			m_nActivePushPointIndex -= 1;


	 	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);

		objDistance = GetVectorDistance(g_vecOrigin[iTarget],m_vCPPositions[m_nActivePushPointIndex]);
		distance = GetVectorDistance(vecSpawn,g_vecOrigin[iTarget]);
		if (distance > furthest)
			furthest = distance;
		if ((distance < closest) || (closest < 0))
			closest = distance;
		
		if (GetClientTeam(iTarget) != m_iTeam) {
			// If we are too close
			if (distance < g_flMinPlayerDistance) {
				 return 0;
			}
			new fRandomInt = GetRandomInt(1, 100);

			// If the player can see the spawn point (divided CanSeeVector to slightly reduce strictness)
			//(IsVectorInSightRange(iTarget, vecSpawn, 120.0)) ||  / g_flCanSeeVectorMultiplier
			if (ClientCanSeeVector(iTarget, vecSpawn, (g_flMinPlayerDistance * g_flCanSeeVectorMultiplier))) {
				return 0; 
			}

			//Check if players are getting close to point when assaulting
			if (objDistance < 2500 && fRandomInt < 30 && !Ins_InCounterAttack())
				return 0;
		}
	}


	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	//If any player is too far
	if (closest > g_flMaxPlayerDistance) {
		return 0; 
	}
	else if (closest > 2000 && g_cacheObjActive == 1 && Ins_InCounterAttack())
	{
		return 0; 
	}

	m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	new fRandomInt = GetRandomInt(1, 100);
	//Check against back spawn if in counter
	if (Ins_InCounterAttack() && m_nActivePushPointIndex > 0)
		m_nActivePushPointIndex -= 1;

	Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	objDistance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
	if (objDistance > (tObjectiveDistance) && (((acp+1) != ncp) || !Ins_InCounterAttack()) && fRandomInt < 25) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
		 return 0;
	} 
	else if (objDistance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult) && 
		(((acp+1) != ncp) || !Ins_InCounterAttack()) && fRandomInt < 25) {
		 return 0;
	}
	fRandomInt = GetRandomInt(1, 100);
	//If final point respawn around last point, not final point
	if ((((acp+1) == ncp) || Ins_InCounterAttack()) && fRandomInt < 25)
	{
		new m_nActivePushPointIndexFinal = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
		m_nActivePushPointIndexFinal -= 1;
		objDistance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndexFinal]);
		if (objDistance > (tObjectiveDistance)) {// && (fRandomFloat <= g_dynamicSpawn_Perc)) {
			 return 0;
		} 
		else 
		if (objDistance > (tObjectiveDistance * g_DynamicRespawn_Distance_mult)) {
			 return 0;
		}
	}

	//Check against bad spawn positions
	// if (Ins_InCounterAttack())
	// {
	// 	for (new client = 0; client < MaxClients; client++) {
	// 		if (!IsValidClient(client) || client <= 0)
	// 			continue;
	// 		if (!IsClientInGame(client))
	// 			continue;
	// 		if (g_badSpawnPos_Track[client][0] == 0 && g_badSpawnPos_Track[client][1] == 0 && g_badSpawnPos_Track[client][2] == 0)
	// 			continue;

	// 		int m_iTeam = GetClientTeam(client);
	// 		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
	// 		{
	// 			distance = GetVectorDistance(vecSpawn,g_badSpawnPos_Track[client]);

	// 			//GetArrayArray(g_badSpawnPos_Array, badPos, tBadPos, sizeof(tBadPos));

	// 			if (distance <= 240) {
	// 					PrintToServer("BAD POS DETECTED: (%f, %f, %f)", g_badSpawnPos_Track[client][0], g_badSpawnPos_Track[client][1], g_badSpawnPos_Track[client][2]);
	// 					return 0;
	// 				}
	// 		}

	// 	} 
	// }
		
		
	//  }
	return 1;
}

public GetPushPointIndex(Float:fRandomFloat, client)
{
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	//Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
	//new Float:distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
	//Check last point	
 		
	if (((acp+1) == ncp && Ins_InCounterAttack()) || g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc || (Ins_InCounterAttack()) || (m_nActivePushPointIndex > 1))
 	{
 		//PrintToServer("###POINT_MOD### | fRandomFloat: %f | g_dynamicSpawnCounter_Perc %f ",fRandomFloat, g_dynamicSpawnCounter_Perc);
 		if ((acp+1) == ncp && Ins_InCounterAttack())
 		{
 			if (g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc)
 				m_nActivePushPointIndex--;
 		}
 		else
 		{
	 		if (Ins_InCounterAttack() && (acp+1) != ncp)
	 		{
	 			if (fRandomFloat <= 0.5 && m_nActivePushPointIndex > 0)
	 				m_nActivePushPointIndex--;
	 			else
	 				m_nActivePushPointIndex++;
	 		}
	 		else if (!Ins_InCounterAttack())
	 		{
	 			if (m_nActivePushPointIndex > 0)
	 			{
	 				if (g_spawnFrandom[client] < g_dynamicSpawn_Perc)
	 					m_nActivePushPointIndex--;
	 			}
	 		}
	 	}

 	}
 	return m_nActivePushPointIndex;
	
}

float GetSpawnPoint_SpawnPoint(client) {
	int m_iTeam = GetClientTeam(client);
	int m_iTeamNum;
	float vecSpawn[3];
	float vecOrigin[3];
	float distance;
	GetClientAbsOrigin(client,vecOrigin);
	new Float:fRandomFloat = GetRandomFloat(0, 1.0);

	//PrintToServer("GetSpawnPoint_SpawnPoint Call");
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	if (((acp+1) == ncp) || (Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc) || (!Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawn_Perc && acp > 1))
		m_nActivePushPointIndex = GetPushPointIndex(fRandomFloat, client);

				
	new point = FindEntityByClassname(-1, "ins_spawnpoint");
	new Float:tObjectiveDistance = g_flMinObjectiveDistance;
	while (point != -1) {
		//m_iTeamNum = GetEntProp(point, Prop_Send, "m_iTeamNum");
		//if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
			Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
			distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance,m_nActivePushPointIndex)) {
				vecSpawn = GetInsSpawnGround(point, vecSpawn);
				//new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				PrintToServer("FOUND! m_nActivePushPointIndex: %d %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMinObjectiveDistance %f RAW ACP: %d",m_nActivePushPointIndex, client, client, point, distance, tObjectiveDistance, g_flMinObjectiveDistance, acp);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance += 4.0;
			}
		//}
		point = FindEntityByClassname(point, "ins_spawnpoint");
	}
	PrintToServer("1st Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	//Lets try again but wider range
	new point2 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 4);
	while (point2 != -1) {
		//m_iTeamNum = GetEntProp(point2, Prop_Send, "m_iTeamNum");
		//if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point2, Prop_Send, "m_vecOrigin", vecSpawn);

			Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
			distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance,m_nActivePushPointIndex)) {
				vecSpawn = GetInsSpawnGround(point2, vecSpawn);
				//new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				PrintToServer("FOUND! m_nActivePushPointIndex: %d %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMinObjectiveDistance %f RAW ACP: %d",m_nActivePushPointIndex, client, client, point2, distance, tObjectiveDistance, g_flMinObjectiveDistance, acp);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance += 4.0;
			}
		//}
		point2 = FindEntityByClassname(point2, "ins_spawnpoint");
	}
	PrintToServer("2nd Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	//Lets try again but wider range
	new point3 = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 10);
	while (point3 != -1) {
		//m_iTeamNum = GetEntProp(point3, Prop_Send, "m_iTeamNum");
		//if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(point3, Prop_Send, "m_vecOrigin", vecSpawn);
			Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
			distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance,m_nActivePushPointIndex)) {
				vecSpawn = GetInsSpawnGround(point3, vecSpawn);
				//new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				PrintToServer("FOUND! m_nActivePushPointIndex: %d %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMinObjectiveDistance %f RAW ACP: %d",m_nActivePushPointIndex, client, client, point3, distance, tObjectiveDistance, g_flMinObjectiveDistance, acp);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance += 4.0;
			}
		//}
		point3 = FindEntityByClassname(point3, "ins_spawnpoint");
	}
	PrintToServer("3rd Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	new pointFinal = FindEntityByClassname(-1, "ins_spawnpoint");
	tObjectiveDistance = ((g_flMinObjectiveDistance + 100) * 4);
	m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	//m_nActivePushPointIndex = GetPushPointIndex(fRandomFloat);
	if (m_nActivePushPointIndex > 1)
	{	
		if ((acp+1) >= ncp)
			m_nActivePushPointIndex--;
		else
			m_nActivePushPointIndex++;

	}
	while (pointFinal != -1) {
		//m_iTeamNum = GetEntProp(pointFinal, Prop_Send, "m_iTeamNum");
		//if (m_iTeamNum == m_iTeam) {
			GetEntPropVector(pointFinal, Prop_Send, "m_vecOrigin", vecSpawn);
			
			Ins_ObjectiveResource_GetPropVector("m_vCPPositions",m_vCPPositions[m_nActivePushPointIndex],m_nActivePushPointIndex);
			distance = GetVectorDistance(vecSpawn,m_vCPPositions[m_nActivePushPointIndex]);
			if (CheckSpawnPoint(vecSpawn,client,tObjectiveDistance,m_nActivePushPointIndex)) {
				vecSpawn = GetInsSpawnGround(pointFinal, vecSpawn);
				//new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
				PrintToServer("FINAL PASS FOUND! m_nActivePushPointIndex: %d %N (%d) spawnpoint %d Distance: %f tObjectiveDistance: %f g_flMinObjectiveDistance: %f RAW ACP: %d",m_nActivePushPointIndex, client, client, pointFinal, distance, tObjectiveDistance, g_flMinObjectiveDistance, acp);
				return vecSpawn;
			}
			else
			{
				tObjectiveDistance += 4.0;
			}
		//}
		pointFinal = FindEntityByClassname(pointFinal, "ins_spawnpoint");
	}
	PrintToServer("Final Pass: Could not find acceptable ins_spawnzone for %N (%d)", client, client);
	return vecOrigin;
}
float GetSpawnPoint(client) {
	new Float:vecSpawn[3];
/*
	if ((g_iHidingSpotCount) && (g_iSpawnMode == _:SpawnMode_HidingSpots)) {
		vecSpawn = GetSpawnPoint_HidingSpot(client);
	} else {
*/
	vecSpawn = GetSpawnPoint_SpawnPoint(client);
//	}
	//InsLog(DEBUG, "Could not find spawn point for %N (%d)", client, client);
	return vecSpawn;
}
//Lets begin to find a valid spawnpoint after spawned
public TeleportClient(client) {
	new Float:vecSpawn[3];
	vecSpawn = GetSpawnPoint(client);

	//decl FLoat:ClientGroundPos;
	//ClientGroundPos = GetClientGround(client);
	//vecSpawn[2] = ClientGroundPos;
	TeleportEntity(client, vecSpawn, NULL_VECTOR, NULL_VECTOR);
	SetNextAttack(client);
}
public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Redirect all bot spawns
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// new String:sNewNickname[64];
	// Format(sNewNickname, sizeof(sNewNickname), "%N", client);
	// if (StrEqual(sNewNickname, "[INS] RoundEnd Protector"))
	// 	return Plugin_Continue;
	
	if (client > 0 && IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			g_iPlayerRespawnTimerActive[client] = 0;
			
			//remove network ragdoll associated with player
			new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
			if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
				RemoveRagdoll(client);
			
			g_iHurtFatal[client] = 0;

		}
	}

	g_resupplyCounter[client] = GetConVarInt(sm_resupply_delay);
	//For first joining players 
	if (g_playerFirstJoin[client] == 1 && !IsFakeClient(client))
	{
		g_playerFirstJoin[client] = 0;
		// Get SteamID to verify is player has connected before.
		decl String:steamId[64];
		//GetClientAuthString(client, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		new isPlayerNew = FindStringInArray(g_playerArrayList, steamId);

		if (isPlayerNew == -1)
		{
			PushArrayString(g_playerArrayList, steamId);
			PrintToServer("SPAWN: Player %N is new! | SteamID: %s | PlayerArrayList Size: %d", client, steamId, GetArraySize(g_playerArrayList));
		}
	}
	if (!g_iCvar_respawn_enable) {
		return Plugin_Continue;
	}
	if (!IsClientConnected(client)) {
		return Plugin_Continue;
	}
	if (!IsClientInGame(client)) {
		return Plugin_Continue;
	}
	if (!IsValidClient(client)) {
		return Plugin_Continue;
	}
	if (!IsFakeClient(client)) {
		return Plugin_Continue;
	}
	if (g_isCheckpoint == 0) {
		return Plugin_Continue;
	}
	
	if ((StrContains(g_client_last_classstring[client], "juggernaut") > -1) && !Ins_InCounterAttack()) {
		 return Plugin_Handled;
	}
	
	//PrintToServer("Eventspawn Call");
	//Reset this global timer everytime a bot spawns
	g_botStaticGlobal[client] = 0;

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	new Float:vecOrigin[3];
	GetClientAbsOrigin(client,vecOrigin);

	if  (g_playersReady && g_botsReady == 1)
	{
		int m_iTeam = GetClientTeam(client);
		int m_iTeamNum;
		float vecSpawn[3];
		float vecOrigin[3];
		GetClientAbsOrigin(client,vecOrigin);
					
		new point = FindEntityByClassname(-1, "ins_spawnpoint");
		new Float:tObjectiveDistance = g_flMinObjectiveDistance;
		int iCanSpawn = CheckSpawnPointPlayers(vecOrigin,client, tObjectiveDistance);
		while (point != -1) {
			//m_iTeamNum = GetEntProp(point, Prop_Send, "m_iTeamNum");
			//if (m_iTeamNum == m_iTeam) {
				GetEntPropVector(point, Prop_Send, "m_vecOrigin", vecSpawn);
				iCanSpawn = CheckSpawnPointPlayers(vecOrigin,client, tObjectiveDistance);
				if (iCanSpawn == 1) {
					break;
				}
				else
				{
					tObjectiveDistance += 6.0;
				}
			//}
			point = FindEntityByClassname(point, "ins_spawnpoint");
		}
		//Global random for spawning
		g_spawnFrandom[client] = GetRandomInt(0, 100);
		//InsLog(DEBUG, "Event_Spawn iCanSpawn %d", iCanSpawn);
		if (iCanSpawn == 0 || (Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawnCounter_Perc) || 
			(!Ins_InCounterAttack() && g_spawnFrandom[client] < g_dynamicSpawn_Perc && acp > 1)) {
			//PrintToServer("TeleportClient Call");
			TeleportClient(client);
			if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && IsClientConnected(client))
			{
				StuckCheck[client] = 0;
				StartStuckDetection(client);
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_SpawnPost(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	////InsLog(DEBUG, "Event_Spawn called");
	// new String:sNewNickname[64];
	// Format(sNewNickname, sizeof(sNewNickname), "%N", client);
	// if (StrEqual(sNewNickname, "[INS] RoundEnd Protector"))
	// 	return Plugin_Continue;


	//Bots only below this
	if (!IsFakeClient(client)) {
		return Plugin_Continue;
	}
	SetNextAttack(client);
	//new Float:fRandom = GetRandomFloat(0.0, 1.0);
	new fRandom = GetRandomInt(1, 100);
	//Check grenades
	if (fRandom < g_removeBotGrenadeChance && !Ins_InCounterAttack())
	{
		new botGrenades = GetPlayerWeaponSlot(client, 3);
		if (botGrenades != -1 && IsValidEntity(botGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
		{
			while (botGrenades != -1 && IsValidEntity(botGrenades)) // since we only have 3 slots in current theate
			{
				botGrenades = GetPlayerWeaponSlot(client, 3);
				if (botGrenades != -1 && IsValidEntity(botGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
				{
					// Remove grenades but not pistols
					decl String:weapon[32];
					GetEntityClassname(botGrenades, weapon, sizeof(weapon));
					RemovePlayerItem(client,botGrenades);
					AcceptEntityInput(botGrenades, "kill");
				}
			}
		}
	}
	if (!g_iCvar_respawn_enable) {
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public UpdatePlayerOrigins() {
	for (new i = 1; i < MaxClients; i++) {
		if (IsValidClient(i)) {
			GetClientAbsOrigin(i,g_vecOrigin[i]);
		}
	}
}
//This delays bot from attacking once spawned
SetNextAttack(client) {
	float flTime = GetGameTime();
	float flDelay = g_flSpawnAttackDelay;

// Loop through entries in m_hMyWeapons.
	for(new offset = 0; offset < 128; offset += 4) {
		new weapon = GetEntDataEnt2(client, m_hMyWeapons + offset);
		if (weapon < 0) {
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


/*
#####################################################################
# NAV MESH BOT SPAWNS FUNCTIONS START ###############################
# NAV MESH BOT SPAWNS FUNCTIONS START ###############################
#####################################################################
*/

/*
// Check whether current bot position or given hiding point is best position to spawn
int CheckHidingSpotRules(m_nActivePushPointIndex, iCPHIndex, iSpot, client)
{
	// Get Team
	new m_iTeam = GetClientTeam(client);
	
	// Init variables
	new Float:distance,Float:furthest,Float:closest=-1.0,Float:flHidingSpot[3];
	new Float:vecOrigin[3];
	new needSpawn = 0;
	
	// Get current position
	GetClientAbsOrigin(client,vecOrigin);
	
	// Get current hiding point
	flHidingSpot[0] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_X);
	flHidingSpot[1] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Y);
	flHidingSpot[2] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Z);
	// new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// distance = GetVectorDistance(flHidingSpot,m_vCPPositions[m_nActivePushPointIndex]);
	// if (distance > g_flMaxObjectiveDistanceNav) {
	// 	return 0;
	// } 
	// Check players
	for (new iTarget = 1; iTarget < MaxClients; iTarget++)
	{
		if (!IsClientInGame(iTarget) || !IsClientConnected(iTarget))
			continue;
		
		// Get distance from player
		distance = GetVectorDistance(flHidingSpot,g_fPlayerPosition[iTarget]);
		//PrintToServer("[BOTSPAWNS] Distance from %N to iSpot %d is %f",iTarget,iSpot,distance);
		
		// Check distance from player
		if (GetClientTeam(iTarget) != m_iTeam)
		{
			// If player is furthest, update furthest variable
			if (distance > furthest)
				furthest = distance;
			
			// If player is closest, update closest variable
			if ((distance < closest) || (closest < 0))
				closest = distance;
			// If any player is close enough to telefrag
			// if (distance < g_flMinPlayerDistance) {
			// 	 //PrintToServer("DEBUG 1"); return 0;
			// }
			// If the distance is shorter than cvarMinPlayerDistance
			//(IsVectorInSightRange(iTarget, flHidingSpot, 120.0, g_flMinPlayerDistance)) || 
			if (((ClientCanSeeVector(iTarget, flHidingSpot, (g_flMaxPlayerDistance)))))
			{
				//PrintToServer("[BOTSPAWNS] Cannot spawn %N at iSpot %d since it is in sight of %N",client,iSpot,iTarget);
				return 0;
			}
		}
	}
	
	// If closest player is further than cvarMaxPlayerDistance
	if (closest > g_flMaxPlayerDistance)
	{
		//PrintToServer("[BOTSPAWNS] iSpot %d is too far from nearest player distance %f",iSpot,closest);
		return 0;
	}
	
	
	// During counter attack
	// if (Ins_InCounterAttack()) {
	// 	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// 	distance = GetVectorDistance(flHidingSpot,m_vCPPositions[m_nActivePushPointIndex]);
	// 	if (distance < g_flMinCounterattackDistance) {
	// 		return 0;
	// 	}
		
	// }
	
	// Current hiding point is the best place
	//distance = GetVectorDistance(flHidingSpot,vecOrigin);
	//PrintToServer("[BOTSPAWNS] Selected spot for %N, iCPHIndex %d iSpot %d distance %f",client,iCPHIndex,iSpot,distance);
	return 1;
}

// Get best hiding spot
int GetBestHidingSpot(client, iteration=0)
{
	// Refrash players position
	UpdatePlayerOrigins();
	
	// Get current push point
	new m_nActivePushPointIndex = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	// If current push point is not available return -1
	if (m_nActivePushPointIndex < 0) return -1;
	
	// Set minimum hiding point index
	new minidx = (iteration) ? 0 : g_iCPLastHidingSpot[m_nActivePushPointIndex];
	
	// Set maximum hiding point index
	new maxidx = (iteration) ? g_iCPLastHidingSpot[m_nActivePushPointIndex] : g_iCPHidingSpotCount[m_nActivePushPointIndex];
	
	// Loop hiding point index
	for (new iCPHIndex = minidx; iCPHIndex < maxidx; iCPHIndex++)
	{
		// Check given hiding point is best point
		new iSpot = g_iCPHidingSpots[m_nActivePushPointIndex][iCPHIndex];
		if (CheckHidingSpotRules(m_nActivePushPointIndex,iCPHIndex,iSpot,client))
		{
			// Update last hiding spot
			g_iCPLastHidingSpot[m_nActivePushPointIndex] = iCPHIndex;
			return iSpot;
		}
	}
	
	// If this call is iteration and couldn't find hiding spot, return -1
	if (iteration)
		return -1;
	
	// If this call is the first try, call again
	//return GetBestHidingSpot(client,1);
	return -1;
}
*/

/*
#####################################################################
# NAV MESH BOT SPAWNS FUNCTIONS END #################################
# NAV MESH BOT SPAWNS FUNCTIONS END #################################
#####################################################################
*/

// When player connected server, intialize variable
public OnClientPutInServer(client)
{
		g_trackKillDeaths[client] = 0;
		playerPickSquad[client] = 0;
		g_iHurtFatal[client] = -1;
		g_playerFirstJoin[client] = 1;
		g_iPlayerRespawnTimerActive[client] = 0;
	
	//SDKHook(client, SDKHook_PreThinkPost, SHook_OnPreThink);
	new String:sNickname[64];
	Format(sNickname, sizeof(sNickname), "%N", client);
	g_client_org_nickname[client] = sNickname;
}

public OnClientDisconnect(client)
{
	if(client == g_nVIP_ID)
	{
		g_nVIP_ID = 0;
	}
}

// When player connected server, intialize variables
public Action:Event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
		playerPickSquad[client] = 0;
		g_iHurtFatal[client] = -1;
		g_playerFirstJoin[client] = 1;
		g_iPlayerRespawnTimerActive[client] = 0;
		
	
	//g_fPlayerLastChat[client] = GetGameTime();
	
	//Update RespawnCvars when players join
	UpdateRespawnCvars();
}

// When player disconnected server, intialize variables
public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		g_squadSpawnEnabled[client] = 0;
		playerPickSquad[client] = 0;
		// Reset player status
		g_client_last_classstring[client] = ""; //reset his class model
		// Remove network ragdoll associated with player
		new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if (playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);
		
		// Update cvar
		UpdateRespawnCvars();
	}


	g_LastButtons[client] = 0;

	return Plugin_Continue;
}

// When round starts, intialize variables
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{

	//Reset VIP objective count
	g_vip_obj_count = g_iCvar_vip_obj_time;
	g_vip_obj_ready = 1;

	int tsupply_base = 2;
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	tsupply_base += (ncp * 2);
	new Handle:hSupplyBase = FindConVar("mp_supply_token_base");
	SetConVarInt(hSupplyBase, tsupply_base, true, false);
	//Clear bad spawn array
	//ClearArray(g_badSpawnPos_Array);

	//Round_Start CVAR Sets ------------------ START -- vs using HookConVarChange

	//Show scoreboard when dead DISABLED
	new cvar_scoreboard = FindConVar("sv_hud_scoreboard_show_score_dead");
	SetConVarInt(cvar_scoreboard, 0, true, false);


	// Respawn delay for team ins
	g_fCvar_respawn_delay_team_ins = GetConVarFloat(sm_respawn_delay_team_ins);
	g_fCvar_respawn_delay_team_ins_spec = GetConVarFloat(sm_respawn_delay_team_ins_special);

	g_AIDir_TeamStatus = 50;
	g_AIDir_BotReinforceTriggered = false;

	g_iReinforceTime = GetConVarInt(sm_respawn_reinforce_time);

	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);

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
	new Handle:hCvar = INVALID_HANDLE;
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, -1);
	
	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();
	
	//Hunt specific
	if (g_isHunt == 1)
	{
		g_iReinforceTime = (g_iReinforceTime * g_iReinforce_Mult) + g_iReinforce_Mult_Base;
	}

	// Check gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	//PrintToServer("[REVIVE_DEBUG] ROUND STARTED");
	
	// Warming up revive
	g_iEnableRevive = 0;
	new iPreRoundFirst = GetConVarInt(FindConVar("mp_timer_preround_first"));
	new iPreRound = GetConVarInt(FindConVar("mp_timer_preround"));
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

	if (g_easterEggRound == true)
	{
		PrintToChatAll("************EASTER EGG ROUND************");
		PrintToChatAll("******NO WHINING, BE NICE, HAVE FUN*****");
		PrintToChatAll("******MAX ROUNDS CHANGED TO 2!**********");
		PrintToChatAll("******WORK TOGETHER, ADAPT!*************");
		PrintToChatAll("************EASTER EGG ROUND************");
	}
	return Plugin_Continue;
}

void SecTeamLivesBonus()
{
	new secTeamCount = GetTeamSecCount();
	if (secTeamCount <= 9)
	{
		g_iRespawnCount[2] += 1;
	}
	//else if (secTeamCount >= 10 && secTeamCount <= 14)
	//{
	//	g_iRespawnCount[2] += 1;
	//}
}

//Adjust Lives Per Point Based On Players
void SecDynLivesPerPoint()
{
	new secTeamCount = GetTeamSecCount();
	if (secTeamCount <= 9)
	{
		g_iRespawnCount[2] += 1;
	}
}

// Round starts
public Action:PreReviveTimer(Handle:Timer)
{
	//h_PreReviveTimer = INVALID_HANDLE;
	//PrintToServer("ROUND STATUS AND REVIVE ENABLED********************");
	g_iRoundStatus = 1;
	g_iEnableRevive = 1;
	
	// Update remaining life cvar
	new Handle:hCvar = INVALID_HANDLE;
	new iRemainingLife = GetRemainingLife();
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, iRemainingLife);
}
// Botspawn trigger
public Action:BotsReady_Timer(Handle:Timer)
{
	//h_PreReviveTimer = INVALID_HANDLE;
	//PrintToServer("ROUND STATUS AND REVIVE ENABLED********************");
	g_botsReady = 1;
}
// When round ends, intialize variables
public Action:Event_RoundEnd_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Reset VIP objective count
	g_vip_obj_count = g_iCvar_vip_obj_time;
	g_vip_obj_ready = 1;

	//Show scoreboard when dead ENABLED
	new cvar_scoreboard = FindConVar("sv_hud_scoreboard_show_score_dead");
	SetConVarInt(cvar_scoreboard, 1, true, false);


	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
			continue;
		if (!IsClientInGame(client))
			continue;
		if (IsFakeClient(client))
			continue;
		new tTeam = GetClientTeam(client);
		if (tTeam != TEAM_1_SEC)
			continue;
		//if ((g_iStatRevives[client] > 0 || g_iStatHeals[client] > 0) && StrContains(g_client_last_classstring[client], "medic") > -1)
		//{
			//decl String:sBuf[255];
			// Hint to iMedic
			//Format(sBuf, 255,"[MEDIC STATS] for %N: HEALS: %d | REVIVES: %d", client, g_iStatHeals[client], g_iStatRevives[client]);
			//PrintHintText(client, "%s", sBuf);
			//PrintToChatAll("%s", sBuf);
		//}

		playerInRevivedState[client] = false;
	}
	// Stop counter-attack music
	//StopCounterAttackMusic();

	//Reset Variables
	g_removeBotGrenadeChance = 50;
}

// When round ends, intialize variables
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Set client command for round end music
	// int iWinner = GetEventInt(event, "winner");
	// decl String:sMusicCommand[128];
	// if (iWinner == TEAM_1_SEC)
	// 	Format(sMusicCommand, sizeof(sMusicCommand), "playgamesound Music.WonGame_Security");
	// else
	// 	Format(sMusicCommand, sizeof(sMusicCommand), "playgamesound Music.LostGame_Insurgents");
	
	// // Play round end music
	// for (int i = 1; i <= MaxClients; i++)
	// {
	// 	if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
	// 	{
	// 		ClientCommand(i, "%s", sMusicCommand);
	// 	}
	// }
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
	new Handle:hCvar = INVALID_HANDLE;
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, -1);
	
	//PrintToServer("[REVIVE_DEBUG] ROUND ENDED");	
	// Cooldown revive
	g_iEnableRevive = 0;
	g_iRoundStatus = 0;
	g_botsReady = 0;
	
	// Reset respawn token
	ResetInsurgencyLives();
	ResetSecurityLives();
	
	//Reset new spawn system bot count
	g_maxbots_std = 0;
	g_maxbots_light = 0;
	g_maxbots_jug = 0;
	g_maxbots_bomb = 0;

	g_bots_std = 0;
	g_bots_light = 0;
	g_bots_jug = 0;
	g_bots_bomb = 0;
	////////////////////////
	// Rank System
	// if (g_hDB != INVALID_HANDLE)
	// {
	// 	for (new client=1; client<=MaxClients; client++)
	// 	{
	// 		if (IsClientInGame(client))
	// 		{
	// 			saveUser(client);
	// 			CreateTimer(0.5, Timer_GetMyRank, client);
	// 		}
	// 	}
	// }
	////////////////////////

	//Lua Healing kill sound
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "healthkit")) > MaxClients && IsValidEntity(ent))
	{
		StopSound(ent, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		PrintToServer("KILL HEALTHKITS");
		AcceptEntityInput(ent, "Kill");
	}

}

// Check occouring counter attack when control point captured
public Action:Event_ControlPointCaptured_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Clear bad spawn array
	//ClearArray(g_badSpawnPos_Array);
	for (new client = 0; client < MaxClients; client++) {
		if (!IsValidClient(client) || client <= 0)
				continue;
		if (!IsClientInGame(client))
			continue;
		int m_iTeam = GetClientTeam(client);
		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
		{
			g_badSpawnPos_Track[client][0] = 0;
			g_badSpawnPos_Track[client][1] = 0;
			g_badSpawnPos_Track[client][2] = 0;
		}
	} 

	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost) return Plugin_Continue;

	
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	//AI Director Status ###START###
	new secTeamCount = GetTeamSecCount();
	new secTeamAliveCount = Team_CountAlivePlayers(TEAM_1_SEC);

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


	// Get gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	// Init variables
	new Handle:cvar;
	
	// Set minimum and maximum counter attack duration tim
	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	new final_ca_dur = GetConVarInt(sm_respawn_final_counter_dur_sec);

	// Get random duration
	new fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	new fRandomIntCounterLarge = GetRandomInt(1, 100);
	new largeCounterEnabled = false;
	if (fRandomIntCounterLarge <= 15)
	{
		fRandomInt = (fRandomInt * 2);
		new fRandomInt2 = GetRandomInt(60, 90);
		final_ca_dur = (final_ca_dur + fRandomInt2);
		largeCounterEnabled = true;
		
	}
	// Set counter attack duration to server
	new Handle:cvar_ca_dur;
	


	// Final counter attack
	if ((acp+1) == ncp)
	{
		g_iRemaining_lives_team_ins = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i > 0 && IsClientInGame(i) && IsClientConnected(i))
			{
				if(IsFakeClient(i))
					ForcePlayerSuicide(i);
			}
		}
		
		//g_AIDir_TeamStatus -= 10;

		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		SetConVarInt(cvar_ca_dur, final_ca_dur, true, false);
		g_dynamicSpawnCounter_Perc += 10;

		if (g_finale_counter_spec_enabled == 1)
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;

		//If endless spawning on final counter attack, add lives on finale counter on a delay
		if (g_iCvar_final_counterattack_type == 2)
		{
			new tCvar_CounterDelayValue = GetConVarInt(FindConVar("mp_checkpoint_counterattack_delay_finale"));
			CreateTimer((tCvar_CounterDelayValue), Timer_FinaleCounterAssignLives, _);
		}
	}
	// Normal counter attack
	else
	{
		g_AIDir_TeamStatus -= 5;

		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		SetConVarInt(cvar_ca_dur, fRandomInt, true, false);
	}
	
	
	// Get ramdom value for occuring counter attack
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	PrintToServer("Counter Chance = %f", g_respawn_counter_chance);
	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && g_isCheckpoint == 1 && ((acp+1) != ncp))
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER YES");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		if (largeCounterEnabled)
		{
			PrintHintTextToAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
			PrintToChatAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
		}


		g_AIDir_TeamStatus -= 5;
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer((cvar_ca_dur + 1), Timer_CounterAttackEnd, _);

		if (g_elite_counter_attacks == 1)
		{
			EnableDisableEliteBotCvars(1, 0);
			new tCvar = FindConVar("ins_bot_count_checkpoint_max");
			new tCvarIntValue = GetConVarInt(FindConVar("ins_bot_count_checkpoint_max"));
			tCvarIntValue += 3;
			SetConVarInt(tCvar, tCvarIntValue, true, false);
		}
	}
	// If last capture point
	else if (g_isCheckpoint == 1 && ((acp+1) == ncp))
	{
		cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer((cvar_ca_dur + 1), Timer_CounterAttackEnd, _);

		if (g_elite_counter_attacks == 1)
		{
			EnableDisableEliteBotCvars(1, 1);
			new tCvar = FindConVar("ins_bot_count_checkpoint_max");
			new tCvarIntValue = GetConVarInt(FindConVar("ins_bot_count_checkpoint_max"));
			tCvarIntValue += 3;
			SetConVarInt(tCvar, tCvarIntValue, true, false);
		}
	}
	// Not occurs counter attack
	else
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER NO");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 1, true, false);
	}
	
	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

	return Plugin_Continue;
}

// Play music during counter-attack
public Action:Timer_CounterAttackSound(Handle:event)
{
	if (g_iRoundStatus == 0 || !Ins_InCounterAttack())
		return;
	
	// Play music
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			//ClientCommand(i, "playgamesound Music.StartCounterAttack");
			//ClientCommand(i, "play *cues/INS_GameMusic_AboutToAttack_A.ogg");
		}
	}
	
	// Loop
	//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
}

// When control point captured, reset variables
public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue;

	g_cacheObjActive = 0;
	// If VIP capped, reward team with supply points
	decl String:cappers[512];
	GetEventString(event, "cappers", cappers, sizeof(cappers));
	new cappersLength = strlen(cappers);
	if (g_vip_enable)
	{
		for (new i = 0 ; i < cappersLength; i++)
		{
			new clientCapper = cappers[i];
			if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && 
				IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper) && 
				(StrContains(g_client_last_classstring[clientCapper], "vip") > -1) && g_vip_obj_count > 0)
			{
					//Reward team with tokens (credits to INS server)
					ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
					new nMaxSupply = GetConVarInt(cvar_tokenmax);
					//Determine reward
					new nRandSupplyReward = GetRandomInt(g_iCvar_vip_min_sp_reward, g_iCvar_vip_max_sp_reward);

					for(new client = 1; client <= MaxClients; client++)
					{
						//new nCurrentPlayerTeam = GetClientTeam(client);
						if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
						{
							int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
							int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
							
							if(nSupplyPoint <= nMaxSupply)
							{
								
								nSupplyPoint += nRandSupplyReward;
								nAvailableSupplyPoint += nRandSupplyReward;
								PrintToChat(client, "VIP has captured point\nYou have received %i supply point(s) as reward", nRandSupplyReward);
							}

							//Set client nSupplyPoint
							SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
							SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
						}
					}
				
					break;
			}
		}
	}
	// Reset reinforcement time
	g_iReinforceTime = g_iReinforceTime_AD_Temp;
	
	// Reset respawn tokens
	ResetInsurgencyLives();
	if (g_iCvar_respawn_reset_type && g_isCheckpoint)
		ResetSecurityLives();

	//PrintToServer("CONTROL POINT CAPTURED");
	
	return Plugin_Continue;
}

// When control point captured, update respawn point and respawn all players
public Action:Event_ControlPointCaptured_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue; 
	
	if (GetConVarInt(sm_respawn_security_on_counter) == 1) //Test with Ins_InCounterAttack() later
	{
		// Get client who captured control point.
		decl String:cappers[512];
		GetEventString(event, "cappers", cappers, sizeof(cappers));
		new cappersLength = strlen(cappers);
		for (new i = 0 ; i < cappersLength; i++)
		{
			new clientCapper = cappers[i];
			if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper))
			{
				// Get player's position
				new Float:capperPos[3];
				GetClientAbsOrigin(clientCapper, Float:capperPos);
				
				// Update respawn position
				g_fRespawnPosition = capperPos;
				
				break;
			}
		}

		// Respawn all players
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				new Float:clientPos[3];
				GetClientAbsOrigin(client, Float:clientPos);
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
	// //Elite Bots Reset
	// if (g_elite_counter_attacks == 1)
	// 	CreateTimer(5.0, Timer_EliteBots);

	
	// Update cvars
	UpdateRespawnCvars();


	//Reset security team wave counter
	g_secWave_Timer = g_iRespawnSeconds;
	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// If last capture point
	if (g_isCheckpoint == 1 && ((acp+1) == ncp))
	{
		g_secWave_Timer = g_iRespawnSeconds;
		g_secWave_Timer += (GetTeamSecCount() * 4);
	}
	else if (Ins_InCounterAttack())
		g_secWave_Timer += (GetTeamSecCount() * 3);

	//Reset VIP Objective counter
	g_vip_obj_count = g_iCvar_vip_obj_time;
	g_vip_obj_ready = 1;
	
	return Plugin_Continue;
}


// When ammo cache destroyed, update respawn position and reset variables
public Action:Event_ObjectDestroyed_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{


	//Clear bad spawn array
	//ClearArray(g_badSpawnPos_Array);
	for (new client = 0; client < MaxClients; client++) {
		if (!IsValidClient(client) || client <= 0)
				continue;
		if (!IsClientInGame(client))
			continue;
		int m_iTeam = GetClientTeam(client);
		if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
		{
			g_badSpawnPos_Track[client][0] = 0;
			g_badSpawnPos_Track[client][1] = 0;
			g_badSpawnPos_Track[client][2] = 0;
		}
	} 

	g_checkStaticAmt = GetConVarInt(sm_respawn_check_static_enemy);
	g_checkStaticAmtCntr = GetConVarInt(sm_respawn_check_static_enemy_counter);
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue;


	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	//AI Director Status ###START###
	new secTeamCount = GetTeamSecCount();
	new secTeamAliveCount = Team_CountAlivePlayers(TEAM_1_SEC);

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
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	// Init variables
	new Handle:cvar;
	
	// Set minimum and maximum counter attack duration tim
	g_counterAttack_min_dur_sec = GetConVarInt(sm_respawn_min_counter_dur_sec);
	g_counterAttack_max_dur_sec = GetConVarInt(sm_respawn_max_counter_dur_sec);
	new final_ca_dur = GetConVarInt(sm_respawn_final_counter_dur_sec);

	// Get random duration
	new fRandomInt = GetRandomInt(g_counterAttack_min_dur_sec, g_counterAttack_max_dur_sec);
	new fRandomIntCounterLarge = GetRandomInt(1, 100);
	new largeCounterEnabled = false;
	if (fRandomIntCounterLarge <= 15)
	{
		fRandomInt = (fRandomInt * 2);
		new fRandomInt2 = GetRandomInt(90, 180);
		final_ca_dur = (final_ca_dur + fRandomInt2);
		largeCounterEnabled = true;
	}
	// Set counter attack duration to server
	new Handle:cvar_ca_dur;
	
	// Final counter attack
	if ((acp+1) == ncp)
	{
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration_finale");
		SetConVarInt(cvar_ca_dur, final_ca_dur, true, false);
		g_dynamicSpawnCounter_Perc += 10;
		//g_AIDir_TeamStatus -= 10;

		if (g_finale_counter_spec_enabled == 1)
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;
	}
	// Normal counter attack
	else
	{
		g_AIDir_TeamStatus -= 5;
		cvar_ca_dur = FindConVar("mp_checkpoint_counterattack_duration");
		SetConVarInt(cvar_ca_dur, fRandomInt, true, false);
	}
	
	//Are we using vanilla counter attack?
	if (g_iCvar_counterattack_vanilla == 1) return Plugin_Continue;

	// Get ramdom value for occuring counter attack
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	PrintToServer("Counter Chance = %f", g_respawn_counter_chance);
	// Occurs counter attack
	if (fRandom < g_respawn_counter_chance && g_isCheckpoint && ((acp+1) != ncp))
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER YES");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		if (largeCounterEnabled)
		{
			PrintHintTextToAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
			PrintToChatAll("[INTEL]: Enemy forces are sending a large counter-attack your way!  Get ready to defend!");
		}
		g_AIDir_TeamStatus -= 5;
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);

		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer((cvar_ca_dur + 1), Timer_CounterAttackEnd, _);

		if (g_elite_counter_attacks == 1)
		{
			EnableDisableEliteBotCvars(1, 0);
			new tCvar = FindConVar("ins_bot_count_checkpoint_max");
			new tCvarIntValue = GetConVarInt(FindConVar("ins_bot_count_checkpoint_max"));
			tCvarIntValue += 3;
			SetConVarInt(tCvar, tCvarIntValue, true, false);
		}
	}
	// If last capture point
	else if (g_isCheckpoint == 1 && ((acp+1) == ncp))
	{
		cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 0, true, false);
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 1, true, false);
		
		// Call music timer
		//CreateTimer(COUNTER_ATTACK_MUSIC_DURATION, Timer_CounterAttackSound);
		
		//Create Counter End Timer
		g_isEliteCounter = 1;
		CreateTimer((cvar_ca_dur + 1), Timer_CounterAttackEnd, _);

		if (g_elite_counter_attacks == 1)
		{
			EnableDisableEliteBotCvars(1, 1);
			new tCvar = FindConVar("ins_bot_count_checkpoint_max");
			new tCvarIntValue = GetConVarInt(FindConVar("ins_bot_count_checkpoint_max"));
			tCvarIntValue += 3;
			SetConVarInt(tCvar, tCvarIntValue, true, false);
		}
	}
	// Not occurs counter attack
	else
	{
		cvar = INVALID_HANDLE;
		//PrintToServer("COUNTER NO");
		cvar = FindConVar("mp_checkpoint_counterattack_disable");
		SetConVarInt(cvar, 1, true, false);
	}

	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

	return Plugin_Continue;
}

// When ammo cache destroyed, update respawn position and reset variables
public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_isHunt == 1)
	{
		g_huntCacheDestroyed = true;
		//g_iReinforceTime = g_iReinforceTime + g_huntReinforceCacheAdd;
		PrintHintTextToAll("Cache destroyed! Kill all enemies and reinforcements to win!");
		PrintToChatAll("Cache destroyed! Kill all enemies and reinforcements to win!");
		
	}
	// Checkpoint
	if (g_isCheckpoint == 1)
	{

		g_cacheObjActive = 1;
		// If VIP capped, reward team with supply points
		decl String:cappers[512];
		GetEventString(event, "cappers", cappers, sizeof(cappers));
		new cappersLength = strlen(cappers);
		if (g_vip_enable)
		{
			for (new i = 0 ; i < cappersLength; i++)
			{
				new clientCapper = cappers[i];
				if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && 
					IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper) && 
					(StrContains(g_client_last_classstring[clientCapper], "vip") > -1) && g_vip_obj_count > 0)
				{
						//Reward team with tokens (credits to INS server)
						ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
						new nMaxSupply = GetConVarInt(cvar_tokenmax);
						//Determine reward
						new nRandSupplyReward = GetRandomInt(g_iCvar_vip_min_sp_reward, g_iCvar_vip_max_sp_reward);

						for(new client = 1; client <= MaxClients; client++)
						{
							//new nCurrentPlayerTeam = GetClientTeam(client);
							if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
							{
								int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
								int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
								
								if(nSupplyPoint <= nMaxSupply)
								{
									
									nSupplyPoint += nRandSupplyReward;
									nAvailableSupplyPoint += nRandSupplyReward;
									PrintToChat(client, "VIP has destroyed point\nYou have received %i supply point(s) as reward", nRandSupplyReward);
								}

								//Set client nSupplyPoint
								SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
								SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
							}
						}
					
						break;
				}
			}
		}
		// Update respawn position
		new attacker = GetEventInt(event, "attacker");
		new assister = GetEventInt(event, "assister");

		if (attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker) || assister > 0 && IsClientInGame(assister) && IsClientConnected(assister))
		{
			new Float:attackerPos[3];
			GetClientAbsOrigin(attacker, Float:attackerPos);
			g_fRespawnPosition = attackerPos;
			if (g_vip_enable)
			{
				if(attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker) && 
					IsPlayerAlive(attacker) && !IsFakeClient(attacker) && 
					(StrContains(g_client_last_classstring[attacker], "vip") > -1) && g_vip_obj_count > 0 || assister > 0 && IsClientInGame(assister) && IsClientConnected(assister) && 
					IsPlayerAlive(assister) && !IsFakeClient(assister) && 
					(StrContains(g_client_last_classstring[assister], "vip") > -1) && g_vip_obj_count > 0)
				{
					//Reward team with tokens (credits to INS server)
					ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
					new nMaxSupply = GetConVarInt(cvar_tokenmax);
					//Determine reward
					new nRandSupplyReward = GetRandomInt(g_iCvar_vip_min_sp_reward, g_iCvar_vip_max_sp_reward);

					for(new client = 1; client <= MaxClients; client++)
					{
						//new nCurrentPlayerTeam = GetClientTeam(client);
						if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
						{
							int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
							int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
							
							if(nSupplyPoint <= nMaxSupply)
							{
								
								nSupplyPoint += nRandSupplyReward;
								nAvailableSupplyPoint += nRandSupplyReward;
								PrintToChat(client, "VIP has destroyed point\nYou have received %i supply point(s) as reward", nRandSupplyReward);
							}

							//Set client nSupplyPoint
							SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
							SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
						}
					}
					
				}
				
			}
		}
		
		// Reset reinforcement time
		g_iReinforceTime = g_iReinforceTime_AD_Temp;
		
		// Reset respawn token
		ResetInsurgencyLives();
		if (g_iCvar_respawn_reset_type && g_isCheckpoint)
			ResetSecurityLives();
	}
	
	// Conquer, Respawn all players
	else if (g_isConquer == 1 || g_isHunt == 1)
	{
		for (new client = 1; client <= MaxClients; client++)
		{	
			if (IsClientConnected(client) && !IsFakeClient(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				if(IsClientInGame(client) && !IsClientTimingOut(client) && playerPickSquad[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1_SEC)
				{
					CreateCounterRespawnTimer(client);
				}
			}
		}
	}
	
	return Plugin_Continue;
}
// When control point captured, update respawn point and respawn all players
public Action:Event_ObjectDestroyed_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Return if conquer
	if (g_isConquer == 1 || g_isHunt == 1 || g_isOutpost == 1) return Plugin_Continue; 
	
	if (GetConVarInt(sm_respawn_security_on_counter) == 1)
	{
		// Get client who captured control point.
		decl String:cappers[512];
		GetEventString(event, "cappers", cappers, sizeof(cappers));
		new cappersLength = strlen(cappers);
		for (new i = 0 ; i < cappersLength; i++)
		{
			new clientCapper = cappers[i];
			if(clientCapper > 0 && IsClientInGame(clientCapper) && IsClientConnected(clientCapper) && IsPlayerAlive(clientCapper) && !IsFakeClient(clientCapper))
			{
				// Get player's position
				new Float:capperPos[3];
				GetClientAbsOrigin(clientCapper, Float:capperPos);
				
				// Update respawn position
				g_fRespawnPosition = capperPos;
				
				break;
			}
		}

		// Respawn all players
		for (new client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsClientConnected(client))
			{
				new team = GetClientTeam(client);
				new Float:clientPos[3];
				GetClientAbsOrigin(client, Float:clientPos);
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
	

	// //Elite Bots Reset
	// if (g_elite_counter_attacks == 1)
	// 	CreateTimer(5.0, Timer_EliteBots);
	//PrintToServer("CONTROL POINT CAPTURED POST");

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	// If last capture point
	if (g_isCheckpoint == 1 && ((acp+1) == ncp))
	{
		g_secWave_Timer = g_iRespawnSeconds;
		g_secWave_Timer += (GetTeamSecCount() * 4);
	}
	else if (Ins_InCounterAttack())
		g_secWave_Timer += (GetTeamSecCount() * 3);

	//Reset VIP timer
	g_vip_obj_count = g_iCvar_vip_obj_time;	

	return Plugin_Continue;
}

//Command Actions START
public Action:serverhelp(client, args) 
{ 
	PrintToChat(client, "[SERVER_HELP] Visit www.fearless-assassins.com in/out of game for more Info/Guides.");
	return Plugin_Handled;
}
//VIP Info Command (Credits: INS Server)
public Action:Cmd_VIP(client, args)
{
	int nPlayerHealth = GetClientHealth(client);
	if((g_nVIP_ID != 0) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "\x04VIP\x01 needs to capture point within 5 minutes to earn bonus supply.");
		PrintToChat(client, "\x04VIP\x01 needs to capture point within 5 minutes to earn bonus supply. Does not include destroying objectives.");
	}
	return Plugin_Handled;
}
//Squad Spawning Toggle
public Action:SquadSpawn(client, args) 
{ 
	if (client < 0 || !IsValidClient(client) || !IsClientInGame(client))
		return Plugin_Handled;

	new iTeam = GetClientTeam(client);
	if ((iTeam == TEAM_1_SEC && playerPickSquad[client] == 1) && 
		(StrContains(g_client_last_classstring[client], "Gnalvl_squadleader_usmc") > -1 || 
		StrContains(g_client_last_classstring[client], "gnalvl_teamleader_usmc") > -1 ||
		StrContains(g_client_last_classstring[client], "Gnalvl_teamleader_recon_usmc") > -1) )
	{
		PrintToChat(client, "[SQUAD_SPAWN] You can't squad spawn as a leader!");
		g_squadSpawnEnabled[client] = 0;
		return Plugin_Handled;
	}

	if (g_squadSpawnEnabled[client] == 1)
	{
		g_squadSpawnEnabled[client] = 0;
		PrintToChat(client, "[SQUAD_SPAWN] Squad spawning disabled!");
	}
	else
	{
		g_squadSpawnEnabled[client] = 1;
		PrintToChat(client, "[SQUAD_SPAWN] Squad spawning enabled!");

	}
	return Plugin_Handled;
	//PrintToChat(client, "[SERVER_HELP] Visit SERNIX.DYNU.COM in/out of game for more SERNIX Info/Guides.");
}

public OnWeaponReload(weapon, bool:bSuccessful)
{
	if (bSuccessful)
	{
	PrintToChatAll("reload success");
	}
}



public Action:Toggle_Hints(client, args) 
{
	if (g_hintsEnabled[client])
	{
		g_hintsEnabled[client] = false;
		PrintToChat(client, "Hints disabled!");
	}
	else
	{
		g_hintsEnabled[client] = true;
		PrintToChat(client, "Hints enabled!");
	}
}

//Extend Map with /emap or sm_emap
public Action:emap(client, args) 
{ 	
	if (g_extendMapVote[client] == 1)
	{
		g_extendMapVote[client] = 0;
		PrintToChat(client, "You are AGAINST extending map!");
	}
	else
	{
		g_extendMapVote[client] = 1;
		PrintToChat(client, "You are FOR extending map!");
	}
}


//Test stuff with /test command or sm_test
public Action:test(client, args) 
{ 	



	//new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	//// Active control poin
	//new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	//PrintToChatAll("acp %d, ncp %d ", acp, ncp);
	//DisplayInstructorHint(EntRefToEntIndex(client), 5.0, 0.0, 1000.0, true, fa, "icon_interact", "icon_interact", "", true, {255, 215, 0}, "IED Jammer is broken!  Fix it!");
	//DisplayInstructorHint(client, 5.0, 0.0, 3.0, true, true, "icon_interact", "icon_interact", "", true, {255, 255, 255}, "Crouch (hold) and press R w/ knife to resupply");
//	new primaryWeapon = GetPlayerWeaponSlot(client, 0);
//	new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
//	new playerGrenades = GetPlayerWeaponSlot(client, 3);
	
//	//SetWeaponAmmo(client, primaryWeapon, 3, 0);

//	SDKHook(primaryWeapon, SDKHook_ReloadPost, OnWeaponReload);
	//Client_SetWeaponPlayerAmmoEx(client, primaryWeapon, 3, 3);
	 // Jareds pistols only code to verify iMedic is carrying knife
	 //new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	 //if (ActiveWeapon < 0)
	 //	return Plugin_Continue;
	
	// // Get weapon class name
	// decl String:sWeapon[32];
	// GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
	// //new primaryWeapon = GetPlayerWeaponSlot(client, 0);
	// // if (primaryWeapon != -1 && IsValidEntity(primaryWeapon))
	// // {
	// // }
	// // Call revive function
	// //CreateReviveTimer(iInjured);
	// RemovePlayerItem(client,ActiveWeapon);
 //    //Client_RemoveAllWeapons(client, "weapon_knife", true); 
 //    Client_GiveWeaponAndAmmo(client, "weapon_m4a1", _, 1, _, 10); 
	// new Handle:forceResupply;
	// new Handle:hGameConfig;
	// // Init respawn function
	// // Next 14 lines of text are taken from Andersso's DoDs respawn plugin. Thanks :)
	//  hGameConfig = LoadGameConfigFile("insurgency.games");
	
	// if (hGameConfig == INVALID_HANDLE)
	// 	SetFailState("Fatal Error: Missing File \"insurgency.games\"!");

	// StartPrepSDKCall(SDKCall_Entity);
	// PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CINSWeapon::DecrementAmmo");
	
	// forceResupply = EndPrepSDKCall();
	// if (forceResupply == INVALID_HANDLE) {
	// 	SetFailState("Fatal Error: Unable to find signature for \"CINSWeapon::DecrementAmmo\"!");
	// }
	// new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	// if (ActiveWeapon < 0)
	// 	return Plugin_Continue;
	// SDKCall(forceResupply, ActiveWeapon);
	//PrintToServer("clientMags: %d", clientMags);
   return Plugin_Handled; 
} 
//Command Actions END


//Enable/Disable Elite Bots
void EnableDisableEliteBotCvars(tEnabled, isFinale)
{
	new Float:tCvarFloatValue;
	new Int:tCvarIntValue;
	new Handle:tCvar;
	if (tEnabled == 1)
	{
		PrintToServer("BOT_SETTINGS_APPLIED");
		if (isFinale == 1)
		{
			tCvar = FindConVar("mp_player_resupply_coop_delay_max");
			SetConVarInt(tCvar, g_coop_delay_penalty_base, true, false);
			tCvar = FindConVar("mp_player_resupply_coop_delay_penalty");
			SetConVarInt(tCvar, g_coop_delay_penalty_base, true, false);
			tCvar = FindConVar("mp_player_resupply_coop_delay_base");
			SetConVarInt(tCvar, g_coop_delay_penalty_base, true, false);
		}

		tCvar = FindConVar("bot_attackdelay_frac_difficulty_impossible");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_attackdelay_frac_difficulty_impossible"));
		tCvarFloatValue = tCvarFloatValue - g_bot_attackdelay_frac_difficulty_impossible_mult;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_amt_close");
		tCvarIntValue = GetConVarInt(FindConVar("bot_attack_aimpenalty_amt_close"));
		tCvarIntValue = tCvarIntValue - g_bot_attack_aimpenalty_amt_close_mult;
		SetConVarInt(tCvar, tCvarIntValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_amt_far");
		tCvarIntValue = GetConVarInt(FindConVar("bot_attack_aimpenalty_amt_far"));
		tCvarIntValue = tCvarIntValue - g_bot_attack_aimpenalty_amt_far_mult;
		SetConVarInt(tCvar, tCvarIntValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_time_close");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_attack_aimpenalty_time_close"));
		tCvarFloatValue = tCvarFloatValue - g_bot_attack_aimpenalty_time_close_mult;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_attack_aimpenalty_time_far");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_attack_aimpenalty_time_far"));
		tCvarFloatValue = tCvarFloatValue - g_bot_attack_aimpenalty_time_far_mult;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_attack_aimtolerance_newthreat_amt");
		tCvarIntValue = GetConVarInt(FindConVar("bot_attack_aimtolerance_newthreat_amt"));
		tCvarIntValue = tCvarIntValue - g_bot_attack_aimtolerance_newthreat_amt_mult;
		SetConVarFloat(tCvar, tCvarIntValue, true, false);

		tCvar = FindConVar("bot_aim_aimtracking_base");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_aim_aimtracking_base"));
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_aimtracking_base;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_aimtracking_frac_impossible");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_aim_aimtracking_frac_impossible"));
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_aimtracking_frac_impossible;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_angularvelocity_frac_impossible");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_aim_angularvelocity_frac_impossible"));
		tCvarFloatValue = tCvarFloatValue + g_bot_aim_angularvelocity_frac_impossible;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_angularvelocity_frac_sprinting_target");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_aim_angularvelocity_frac_sprinting_target"));
		tCvarFloatValue = tCvarFloatValue + g_bot_aim_angularvelocity_frac_sprinting_target;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);

		tCvar = FindConVar("bot_aim_attack_aimtolerance_frac_impossible");
		tCvarFloatValue = GetConVarFloat(FindConVar("bot_aim_attack_aimtolerance_frac_impossible"));
		tCvarFloatValue = tCvarFloatValue - g_bot_aim_attack_aimtolerance_frac_impossible;
		SetConVarFloat(tCvar, tCvarFloatValue, true, false);
		//Make sure to check for FLOATS vs INTS and +/-!
	}
	else
	{
		PrintToServer("BOT_SETTINGS_APPLIED_2");

		tCvar = FindConVar("ins_bot_count_checkpoint_max");
		SetConVarInt(tCvar, g_ins_bot_count_checkpoint_max_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_max");
		SetConVarInt(tCvar, g_mp_player_resupply_coop_delay_max_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_penalty");
		SetConVarInt(tCvar, g_mp_player_resupply_coop_delay_penalty_org, true, false);
		tCvar = FindConVar("mp_player_resupply_coop_delay_base");
		SetConVarInt(tCvar, g_mp_player_resupply_coop_delay_base_org, true, false);
		tCvar = FindConVar("bot_attackdelay_frac_difficulty_impossible");
		SetConVarFloat(tCvar, g_bot_attackdelay_frac_difficulty_impossible_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_amt_close");
		SetConVarInt(tCvar, g_bot_attack_aimpenalty_amt_close_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_amt_far");
		SetConVarInt(tCvar, g_bot_attack_aimpenalty_amt_far_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_time_close");
		SetConVarFloat(tCvar, g_bot_attack_aimpenalty_time_close_org, true, false);
		tCvar = FindConVar("bot_attack_aimpenalty_time_far");
		SetConVarFloat(tCvar, g_bot_attack_aimpenalty_time_far_org, true, false);
		tCvar = FindConVar("bot_attack_aimtolerance_newthreat_amt");
		SetConVarFloat(tCvar, g_bot_attack_aimtolerance_newthreat_amt_org, true, false);

		tCvar = FindConVar("bot_aim_aimtracking_base");
		SetConVarFloat(tCvar, g_bot_aim_aimtracking_base_org, true, false);
		tCvar = FindConVar("bot_aim_aimtracking_frac_impossible");
		SetConVarFloat(tCvar, g_bot_aim_aimtracking_frac_impossible_org, true, false);
		tCvar = FindConVar("bot_aim_angularvelocity_frac_impossible");
		SetConVarFloat(tCvar, g_bot_aim_angularvelocity_frac_impossible_org, true, false);
		tCvar = FindConVar("bot_aim_angularvelocity_frac_sprinting_target");
		SetConVarFloat(tCvar, g_bot_aim_angularvelocity_frac_sprinting_target_org, true, false);
		tCvar = FindConVar("bot_aim_attack_aimtolerance_frac_impossible");
		SetConVarFloat(tCvar, g_bot_aim_attack_aimtolerance_frac_impossible_org, true, false);

	}
}

public Action:cmd_kill(client, args) {
	/*g_trackKillDeaths[client] += 1;
	PrintToChatAll("\x05%N\x01 has used the kill command! | Times Used: %d | Abusing for ammo = ban", client, g_trackKillDeaths[client]);
	PrintToChat(client, "\x04[=F|A= RULES] %t", "Abusing kill command is not allowed! | Times used %d | Abusing for ammo = ban", g_trackKillDeaths[client]);*/
	return Plugin_Handled;
}
// On finale counter attack, add lives back to insurgents to trigger unlimited respawns (this is redundant code now and may use for something else)
public Action:Timer_FinaleCounterAssignLives(Handle:Timer)
{
	if (g_iCvar_final_counterattack_type == 2)
	{
			// Reset remaining lives for bots
			g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins;
	}
}

// When counter-attack end, reset reinforcement time
public Action:Timer_CounterAttackEnd(Handle:Timer)
{


	//Clear bad spawn array
	//ClearArray(g_badSpawnPos_Array);

	
	//g_bIsCounterAttackTimerActive = false;
	// If round end, exit
	// if (g_iRoundStatus == 0)
	// {
	// 	// Stop counter-attack music
	// 	//StopCounterAttackMusic();
		
	// 	// Reset variable
	// 	g_bIsCounterAttackTimerActive = false;
	// 	return Plugin_Stop;
	// }
	//Disable elite bots when not in counter
	if (g_isEliteCounter == 1 && g_elite_counter_attacks == 1)
	{
		g_isEliteCounter = 0;
		EnableDisableEliteBotCvars(0, 0);
	}
	// Check counter-attack end
	// if (!Ins_InCounterAttack())
	// {
		//EnableDisableEliteBotCvars(0, 0);
		// Reset reinforcement time
		
		//g_iReinforceTime = g_iReinforceTime_AD_Temp;
		
		// Reset respawn token
		ResetInsurgencyLives();
		if (g_iCvar_respawn_reset_type && g_isCheckpoint)
			ResetSecurityLives();
		
		// Stop counter-attack music
		//StopCounterAttackMusic();
		
		// Reset variable
		g_bIsCounterAttackTimerActive = false;
		
		new Handle:cvar = INVALID_HANDLE;
		cvar = FindConVar("mp_checkpoint_counterattack_always");
		SetConVarInt(cvar, 0, true, false);
		
		for (new client = 0; client < MaxClients; client++) {
			if (!IsValidClient(client) || client <= 0)
				continue;
			if (!IsClientInGame(client))
				continue;
			int m_iTeam = GetClientTeam(client);
			if (IsFakeClient(client) && m_iTeam == TEAM_2_INS)
			{
				g_badSpawnPos_Track[client][0] = 0;
				g_badSpawnPos_Track[client][1] = 0;
				g_badSpawnPos_Track[client][2] = 0;
			}
		} 

		//PrintToServer("[RESPAWN] Counter-attack is over.");
		return Plugin_Stop;
	//}
	
	//return Plugin_Continue;
}

// Stop couter-attack music
void StopCounterAttackMusic()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			//ClientCommand(i, "snd_restart");
			//FakeClientCommand(i, "snd_restart");
			StopSound(i, SNDCHAN_STATIC, "*cues/INS_GameMusic_AboutToAttack_A.ogg");
		}
	}
}

//Run this to mark a bot as ready to spawn. Add tokens if you want them to be able to spawn.
void ResetSecurityLives()
{
	// Disable if counquer
	//if (g_isConquer == 1 || g_isOutpost == 1) return;
		// The number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Active control poin
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");


	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) return;
	
	// Update cvars
	UpdateRespawnCvars();

	if (g_isCheckpoint)
	{
		//If spawned per point, give more per-point lives based on team count.
		if (g_iCvar_respawn_reset_type == 1)
			SecDynLivesPerPoint();
	}
	// Individual lives
	if (g_iCvar_respawn_type_team_sec == 1)
	{
		for (new client=1; client<=MaxClients; client++)
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				//Reset Medic Stats:
				g_playerMedicRevivessAccumulated[client] = 0;
				g_playerMedicHealsAccumulated[client] = 0;
				g_playerNonMedicHealsAccumulated[client] = 0;
				
				// Check Team
				new iTeam = GetClientTeam(client);
				if (iTeam != TEAM_1_SEC)
					continue;

				//Bonus lives for conquer/outpost
				if (g_isConquer == 1 || g_isOutpost == 1 || g_isHunt == 1)
					g_iSpawnTokens[client] = g_iRespawnCount[iTeam] + 10;
				else
				{
					// Individual SEC lives
					if (g_isCheckpoint == 1 && g_iCvar_respawn_type_team_sec == 1)
					{
						// Reset remaining lives for player
						g_iSpawnTokens[client] = g_iRespawnCount[iTeam];
					}
				}
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
	// Disable if counquer
	//if (g_isConquer == 1 || g_isOutpost == 1) return;
	
	// Return if respawn is disabled
	if (!g_iCvar_respawn_enable) return;
	
	// Update cvars
	UpdateRespawnCvars();
	
	// Individual lives
	if (g_iCvar_respawn_type_team_ins == 1)
	{
		for (new client=1; client<=MaxClients; client++)
		{
			// Check valid player
			if (client > 0 && IsClientInGame(client))
			{
				// Check Team
				new iTeam = GetClientTeam(client);
				if (iTeam != TEAM_2_INS)
					continue;
				
				//Bonus lives for conquer/outpost
				if (g_isConquer == 1 || g_isOutpost == 1 || g_isHunt == 1)
					g_iSpawnTokens[client] = g_iRespawnCount[iTeam] + 10;
				else
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
public Action:Event_PlayerPickSquad_Post( Handle:event, const String:name[], bool:dontBroadcast )
{
	//"squad_slot" "byte"
	//"squad" "byte"
	//"userid" "short"
	//"class_template" "string"
	//PrintToServer("##########PLAYER IS PICKING SQUAD!############");
	
	// Get client ID
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	// Get class name
	decl String:class_template[64];
	GetEventString(event, "class_template", class_template, sizeof(class_template));
	
	// Set class string
	g_client_last_classstring[client] = class_template;
	g_hintsEnabled[client] = true;

	if( client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;	
	// Init variable
	playerPickSquad[client] = 1;
	
	// If player changed squad and remain ragdoll
	new team = GetClientTeam(client);
	if (client > 0 && IsClientInGame(client) && IsClientObserver(client) && !IsPlayerAlive(client) && g_iHurtFatal[client] == 0 && team == TEAM_1_SEC)
	{
		// Remove ragdoll
		new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
		if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
			RemoveRagdoll(client);
		
		// Init variable
		g_iHurtFatal[client] = -1;
	}

	g_fPlayerLastChat[client] = GetGameTime();

	// Get player nickname
	decl String:sNewNickname[64];

	// Medic class
	if (StrContains(g_client_last_classstring[client], "medic") > -1)
	{
		// Admin medic
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_KICK))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN][MEDIC] %s", g_client_org_nickname[client]);
		// Donor medic
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM2))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR][MEDIC] %s", g_client_org_nickname[client]);
		// Normal medic
		else
			Format(sNewNickname, sizeof(sNewNickname), "[MEDIC] %s", g_client_org_nickname[client]);
	}
	else if (StrContains(g_client_last_classstring[client], "engineer") > -1)
	{
		// Admin medic
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_KICK))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN][ENG] %s", g_client_org_nickname[client]);
		// Donor medic
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM2))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR][ENG] %s", g_client_org_nickname[client]);
		// Normal medic
		else
			Format(sNewNickname, sizeof(sNewNickname), "[ENG] %s", g_client_org_nickname[client]);
	}
	else if (StrContains(g_client_last_classstring[client], "mg") > -1)
	{
		// Admin medic
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_KICK))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN][MG] %s", g_client_org_nickname[client]);
		// Donor medic
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM2))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR][MG] %s", g_client_org_nickname[client]);
		// Normal medic
		else
			Format(sNewNickname, sizeof(sNewNickname), "[MG] %s", g_client_org_nickname[client]);
	}
	// Normal class
	else
	{
		// Admin
		if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_KICK))
			Format(sNewNickname, sizeof(sNewNickname), "[ADMIN] %s", g_client_org_nickname[client]);
		// Donor
		else if (GetConVarInt(sm_respawn_enable_donor_tag) == 1 && (GetUserFlagBits(client) & ADMFLAG_CUSTOM2))
			Format(sNewNickname, sizeof(sNewNickname), "[DONOR] %s", g_client_org_nickname[client]);
		// Normal player
		else
			Format(sNewNickname, sizeof(sNewNickname), "%s", g_client_org_nickname[client]);
	}
	
	// Set player nickname
	decl String:sCurNickname[64];
	Format(sCurNickname, sizeof(sCurNickname), "%N", client);
	if (!StrEqual(sCurNickname, sNewNickname))
		SetClientName(client, sNewNickname);
	
	g_playersReady = true;

	//Allow new players to use lives to respawn on join
	if (g_iRoundStatus == 1 && g_playerFirstJoin[client] == 1 && !IsPlayerAlive(client) && team == TEAM_1_SEC)
	{
		// Get SteamID to verify is player has connected before.
		decl String:steamId[64];
		//GetClientAuthString(client, steamId, sizeof(steamId));
		GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));
		new isPlayerNew = FindStringInArray(g_playerArrayList, steamId);

		if (isPlayerNew != -1)
		{
			PrintToServer("Player %N has reconnected! | SteamID: %s | Index: %d", client, steamId, isPlayerNew);
		}
		else
		{
			PushArrayString(g_playerArrayList, steamId);
			PrintToServer("Player %N is new! | SteamID: %s | PlayerArrayList Size: %d", client, steamId, GetArraySize(g_playerArrayList));
			// Give individual lives to new player (no longer just at beginning of round)
			if (g_iCvar_respawn_type_team_sec == 1)
			{	
				if (g_isCheckpoint && g_iCvar_respawn_reset_type == 0)
				{
					// The number of control points
					new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
					// Active control poin
					new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
					new tLiveSec = GetConVarInt(sm_respawn_lives_team_sec);

					if (acp <= (ncp / 2))
						g_iSpawnTokens[client] = tLiveSec;
					else
						g_iSpawnTokens[client] = (tLiveSec / 2);

					if (tLiveSec < 1)
					{
						tLiveSec = 1;
						g_iSpawnTokens[client] = tLiveSec;
					}
				}
				else
					g_iSpawnTokens[client] = GetConVarInt(sm_respawn_lives_team_sec);

			
			}
			CreatePlayerRespawnTimer(client);
		}
	}

	//Assign VIP (Credits INS Server)
	if(StrContains(class_template, "vip") > -1)
	{
		g_nVIP_ID = client;
	}
	
	if((client == g_nVIP_ID) && (StrContains(class_template, "vip") == -1))
	{
		g_nVIP_ID = 0;
	}

	//Update RespawnCvars when player picks squad
	UpdateRespawnCvars();
}

// Triggers when player hurt
public Action:Event_PlayerHurt_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(victim) && IsFakeClient(victim)) 
		return Plugin_Continue;

	new victimHealth = GetEventInt(event, "health");
	new dmg_taken = GetEventInt(event, "dmg_health");
	//PrintToServer("victimHealth: %d, dmg_taken: %d", victimHealth, dmg_taken);
	if (g_fCvar_fatal_chance > 0.0 && dmg_taken > victimHealth)
	{
		// Get information for event structure
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new hitgroup = GetEventInt(event, "hitgroup");
		
		// Update last damege (related to 'hurt_fatal')
		g_clientDamageDone[victim] = dmg_taken;
		
		// Get weapon
		decl String:weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		//PrintToServer("[DAMAGE TAKEN] Weapon used: %s, Damage done: %i",weapon, dmg_taken);
		
		// Check is team attack
		new attackerTeam;
		if (attacker > 0 && IsClientInGame(attacker) && IsClientConnected(attacker))
			attackerTeam = GetClientTeam(attacker);
		
		// Get fatal chance
		new Float:fRandom = GetRandomFloat(0.0, 1.0);
		
		// Is client valid
		if (IsClientInGame(victim))
		{
			
			// Explosive
			if (hitgroup == 0)
			{
				//explosive list
				//incens
				//grenade_molotov, grenade_anm14
				//PrintToServer("[HITGROUP HURT BURN]");
				//grenade_m67, grenade_f1, grenade_ied, grenade_c4, rocket_rpg7, rocket_at4, grenade_gp25_he, grenade_m203_he	
				// flame
				if (StrEqual(weapon, "grenade_anm14", false) || StrEqual(weapon, "grenade_molotov", false))
				{
					//PrintToServer("[SUICIDE] incen/molotov DETECTED!");
					if (dmg_taken >= g_iCvar_fatal_burn_dmg && (fRandom <= g_fCvar_fatal_chance))
					{
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
					StrEqual(weapon, "grenade_m203_he", false))
				{
					//PrintToServer("[HITGROUP HURT EXPLOSIVE]");
					if (dmg_taken >= g_iCvar_fatal_explosive_dmg && (fRandom <= g_fCvar_fatal_chance))
					{
						// Hurt fatally
						g_iHurtFatal[victim] = 1;
						
						//PrintToServer("[PLAYER HURT EXPLOSIVE]");
					}
				}
				//PrintToServer("[SUICIDE] HITRGOUP 0 [GENERIC]");
			}
			// Headshot
			else if (hitgroup == 1)
			{
				//PrintToServer("[PLAYER HURT HEAD]");
				if (dmg_taken >= g_iCvar_fatal_head_dmg && (fRandom <= g_fCvar_fatal_head_chance) && attackerTeam != TEAM_1_SEC)
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[BOTSPAWNS] BOOM HEADSHOT");
				}
			}
			// Chest
			else if (hitgroup == 2 || hitgroup == 3)
			{
				//PrintToServer("[HITGROUP HURT CHEST]");
				if (dmg_taken >= g_iCvar_fatal_chest_stomach && (fRandom <= g_fCvar_fatal_chance))
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[PLAYER HURT CHEST]");
				}
			}
			// Limbs
			else if (hitgroup == 4 || hitgroup == 5  || hitgroup == 6 || hitgroup == 7)
			{
				//PrintToServer("[HITGROUP HURT LIMBS]");
				if (dmg_taken >= g_iCvar_fatal_limb_dmg && (fRandom <= g_fCvar_fatal_chance))
				{
					// Hurt fatally
					g_iHurtFatal[victim] = 1;
					
					//PrintToServer("[PLAYER HURT LIMBS]");
				}
			}
		}
	}
	//Track wound type (minor, moderate, critical)
	if (g_iHurtFatal[victim] != 1)
	{
		if (dmg_taken <= g_minorWound_dmg)
		{
			g_playerWoundTime[victim] = g_minorRevive_time;
			g_playerWoundType[victim] = 0;
		}
		else if (dmg_taken > g_minorWound_dmg && dmg_taken <= g_moderateWound_dmg)
		{
			g_playerWoundTime[victim] = g_modRevive_time;
			g_playerWoundType[victim] = 1;
		}
		else if (dmg_taken > g_moderateWound_dmg)
		{
			g_playerWoundTime[victim] = g_critRevive_time;
			g_playerWoundType[victim] = 2;
		}
	}
	else
	{
		g_playerWoundTime[victim] = -1;
		g_playerWoundType[victim] = -1;
	}

	
	
	////////////////////////
	// Rank System
	new attackerId = GetEventInt(event, "attacker");
	new hitgroup = GetEventInt(event,"hitgroup");

	new attacker = GetClientOfUserId(attackerId);

	if ( hitgroup == 1 )
	{
		g_iStatHeadShots[attacker]++;
	}
	////////////////////////
	
	return Plugin_Continue;
}

// Trigged when player die PRE
public Action:Event_PlayerDeath_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		// Tracking ammo
		if (g_iEnableRevive == 1 && g_iRoundStatus == 1 && g_iCvar_enable_track_ammo == 1)
		{
			//PrintToChatAll("### GET PLAYER WEAPONS ###");
			//CONSIDER IF PLAYER CHOOSES DIFFERENT CLASS
			// Get weapons
			new primaryWeapon = GetPlayerWeaponSlot(client, 0);
			new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
			//new playerGrenades = GetPlayerWeaponSlot(client, 3);
			
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
			//PrintToServer("PlayerClip_1 %i, PlayerClip_2 %i, playerAmmo_1 %i, playerAmmo_2 %i, playerGrenades %i",playerClip[client][0], playerClip[client][1], playerAmmo[client][0], playerAmmo[client][1], playerAmmo[client][2]); 
			// if (playerGrenades != -1 && IsValidEntity(playerGrenades))
			// {
			// 	 playerGrenadeType[victim][0] = GetGrenadeAmmo(victim, Gren_M67);
			// 	 playerGrenadeType[victim][1] = GetGrenadeAmmo(victim, Gren_Incen);
			// 	 playerGrenadeType[victim][2] = GetGrenadeAmmo(victim, Gren_Molot);
			// 	 playerGrenadeType[victim][3] = GetGrenadeAmmo(victim, Gren_M18);
			// 	 playerGrenadeType[victim][4] = GetGrenadeAmmo(victim, Gren_Flash);
			// 	 playerGrenadeType[victim][5] = GetGrenadeAmmo(victim, Gren_F1);
			// 	 playerGrenadeType[victim][6] = GetGrenadeAmmo(victim, Gren_IED);
			// 	 playerGrenadeType[victim][7] = GetGrenadeAmmo(victim, Gren_C4);
			// 	 playerGrenadeType[victim][8] = GetGrenadeAmmo(victim, Gren_AT4);
			// 	 playerGrenadeType[victim][9] = GetGrenadeAmmo(victim, Gren_RPG7);
			// }
		}

}
// Trigged when player die
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	////////////////////////
	// Rank System
	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	
	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);

	if(victim != attacker){
		g_iStatKills[attacker]++;
		g_iStatDeaths[victim]++;

	} else {
		g_iStatSuicides[victim]++;
		g_iStatDeaths[victim]++;
	}

	////////////////////////
	
	// Get player ID
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
    g_iPlayerBGroups[client] = GetEntProp(client, Prop_Send, "m_nBody");

	//PrintToServer("BodyGroups: %d", g_iPlayerBGroups[client]);

	// Check client valid
	if (!IsClientInGame(client)) return Plugin_Continue;
	
	// Set variable
	new dmg_taken = GetEventInt(event, "damagebits");
	if (dmg_taken <= 0)
	{
		g_playerWoundTime[client] = g_minorRevive_time;
		g_playerWoundType[client] = 0;
	}
	//PrintToServer("[PLAYERDEATH] Client %N has %d lives remaining", client, g_iSpawnTokens[client]);

	// Get gamemode
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	new team = GetClientTeam(client);
	new attackerTeam = GetClientTeam(attacker);

	//AI Director START
	//Bot Team AD Status
	if (team == TEAM_2_INS && g_iRoundStatus == 1 && attackerTeam == TEAM_1_SEC)
	{
		//Bonus point for specialty bots
		if (AI_Director_IsSpecialtyBot(client))
			g_AIDir_TeamStatus += 1;
			
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
			g_AIDir_TeamStatus -= 3;
		else
			g_AIDir_TeamStatus -= 2;

		if ((StrContains(g_client_last_classstring[client], "medic") > -1))
			g_AIDir_TeamStatus -= 3;

	}

	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);
		
	//AI Director END

	if (g_iCvar_revive_enable)
	{
		// Convert ragdoll
		if (team == TEAM_1_SEC)
		{
			// Get current position
			decl Float:vecPos[3];
			GetClientAbsOrigin(client, Float:vecPos);
			g_fDeadPosition[client] = vecPos;
			
			// Call ragdoll timer
			if (g_iEnableRevive == 1 && g_iRoundStatus == 1)
				CreateTimer(5.0, ConvertDeleteRagdoll, client);
		}
	}
	// Check enables
	if (g_iCvar_respawn_enable)
	{
		
		// Client should be TEAM_1_SEC = HUMANS or TEAM_2_INS = BOTS
		if ((team == TEAM_1_SEC) || (team == TEAM_2_INS))
		{
			// The number of control points
			new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
			
			// Active control poin
			new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
			
			// Do not decrease life in counterattack
			if (g_isCheckpoint == 1 && Ins_InCounterAttack() && 
				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) || 
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))
			)
			{
				// Respawn type 1 bots
				if ((g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS) && 
				(((acp+1) == ncp &&  g_iCvar_final_counterattack_type == 2) || 
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))
				)
				{
					if ((g_iSpawnTokens[client] < g_iRespawnCount[team]))
						g_iSpawnTokens[client] = (g_iRespawnCount[team] + 1);
					
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
						decl String:sChat[128];
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
				((acp+1) != ncp && g_iCvar_counterattack_type == 2))
				)
				{
					g_iRemaining_lives_team_ins = g_iRespawn_lives_team_ins + 1;
					
					// Call respawn timer
					CreateBotRespawnTimer(client);
				}
			}
			// Normal respawn
			else if ((g_iCvar_respawn_type_team_sec == 1 && team == TEAM_1_SEC) || (g_iCvar_respawn_type_team_ins == 1 && team == TEAM_2_INS))
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
					decl String:sChat[128];
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
					decl String:sChat[128];
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
	/*decl String:wound_hint[64];
	decl String:fatal_hint[64];
	decl String:woundType[64];
	if (g_playerWoundType[client] == 0)
		woundType = "MINORLY WOUNDED";
	else if (g_playerWoundType[client] == 1)
		woundType = "MODERATELY WOUNDED";
	else if (g_playerWoundType[client] == 2)
		woundType = "CRITCALLY WOUNDED";

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
		}*/
	
		
	// Update remaining life
	new Handle:hCvar = INVALID_HANDLE;
	new iRemainingLife = GetRemainingLife();
	hCvar = FindConVar("sm_remaininglife");
	SetConVarInt(hCvar, iRemainingLife);
	
	return Plugin_Continue;
}

// Convert dead body to new ragdoll
public Action:ConvertDeleteRagdoll(Handle:Timer, any:client)
{	
	if (IsClientInGame(client) && g_iRoundStatus == 1 && !IsPlayerAlive(client)) 
	{
		//PrintToServer("CONVERT RAGDOLL********************");
		//new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		//TeleportEntity(clientRagdoll, g_fDeadPosition[client], NULL_VECTOR, NULL_VECTOR);
		
		// Get dead body
		new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		
		//This timer safely removes client-side ragdoll
		if(clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll) && g_iEnableRevive == 1)
		{
			// Get dead body's entity
			new ref = EntIndexToEntRef(clientRagdoll);
			new entity = EntRefToEntIndex(ref);
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
			new tempRag = CreateEntityByName("prop_ragdoll");
			
			// Set client's new ragdoll
			g_iClientRagdolls[client]  = EntIndexToEntRef(tempRag);
			
			// Set position
			g_fDeadPosition[client][2] = g_fDeadPosition[client][2] + 50;
			
			// If success initialize ragdoll
			if(tempRag != -1)
			{
				// Get model name
				decl String:sModelName[64];
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
				new Handle:revivePack;
				CreateDataTimer(1.0 , Timer_RevivePeriod, revivePack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
				WritePackCell(revivePack, client);
				WritePackCell(revivePack, tempRag);
				*/
			}
			else
			{
				// If failed to create ragdoll, remove entity
				if(tempRag > 0 && IsValidEdict(tempRag) && IsValidEntity(tempRag))
					RemoveRagdoll(client);
			}
		}
	}
}

// Remove ragdoll
void RemoveRagdoll(client)
{
	//new ref = EntIndexToEntRef(g_iClientRagdolls[client]);
	new entity = EntRefToEntIndex(g_iClientRagdolls[client]);
	if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
		g_iClientRagdolls[client] = INVALID_ENT_REFERENCE;
	}	
}

// This handles revives by medics
public CreateReviveTimer(client)
{
	CreateTimer(0.0, RespawnPlayerRevive, client);
}

// Handles spawns when counter attack starts
public CreateCounterRespawnTimer(client)
{
	CreateTimer(0.0, RespawnPlayerCounter, client);
}

// Respawn bot
public CreateBotRespawnTimer(client)
{	
	if ((g_cqc_map_enabled == 1 && Ins_InCounterAttack() && ((StrContains(g_client_last_classstring[client], "bomber") > -1) || 
		(StrContains(g_client_last_classstring[client], "juggernaut") > -1))) || 
		(!Ins_InCounterAttack() && ((StrContains(g_client_last_classstring[client], "bomber") > -1) || 
			(StrContains(g_client_last_classstring[client], "juggernaut") > -1)))) //make sure its a bot bomber
	{
		new fRandomFloat = GetRandomFloat(0, 1);
		new tSpecRespawnDelay = 0;

		if (g_cqc_map_enabled == 1 && Ins_InCounterAttack())
		{
			if (StrContains(g_client_last_classstring[client], "bomber") > -1)
			{
				PrintToServer("BOMBER SPAWN: Delay %f", (g_fCvar_respawn_delay_team_ins_spec / 3));
				CreateTimer((g_fCvar_respawn_delay_team_ins_spec / 3), RespawnBot, client);
			}
			else if (StrContains(g_client_last_classstring[client], "juggernaut") > -1)
			{
				PrintToServer("JUGGER SPAWN: Delay %f", (g_fCvar_respawn_delay_team_ins_spec / 4));
				CreateTimer((g_fCvar_respawn_delay_team_ins_spec / 4), RespawnBot, client);
			}
		}
		else
		{
			if (StrContains(g_client_last_classstring[client], "bomber") > -1)
			{
				CreateTimer((g_fCvar_respawn_delay_team_ins_spec * 2), RespawnBot, client);
			}
			else if (StrContains(g_client_last_classstring[client], "juggernaut") > -1)
			{
				CreateTimer((g_fCvar_respawn_delay_team_ins_spec), RespawnBot, client);
			}
		}
	}
	else
		CreateTimer(g_fCvar_respawn_delay_team_ins, RespawnBot, client);
	
}

// Respawn player
public CreatePlayerRespawnTimer(client)
{
	// Check is respawn timer active
	if (g_iPlayerRespawnTimerActive[client] == 0)
	{
		// Set timer active
		g_iPlayerRespawnTimerActive[client] = 1;
		
		new validAntenna = -1;
		validAntenna = FindValid_Antenna();

		// Set remaining timer for respawn
		if (validAntenna != -1)
		{
			new timeReduce = (GetTeamSecCount() / 3);
			if (timeReduce <= 0)
				timeReduce = 3;

			new jammerSpawnReductionAmt = (g_iRespawnSeconds / timeReduce);

			g_iRespawnTimeRemaining[client] = (g_iRespawnSeconds - jammerSpawnReductionAmt);
			if (g_iRespawnTimeRemaining[client] < 5)
				g_iRespawnTimeRemaining[client] = 5;
		}
		else
			g_iRespawnTimeRemaining[client] = g_iRespawnSeconds;
		
		//Sync wave based timer if enabled
		if (g_respawn_mode_team_sec)
			g_iRespawnTimeRemaining[client] = g_secWave_Timer;

		// Call respawn timer
		CreateTimer(1.0, Timer_PlayerRespawn, client, TIMER_REPEAT);
	}
}

// Revive player
public Action:RespawnPlayerRevive(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	if (IsPlayerAlive(client) || g_iRoundStatus == 0) return;
	
	//PrintToServer("[REVIVE_RESPAWN] REVIVING client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);
	
	// If set 'sm_respawn_enable_track_ammo', restore player's ammo
	 if (playerRevived[client] == true && g_iCvar_enable_track_ammo == 1)
	 {
	 	playerInRevivedState[client] = true;
	 	//SetPlayerAmmo(client); //AmmoResupply_Player(client, 0, 0, 1);

	 }		
	
	//Set wound health
	new iHealth = GetClientHealth(client);
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
	new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	//CreateTimer(0.0, RespawnPlayerRevivePost, client);
	RespawnPlayerRevivePost(INVALID_HANDLE, client);
	if ((StrContains(g_client_last_classstring[client], "medic") > -1))
		g_AIDir_TeamStatus += 2;
	else
		g_AIDir_TeamStatus += 1;

	g_AIDir_TeamStatus = AI_Director_SetMinMax(g_AIDir_TeamStatus, g_AIDir_TeamStatus_min, g_AIDir_TeamStatus_max);

	
}

// Do post revive stuff
public Action:RespawnPlayerRevivePost(Handle:timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	//PrintToServer("[REVIVE_DEBUG] called RespawnPlayerRevivePost for client %N (%d)",client,client);
	TeleportEntity(client, g_fRagdollPosition[client], NULL_VECTOR, NULL_VECTOR);
	
	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}

// Respawn player in counter attack
public Action:RespawnPlayerCounter(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	if (IsPlayerAlive(client) || g_iRoundStatus == 0) return;
	
	//PrintToServer("[Counter Respawn] Respawning client %N who has %d lives remaining", client, g_iSpawnTokens[client]);
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);

	// Get player's ragdoll
	new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
	
	//Remove network ragdoll
	if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
		RemoveRagdoll(client);
	
		// If set 'sm_respawn_enable_track_ammo', restore player's ammo
		// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	//Remove grenades if not finale
	if ((acp+1) != ncp)
	 	RemoveWeapons(client, 0, 0, 1);

	// Teleport to avtive counter attack point
	//PrintToServer("[REVIVE_DEBUG] called RespawnPlayerPost for client %N (%d)",client,client);
	if (g_fRespawnPosition[0] != 0.0 && g_fRespawnPosition[1] != 0.0 && g_fRespawnPosition[2] != 0.0)
		TeleportEntity(client, g_fRespawnPosition, NULL_VECTOR, NULL_VECTOR);
	
	// Reset ragdoll position
	g_fRagdollPosition[client][0] = 0.0;
	g_fRagdollPosition[client][1] = 0.0;
	g_fRagdollPosition[client][2] = 0.0;
}


// Respawn bot
public Action:RespawnBot(Handle:Timer, any:client)
{

	// Exit if client is not in game
	if (IsPlayerAlive(client) || !IsClientInGame(client) || g_iRoundStatus == 0) return;

	decl String:sModelName[64];
	GetClientModel(client, sModelName, sizeof(sModelName));
	if (StrEqual(sModelName, ""))
	{
		//PrintToServer("Invalid model: %s", sModelName);
		return; //check if model is blank
	}
	else
	{
		//PrintToServer("Valid model: %s", sModelName);
	}
	
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
	
	// Call forcerespawn fucntion
	SDKCall(g_hForceRespawn, client);

	//ins_spawnpoint forcerespawn
	//TeleportClient(client);

	//Do the post-spawn stuff like moving to final "spawnpoint" selected
	// if (g_iCvar_SpawnMode == 1)
	// {
	// 	//CreateTimer(0.0, RespawnBotPost, client);
	// 	RespawnBotPost(INVALID_HANDLE, client);
	// }
	
}

//Handle any work that needs to happen after the client is in the game
public Action:RespawnBotPost(Handle:timer, any:client)
{
	/*
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;

	//PrintToServer("[BOTSPAWNS] called RespawnBotPost for client %N (%d)",client,client);
	//g_iSpawning[client] = 0;
	
	if ((g_iHidingSpotCount) && !Ins_InCounterAttack())
	{	
		//PrintToServer("[BOTSPAWNS] HAS g_iHidingSpotCount COUNT");
		
		//Older Nav Spawning
		// Get hiding point - Nav Spawning - Commented for Rehaul
		new Float:flHidingSpot[3];
		new iSpot = GetBestHidingSpot(client);

		//PrintToServer("[BOTSPAWNS] FOUND Hiding spot %d",iSpot);
		
		//If found hiding spot
		if (iSpot > -1)
		{
			// Set hiding spot
			flHidingSpot[0] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_X);
			flHidingSpot[1] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Y);
			flHidingSpot[2] = GetArrayCell(g_hHidingSpots, iSpot, NavMeshHidingSpot_Z);
			
			// Debug message
			//new Float:vecOrigin[3];
			//GetClientAbsOrigin(client,vecOrigin);
			//new Float:distance = GetVectorDistance(flHidingSpot,vecOrigin);
			//PrintToServer("[BOTSPAWNS] Teleporting %N to hiding spot %d at %f,%f,%f distance %f", client, iSpot, flHidingSpot[0], flHidingSpot[1], flHidingSpot[2], distance);
			
			// Teleport to hiding spot
			TeleportEntity(client, flHidingSpot, NULL_VECTOR, NULL_VECTOR);
		}
	}
	*/
	
}
// Monitor player reload and set ammo after each reload
public Action:Timer_ForceReload(Handle:Timer, any:client)
{
	new bool:isReloading = Client_IsReloading(client);
	new primaryWeapon = GetPlayerWeaponSlot(client, 0);
	new secondaryWeapon = GetPlayerWeaponSlot(client, 1);

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
public Action:Timer_PlayerRespawn(Handle:Timer, any:client)
{
	decl String:sRemainingTime[256];
	
	// Exit if client is not in game
	if (!IsClientInGame(client)) return Plugin_Stop; // empty class name
	
	//if (!IsPlayerAlive(client) && g_iRoundStatus == 1)
	//{
		//g_squadLeader[client] = GetSquadLeader(client);
		/*if (g_iRespawnTimeRemaining[client] > 0)
		{	
			if (g_playerFirstJoin[client] == 1)
			{
				//GetSquadSpawnStatus(client)
				//Get Leader Status >> 0 = Dead/Disconnected, 1 = Alive and well
				// Print remaining time to center text area
				if (!IsFakeClient(client))
				{
					if (g_squadSpawnEnabled[client] == 1)
					{
						if (g_squadLeader[client] == -1)
							Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] This is your first time joining. Squad has no leader! Reinforcing normally in %d second%s (%d lives left) ", g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						else if (IsValidClient(g_squadLeader[client]) && IsClientInGame(g_squadLeader[client]) && playerPickSquad[g_squadLeader[client]] == 1)
						{	
							if (Ins_InCounterAttack())
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] This is your first time joining. Counter-attack in Progress! Reinforcing normally in %d second%s (%d lives left) ", g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
							else if (IsPlayerAlive(g_squadLeader[client]))
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] This is your first time joining. You will squad reinforce on %N in %d second%s (%d lives left) ", g_squadLeader[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
							else
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] This is your first time joining. Squad leader %N is dead! Reinforcing normally in %d second%s (%d lives left) ", g_squadLeader[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						}

					}
					else
						Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_DISABLED|Type /ss to toggle] This is your first time joining.  You will reinforce in %d second%s (%d lives left) ", g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						
					PrintCenterText(client, sRemainingTime);
				}
			}
			else
			{
				new String:woundType[128];
				new tIsFatal = false;
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
					if (g_squadSpawnEnabled[client] == 1)
					{
						if (g_squadLeader[client] == -1)
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] %s for %d damage | If wounded, wait patiently for a medic..do NOT mic/chat spam!\n\n                Squad has no leader! Reinforcing normally in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						else if (IsValidClient(g_squadLeader[client]) && IsClientInGame(g_squadLeader[client]) && playerPickSquad[g_squadLeader[client]] == 1)
						{

							if (Ins_InCounterAttack())
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] %s for %d damage | If wounded, wait patiently for a medic..do NOT mic/chat spam!\n\n                Counter-attack in progress! Reinforcing normally in %d second%s (%d lives left)  ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
							else if (IsPlayerAlive(g_squadLeader[client]))
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] %s for %d damage | If wounded, wait patiently for a medic..do NOT mic/chat spam!\n\n                Squad reinforcing on %N in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_squadLeader[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
							else
								Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_ENABLED|Type /ss to toggle] %s for %d damage | If wounded, wait patiently for a medic..do NOT mic/chat spam!\n\n                Squad leader %N is dead! Reinforcing normally in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_squadLeader[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						}

					}
					//Normal spawn
					else
					{
						if (tIsFatal)
						{
							Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_DISABLED|Type /ss to toggle] %s for %d damage\n\n                Reinforcing in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						}
						else
						{
							Format(sRemainingTime, sizeof(sRemainingTime),"[SQUAD_SPAWN_DISABLED|Type /ss to toggle] %s for %d damage | wait patiently for a medic..do NOT mic/chat spam!\n\n                Reinforcing in %d second%s (%d lives left) ", woundType, g_clientDamageDone[client], g_iRespawnTimeRemaining[client], (g_iRespawnTimeRemaining[client] > 1 ? "s" : ""), g_iSpawnTokens[client]);
						}
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
				//PrintCenterText(client, "You reinforced! (%d lives left)", g_iSpawnTokens[client]);

			//Lets confirm squad spawn
			//new tSquadSpawned = false;

			//Spawn on Squad Leader Action
			if (!Ins_InCounterAttack() && g_squadSpawnEnabled[client] == 1 && g_squadLeader[client] != -1 && IsPlayerAlive(g_squadLeader[client]) && playerPickSquad[g_squadLeader[client]] == 1)
			{
				if (IsValidClient(g_squadLeader[client]) && IsClientInGame(g_squadLeader[client]))
				{
					new Float:tSquadLeadPos[3];
					GetClientAbsOrigin(g_squadLeader[client], tSquadLeadPos);
					TeleportEntity(client, tSquadLeadPos, NULL_VECTOR, NULL_VECTOR);
					//PrintHintText(g_squadLeader[client], "%N squad-reinforced on you!", client);
					//tSquadSpawned = true;
					g_AIDir_TeamStatus += 2;
				}
			}

			// Get ragdoll position
			new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
			
			// Remove network ragdoll
			if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
				RemoveRagdoll(client);
			
			// Do the post-spawn stuff like moving to final "spawnpoint" selected
			//CreateTimer(0.0, RespawnPlayerPost, client);
			//RespawnPlayerPost(INVALID_HANDLE, client);
					
			// Reset ragdoll position
			g_fRagdollPosition[client][0] = 0.0;
			g_fRagdollPosition[client][1] = 0.0;
			g_fRagdollPosition[client][2] = 0.0;

			// Announce respawn if not wave based (to avoid spam)
			if (!g_respawn_mode_team_sec)
			{
				//if (g_squadSpawnEnabled[client] == 1 && tSquadSpawned == true)
				//	PrintToChatAll("\x05%N\x01 squad-reinforced on %N", client, g_squadLeader[client]);
				//else
				//	PrintToChatAll("\x05%N\x01 reinforced..", client);
			}
			// Reset variable
			g_iPlayerRespawnTimerActive[client] = 0;
			
			return Plugin_Stop;
		}*/
	//}
	//else
	//{
		// Reset variable
		g_iPlayerRespawnTimerActive[client] = 0;
		
		return Plugin_Stop;
	//}
	
	return Plugin_Continue;
}


// Handles reviving for medics and non-medics
public Action:Timer_ReviveMonitor(Handle:timer, any:data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	
	// Init variables
	new Float:fReviveDistance = 65.0;
	new iInjured;
	new iInjuredRagdoll;
	new Float:fRagPos[3];
	new Float:fMedicPos[3];
	new Float:fDistance;
	
	// Search medics
	for (new iMedic = 1; iMedic <= MaxClients; iMedic++)
	{
		if (!IsClientInGame(iMedic) || IsFakeClient(iMedic))
			continue;
		
		// Is valid iMedic?
		if (IsPlayerAlive(iMedic) && (StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		{
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured)
			)
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll)
				)
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
				new ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If iMedic can see ragdoll and using defib or knife
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance)) 
					&& ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))
				)
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveRemainingTime[iInjured]);		
					decl String:sBuf[255];
					
					// Need more time to reviving
					if (g_iReviveRemainingTime[iInjured] > 0)
					{

						decl String:woundType[64];
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
						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you from a %s", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Add kill bonus to iMedic
						//new iBonus = GetConVarInt(sm_revive_bonus);
						//PrintToServer("iBonus: %d", iBonus);
						//new iScore = GetClientFrags(iMedic) + iBonus;
						//PrintToServer("GetClientFrags: %d | iScore: %d", GetClientFrags(iMedic), iScore);
						//SetEntProp(iMedic, Prop_Data, "m_iFrags", iScore);
						
						/////////////////////////
						// Rank System
						g_iStatRevives[iMedic]++;
						//
						/////////////////////////
						
						//Accumulate a revive
						g_playerMedicRevivessAccumulated[iMedic]++;
						new iReviveCap = GetConVarInt(sm_revive_cap_for_bonus);

						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s | Revives remaining til bonus life: %d", iInjured, woundType, (iReviveCap - g_playerMedicRevivessAccumulated[iMedic]));
						PrintHintText(iMedic, "%s", sBuf);
						// Add score bonus to iMedic (doesn't work)
						//iScore = GetPlayerScore(iMedic);
						//PrintToServer("[SCORE] score: %d", iScore + 10);
						//SetPlayerScore(iMedic, iScore + 10);
						if (g_playerMedicRevivessAccumulated[iMedic] >= iReviveCap)
						{
							g_playerMedicRevivessAccumulated[iMedic] = 0;
							g_iSpawnTokens[iMedic]++;
							decl String:sBuf2[255];
							//if (iBonus > 1)
							//	Format(sBuf2, 255,"Awarded %i kills and %i score for revive", iBonus, 10);
							//else
							Format(sBuf2, 255,"Awarded %i life for reviving %d players", 1, iReviveCap);
							PrintToChat(iMedic, "%s", sBuf2);
						}

						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;

						//Reward nearby medics who asssisted
						Check_NearbyMedicsRevive(iMedic, iInjured);
						
						// Reset revive counter
						playerRevived[iInjured] = true;
						
						// Call revive function
						g_playerNonMedicRevive[iInjured] = 0;
						CreateReviveTimer(iInjured);
						
						//PrintToServer("##########PLAYER REVIVED %s ############", playerRevived[iInjured]);
						continue;
					}
				}
			}
		}
		//Non Medics with Medic Pack
		else if (IsPlayerAlive(iMedic) && !(StrContains(g_client_last_classstring[iMedic], "medic") > -1))
		{
			//PrintToServer("Non-Medic Reviving..");
			// Check is there nearest body
			iInjured = g_iNearestBody[iMedic];
			
			// Valid nearest body
			if (iInjured > 0 && IsClientInGame(iInjured) && !IsPlayerAlive(iInjured) && g_iHurtFatal[iInjured] == 0 
				&& iInjured != iMedic && GetClientTeam(iMedic) == GetClientTeam(iInjured)
			)
			{
				// Get found medic position
				GetClientAbsOrigin(iMedic, fMedicPos);
				
				// Get player's entity index
				iInjuredRagdoll = EntRefToEntIndex(g_iClientRagdolls[iInjured]);
				
				// Check ragdoll is valid
				if(iInjuredRagdoll > 0 && iInjuredRagdoll != INVALID_ENT_REFERENCE
					&& IsValidEdict(iInjuredRagdoll) && IsValidEntity(iInjuredRagdoll)
				)
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
				new ActiveWeapon = GetEntPropEnt(iMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				
				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
				//PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);
				
				// If NON Medic can see ragdoll and using healthkit
				if (fDistance < fReviveDistance && (ClientCanSeeVector(iMedic, fRagPos, fReviveDistance)) 
					&& ((StrContains(sWeapon, "weapon_healthkit") > -1))
				)
				{
					//PrintToServer("[REVIVE_DEBUG] Distance from %N to %N is %f Seconds %d", iInjured, iMedic, fDistance, g_iReviveNonMedicRemainingTime[iInjured]);		
					decl String:sBuf[255];
					
					// Need more time to reviving
					if (g_iReviveNonMedicRemainingTime[iInjured] > 0)
					{

						//PrintToServer("NONMEDIC HAS TIME");
						if (g_playerWoundType[iInjured] == 0 || g_playerWoundType[iInjured] == 1 || g_playerWoundType[iInjured] == 2)
						{
							decl String:woundType[64];
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
						// else if (g_playerWoundType[iInjured] == 1 || g_playerWoundType[iInjured] == 2)
						// {
						// 	decl String:woundType[64];
						// 	if (g_playerWoundType[iInjured] == 1)
						// 		woundType = "moderately wounded";
						// 	else if (g_playerWoundType[iInjured] == 2)
						// 		woundType = "critically wounded";
						// 	// Hint to NonMedic
						// 	Format(sBuf, 255,"%N is %s and can only be revived by a medic!", iInjured, woundType);
						// 	PrintHintText(iMedic, "%s", sBuf);
						// }
						//prevent respawn while reviving
						g_iRespawnTimeRemaining[iInjured]++;
					}
					// Revive player
					else if (g_iReviveNonMedicRemainingTime[iInjured] <= 0)
					{	
						decl String:woundType[64];
						if (g_playerWoundType[iInjured] == 0)
							woundType = "minor wound";
						else if (g_playerWoundType[iInjured] == 1)
							woundType = "moderate wound";
						else if (g_playerWoundType[iInjured] == 2)
							woundType = "critical wound";

						// Chat to all
						Format(sBuf, 255,"\x05%N\x01 revived \x03%N from a %s", iMedic, iInjured, woundType);
						PrintToChatAll("%s", sBuf);
						
						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s", iInjured, woundType);
						PrintHintText(iMedic, "%s", sBuf);
						
						// Hint to victim
						Format(sBuf, 255,"%N revived you from a %s", iMedic, woundType);
						PrintHintText(iInjured, "%s", sBuf);
						
						// Add kill bonus to iMedic
						// new iBonus = GetConVarInt(sm_revive_bonus);
						// new iScore = GetClientFrags(iMedic) + iBonus;
						// SetEntProp(iMedic, Prop_Data, "m_iFrags", iScore);
						
						
						/////////////////////////
						// Rank System
						g_iStatRevives[iMedic]++;
						//
						/////////////////////////
						
						//Accumulate a revive
						g_playerMedicRevivessAccumulated[iMedic]++;
						new iReviveCap = GetConVarInt(sm_revive_cap_for_bonus);

						// Hint to iMedic
						Format(sBuf, 255,"You revived %N from a %s | Revives remaining til bonus life: %d", iInjured, woundType, (iReviveCap - g_playerMedicRevivessAccumulated[iMedic]));
						PrintHintText(iMedic, "%s", sBuf);
						// Add score bonus to iMedic (doesn't work)
						//iScore = GetPlayerScore(iMedic);
						//PrintToServer("[SCORE] score: %d", iScore + 10);
						//SetPlayerScore(iMedic, iScore + 10);
						if (g_playerMedicRevivessAccumulated[iMedic] >= iReviveCap)
						{
							g_playerMedicRevivessAccumulated[iMedic] = 0;
							g_iSpawnTokens[iMedic]++;
							decl String:sBuf2[255];
							//if (iBonus > 1)
							//	Format(sBuf2, 255,"Awarded %i kills and %i score for revive", iBonus, 10);
							//else
							Format(sBuf2, 255,"Awarded %i life for reviving %d players", 1, iReviveCap);
							PrintToChat(iMedic, "%s", sBuf2);
						}

						
						// Update ragdoll position
						g_fRagdollPosition[iInjured] = fRagPos;
						
						//Reward nearby medics who asssisted
						Check_NearbyMedicsRevive(iMedic, iInjured);

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
public Action:Timer_MedicMonitor(Handle:timer)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Search medics
	for(new medic = 1; medic <= MaxClients; medic++)
	{
		if (!IsClientInGame(medic) || IsFakeClient(medic))
			continue;
		
		// Medic only can inspect health.
		new iTeam = GetClientTeam(medic);
		if (iTeam == TEAM_1_SEC && IsPlayerAlive(medic) && StrContains(g_client_last_classstring[medic], "medic") > -1)
		{
			// Target is teammate and alive.
			new iTarget = TraceClientViewEntity(medic);
			if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
			{
				// Check distance
				new bool:bCanHealPaddle = false;
				new bool:bCanHealMedpack = false;
				new Float:fReviveDistance = 80.0;
				new Float:vecMedicPos[3];
				new Float:vecTargetPos[3];
				new Float:tDistance;
				GetClientAbsOrigin(medic, Float:vecMedicPos);
				GetClientAbsOrigin(iTarget, Float:vecTargetPos);
				tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
				
				if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
				{
					// Check weapon
					new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
					if (ActiveWeapon < 0)
						continue;
					decl String:sWeapon[32];
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
				new iHealth = GetClientHealth(iTarget);

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
						new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
						new iRewardMedicEnabled = GetConVarInt(sm_reward_medics_enabled);
						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							// new iBonus = GetConVarInt(sm_heal_bonus);
							// new iScore = GetClientFrags(medic) + iBonus;
							// SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
							g_iSpawnTokens[medic]++;
							decl String:sBuf2[255];
							// if (iBonus > 1)
							// 	Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
							// else
							Format(sBuf2, 255,"Awarded %i life for healing %i in HP of other players.", 1, iHealthCap);
							
							PrintToChat(medic, "%s", sBuf2);
						}
						
						if (iHealth >= 100)
						{
							////////////////////////
							// Rank System
							g_iStatHeals[medic]++;
							//
							////////////////////////

							iHealth = 100;
							//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
							PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
							decl String:sBuf[255];
							Format(sBuf, 255,"You fully healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerMedicHealsAccumulated[medic]));
							PrintHintText(medic, "%s", sBuf);
							PrintToChat(medic, "%s", sBuf);
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
						new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
						new iRewardMedicEnabled = GetConVarInt(sm_reward_medics_enabled);
						//Reward player for healing
						if (g_playerMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
						{
							g_playerMedicHealsAccumulated[medic] = 0;
							// new iBonus = GetConVarInt(sm_heal_bonus);
							// new iScore = GetClientFrags(medic) + iBonus;
							// SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
							g_iSpawnTokens[medic]++;
							decl String:sBuf2[255];
							// if (iBonus > 1)
							// 	Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
							// else
							Format(sBuf2, 255,"Awarded %i life for healing %i in HP of other players.", 1, iHealthCap);
							
							PrintToChat(medic, "%s", sBuf2);
						}

						if (iHealth >= 100)
						{
							////////////////////////
							// Rank System
							g_iStatHeals[medic]++;
							//
							////////////////////////
							iHealth = 100;
							
							//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
							PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
							PrintHintText(iTarget, "You were healed by %N (HP: %i)", medic, iHealth);
							decl String:sBuf[255];
							Format(sBuf, 255,"You fully healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerMedicHealsAccumulated[medic]));
							PrintHintText(medic, "%s", sBuf);
							PrintToChat(medic, "%s", sBuf);
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
				new bool:bCanHealMedpack = false;
				new bool:bCanHealPaddle = false;
				
				// Check weapon
				new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;
				decl String:sWeapon[32];
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
				new iHealth = GetClientHealth(medic);
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
			new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
			if (ActiveWeapon < 0)
				continue;
			decl String:checkWeapon[32];
			GetEdictClassname(ActiveWeapon, checkWeapon, sizeof(checkWeapon));
			if ((StrContains(checkWeapon, "weapon_healthkit") > -1))
			{
				// Target is teammate and alive.
				new iTarget = TraceClientViewEntity(medic);
				if(iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && iTeam == GetClientTeam(iTarget))
				{
					// Check distance
					new bool:bCanHealMedpack = false;
					new Float:fReviveDistance = 80.0;
					new Float:vecMedicPos[3];
					new Float:vecTargetPos[3];
					new Float:tDistance;
					GetClientAbsOrigin(medic, Float:vecMedicPos);
					GetClientAbsOrigin(iTarget, Float:vecTargetPos);
					tDistance = GetVectorDistance(vecMedicPos,vecTargetPos);
					
					if (tDistance < fReviveDistance && ClientCanSeeVector(medic, vecTargetPos, fReviveDistance))
					{
						// Check weapon
						new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
						if (ActiveWeapon < 0)
							continue;

						decl String:sWeapon[32];
						GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
						if ((StrContains(sWeapon, "weapon_healthkit") > -1))
						{
							bCanHealMedpack = true;
						}
					}
					// Check heal
					new iHealth = GetClientHealth(iTarget);

					if (tDistance < 750.0) 
					{
						PrintHintText(medic, "%N\nHP: %i", iTarget, iHealth);
					}
					if (bCanHealMedpack)
					{
						if (iHealth < g_nonMedic_maxHealOther)
						{
							iHealth += g_nonMedicHeal_amount;
							g_playerNonMedicHealsAccumulated[medic] += g_nonMedicHeal_amount;
							new iHealthCap = GetConVarInt(sm_heal_cap_for_bonus);
							new iRewardMedicEnabled = GetConVarInt(sm_reward_medics_enabled);
							//Reward player for healing
							if (g_playerNonMedicHealsAccumulated[medic] >= iHealthCap && iRewardMedicEnabled == 1)
							{
								g_playerNonMedicHealsAccumulated[medic] = 0;
								// new iBonus = GetConVarInt(sm_heal_bonus);
								// new iScore = GetClientFrags(medic) + iBonus;
								// SetEntProp(medic, Prop_Data, "m_iFrags", iScore);
								g_iSpawnTokens[medic]++;
								decl String:sBuf2[255];
								// if (iBonus > 1)
								// 	Format(sBuf2, 255,"Awarded %i kills for healing %i in HP of other players.", iBonus, iHealthCap);
								// else
								Format(sBuf2, 255,"Awarded %i life for healing %i in HP of other players.", 1, iHealthCap);
								
								PrintToChat(medic, "%s", sBuf2);
							}

							if (iHealth >= g_nonMedic_maxHealOther)
							{
								////////////////////////
								// Rank System
								g_iStatHeals[medic]++;
								//
								////////////////////////
								iHealth = g_nonMedic_maxHealOther;
								
								//Client_PrintToChatAll(false, "{OG}%N{N} healed {OG}%N", medic, iTarget);
								//PrintToChatAll("\x05%N\x01 healed \x05%N", medic, iTarget);
								PrintHintText(iTarget, "Non-Medic %N can only heal you for %i HP!)", medic, iHealth);
								
								decl String:sBuf[255];
								Format(sBuf, 255,"You max healed %N | Health points remaining til bonus life: %d", iTarget, (iHealthCap - g_playerNonMedicHealsAccumulated[medic]));
								PrintHintText(medic, "%s", sBuf);
								PrintToChat(medic, "%s", sBuf);
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
					new bool:bCanHealMedpack = false;
					
					// Check weapon
					new ActiveWeapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
					if (ActiveWeapon < 0)
						continue;
					decl String:sWeapon[32];
					GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

					if ((StrContains(sWeapon, "weapon_healthkit") > -1))
					{
						bCanHealMedpack = true;
					}
					
					// Check heal
					new iHealth = GetClientHealth(medic);
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
 
// public Action:Timer_ElitePeriodTick(Handle:timer, any:data)
// {
// 	new fTempTime = 
// 	if (g_elitePeriod == 0)
// 	{


// 	}

// }

public Action:Timer_VIPCheck_Main(Handle:timer, any:data)
{
	//Only count down if not in counter
	if (!Ins_InCounterAttack() && g_vip_obj_count >= 0)
		g_vip_obj_count--;

	//PrintToServer("[VIP] g_vip_obj_count: %i ", g_vip_obj_count);

	decl String:textToPrintChat[128];
	//decl String:textToPrint[64];
	// Announce every 10 seconds
	if (g_vip_obj_count > 0 && (g_vip_obj_count % 45 == 0 || g_vip_obj_count < 4 || g_vip_obj_count == 10 || g_vip_obj_count == 20))
	{				
		
		//Format(textToPrint, sizeof(textToPrint), "Capture point with VIP in %d second to receive bonus supply!", g_vip_obj_count);
		Format(textToPrintChat, sizeof(textToPrintChat), "\x04VIP\x01 must be capture next point within %d second(s) for team to receive bonus supply!", g_vip_obj_count);
		PrintToChatAll("Destroyable objectives should work as well.");
		//PrintHintTextToAll(textToPrint);
		PrintToChatAll(textToPrintChat);
		if (g_nVIP_ID == 0)
		{
			Format(textToPrintChat, sizeof(textToPrintChat), "No \x04VIP\x01 on team | Supply points will not be granted for capturing objectives.");
			//PrintHintTextToAll(textToPrint);
			PrintToChatAll(textToPrintChat);
		}
	}
	if (g_vip_obj_count == 0 && g_vip_obj_ready != 0)
	{
		g_vip_obj_ready = 0;
		PrintToChatAll("\x04VIP\x01 failed to capture point within allotted time of %d seconds.", g_iCvar_vip_obj_time);

		if (g_nVIP_ID == 0)
		{
			Format(textToPrintChat, sizeof(textToPrintChat), "No \x04VIP\x01 on team | Supply points will not be granted.");
			//PrintHintTextToAll(textToPrint);
			PrintToChatAll(textToPrintChat);
		}
	}
}

//Main AI Director Tick
public Action:Timer_AIDirector_Main(Handle:timer, any:data)
{
	g_AIDir_AnnounceCounter++;
	g_AIDir_ChangeCond_Counter++;
	g_AIDir_AmbushCond_Counter++;
	
	//Ambush Reinforcement Chance
	new tAmbushChance = GetRandomInt(0, 100);

	//AI Director DEBUG
	if (g_AIDir_AnnounceCounter >= g_AIDir_AnnounceTrig)
	{
		g_AIDir_AnnounceCounter = 0;
		new tIsInCounter = 0;
		if (Ins_InCounterAttack())
			tIsInCounter = 1;

		PrintToServer("[AI_DIRECTOR] STATUS: %i | g_AIDir_CurrDiff %d | InCounter: %d | DiffChanceBase: %d", g_AIDir_TeamStatus, g_AIDir_CurrDiff, tIsInCounter, g_AIDir_DiffChanceBase);
		PrintToServer("[AI_DIRECTOR]: Ambush_Counter: %d | tAmbushChance: %d | AmbushCond_Chance %d",g_AIDir_AmbushCond_Counter, tAmbushChance, g_AIDir_AmbushCond_Chance);
		PrintToServer("[AI_DIRECTOR]: AmbushCond_Chance: %d | ChangeCond_Counter: %d | ChangeCond_Rand %d",g_AIDir_AmbushCond_Rand, g_AIDir_ChangeCond_Counter, g_AIDir_ChangeCond_Rand);
			
	}

	//AI Director Set Difficulty
	if (g_AIDir_ChangeCond_Counter >= g_AIDir_ChangeCond_Rand)
	{
		g_AIDir_ChangeCond_Counter = 0;
		g_AIDir_ChangeCond_Rand = GetRandomInt(g_AIDir_ChangeCond_Min, g_AIDir_ChangeCond_Max);
		PrintToServer("[AI_DIRECTOR] STATUS: %i | SetDifficulty CALLED", g_AIDir_TeamStatus);
		AI_Director_SetDifficulty(g_AIDir_TeamStatus, g_AIDir_TeamStatus_max);
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
			PrintToServer("[AI_DIRECTOR]: tAmbushChance: %d | g_AIDir_AmbushCond_Chance %d", tAmbushChance, g_AIDir_AmbushCond_Chance);
			//Reset
			g_AIDir_AmbushCond_Counter = 0;
			g_AIDir_AmbushCond_Rand = GetRandomInt(g_AIDir_AmbushCond_Min, g_AIDir_AmbushCond_Max);
		}
	}

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");
	
	//Confirm percent finale
	if ((acp+1) == ncp)
	{
		if (g_finale_counter_spec_enabled == 1)
				g_dynamicSpawnCounter_Perc = g_finale_counter_spec_percent;
	}

	return Plugin_Continue;

}

public Action:Timer_AmmoResupply(Handle:timer, any:data)
{
	if (g_iRoundStatus == 0) return Plugin_Continue;
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
			continue;
		new team = GetClientTeam(client); 
		// Valid medic?
		if (IsPlayerAlive(client) && team == TEAM_1_SEC)
		{
			new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if (ActiveWeapon < 0)
				continue;

			// Get weapon class name
			decl String:sWeapon[32];
			GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
			if (GetClientButtons(client) & INS_RELOAD && ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1)))
			{
				new validAmmoCache = -1;
				validAmmoCache = FindValidProp_InDistance(client);
				//PrintToServer("validAmmoCache: %d", validAmmoCache);
				if (validAmmoCache != -1)
				{
					g_resupplyCounter[client] -= 1;
					if (g_ammoResupplyAmt[validAmmoCache] <= 0)
					{
						new secTeamCount = GetTeamSecCount();
						g_ammoResupplyAmt[validAmmoCache] = (secTeamCount / 3);
						if (g_ammoResupplyAmt[validAmmoCache] <= 1)
						{
							g_ammoResupplyAmt[validAmmoCache] = 1;
						}

					}
					decl String:sBuf[255];
					// Hint to client
					Format(sBuf, 255,"Resupplying ammo in %d seconds | Supply left: %d", g_resupplyCounter[client], g_ammoResupplyAmt[validAmmoCache]);
					PrintHintText(client, "%s", sBuf);
					if (g_resupplyCounter[client] <= 0)
					{
						g_resupplyCounter[client] = GetConVarInt(sm_resupply_delay);
						//Spawn player again
						AmmoResupply_Player(client, 0, 0, 0);
						

						g_ammoResupplyAmt[validAmmoCache] -= 1;
						if (g_ammoResupplyAmt[validAmmoCache] <= 0)
						{
							if(validAmmoCache != -1)
								AcceptEntityInput(validAmmoCache, "kill");
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
}

public AmmoResupply_Player(client, primaryRemove, secondaryRemove, grenadesRemove)
{

	new Float:plyrOrigin[3];
	new Float:tempOrigin[3];
	GetClientAbsOrigin(client,plyrOrigin);
	tempOrigin = plyrOrigin;
	tempOrigin[2] = -5000;

	//TeleportEntity(client, tempOrigin, NULL_VECTOR, NULL_VECTOR);
	//ForcePlayerSuicide(client);
	// Get dead body
	new clientRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	
	//This timer safely removes client-side ragdoll
	if(clientRagdoll > 0 && IsValidEdict(clientRagdoll) && IsValidEntity(clientRagdoll))
	{
		// Get dead body's entity
		new ref = EntIndexToEntRef(clientRagdoll);
		new entity = EntRefToEntIndex(ref);
		if(entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
		{
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
}
//Find Valid Prop
public RemoveWeapons(client, primaryRemove, secondaryRemove, grenadesRemove)
{

	new primaryWeapon = GetPlayerWeaponSlot(client, 0);
	new secondaryWeapon = GetPlayerWeaponSlot(client, 1);
	new playerGrenades = GetPlayerWeaponSlot(client, 3);

	// Check and remove primaryWeapon
	if (primaryWeapon != -1 && IsValidEntity(primaryWeapon) && primaryRemove == 1) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	{
		// Remove primaryWeapon
		decl String:weapon[32];
		GetEntityClassname(primaryWeapon, weapon, sizeof(weapon));
		RemovePlayerItem(client,primaryWeapon);
		AcceptEntityInput(primaryWeapon, "kill");
	}
	// Check and remove secondaryWeapon
	if (secondaryWeapon != -1 && IsValidEntity(secondaryWeapon) && secondaryRemove == 1) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	{
		// Remove primaryWeapon
		decl String:weapon[32];
		GetEntityClassname(secondaryWeapon, weapon, sizeof(weapon));
		RemovePlayerItem(client,secondaryWeapon);
		AcceptEntityInput(secondaryWeapon, "kill");
	}
	// Check and remove grenades
	if (playerGrenades != -1 && IsValidEntity(playerGrenades) && grenadesRemove == 1) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 13
	{
		while (playerGrenades != -1 && IsValidEntity(playerGrenades)) // since we only have 3 slots in current theate
		{
			playerGrenades = GetPlayerWeaponSlot(client, 3);
			if (playerGrenades != -1 && IsValidEntity(playerGrenades)) // We need to figure out what slots are defined#define Slot_HEgrenade 11, #define Slot_Flashbang 12, #define Slot_Smokegrenade 1
			{
				// Remove grenades
				decl String:weapon[32];
				GetEntityClassname(playerGrenades, weapon, sizeof(weapon));
				RemovePlayerItem(client,playerGrenades);
				AcceptEntityInput(playerGrenades, "kill");
				
			}
		}
	}
}
//Find Valid Prop
public FindValidProp_InDistance(client)
{

	new prop;
	while ((prop = FindEntityByClassname(prop, "prop_dynamic_override")) != -1)
	{
		new String:propModelName[128];
		GetEntPropString(prop, Prop_Data, "m_ModelName", propModelName, 128);
		//PrintToChatAll("propModelName %s", propModelName);
		if (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl") || StrContains(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl") > -1)
		{
			new Float:tDistance = (GetEntitiesDistance(client, prop));
			if (tDistance <= (GetConVarInt(sm_ammo_resupply_range)))
			{
				return prop;
			}
		}

	}
	return -1;
}
stock AI_Director_IsSpecialtyBot(client)
{
	if (IsFakeClient(client) && ((StrContains(g_client_last_classstring[client], "bomber") > -1) || (StrContains(g_client_last_classstring[client], "juggernaut") > -1)))
		return true;
	else
		return false;
}
stock Float:GetEntitiesDistance(ent1, ent2)
{
	new Float:orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	new Float:orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);

	return GetVectorDistance(orig1, orig2);
} 
public Action:Timer_AmbientRadio(Handle:timer, any:data)
{
	if (g_iRoundStatus == 0) return Plugin_Continue;
	for (new client = 1; client <= MaxClients; client++)
	{

		if (!IsClientInGame(client) || IsFakeClient(client))
			continue;
		
		new team = GetClientTeam(client); 
		// Valid medic?
		if (IsPlayerAlive(client) && ((StrContains(g_client_last_classstring[client], "squadleader") > -1) || (StrContains(g_client_last_classstring[client], "teamleader") > -1)) && team == TEAM_1_SEC)
		{


			new fRandomChance = GetRandomInt(1, 100);
			if (fRandomChance < 50)
			{	
				new Handle:hDatapack;
				new fRandomFloat = GetRandomFloat(1.0, 30.0);
				//CreateTimer(fRandomFloat, Timer_PlayAmbient);
				CreateDataTimer(fRandomFloat, Timer_PlayAmbient, hDatapack);
				WritePackCell(hDatapack, client);
			}
		}
	}
	return Plugin_Continue;


}
public Action:Timer_PlayAmbient(Handle:timer, Handle:hDatapack)
{

	ResetPack(hDatapack);
	new client = ReadPackCell(hDatapack);
				//PrintToServer("PlaySound");
	switch(GetRandomInt(1, 18))
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
		case 11: EmitSoundToAll("sernx_lua_sounds/radio/radio1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 12: EmitSoundToAll("sernx_lua_sounds/radio/radio2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 13: EmitSoundToAll("sernx_lua_sounds/radio/radio3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 14: EmitSoundToAll("sernx_lua_sounds/radio/radio4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 15: EmitSoundToAll("sernx_lua_sounds/radio/radio5.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 16: EmitSoundToAll("sernx_lua_sounds/radio/radio6.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 17: EmitSoundToAll("sernx_lua_sounds/radio/radio7.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
		case 18: EmitSoundToAll("sernx_lua_sounds/radio/radio8.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
	}
	return Plugin_Continue;

}
// Check for nearest player
public Action:Timer_NearestBody(Handle:timer, any:data)
{
	// Check round state
	if (g_iRoundStatus == 0) return Plugin_Continue;
	
	// Variables to store
	new Float:fMedicPosition[3];
	new Float:fMedicAngles[3];
	new Float:fInjuredPosition[3];
	new Float:fNearestDistance;
	new Float:fTempDistance;

	// iNearestInjured client
	new iNearestInjured;
	
	decl String:sDirection[64];
	decl String:sDistance[64];
    decl String:sHeight[6];

	// Client loop
	for (new medic = 1; medic <= MaxClients; medic++)
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
			for (new search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search))
					continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					new clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
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
				new Float:beamPos[3];
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
			for (new search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || IsFakeClient(search) || IsPlayerAlive(search))
					continue;
				
				// Check if valid
				if (g_iHurtFatal[search] == 0 && search != medic && GetClientTeam(medic) == GetClientTeam(search))
				{
					// Get found client's ragdoll
					new clientRagdoll = EntRefToEntIndex(g_iClientRagdolls[search]);
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


public Check_NearbyPlayers(enemyBot)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		{
			if (IsPlayerAlive(client))
			{
				new Float:botOrigin[3];
				new Float:clientOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(enemyBot,botOrigin);
				GetClientAbsOrigin(client,clientOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(botOrigin,clientOrigin);

				if (fDistance <= 600)
				{
					return true;
				}
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
String:GetDirectionString(Float:fClientAngles[3], Float:fClientPosition[3], Float:fTargetPosition[3])
{
	new
		Float:fTempAngles[3],
		Float:fTempPoints[3];
		
	decl String:sDirection[64];

	// Angles from origin
	MakeVectorFromPoints(fClientPosition, fTargetPosition, fTempPoints);
	GetVectorAngles(fTempPoints, fTempAngles);
	
	// Differenz
	new Float:fDiff = fClientAngles[1] - fTempAngles[1];
	
	// Correct it
	if (fDiff < -180)
		fDiff = 360 + fDiff;

	if (fDiff > 180)
		fDiff = 360 - fDiff;
	
	// Now geht the direction
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
String:GetDistanceString(Float:fDistance)
{
	// Distance to meters
	new Float:fTempDistance = fDistance * 0.01905;
	decl String:sResult[64];

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
String:GetHeightString(Float:fClientPosition[3], Float:fTargetPosition[3])
{
    decl String:s[6];
    
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
stock TagsCheck(const String:tag[], bool:remove = false)
{
	new Handle:hTags = FindConVar("sv_tags");
	decl String:tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (StrContains(tags, tag, false) == -1 && !remove)
	{
		decl String:newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		ReplaceString(newTags, sizeof(newTags), ",,", ",", false);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	else if (StrContains(tags, tag, false) > -1 && remove)
	{
		ReplaceString(tags, sizeof(tags), tag, "", false);
		ReplaceString(tags, sizeof(tags), ",,", ",", false);
		SetConVarString(hTags, tags);
	}
}

// Get tesm2 player count
stock GetTeamSecCount() {
	new clients = 0;
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

// Get real client count
stock GetRealClientCount( bool:inGameOnly = true ) {
	new clients = 0;
	for( new i = 1; i <= GetMaxClients(); i++ ) {
		if(((inGameOnly)?IsClientInGame(i):IsClientConnected(i)) && !IsFakeClient(i)) {
			clients++;
		}
	}
	return clients;
}

// Get insurgent team bot count
stock GetTeamInsCount() {
	new clients;
	for(new i = 1; i <= GetMaxClients(); i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i) && IsFakeClient(i)) {
			clients++;
		}
	}
	return clients;
}

// Get remaining life
stock GetRemainingLife()
{
	new iResult;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i > 0 && IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			if (g_iSpawnTokens[i] > 0)
				iResult = iResult + g_iSpawnTokens[i];
		}
	}
	
	return iResult;
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

// Get player score (works fine)
int GetPlayerScore(client)
{
	// Get player manager class
	new iPlayerManager, String:iPlayerManagerNetClass[32];
	iPlayerManager = FindEntityByClassname(0,"ins_player_manager");
	GetEntityNetClass(iPlayerManager, iPlayerManagerNetClass, sizeof(iPlayerManagerNetClass));
	
	// Check result
	if (iPlayerManager < 1)
	{
		//PrintToServer("[SCORE] Unable to find ins_player_manager");
		return -1;
	}
	
	// Debug result
	//PrintToServer("[SCORE] iPlayerManagerNetClass %s", iPlayerManagerNetClass);
	
	// Get player score structure
	new m_iPlayerScore = FindSendPropInfo(iPlayerManagerNetClass, "m_iPlayerScore");
	
	// Check result
	if (m_iPlayerScore < 1) {
		//PrintToServer("[SCORE] Unable to find ins_player_manager property m_iPlayerScore");
		return -1;
	}
	
	// Get score
	new iScore = GetEntData(iPlayerManager, m_iPlayerScore + (4 * client));
	
	return iScore;
}

// Set player score (doesn't work)	
void SetPlayerScore(client, iScore)
{
	// Get player manager class
	new iPlayerManager, String:iPlayerManagerNetClass[32];
	iPlayerManager = FindEntityByClassname(0,"ins_player_manager");
	GetEntityNetClass(iPlayerManager, iPlayerManagerNetClass, sizeof(iPlayerManagerNetClass));
	
	// Check result
	if (iPlayerManager < 1)
	{
		//PrintToServer("[SCORE] Unable to find ins_player_manager");
		return;
	}
	
	// Debug result
	//PrintToServer("[SCORE] iPlayerManagerNetClass %s", iPlayerManagerNetClass);
	
	// Get player score
	new m_iPlayerScore = FindSendPropInfo(iPlayerManagerNetClass, "m_iPlayerScore");
	
	// Check result
	if (m_iPlayerScore < 1) {
		//PrintToServer("[SCORE] Unable to find ins_player_manager property m_iPlayerScore");
		return;
	}
	
	// Set score
	SetEntData(iPlayerManager, m_iPlayerScore + (4 * client), iScore, _, true);
}

//Find Valid Antenna
public FindValid_Antenna()
{
	new prop;
	while ((prop = FindEntityByClassname(prop, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
	{
		new String:propModelName[128];
		GetEntPropString(prop, Prop_Data, "m_ModelName", propModelName, 128);
		if (StrEqual(propModelName, "models/sernix/ied_jammer/ied_jammer.mdl"))
		{
			return prop;
		}

	}
	return -1;
}
/*
########################LUA HEALING INTEGRATION######################
#	This portion of the script adds in health packs from Lua 		#
##############################START##################################
#####################################################################
*/
public Action:Event_GrenadeThrown(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new nade_id = GetEventInt(event, "entityid");
	if (nade_id > -1 && client > -1)
	{
		if (IsPlayerAlive(client))
		{
			decl String:grenade_name[32];
			GetEntityClassname(nade_id, grenade_name, sizeof(grenade_name));
			if (StrEqual(grenade_name, "healthkit"))
			{
				switch(GetRandomInt(1, 18))
				{
					case 1: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 2: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 3: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/need_backup3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 4: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/holdposition2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 5: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/holdposition3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 6: EmitSoundToAll("player/voice/radial/security/leader/unsuppressed/moving2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 7: EmitSoundToAll("player/voice/radial/security/leader/suppressed/backup3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 8: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 9: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 10: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 11: EmitSoundToAll("player/voice/radial/security/leader/suppressed/holdposition4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 12: EmitSoundToAll("player/voice/radial/security/leader/suppressed/moving3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 13: EmitSoundToAll("player/voice/radial/security/leader/suppressed/ontheway1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 14: EmitSoundToAll("player/voice/security/command/leader/located4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 15: EmitSoundToAll("player/voice/security/command/leader/setwaypoint1.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 16: EmitSoundToAll("player/voice/security/command/leader/setwaypoint2.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 17: EmitSoundToAll("player/voice/security/command/leader/setwaypoint3.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
					case 18: EmitSoundToAll("player/voice/security/command/leader/setwaypoint4.ogg", client, SNDCHAN_VOICE, _, _, 1.0);
				}
			}
		}
	}
}

//Healthkit Start

public OnEntityDestroyed(entity)
{
	if (entity > MaxClients)
	{
		decl String:classname[255];
		GetEntityClassname(entity, classname, 255);
		if (StrEqual(classname, "healthkit"))
		{
			StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		}
		if (!(StrContains(classname, "wcache_crate_01") > -1))
		{
			g_ammoResupplyAmt[entity] = 0; 
		}
    }
}

public OnEntityCreated(entity, const String:classname[])
{

	if (StrEqual(classname, "healthkit"))
	{
		new Handle:hDatapack;

		g_healthPack_Amount[entity] = g_medpack_health_amt;
		CreateDataTimer(Healthkit_Timer_Tickrate, Healthkit, hDatapack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(hDatapack, entity);
		WritePackFloat(hDatapack, GetGameTime()+Healthkit_Timer_Timeout);
		g_fLastHeight[entity] = -9999.0;
		g_iTimeCheckHeight[entity] = -9999;
		SDKHook(entity, SDKHook_VPhysicsUpdate, HealthkitGroundCheck);
		CreateTimer(0.1, HealthkitGroundCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (StrEqual(classname, "grenade_m67") || StrEqual(classname, "grenade_f1"))
	{
		CreateTimer(0.5, GrenadeScreamCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (StrEqual(classname, "grenade_molotov") || StrEqual(classname, "grenade_anm14"))
		CreateTimer(0.2, FireScreamCheckTimer, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	

}
public Action:FireScreamCheckTimer(Handle:timer, any:entity)
{
	new Float:fGrenOrigin[3];
	new Float:fPlayerOrigin[3];
	new Float:fPlayerEyeOrigin[3];
	new owner;
	if (IsValidEntity(entity) && entity > 0)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fGrenOrigin);
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}
	else
		KillTimer(timer);


	
 
	for (new client = 1;client <= MaxClients;client++)
	{
		if (client <= 0 || !IsClientInGame(client) || !IsClientConnected(client))
			continue;
		if (owner <= 0 || !IsClientInGame(owner) || !IsClientConnected(owner))
			continue;
		if (IsFakeClient(client))
			continue;

		if (IsPlayerAlive(client) && GetClientTeam(client) == 2 && GetClientTeam(owner) == 3)
		{

			GetClientEyePosition(client, fPlayerEyeOrigin);
			GetClientAbsOrigin(client,fPlayerOrigin);
			//new Handle:trace = TR_TraceRayFilterEx(fPlayerEyeOrigin, fGrenOrigin, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter); 

			if (GetVectorDistance(fPlayerOrigin, fGrenOrigin) <= 300 &&  g_plyrFireScreamCoolDown[client] <= 0)// && TR_DidHit(trace) && fGrenOrigin[2] > 0)
			{
				//PrintToServer("SCREAM FIRE");
				PlayerFireScreamRand(client);
				new fRandomInt = GetRandomInt(20, 30);
				g_plyrFireScreamCoolDown[client] = fRandomInt;
				//CloseHandle(trace);  
			}
		}
	}

	if (!IsValidEntity(entity) || !(entity > 0))
		KillTimer(timer);
}
public Action:GrenadeScreamCheckTimer(Handle:timer, any:entity)
{
	new Float:fGrenOrigin[3];
	new Float:fPlayerOrigin[3];
	new Float:fPlayerEyeOrigin[3];
	new owner;
	if (IsValidEntity(entity) && entity > 0)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fGrenOrigin);
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}
	else
		KillTimer(timer);

	/*for (new client = 1;client <= MaxClients;client++)
	{
		if (client <= 0 || !IsClientInGame(client) || !IsClientConnected(client))
			continue;

		if (IsFakeClient(client))
			continue;

		if (client > 0 && IsPlayerAlive(client) && GetClientTeam(client) == 2 && GetClientTeam(owner) == 3)
		{

			GetClientEyePosition(client, fPlayerEyeOrigin);
			GetClientAbsOrigin(client,fPlayerOrigin);			
			//new Handle:trace = TR_TraceRayFilterEx(fPlayerEyeOrigin, fGrenOrigin, MASK_VISIBLE, RayType_EndPoint, Base_TraceFilter); 

			if (GetVectorDistance(fPlayerOrigin, fGrenOrigin) <= 240 &&  g_plyrGrenScreamCoolDown[client] <= 0)// && TR_DidHit(trace) && fGrenOrigin[2] > 0)
			{
				PlayerGrenadeScreamRand(client);
				new fRandomInt = GetRandomInt(6, 12);
				g_plyrGrenScreamCoolDown[client] = fRandomInt;
				//CloseHandle(trace); 
			} 
		}
	}*/

	if (!IsValidEntity(entity) || !(entity > 0))
		KillTimer(timer);
}
public Action:HealthkitGroundCheck(entity, activator, caller, UseType:type, Float:value)
{
	new Float:fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
	new iRoundHeight = RoundFloat(fOrigin[2]);
	if (iRoundHeight != g_iTimeCheckHeight[entity])
	{
		g_iTimeCheckHeight[entity] = iRoundHeight;
		g_fTimeCheck[entity] = GetGameTime();
	}
}

public Action:HealthkitGroundCheckTimer(Handle:timer, any:entity)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		new Float:fGameTime = GetGameTime();
		if (fGameTime-g_fTimeCheck[entity] >= 1.0)
		{
			new Float:fOrigin[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
			new iRoundHeight = RoundFloat(fOrigin[2]);
			if (iRoundHeight == g_iTimeCheckHeight[entity])
			{
				g_fTimeCheck[entity] = GetGameTime();
				SDKUnhook(entity, SDKHook_VPhysicsUpdate, HealthkitGroundCheck);
				SDKHook(entity, SDKHook_VPhysicsUpdate, OnEntityPhysicsUpdate);
				KillTimer(timer);
			}
		}
	}
	else KillTimer(timer);
}

public Action:OnEntityPhysicsUpdate(entity, activator, caller, UseType:type, Float:value)
{
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
}

public Action:Healthkit(Handle:timer, Handle:hDatapack)
{
	ResetPack(hDatapack);
	new entity = ReadPackCell(hDatapack);
	new Float:fEndTime = ReadPackFloat(hDatapack);
	new Float:fGameTime = GetGameTime();
	//PrintToServer("fGameTime %i",fGameTime);
	//PrintToServer("g_healthPack_Amount %i",g_healthPack_Amount[entity]);
	if (entity > 0 && IsValidEntity(entity) && fGameTime > fEndTime)
	{
		RemoveHealthkit(entity);
		KillTimer(timer);
		return Plugin_Stop;
	}
	if (g_healthPack_Amount[entity] > 0)
	{	
			//PrintToServer("DEBUG 1");
		if (entity > 0 && IsValidEntity(entity))
		{
			//PrintToServer("DEBUG 2");
			new Float:fOrigin[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
			if (g_fLastHeight[entity] == -9999.0)
			{
				g_fLastHeight[entity] = 0.0;
				//Play sound
				
				//PrintToServer("DEBUG 3");
			}
			fOrigin[2] += 1.0;
			TE_SetupBeamRingPoint(fOrigin, 1.0, Healthkit_Radius*1.95, g_iBeaconBeam, g_iBeaconHalo, 0, 30, 5.0, 3.0, 0.0, {0, 200, 0, 255}, 1, (FBEAM_FADEOUT));
			//void TE_SetupBeamRingPoint(const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
			TE_SendToAll();
			fOrigin[2] -= 16.0;
			if (fOrigin[2] != g_fLastHeight[entity])
			{
				g_fLastHeight[entity] = fOrigin[2];
			}
			else
			{
				new Float:fAng[3];
				GetEntPropVector(entity, Prop_Send, "m_angRotation", fAng);
				if (fAng[1] > 89.0 || fAng[1] < -89.0)
					fAng[1] = 90.0;
				if (fAng[2] > 89.0 || fAng[2] < -89.0)
				{
					fAng[2] = 0.0;
					fOrigin[2] -= 6.0;
					TeleportEntity(entity, fOrigin, fAng, Float:{0.0, 0.0, 0.0});
					fOrigin[2] += 6.0;
					EmitSoundToAll("ui/sfx/cl_click.wav", entity, SNDCHAN_VOICE, _, _, 1.0);
				}
			}
			for (new client = 1;client <= MaxClients;client++)
			{
				if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
				{
					//non medic area heal self
					if (!(StrContains(g_client_last_classstring[client], "medic") > -1))
					{ 
						decl Float:fPlayerOrigin[3];
						GetClientEyePosition(client, fPlayerOrigin);
						if (GetVectorDistance(fPlayerOrigin, fOrigin) <= Healthkit_Radius)
						{
									//PrintToServer("DEBUG 5");
							//g_medpack_health_amt
							new Handle:hData = CreateDataPack();
							WritePackCell(hData, entity);
							WritePackCell(hData, client);
							//fOrigin[2] += 6.0;
							//new Handle:trace = TR_TraceRayFilterEx(fPlayerOrigin, fOrigin, MASK_SOLID, RayType_EndPoint, Filter_ClientSelf, hData);
							CloseHandle(hData);
							new isMedicNearby = Check_NearbyMedics(client);
							//if (!TR_DidHit(trace))
							if (isMedicNearby)
							{	
									//PrintToServer("DEBUG 4");
								new iHealth = GetClientHealth(client);
								//new iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
								//new iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
								if (iHealth < 100)
								{
									//PrintToServer("DEBUG 6");
									iHealth += g_iHeal_amount_paddles;
									g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
									if (iHealth >= 100)
									{
										EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
										iHealth = 100;
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "A medic assisted in healing you (HP: %i)", iHealth);
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "Medic area healing you (HP: %i)", iHealth);
										switch(GetRandomInt(1, 6))
										{
											case 1: EmitSoundToAll("weapons/universal/uni_crawl_l_01.wav", client, SNDCHAN_VOICE, _, _, 1.0);
											case 2: EmitSoundToAll("weapons/universal/uni_crawl_l_04.wav", client, SNDCHAN_VOICE, _, _, 1.0);
											case 3: EmitSoundToAll("weapons/universal/uni_crawl_l_02.wav", client, SNDCHAN_VOICE, _, _, 1.0);
											case 4: EmitSoundToAll("weapons/universal/uni_crawl_r_03.wav", client, SNDCHAN_VOICE, _, _, 1.0);
											case 5: EmitSoundToAll("weapons/universal/uni_crawl_r_05.wav", client, SNDCHAN_VOICE, _, _, 1.0);
											case 6: EmitSoundToAll("weapons/universal/uni_crawl_r_06.wav", client, SNDCHAN_VOICE, _, _, 1.0);
										}
									}

									SetEntityHealth(client, iHealth);
								}
							}
							else
							{
									//PrintToServer("DEBUG 7");
								//Get weapon
								decl String:sWeapon[32];
								new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
								if (ActiveWeapon < 0)
									continue;

								GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
								new iHealth = GetClientHealth(client);
								if ((StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))
								{
									//PrintToServer("DEBUG 8");
									if (iHealth < g_nonMedicHealSelf_max)
									{
									//PrintToServer("DEBUG 9");
										iHealth += g_nonMedicHeal_amount;
										g_healthPack_Amount[entity] -= g_nonMedicHeal_amount;
										if (iHealth >= g_nonMedicHealSelf_max)
										{
									//PrintToServer("DEBUG 10");
											//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = g_nonMedicHealSelf_max;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Healing Self (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
										}

										SetEntityHealth(client, iHealth);
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_nonMedicHealSelf_max);
									}

								}
								else if (iHealth < g_nonMedicHealSelf_max && !(StrContains(sWeapon, "weapon_knife") > -1))
								{
										PrintHintText(client, "No medics nearby! Pull knife out to heal! (HP: %i)", iHealth);
								}
							}
							
						}
					} //Medic assist area heal and self heal
					else if ((StrContains(g_client_last_classstring[client], "medic") > -1))
					{
						 decl Float:fPlayerOrigin[3];
						GetClientEyePosition(client, fPlayerOrigin);
						if (GetVectorDistance(fPlayerOrigin, fOrigin) <= Healthkit_Radius)
						{
							//g_medpack_health_amt
							new Handle:hData = CreateDataPack();
							WritePackCell(hData, entity);
							WritePackCell(hData, client);
							fOrigin[2] += 32.0;
							//new Handle:trace = TR_TraceRayFilterEx(fPlayerOrigin, fOrigin, MASK_SOLID, RayType_EndPoint, Filter_ClientSelf, hData);
							CloseHandle(hData);

							new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
							if (ActiveWeapon < 0)
								continue;

							// Get weapon class name
							decl String:sWeapon[32];
							GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
							new bool:bCanHealPaddle = false;
							if (((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1)))
							{
								//PrintToServer("DEBUG 3");
								new iHealth = GetClientHealth(client);
								//new iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
								//new iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
								if (Check_NearbyMedics(client))
								{
									if (iHealth < 100)
									{
										iHealth += g_iHeal_amount_paddles;
										g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
										if (iHealth >= 100)
										{
											//EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = 100;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "A medic assisted in healing you (HP: %i)", iHealth);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Self area healing (HP: %i)", iHealth);
										}

										SetEntityHealth(client, iHealth);
									}
								}
								else
								{
									if (iHealth < g_medicHealSelf_max)
									{
										iHealth += g_iHeal_amount_paddles;
										g_healthPack_Amount[entity] -= g_iHeal_amount_paddles;
										if (iHealth >= g_medicHealSelf_max)
										{
											EmitSoundToAll("Lua_sounds/healthkit_complete.wav", client, SNDCHAN_STATIC, _, _, 1.0);
											iHealth = g_medicHealSelf_max;
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "You area healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
										}
										else 
										{
											PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
											PrintHintText(client, "Self area healing (HP: %i) | MAX %i", iHealth, g_medicHealSelf_max);
										}
									}
									else 
									{
										PrintCenterText(client, "Medical Pack HP Left: %i", g_healthPack_Amount[entity]);
										PrintHintText(client, "You healed yourself (HP: %i) | MAX: %i", iHealth, g_medicHealSelf_max);
									}
								}
							}
						}
					}
				}
			}
		}
		else
		{
			//PrintToServer("DEBUG 4");
			RemoveHealthkit(entity);
			KillTimer(timer);
		}
	}
	else if (g_healthPack_Amount[entity] <= 0)
	{
			//PrintToServer("DEBUG 5");
		RemoveHealthkit(entity);
		KillTimer(timer);
	}
	return Plugin_Continue;
}




public bool:Filter_ClientSelf(entity, contentsMask, any:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	new player = ReadPackCell(data);
	if (entity != client && entity != player)
		return true;
	return false;
}

public RemoveHealthkit(entity)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		//StopSound(entity, SNDCHAN_STATIC, "Lua_sounds/healthkit_healing.wav");
		//EmitSoundToAll("soundscape/emitters/oneshot/radio_explode.ogg", entity, SNDCHAN_STATIC, _, _, 1.0);
		
		//new dissolver = CreateEntityByName("env_entity_dissolver");
		//if (dissolver != -1)
		//{
			// DispatchKeyValue(dissolver, "dissolvetype", Healthkit_Remove_Type);
			// DispatchKeyValue(dissolver, "magnitude", "1");
			// DispatchKeyValue(dissolver, "target", "!activator");
			// AcceptEntityInput(dissolver, "Dissolve", entity);
			// AcceptEntityInput(dissolver, "Kill");

			AcceptEntityInput(entity, "Kill");
		//}
	}
}

public Check_NearbyMedics(client)
{
	for (new friendlyMedic = 1; friendlyMedic <= MaxClients; friendlyMedic++)
	{
		if (IsClientConnected(friendlyMedic) && IsClientInGame(friendlyMedic) && !IsFakeClient(friendlyMedic))
		{
			//PrintToServer("Medic 1");
			//new team = GetClientTeam(friendlyMedic);
			if (IsPlayerAlive(friendlyMedic) && (StrContains(g_client_last_classstring[friendlyMedic], "medic") > -1) && client != friendlyMedic)
			{
			//PrintToServer("Medic 2");
				//Get position of bot and prop
				new Float:plyrOrigin[3];
				new Float:medicOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(client,plyrOrigin);
				GetClientAbsOrigin(friendlyMedic,medicOrigin);
				//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(medicOrigin,plyrOrigin);
				
				new ActiveWeapon = GetEntPropEnt(friendlyMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;

				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

			//PrintToServer("Medic 3");
				new bool:bCanHealPaddle = false;
				if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1) || (StrContains(sWeapon, "weapon_healthkit") > -1))
				{
			//PrintToServer("Medic 4");
					bCanHealPaddle = true;
				}
				if (fDistance <= Healthkit_Radius && bCanHealPaddle)
				{
			//PrintToServer("Medic 5");
					return true;
				}
			}
		}
	}
	return false;
}

//This is to award nearby medics that participate in reviving a player
public Check_NearbyMedicsRevive(client, iInjured)
{
	for (new friendlyMedic = 1; friendlyMedic <= MaxClients; friendlyMedic++)
	{
		if (IsClientConnected(friendlyMedic) && IsClientInGame(friendlyMedic) && !IsFakeClient(friendlyMedic))
		{
			//PrintToServer("Medic 1");
			//new team = GetClientTeam(friendlyMedic);
			if (IsPlayerAlive(friendlyMedic) && (StrContains(g_client_last_classstring[friendlyMedic], "medic") > -1) && client != friendlyMedic)
			{
				//PrintToServer("Medic 2");
				//Get position of bot and prop
				new Float:medicOrigin[3];
				new Float:fDistance;
		
				GetClientAbsOrigin(friendlyMedic,medicOrigin);
				//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", propOrigin);
				
				//determine distance from the two
				fDistance = GetVectorDistance(medicOrigin,g_fRagdollPosition[iInjured]);
				
				new ActiveWeapon = GetEntPropEnt(friendlyMedic, Prop_Data, "m_hActiveWeapon");
				if (ActiveWeapon < 0)
					continue;

				// Get weapon class name
				decl String:sWeapon[32];
				GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));

				//PrintToServer("Medic 3");
				new bool:bCanHealPaddle = false;
				if ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1))
				{
					//PrintToServer("Medic 4");
					bCanHealPaddle = true;
				}

				new Float:fReviveDistance = 65.0;
				if (fDistance <= fReviveDistance && bCanHealPaddle)
				{

					decl String:woundType[64];
					if (g_playerWoundType[iInjured] == 0)
						woundType = "minor wound";
					else if (g_playerWoundType[iInjured] == 1)
						woundType = "moderate wound";
					else if (g_playerWoundType[iInjured] == 2)
						woundType = "critical wound";
					decl String:sBuf[255];
					// Chat to all
					Format(sBuf, 255,"\x05%N\x01 revived(assisted) \x03%N from a %s", friendlyMedic, iInjured, woundType);
					PrintToChatAll("%s", sBuf);
					
					// Add kill bonus to friendlyMedic
					// new iBonus = GetConVarInt(sm_revive_bonus);
					// new iScore = GetClientFrags(friendlyMedic) + iBonus;
					// SetEntProp(friendlyMedic, Prop_Data, "m_iFrags", iScore);
					
					/////////////////////////
					// Rank System
					g_iStatRevives[friendlyMedic]++;
					//
					/////////////////////////
					
					// Add score bonus to friendlyMedic (doesn't work)
					//iScore = GetPlayerScore(friendlyMedic);
					//PrintToServer("[SCORE] score: %d", iScore + 10);
					//SetPlayerScore(friendlyMedic, iScore + 10);

					//Accumulate a revive
					g_playerMedicRevivessAccumulated[friendlyMedic]++;
					new iReviveCap = GetConVarInt(sm_revive_cap_for_bonus);
					// Hint to friendlyMedic
					Format(sBuf, 255,"You revived(assisted) %N from a %s | Revives remaining til bonus life: %d", iInjured, woundType, (iReviveCap - g_playerMedicRevivessAccumulated[friendlyMedic]));
					PrintHintText(friendlyMedic, "%s", sBuf);

					if (g_playerMedicRevivessAccumulated[friendlyMedic] >= iReviveCap)
					{
						g_playerMedicRevivessAccumulated[friendlyMedic] = 0;
						g_iSpawnTokens[friendlyMedic]++;
						decl String:sBuf2[255];
						// if (iBonus > 1)
						// 	Format(sBuf2, 255,"Awarded %i kills and %i score for assisted revive", iBonus, 10);
						// else
						Format(sBuf2, 255,"Awarded %i life for reviving %d players", 1, iReviveCap);
						PrintToChat(friendlyMedic, "%s", sBuf2);
					}
				}
			}
		}
	}
}
/*
########################LUA HEALING INTEGRATION######################
#	This portion of the script adds in health packs from Lua 		#
##############################END####################################
#####################################################################
*/




stock Effect_SetMarkerAtPos(client,Float:pos[3],Float:intervall,color[4]){

	
	/*static Float:lastMarkerTime[MAXPLAYERS+1] = {0.0,...};
	new Float:gameTime = GetGameTime();
	
	if(lastMarkerTime[client] > gameTime){
		
		//no update cuz its already up2date
		return;
	}
	
	lastMarkerTime[client] = gameTime+intervall;*/
	
	new Float:start[3];
	new Float:end[3];
	//decl Float:worldMaxs[3];
	
	//World_GetMaxs(worldMaxs);
	
	end[0] = start[0] = pos[0];
	end[1] = start[1] = pos[1];
	end[2] = start[2] = pos[2];
	end[2] += 10000.0;
	start[2] += 5.0;
	
	//intervall -= 0.1;
	
	for(new effect=1;effect<=2;effect++){
		
		
		//blue team
		switch(effect){
			
			case 1:{
				TE_SetupBeamPoints(start, end, g_iBeaconBeam, 0, 0, 20, intervall, 1.0, 50.0, 0, 0.0, color, 0);
			}
			case 2:{
				TE_SetupBeamRingPoint(start, 50.0, 50.1, g_iBeaconBeam, g_iBeaconHalo, 0, 10, intervall, 2.0, 0.0, color, 10, 0);
			}
		}
		
		TE_SendToClient(client);
	}
}

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (client > 0) // Check the client is not console/world?
			if (IsValidClient(client))
			{
				new m_iTeam = GetClientTeam(client);
				if (!IsFakeClient(client) && m_iTeam == TEAM_SPEC)
				{
					//remove network ragdoll associated with player
					new playerRag = EntRefToEntIndex(g_iClientRagdolls[client]);
					if(playerRag > 0 && IsValidEdict(playerRag) && IsValidEntity(playerRag))
						RemoveRagdoll(client);
				}
				if((m_iTeam == TEAM_SPEC) && (client == g_nVIP_ID))
				{
					g_nVIP_ID = 0;
				}
			}

	return Plugin_Continue;
}


//############# AI DIRECTOR In-Script Functions START #######################


public AI_Director_ResetReinforceTimers() 
{
		//Set Reinforce Time
		g_iReinforceTime_AD_Temp = (g_AIDir_ReinforceTimer_Orig);
		g_iReinforceTimeSubsequent_AD_Temp = (g_AIDir_ReinforceTimer_SubOrig);
}
public AI_Director_SetDifficulty(g_AIDir_TeamStatus, g_AIDir_TeamStatus_max) 
{
	AI_Director_ResetReinforceTimers();

	//AI Director Local Scaling Vars
	new 
		AID_ReinfAdj_low = 10, AID_ReinfAdj_med = 20, AID_ReinfAdj_high = 30, AID_ReinfAdj_pScale = 0,
		Float:AID_SpecDelayAdj_low = 10, Float:AID_SpecDelayAdj_med = 20, Float:AID_SpecDelayAdj_high = 30, Float:AID_SpecDelayAdj_pScale_Pro = 0, Float:AID_SpecDelayAdj_pScale_Con = 0,
		AID_AmbChance_vlow = 10, AID_AmbChance_low = 15, AID_AmbChance_med = 20, AID_AmbChance_high = 25, AID_AmbChance_pScale = 0;
	new AID_SetDiffChance_pScale = 0;

	//Scale based on team count
	new tTeamSecCount = GetTeamSecCount();
	if (tTeamSecCount <= 6)
	{
		AID_ReinfAdj_pScale = 8;
		AID_SpecDelayAdj_pScale_Pro = 30;
		AID_SpecDelayAdj_pScale_Con = 10;
	}
	else if (tTeamSecCount >= 7 && tTeamSecCount <= 12)
	{
		AID_ReinfAdj_pScale = 4;
		AID_SpecDelayAdj_pScale_Pro = 20;
		AID_SpecDelayAdj_pScale_Con = 20;
		AID_AmbChance_pScale = 5;
		AID_SetDiffChance_pScale = 5;
	}
	else if (tTeamSecCount >= 13)
	{
		AID_ReinfAdj_pScale = 8;
		AID_SpecDelayAdj_pScale_Pro = 10;
		AID_SpecDelayAdj_pScale_Con = 30;
		AID_AmbChance_pScale = 10;
		AID_SetDiffChance_pScale = 10;
	}

	// Get the number of control points
	new ncp = Ins_ObjectiveResource_GetProp("m_iNumControlPoints");
	// Get active push point
	new acp = Ins_ObjectiveResource_GetProp("m_nActivePushPointIndex");

	new tAmbScaleMult = 2;
	if (ncp <= 5)
	{
		tAmbScaleMult = 3;
		AID_SetDiffChance_pScale += 5;
	}
	//Add More to Ambush chance based on what point we are at. 
	AID_AmbChance_pScale += (acp * tAmbScaleMult);
	AID_SetDiffChance_pScale += (acp * tAmbScaleMult);

	new Float:cvarSpecDelay = GetConVarFloat(sm_respawn_delay_team_ins_special);
	new fRandomInt = GetRandomInt(0, 100);


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
			g_fCvar_respawn_delay_team_ins_spec = 1;

		//DEBUG: Track Current Difficulty setting
		g_AIDir_CurrDiff = 5;

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
		g_AIDir_CurrDiff = 1;

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
			g_AIDir_CurrDiff = 2;

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
			g_AIDir_CurrDiff = 2;

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
			g_fCvar_respawn_delay_team_ins_spec = 1;

		//DEBUG: Track Current Difficulty setting
		g_AIDir_CurrDiff = 3;

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
			g_fCvar_respawn_delay_team_ins_spec = 1;

		//DEBUG: Track Current Difficulty setting
		g_AIDir_CurrDiff = 4;

		//Set Ambush Chance
		g_AIDir_AmbushCond_Chance = AID_AmbChance_high + AID_AmbChance_pScale;
	}
	//return g_AIDir_TeamStatus; 
}






//############# AI DIRECTOR In-Script END #######################


//############ ON BUTTON PRESS START ###########################

/*public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{

  if (!IsFakeClient(client))
  {
    //PrintToServer("BUTTON PRESS DEBUG RUNCMD");
    for (new i = 0; i < MAX_BUTTONS; i++)
    {
        new button = (1 << i);
        if ((buttons & button)) { 
    	     if (!(g_LastButtons[client] & button)) { 
                 OnButtonPress(client, button); 
             } 
         } else if ((g_LastButtons[client] & button)) { 
             OnButtonRelease(client, button); 
        }  
		         OnButtonPress(client, button, buttons); 
        }
    }
      
     g_LastButtons[client] = buttons;
  }
    return Plugin_Continue;
}

OnButtonPress(client, button, buttons)
{
	new ActiveWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

	if (ActiveWeapon < 0 || g_iRoundStatus == 0)
		return Plugin_Handled;


	// Get weapon class name
	/*decl String:sWeapon[32];
	GetEdictClassname(ActiveWeapon, sWeapon, sizeof(sWeapon));
	////PrintToServer("[KNIFE ONLY] CheckWeapon for iMedic %d named %N ActiveWeapon %d sWeapon %s",iMedic,iMedic,ActiveWeapon,sWeapon);

   if (GetGameTime()-g_fPlayerLastChat[client] >= 1.0 && (buttons & INS_DUCK || buttons & INS_PRONE) && (buttons & INS_RELOAD) && ((StrContains(sWeapon, "weapon_defib") > -1) || (StrContains(sWeapon, "weapon_knife") > -1) || (StrContains(sWeapon, "weapon_kabar") > -1)))// && !(buttons & IN_FORWARD) && !(buttons & IN_ATTACK2) && !(buttons & IN_ATTACK))// & !IN_ATTACK2) 
   {
		g_fPlayerLastChat[client] = GetGameTime();
				
		new team = GetClientTeam(client); 
		// Valid medic?
		if (IsPlayerAlive(client) && team == TEAM_1_SEC)
		{
				new iAimTarget = -1;
				iAimTarget = FindValidProp_InDistance(client);

			if (iAimTarget < 0)
				return Plugin_Stop;


			new Float:vOrigin[3], Float:vTargetOrigin[3];
			GetEntPropVector(iAimTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
			GetClientAbsOrigin(client, vTargetOrigin);

			new String:targetname[64];
			GetEntPropString(iAimTarget, Prop_Data, "m_iName", targetname, sizeof(targetname));
			new String:propModelName[64];
			GetEntPropString(iAimTarget, Prop_Data, "m_ModelName", propModelName, sizeof(propModelName));

			PrintToChat(client, "iAimTarget: %d | propModelName %s | targetname %s true %b", iAimTarget, propModelName, targetname, (StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl", true) > -1));
			if (ClientCanSeeVector(client, vOrigin, 100) && (GetVectorDistance(vOrigin, vTargetOrigin) <= 80.0) && StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl", false))
			{
				g_resupplyCounter[client] -= 1;
				new ammoStock = RoundToNearest(GetEntPropFloat(iAimTarget, Prop_Data, "m_flLocalTime"));
				if (g_ammoResupplyAmt[validAmmoCache] <= 0)
				{
					new secTeamCount = GetTeamSecCount();
					g_ammoResupplyAmt[validAmmoCache] = (secTeamCount / 3);
					if (g_ammoResupplyAmt[validAmmoCache] <= 1)
					{
						g_ammoResupplyAmt[validAmmoCache] = 1;
					}
				}

			decl String:sBuf[255];
				// Hint to client
				Format(sBuf, 255,"Resupplying ammo in %d seconds | Supply left: %d", g_resupplyCounter[client], ammoStock);
				PrintHintText(client, "%s", sBuf);

				//Controls loop interval

				if (g_resupplyCounter[client] <= 0)
				{
					
					ammoStock -= 1.0;
					if (ammoStock <= 0)
					{
						if(iAimTarget != -1)
							AcceptEntityInput(iAimTarget, "kill");
					}

					SetEntPropFloat(iAimTarget, Prop_Data, "m_flLocalTime", ammoStock);
					ammoStock = RoundToNearest(GetEntPropFloat(iAimTarget, Prop_Data, "m_flLocalTime"));
					Format(sBuf, 255,"Rearmed! Ammo Supply left: %d", ammoStock);
					
					PrintHintText(client, "%s", sBuf);
					PrintToChat(client, "%s", sBuf);

					g_resupplyCounter[client] = GetConVarInt(sm_resupply_delay);
					//Spawn player again
					//FakeClientCommand(client, "inventory_resupply");
					AmmoResupply_Player(client, 0, 0, 0);

				}
			}
			
		}
		
   	}
		return Plugin_Stop;

   	
}*/

//OnButtonRelease(client, button)
//{
  ////PrintToServer("BUTTON RELEASE");
  
    // do stuff
//}

//##################### ON BUTTON PRESS END ######################


//##################### ON PRE THINK START #######################

/*public SHook_OnPreThink(client)
{
	if (IsFakeClient(client))
		return;
	new team = GetClientTeam(client);
	if(IsClientInGame(client) && !IsClientTimingOut(client) && playerPickSquad[client] == 1 && IsPlayerAlive(client) && team == TEAM_1_SEC && g_iRoundStatus == 1)
	{
		if ((GetGameTime()-g_fPlayerLastChat[client] >= 1.0))
		{
			g_hintCoolDown[client] -= 1;
			new iAimTarget = GetClientAimTarget(client, false);
			if (iAimTarget < 0 || iAimTarget < MaxClients || FindDataMapInfo(iAimTarget, "m_ModelName") == -1)
				return;

			
			
			new String:propModelName[128];
			GetEntPropString(iAimTarget, Prop_Data, "m_ModelName", propModelName, 128);
			new Float:vOrigin[3], Float:vTargetOrigin[3];

			GetEntPropVector(iAimTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
			GetClientAbsOrigin(client, vTargetOrigin);
			//PrintToChatAll("g_hintCoolDown[client] %d | propModelName %s | Distance %d", g_hintCoolDown[client], propModelName, (GetVectorDistance(vOrigin, vTargetOrigin) <= 100.0));
			
			if (g_hintsEnabled[client] && g_hintCoolDown[client] <= 0 && (GetGameTime()-g_fPlayerLastChat[client] >= 1.0) && (GetVectorDistance(vOrigin, vTargetOrigin) <= 100.0) && StrEqual(propModelName, "models/sernix/ammo_cache/ammo_cache_small.mdl"))
			{

				g_hintCoolDown[client] = 30;
				g_fPlayerLastChat[client] = GetGameTime();
				DisplayInstructorHint(iAimTarget, 6.0, 0.0, 120.0, true, true, "icon_interact", "icon_interact", "", true, {255, 255, 255}, "Crouch (hold) and press RELOAD w/ knife to resupply");
				PrintHintText(client, "Crouch (hold) and press RELOAD w/ knife to resupply | toggle hints /hints");
				PrintToChat(client, "Crouch (hold) and press RELOAD w/ knife to resupply | toggle hints /hints");
			}


			decl String:targetname[128];
			GetEntPropString(iAimTarget, Prop_Data, "m_iName", targetname, sizeof(targetname));
			if ((StrContains(g_client_last_classstring[client], "engineer") > -1) && StrContains(targetname, "OMPropSpawnProp", true) != -1 && g_hintsEnabled[client] && g_hintCoolDown[client] <= 0 && 
				(GetGameTime()-g_fPlayerLastChat[client] >= 1.0) && (GetVectorDistance(vOrigin, vTargetOrigin) <= 100.0) && 
				(StrEqual(propModelName, "models/fortifications/barbed_wire_02b.mdl") || StrEqual(propModelName, "models/static_fortifications/sandbagwall01.mdl") || 
				StrEqual(propModelName, "models/static_fortifications/sandbagwall02.mdl")))
			{

				g_hintCoolDown[client] = 30;
				g_fPlayerLastChat[client] = GetGameTime();
				DisplayInstructorHint(iAimTarget, 6.0, 0.0, 3.0, true, true, "icon_interact", "icon_interact", "", true, {255, 255, 255}, "Press USE w/ knife out to repair (engineer only)");
				PrintHintText(client, "Press USE w/ knife out to repair (engineer only) | toggle hints /hints");
				PrintToChat(client, "Press USE w/ knife out to repair (engineer only) | toggle hints /hints");
			}

			g_fPlayerLastChat[client] = GetGameTime();
		}
		

	}
	else
		return;
}*/


//################## ON PRETHINK END #########################