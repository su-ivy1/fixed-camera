fx_version 'cerulean'
game 'gta5'

name 'fixed_phone_camera'
author 'nichicoma'
description 'lb-phone camera extension: capture to gallery + freeze toggle'
version '0.2.0'

-- lb-phone のクライアント exports を利用する拡張リソース
dependency 'lb-phone'

client_scripts {
    'config.lua',
    'client/main.lua',
}

-- lb-phone custom app の UI (Phase 2)
ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/icon.svg',
}
