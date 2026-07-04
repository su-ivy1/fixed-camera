fx_version 'cerulean'
game 'gta5'

name 'fixed_phone_camera'
author 'iqos'
description 'lb-phone camera extension: capture to gallery + freeze toggle'
version '0.2.0'

-- 依存する電話リソースは config.lua の Config.PhoneResource で指定する
-- (本番 / mock の切替はそこ 1 箇所)。
-- dependency は特定リソース名に固定されてしまい、mock 単体起動を妨げるため
-- 使わない。起動順は server.cfg の ensure 順で、存在確認は runtime の
-- GetResourceState で担保する。
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
