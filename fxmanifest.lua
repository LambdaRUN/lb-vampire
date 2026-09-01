fx_version 'cerulean'
game 'gta5'

author 'LB Scripts'
description 'LB-VAMPIRE - Production V1'
version '0.7.6-5D'

lua54 'yes'

ui_page 'web/standalone-hud/index.html'

files {
    'web/standalone-hud/index.html',
    'web/standalone-hud/style.css',
    'web/standalone-hud/app.js',
    'web/standalone-hud/consent.css',
    'web/standalone-hud/consent.js',
    'web/standalone-hud/feeding-status.css',
    'web/standalone-hud/feeding-status.js',
    'web/standalone-hud/scent-tracking.css',
    'web/standalone-hud/scent-tracking.js',
    'web/standalone-hud/ability-menu.css',
    'web/standalone-hud/ability-menu-core.js',
    'web/standalone-hud/ability-menu.js',
    'web/standalone-hud/torpor.css',
    'web/standalone-hud/torpor.js'
}

shared_scripts {
    'config/config.lua',
    'shared/damage_math.lua',
    'shared/torpor_math.lua'
}

client_scripts {
    'client/bootstrap.lua',
    'bridge/dispatch/ps_client.lua',

    'bridge/weather/qb.lua',
    'bridge/spawn/qb.lua',
    'bridge/hud/standalone.lua',
    'bridge/death/qb.lua',

    'client/blood.lua',
    'client/bloodbag.lua',
    'client/humanblood.lua',
    'client/humanblood_consequences.lua',
    'client/sun.lua',
    'client/feeding.lua',
    'client/feeding_consent.lua',
    'client/feeding_runtime.lua',
    'client/feeding_status.lua',
    'client/interactions.lua',
    'client/npc_feeding.lua',
    'client/torpor.lua',
    'client/damage.lua',
    'client/ammo.lua',
    'client/abilities.lua',
    'client/beast_call.lua',
    'client/ability_menu.lua',

    'client/npc_reactions.lua',
    'client/npc_debug.lua',

    'bridge/target/qb.lua',
    'client/debug_feeding.lua',
    'client/hud.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'bridge/framework/qb.lua',
    'bridge/notify/qb.lua',
    'bridge/logs/qb.lua',

    'bridge/weather/server_qb.lua',

    'bridge/dispatch/qb.lua',
    'bridge/dispatch/ps.lua',
    'bridge/dispatch/manager.lua',

    'server/bootstrap.lua',
    'server/persistence.lua',
    'server/blood.lua',
    'server/humanblood.lua',
    'server/humanblood_consequences.lua',
    'server/sun.lua',
    'server/vampires.lua',
    'server/torpor.lua',
    'server/ammo.lua',
    'server/damage.lua',
    'server/blood_affinity.lua',
    'server/feeding.lua',
    'server/feeding_interrupts.lua',
    'server/feeding_status.lua',
    'server/npc_blood.lua',
    'server/npc_feeding.lua',
    'server/abilities.lua',
    'server/beast_call.lua',
    'server/npc_witness.lua',
    'server/npc_debug.lua',
    'server/items.lua',
    'server/admin.lua',
    'server/debug.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}
