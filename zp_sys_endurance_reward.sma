/**
----------------------------------
-* [ZP]zombie:Endurance Reward *--
-* by i-c0112
-* V0.0.1 (2014/12/23)
----------------------------------
In maps where zombies can be easily taken down by large group of human in an open space,
the gameplay experience is so broken that none can actually enjoy the game.
This plugin however give the possibility for zombies to turn over by rewarding ammopacks to zombies that endure tons of damage.
So human would now think twice before wasting bullets and give zombies access to powerful extra items.

----------------------------------
---*     Licensing info      *----
----------------------------------
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

**/

// ========================
// ==== configuration =====
// ========================
#define DMG_THRESHOLD 2000
#define REWARD 4

#define COMBO
#if defined COMBO
#define COMBO_MAX 3
#define COMBO_MODE 0 // 0:linear, 1:exponential
#define COMBO_FACTOR 0.5 // linear: bonus each combo level gives; exponential: factor to multiply for each combo level
#define COMBO_EXPIRE 5.0
#endif

// ==== end of configuration ====

// print debug message
#define DEBUG

#define PLUGIN "[ZP] EnduranceReward"
#define VERSION "0.1.0"
#define AUTHOR "i-c0112"

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>

// player variable(system)
new g_alive[33], g_connected[33], g_zombie[33], g_bot[33]
// player variable(plugin)
#if defined COMBO
new g_combo[33], Float:g_flDmg[33], Float:g_flReward[33], Float:g_flExp[33]
#endif
// system variable
new g_hamczbot, g_maxplayer

// snippet from ZP by "MeRcyLeZZ"
#define is_user_valid_connected(%0) (1 <= (%0) <= g_maxplayer && g_connected[(%0)])

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    RegisterHam(Ham_Killed, "player", "fw_Killed_Post", 1)
    RegisterHam(Ham_Spawn, "player", "fw_Spawn_Post", 1)
    RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_Post", 1)

    g_maxplayer = get_maxplayers()
}

public zp_user_infected_post(id, infector, nemesis)
{
    g_zombie[id] = true

#if defined COMBO
    g_combo[id] = 0
    g_flDmg[id] = g_flReward[id] = 0.0
#endif
}

public client_disconnect(id)
{
    g_alive[id] = false
    g_connected[id] = false
    g_zombie[id] = false
    g_bot[id] = false
}

public client_putinserver(id)
{
    g_alive[id] = false
    g_connected[id] = true
    g_zombie[id] = false
    g_bot[id] = false

#if defined COMBO
    g_combo[id] = 0
    g_flDmg[id] = g_flReward[id] = g_flExp[id] = 0.0
#endif

    if (!g_hamczbot && is_user_bot(id))
    {
        g_bot[id] = true

        static classname[32]
        pev(id, pev_classname, classname, charsmax(classname))

        // not a cz bot?
        if (equal(classname, "player"))
            return

        set_task(0.1, "task_hamczbot", id)
    }
}

public fw_Killed_Post(victim, attacker, shouldgib)
{
    g_alive[victim] = false
}

public fw_Spawn_Post(id)
{
    g_alive[id] = true
    g_zombie[id] = false

    // [bugfix]
    // ZP infect players when half way through Ham_Spawn dispatching.
    // This results in out of order forward call in successive plugins(which loaded after ZP).
    if (zp_get_user_zombie(id))
        zp_user_infected_post(id, 0, false)
}

public fw_TakeDamage_Post(victim, inflictor, attacker, Float:damage, damage_type)
{
    if (!g_zombie[victim])
        return HAM_IGNORED

    // self-damage or non-player damage source
    if (victim == attacker || !is_user_valid_connected(attacker))
        return HAM_IGNORED

    static Float:reward
    reward = float(REWARD)

    g_flDmg[victim] += damage
    while (g_flDmg[victim] >= DMG_THRESHOLD)
    {
    #if defined DEBUG
        server_print("Player ^"%d^" Damage Accumulated: %f", victim, g_flDmg[victim])
    #endif
        g_flDmg[victim] -= DMG_THRESHOLD

    #if defined COMBO
        if (g_flExp[victim] - get_gametime() <= 0.0)
            g_combo[victim] = 0

        ++g_combo[victim]
        g_flExp[victim] = get_gametime() + COMBO_EXPIRE
        
        #if defined DEBUG
        server_print("Player ^"%d^" current combo ^"%d^"", victim, g_combo[victim])
        #endif
        
        // reaching max combo, no more stacked bonus
        if (0 < COMBO_MAX < g_combo[victim])
        {
            g_combo[victim] = COMBO_MAX
        }
        else
        {
            if (g_combo[victim] == 1)
                g_flReward[victim] = reward
            else
            {
                switch (COMBO_MODE)
                {
                    case 0: {
                        g_flReward[victim] += reward * COMBO_FACTOR
                    }
                    case 1: {
                        g_flReward[victim] *= COMBO_FACTOR
                    }
                default:
                    // unknown mode, function as no combo
                    g_flReward[victim] = reward
                }
            }
        }
        reward = g_flReward[victim]
        #if defined DEBUG
            server_print("player ^"%d^" is rewarded for his/her endurance: ^"%f^" ammo packs", victim, reward)
        #endif
    #endif // defined COMBO
    
        zp_set_user_ammo_packs(victim, zp_get_user_ammo_packs(victim) + floatround(reward, floatround_floor))        
    } // g_flDmg >= COMBO_THRESHOLD
    return HAM_HANDLED
}

public task_hamczbot(id)
{
    if (g_hamczbot || !g_connected[id] || !g_bot[id])
        return

    RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage_Post", 1)

    g_hamczbot = true
}
