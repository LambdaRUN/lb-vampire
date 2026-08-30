fx_version 'cerulean'
game 'gta5'

author 'LB Scripts'
description 'LB-VAMPIRE - Production V1'
version '0.4.6'

lua54 'yes'

ui_page 'web/standalone-hud/index.html'

files {
    'web/standalone-hud/index.html',
    'web/standalone-hud/style.css',
    'web/standalone-hud/app.js',
    'web/standalone-hud/consent.css',
    'web/standalone-hud/consent.js',
    'web/standalone-hud/feeding-status.css',
    'web/standalone-hud/feeding-status.js'
}

shared_scripts {
    'config/config.lua'
}

client_scripts {
    'client/bootstrap.lua',

    'bridge/weather/qb.lua',
    'bridge/spawn/qb.lua',
    'bridge/hud/standalone.lua',

    'client/blood.lua',
    'client/humanblood.lua',
    'client/humanblood_consequences.lua',
    'client/sun.lua',
    'client/feeding.lua',
    'client/feeding_consent.lua',
    'client/feeding_runtime.lua',
    'client/feeding_status.lua',
    'client/interactions.lua',
    'bridge/target/qb.lua',
    'client/debug_feeding.lua',
    'client/hud.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'bridge/framework/qb.lua',
    'bridge/notify/qb.lua',
    'bridge/logs/qb.lua',

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
    'server/blood_affinity.lua',
    'server/feeding.lua',
    'server/feeding_interrupts.lua',
    'server/feeding_status.lua',
    'server/npc_blood.lua',
    'server/npc_witness.lua',
    'server/items.lua',
    'server/admin.lua',
    'server/debug.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}