--[[
    fixed_phone_camera / client/main.lua  (Phase 2: custom app)

    lb-phone のカメラ機能を呼び出す拡張リソース。
      - custom app "Fixed Cam" : スマホ内アプリからカメラを起動 / 固定 / 終了
      - /phonecam              : カメラの開閉（コマンドからも利用可）
      - X (デフォルト)         : カメラ起動中に ToggleCameraFrozen で固定 / 固定解除
    独自の CreateCam / RenderScriptCams は使わず、lb-phone の exports に委譲する。
]]

local State = {
    active = false, -- カメラ起動中かどうか
    frozen = false, -- 固定中かどうか (UI 表示用。真の固定状態は lb-phone 側)
}

--------------------------------------------------------------------------------
-- utils
--------------------------------------------------------------------------------

local function dbg(...)
    if Config.Debug then
        print('[fixed_phone_camera]', ...)
    end
end

-- lb-phone が起動しているか確認する。未起動なら false を返し、エラーにしない。
local function isPhoneReady()
    if GetResourceState(Config.PhoneResource) ~= 'started' then
        dbg(Config.PhoneResource .. ' is not started; aborting')
        return false
    end
    return true
end

-- lb-phone の export を安全に呼ぶ。存在しない export でもクラッシュさせない。
local function callPhone(exportName, ...)
    if not isPhoneReady() then
        return nil
    end

    local phone = exports[Config.PhoneResource]
    if type(phone[exportName]) ~= 'function' then
        dbg('export not found:', exportName)
        return nil
    end

    local ok, result = pcall(function(...)
        return phone[exportName](phone, ...)
    end, ...)

    if not ok then
        dbg('export call failed:', exportName, result)
        return nil
    end

    return result
end

-- 現在の状態を custom app の UI へ通知する ('idle' | 'live' | 'frozen')
local function pushState()
    local state = 'idle'
    if State.active then
        state = State.frozen and 'frozen' or 'live'
    end
    callPhone('SendCustomAppMessage', Config.App.identifier, {
        action = 'state',
        state = state,
    })
end

--------------------------------------------------------------------------------
-- camera open / close
--------------------------------------------------------------------------------

local function openCamera()
    if State.active then
        dbg('camera already active')
        return
    end

    if not isPhoneReady() then
        print('[fixed_phone_camera] lb-phone が起動していません。ensure lb-phone を確認してください。')
        return
    end

    -- 歩けるカメラを有効化 (設定時のみ)
    if Config.UseWalkableCam then
        callPhone('EnableWalkableCam', Config.WalkableSelfie)
    end

    callPhone('SetCameraComponent', {
        default = Config.CameraDefault,
        permissions = Config.CameraPermissions,
        saveToGallery = Config.SaveToGallery,
        cb = function(src)
            -- 撮影後に画像 src を受け取る
            dbg('photo captured, src =', src)
            print('[fixed_phone_camera] captured src:', tostring(src))
        end,
    })

    State.active = true
    State.frozen = false
    pushState()
    dbg('camera opened')
end

local function closeCamera()
    if not State.active then
        return
    end

    if Config.UseWalkableCam then
        callPhone('DisableWalkableCam')
    end

    State.active = false
    State.frozen = false
    pushState()
    dbg('camera closed')
end

local function ToggleCameraMode()
    if State.active then
        closeCamera()
    else
        openCamera()
    end
end

--------------------------------------------------------------------------------
-- freeze toggle (X)
--------------------------------------------------------------------------------

local function ToggleFrozen()
    if not State.active then
        return -- カメラ起動中のみ有効
    end
    callPhone('ToggleCameraFrozen')
    State.frozen = not State.frozen
    pushState()
    dbg('toggled camera frozen ->', tostring(State.frozen))
end

--------------------------------------------------------------------------------
-- lb-phone custom app (Phase 2)
--------------------------------------------------------------------------------

local appRegistered = false

local function registerApp()
    if not Config.UseCustomApp or appRegistered then
        return
    end
    if not isPhoneReady() then
        return -- lb-phone 起動後に再試行する
    end

    callPhone('AddCustomApp', {
        identifier = Config.App.identifier,
        name = Config.App.name,
        description = Config.App.description,
        developer = Config.App.developer,
        defaultApp = Config.App.defaultApp,
        ui = Config.App.ui,
        icon = Config.App.icon,
    })
    appRegistered = true
    dbg('custom app registered:', Config.App.identifier)
end

local function unregisterApp()
    if not appRegistered then
        return
    end
    callPhone('RemoveCustomApp', Config.App.identifier)
    appRegistered = false
    dbg('custom app removed:', Config.App.identifier)
end

-- UI (iframe) からのメッセージ受け口
RegisterNUICallback('openCamera', function(_, cb)
    openCamera()
    cb({ ok = true })
end)

RegisterNUICallback('toggleFrozen', function(_, cb)
    ToggleFrozen()
    cb({ ok = true })
end)

RegisterNUICallback('closeCamera', function(_, cb)
    closeCamera()
    cb({ ok = true })
end)

-- 自リソース起動時と、lb-phone が後から起動した時に app を登録する
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == Config.PhoneResource then
        registerApp()
    end
end)

CreateThread(function()
    registerApp() -- 既に lb-phone が起動済みのケース
end)

--------------------------------------------------------------------------------
-- registration
--------------------------------------------------------------------------------

RegisterCommand(Config.Command, function()
    ToggleCameraMode()
end, false)

RegisterCommand(Config.ToggleFrozenKeyCommand, function()
    ToggleFrozen()
end, false)

RegisterKeyMapping(
    Config.ToggleFrozenKeyCommand,
    Config.ToggleFrozenKeyDescription,
    Config.DefaultMapper,
    Config.DefaultKey
)

--------------------------------------------------------------------------------
-- resource stop cleanup
--------------------------------------------------------------------------------

AddEventHandler('onClientResourceStop', function(resource)
    -- lb-phone が停止すると custom app は破棄される。再起動後に再登録できるよう
    -- appRegistered を戻し、カメラ状態もクリアする。
    if resource == Config.PhoneResource then
        appRegistered = false
        State.active = false
        State.frozen = false
        dbg('lb-phone stopped; reset app/camera state')
        return
    end

    if resource ~= GetCurrentResourceName() then
        return
    end
    -- 自リソース停止: walkable cam を確実に解除し、app も撤去する
    if GetResourceState(Config.PhoneResource) == 'started' then
        callPhone('DisableWalkableCam')
        unregisterApp()
    end
    State.active = false
    State.frozen = false
    dbg('cleanup on resource stop')
end)
