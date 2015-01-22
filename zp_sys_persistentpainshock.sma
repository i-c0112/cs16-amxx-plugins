/**
    --------------------
        Licensing Info
    --------------------

    To the extent possible under law,
    "i-c0112" has waived all copyright and related or neighboring rights to "Persistent PainShock".
    This work is published from: "Taiwan".
    For more information, see: http://creativecommons.org/publicdomain/zero/1.0/

**/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "Persistent PainShock"
#define VERSION "0.1.1"
#define AUTHOR "i-c0112"

#define DMG_BULLET (1<<1)

const OFFSET_PAINSHOCK = 108 // ConnorMcLeod (from forum AlliedModders)
const OFFSET_CSTEAMS = 114;

const OFFSETDIFF_LINUX = 5

new Float:g_fPainExp[33], g_ispain[33], Float:g_fZvel[33]
new g_zombie[33], g_nemesis[33], g_isalive[33], g_connected[33]

new g_hasHamCzBotReg
new cvar_paindur, cvar_czbotquota

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink_Post", 1)

    RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_Post", 1)
    RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", 1)
    RegisterHam(Ham_Killed, "player", "fw_Killed_Post", 1)
    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Post", 1)

    cvar_czbotquota = get_cvar_pointer("bot_quota")
    cvar_paindur = register_cvar("zp_zombie_stop_move_time", "0.2")
}

public fw_PlayerPreThink_Post(id)
{
    if(!g_isalive[id] || !g_zombie[id])
        return FMRES_IGNORED

    if(!g_ispain[id])
        return FMRES_IGNORED

    static Float:fCurTime
    global_get(glb_time, fCurTime)

    if(fCurTime >= g_fPainExp[id])
    {
        g_ispain[id] = false
        fm_set_user_painshock(id, 1.0);
        return FMRES_IGNORED
    }

    fm_set_user_painshock(id, 0.0)
    return FMRES_HANDLED
}

public fw_TakeDamage_Post(victim, inflictor, attacker, Float:damage, damage_type)
{
    if (!g_isalive[victim] || !g_zombie[victim] || g_nemesis[victim])
        return HAM_IGNORED

    if (!(damage_type & DMG_BULLET))
        return HAM_IGNORED

    static Float:fCurTime, Float:vel[3]
    global_get(glb_time, fCurTime)
    g_ispain[victim] = true
    g_fPainExp[victim] = fCurTime + get_pcvar_float(cvar_paindur)

    pev(victim, pev_velocity, vel)
    vel[0] = vel[1] = 0.0;
    if (!(pev(victim, pev_flags) & FL_ONGROUND))
        vel[2] = g_fZvel[victim]
    set_pev(victim, pev_velocity, vel)
    return HAM_HANDLED
}

public fw_Spawn_Post(id)
{
    // alive and joined?
    if (!is_user_alive(id) || !fm_cs_get_user_team(id))
        return HAM_IGNORED

    g_isalive[id] = true
    g_zombie[id] = false
    g_nemesis[id] = false
    g_ispain[id] = false

    // (bugfix): ZP plugin infect users when they respawn as zombie
    // but in the meanwhile every plugin loaded after ZP plugin is still waiting for call to their spawn forward
    // which results in "zp_user_infected_p* called before Ham_Spawn"
    if (zp_get_user_zombie(id))
        zp_user_infected_post(id, 0, zp_get_user_nemesis(id))

    return HAM_HANDLED
}

public fw_Killed_Post(victim, attacker, shouldgib)
{
    g_isalive[victim] = false
}

public fw_TraceAttack_Post(victim, attacker, Float:damage, Float:direction[3], trace_handle, damage_type)
{
    if (!g_isalive[victim] || !g_zombie[victim])
        return HAM_IGNORED
    if (pev(victim, pev_flags) & FL_ONGROUND)
        return HAM_IGNORED

    static Float:vel[3]
    pev(victim, pev_velocity, vel)
    g_fZvel[victim] = vel[2]
    return HAM_HANDLED
}

public zp_user_infected_post(id, infector, nemesis)
{
    g_zombie[id] = true
    g_nemesis[id] = nemesis
}

public client_putinserver(id)
{
    g_zombie[id] = false
    g_nemesis[id] = false
    g_ispain[id] = false

    g_connected[id] = true

    // is there any CZ bot?
    if (g_hasHamCzBotReg || !get_pcvar_num(cvar_czbotquota))
        return

    static classname[16]
    if (is_user_bot(id))
    {
        pev(id, pev_classname, classname, charsmax(classname))
        if (equal(classname, "player"))
            return

        // "set a task letting private data be initialized" (quoted from ZP v4.3 by "MeRcyLeZZ")
        set_task(0.1, "task_RegisterCzBot", id)
    }
}

public task_RegisterCzBot(id)
{
    // since task is executed after a short while of delay, checking things again is safer
    if (g_hasHamCzBotReg || !get_pcvar_num(cvar_czbotquota) || !g_connected[id])
        return

    if (!is_user_bot(id))
        return

    /* bugfix: at this time, the bot entity data is initialized and thus the classname is now player. So, checking classname here is unnecessary.
    static classname[16]
    pev(id, pev_classname, classname, charsmax(classname))
    if (equal(classname, "player"))
        return
    */

    RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage_Post", 1)
    RegisterHamFromEntity(Ham_Spawn, id, "fw_Spawn_Post", 1)
    RegisterHamFromEntity(Ham_Killed, id, "fw_Killed_Post", 1)
    RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Post", 1)

    g_hasHamCzBotReg = true

    // forward registered after delay might miss some event. (spawn event most probable) (we don't have ways to detect other missed events though)
    if (is_user_alive(id))
        fw_Spawn_Post(id)
}

public client_disconnect(id)
{
    g_connected[id] = false
    g_isalive[id] = false
}

stock fm_cs_get_user_team(id)
{
    return get_pdata_int(id, OFFSET_CSTEAMS, OFFSETDIFF_LINUX)
}

stock fm_set_user_painshock(id, Float:painshock)
{
    set_pdata_float(id, OFFSET_PAINSHOCK, painshock, OFFSETDIFF_LINUX)
}
