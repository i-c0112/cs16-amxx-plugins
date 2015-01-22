/***************************************************
********* "ZP Level" by "[Mychat]i-c0112" **********
****************************************************
********** Editor's Log *****************************
**** v1.0: First Release.
**** v1.1: The DP things make caculation much faster.
	       stop supporting to save bots' data.
**** v1.1.2: Fixed some bug.
**** v2.0(Not yet): Added some special abilities
	       make this plugin more interesting.
****************************************************/




#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>
#include <zombieplague>


new PlayerXp[33], PlayerXpNext[33], PlayerLevel[33]
new cvar_maxlv, cvar_lvxp, cvar_hudmsg
new g_vault, g_sync, g_maxplayers
new g_dp[200] = {0, ...}
#define NVAULT_KEY "zp_level:id:%s"
#define NVAULT_DATA "%d"

#define checkXp(%1)									\
while (PlayerXp[%1] >= getXp(PlayerLevel[%1]+1))	\
	PlayerLevel[%1] ++;								\
if (PlayerLevel[%1] > get_pcvar_num(cvar_maxlv))	\
{													\
	PlayerLevel[%1] = get_pcvar_num(cvar_maxlv);	\
	PlayerXp[%1] = getXp(PlayerLevel[%1]+1);		\
	PlayerXpNext[%1] = PlayerXp[%1];				\
}													\
else												\
	PlayerXpNext[%1] = getXp(PlayerLevel[%1]+1);



getXp(level)
{
	if(1 <= level <= sizeof g_dp)
		return g_dp[level-1];

	new xp = 0
	//Lv1: 0/999 ; Lv2: 1000/1999
	while(level > sizeof g_dp)
	{
		level--
		xp += level * get_pcvar_num(cvar_lvxp)
	}
	return (xp + g_dp[(sizeof g_dp)-1]);
}



public plugin_init()
{
	g_vault = nvault_open("n_PlayerXp")
	register_plugin("升級插件", "1.1.2", "[MyChat]i-c0112")

	register_forward(FM_PlayerPostThink, "fw_PlayerPostThink", 1)

	RegisterHam(Ham_Killed, "player", "fw_Killed", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")

	cvar_maxlv = register_cvar("exp_maxlv", "200")
	cvar_lvxp = register_cvar("exp_xp_per_lv", "1000")
	cvar_hudmsg = register_cvar("exp_hudmsg", "1")

	g_sync = CreateHudSyncObj()
	g_maxplayers = get_maxplayers()

	for(new init = 1; init < sizeof g_dp; init++)
			g_dp[init] = g_dp[init-1] + init * get_pcvar_num(cvar_lvxp)
}

public plugin_end()
{
	nvault_close(g_vault);
}

public fw_PlayerPostThink(id)
{
	if (is_user_bot(id) || !is_user_alive(id)) return;
	static Float:hud_time
	if((get_gametime() - 2.0 > hud_time) && get_pcvar_num(cvar_hudmsg))
	{
		hud_time = get_gametime()
		set_hudmessage(175, 175, 80, 0.75, 0.8, 0, 0.0, 2.0, 0.1, 0.1, -1);
		ShowSyncHudMsg(id, g_sync, "LV.%d^nExp: %d / %d", PlayerLevel[id], PlayerXp[id], PlayerXpNext[id])
	}
}

public fw_Killed(victim, attacker, shouldgib)
{
	if (attacker == victim  || !is_user_connected(attacker) || !is_user_connected(victim))
		return HAM_IGNORED

	if (zp_get_user_zombie(victim) && !zp_get_user_zombie(attacker))
	{
		//server_print("Ham_Killed is called")
		PlayerXp[attacker] += 100
		new temp = PlayerLevel[attacker]
		checkXp(attacker)
		if(temp < PlayerLevel[attacker])
		{
			//client_print(attacker, print_chat, "升級至LV.%d  EXP: %d / %d", PlayerLevel[attacker], PlayerXp[attacker], PlayerXpNext[attacker])
			zp_colored_print(attacker, "^x04[ZP]^x01升級至LV.^x04%d^x01  EXP: ^x04%d ^x01/ ^x04%d", PlayerLevel[attacker], PlayerXp[attacker], PlayerXpNext[attacker])
		}
	}
	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if (victim == attacker || !is_user_connected(attacker) || !is_user_connected(victim))
		return HAM_IGNORED;
	if (zp_get_user_zombie(attacker) || !zp_get_user_zombie(victim))
		return HAM_IGNORED;

	damage *= 1.0 + float(PlayerLevel[attacker]) * 0.05
	SetHamParamFloat(4, damage)

	return HAM_IGNORED;
}


public client_putinserver(id)
{
	PlayerXp[id] = 0
	PlayerXpNext[id] = 0
	PlayerLevel[id] = 0

	static bool:debugged = false
	if(!debugged && is_user_bot(id))
	{
		debugged = true
		set_task(1.0, "_debug", id)
	}
	else if(!is_user_bot(id))
		LoadData(id)

	checkXp(id)
}

public client_disconnect(id)
{
	if(!is_user_bot(id))
	{
		SaveData(id)
		PlayerXp[id] = 0
		PlayerXpNext[id] = 0
		PlayerLevel[id] = 0
	}
}
SaveData(id)
{
	new xp = PlayerXp[id]
	LoadData(id)
	xp = max(xp, PlayerXp[id])	//max level and xp in game can be changed with cvar, but we don't low down our stats saved in nvault.

	new szName[32], szkey[64], szdata[128]

	get_user_name(id, szName, 31)
	formatex(szkey, 63, NVAULT_KEY, szName)
	formatex(szdata, 127, NVAULT_DATA, xp)

	nvault_set(g_vault, szkey, szdata)
}

LoadData(id)
{
	new szName[32], szkey[64]//, szdata[128]

	get_user_name(id, szName, 31)
	formatex(szkey, 63, NVAULT_KEY, szName)
	//formatex(szdata, 255, "%i#%i", PlayerXp[id], PlayerLevel[id])

	PlayerXp[id] = nvault_get(g_vault, szkey)

	/*
    replace_all(szdata, 127, "#", " ")
	new playerxp[64], playerlevel[64]
	parse(szdata, playerxp, 63, playerlevel, 63)
	PlayerLevel[id] = str_to_num(playerlevel)
	PlayerXp[id] = str_to_num(playerxp)
    */
}

public _debug(id)
{
	if(is_user_connected(id))
	{
		RegisterHamFromEntity(Ham_Killed, id, "fw_Killed", 1)
		RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage")
	}
}



// Stock by MeRcyLeZ
// Prints a colored message to target (use 0 for everyone), supports ML formatting.
// Note: I still need to make something like gungame's LANG_PLAYER_C to avoid unintended
// argument replacement when a function passes -1 (it will be considered a LANG_PLAYER)
zp_colored_print(target, const message[], any:...)
{
	new buffer[512], i, argscount
	argscount = numargs()

	// Send to everyone
	if (!target)
	{
		new player
		for (player = 1; player <= g_maxplayers; player++)
		{
			// Not connected
			if (!is_user_connected(player))
				continue;

			// Remember changed arguments
			new changed[5], changedcount // [5] = max LANG_PLAYER occurencies
			changedcount = 0

			// Replace LANG_PLAYER with player id
			for (i = 2; i < argscount; i++)
			{
				if (getarg(i) == LANG_PLAYER)
				{
					setarg(i, 0, player)
					changed[changedcount] = i
					changedcount++
				}
			}

			// Format message for player
			vformat(buffer, charsmax(buffer), message, 3)

			// Send it
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, player)
			write_byte(player)
			write_string(buffer)
			message_end()

			// Replace back player id's with LANG_PLAYER
			for (i = 0; i < changedcount; i++)
				setarg(changed[i], 0, LANG_PLAYER)
		}
	}
	// Send to specific target
	else
	{
		/*
		// Not needed since you should set the ML argument
		// to the player's id for a targeted print message

		// Replace LANG_PLAYER with player id
		for (i = 2; i < argscount; i++)
		{
			if (getarg(i) == LANG_PLAYER)
				setarg(i, 0, target)
		}
		*/

		// Format message for player
		vformat(buffer, charsmax(buffer), message, 3)

		// Send it
		message_begin(MSG_ONE, get_user_msgid("SayText"), _, target)
		write_byte(target)
		write_string(buffer)
		message_end()
	}
}