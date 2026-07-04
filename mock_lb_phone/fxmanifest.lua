fx_version 'cerulean'
game 'gta5'

name 'mock_lb_phone'
author 'nichicoma'
description 'Local behavior mock for lb-phone camera exports (dev only)'
version '0.1.0'

-- ローカル開発用の疑似 lb-phone。本物の lb-phone とは同時起動しないこと。
client_scripts {
    'client/main.lua',
}
