--[[
    fixed_phone_camera / client/main.lua  (MVP)

    lb-phone のカメラ機能を呼び出す拡張リソース。
      - /phonecam       : lb-phone の camera component を開く / 閉じる
      - X (デフォルト)  : カメラ起動中に ToggleCameraFrozen で固定 / 固定解除
    独自の CreateCam / RenderScriptCams は使わず、lb-phone の exports に委譲する。
]]

local State = {
    active = false, -- カメラ起動中かどうか
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
    dbg('toggled camera frozen')
end

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
    if resource ~= GetCurrentResourceName() then
        return
    end
    -- カメラ状態に関係なく walkable cam を確実に解除する
    if GetResourceState(Config.PhoneResource) == 'started' then
        callPhone('DisableWalkableCam')
    end
    State.active = false
    dbg('cleanup on resource stop')
end)
