fx_version 'cerulean'
game 'gta5'

name 'fixed_phone_camera'
author 'nichicoma'
description 'lb-phone camera extension: capture to gallery + freeze toggle'
version '0.2.0'

-- lb-phone のクライアント exports を利用する拡張リソース
-- dependency 'lb-phone'
dependency 'mock_lb_phone' -- ローカルで挙動確認する場合は 'mock_lb_phone' に変更する

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
