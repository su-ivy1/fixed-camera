--[[
    mock_lb_phone / client/main.lua

    ローカル開発用の lb-phone behavior mock。
    本物の lb-phone が無い環境でも、fixed_phone_camera から呼ばれる export の
    挙動（特に ToggleCameraFrozen によるカメラ固定 / 解除）を実際の scripted
    camera で確認できるようにする。

    実装する export:
      SetCameraComponent(data)  -- 疑似カメラ起動 + 擬似撮影 callback
      ToggleCameraFrozen()      -- 追従停止 / 再開で視点固定 / 解除
      EnableWalkableCam(selfie) -- フラグのみ (実カメラは SetCameraComponent で起動)
      DisableWalkableCam()      -- カメラ終了 + cleanup
      IsWalkingCamEnabled()     -- 疑似カメラ起動中か
      SaveToGallery(link)       -- 実保存せず print
]]

local Mock = {
    active = false,
    frozen = false,
    cam = nil,
    fov = 50.0,
}

local function log(...)
    print('[mock_lb_phone]', ...)
end

--------------------------------------------------------------------------------
-- camera lifecycle
--------------------------------------------------------------------------------

local function cleanupCam()
    RenderScriptCams(false, false, 0, true, true)

    if Mock.cam ~= nil and DoesCamExist(Mock.cam) then
        SetCamActive(Mock.cam, false)
        DestroyCam(Mock.cam, false)
    end

    Mock.cam = nil
    Mock.active = false
    Mock.frozen = false
    log('camera cleaned up')
end

local function startCam(fov)
    if Mock.active then
        log('camera already active')
        return
    end

    Mock.fov = fov or 50.0

    local coords = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)

    Mock.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if Mock.cam == nil or not DoesCamExist(Mock.cam) then
        log('failed to create scripted cam')
        cleanupCam()
        return
    end

    SetCamCoord(Mock.cam, coords.x, coords.y, coords.z)
    SetCamRot(Mock.cam, rot.x, rot.y, rot.z, 2)
    SetCamFov(Mock.cam, Mock.fov)
    SetCamActive(Mock.cam, true)
    RenderScriptCams(true, false, 0, true, true)

    Mock.active = true
    Mock.frozen = false

    -- 追従スレッド: frozen でない間は GameplayCam を毎 tick ミラーする
    CreateThread(function()
        while Mock.active do
            if not Mock.frozen and Mock.cam ~= nil and DoesCamExist(Mock.cam) then
                local c = GetGameplayCamCoord()
                local r = GetGameplayCamRot(2)
                local f = GetGameplayCamFov()
                SetCamCoord(Mock.cam, c.x, c.y, c.z)
                SetCamRot(Mock.cam, r.x, r.y, r.z, 2)
                SetCamFov(Mock.cam, f)
            end
            Wait(0)
        end
    end)

    -- 画面上の状態インジケータ (LIVE / FROZEN を可視化)
    CreateThread(function()
        while Mock.active do
            local label = Mock.frozen and '~r~FROZEN' or '~g~LIVE'
            SetTextFont(4)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('MOCK CAM: ' .. label)
            EndTextCommandDisplayText(0.5, 0.9)
            Wait(0)
        end
    end)

    log('camera started (fov=' .. tostring(Mock.fov) .. ')')
end

--------------------------------------------------------------------------------
-- exports
--------------------------------------------------------------------------------

-- 撮影後にギャラリー保存する風のログを出す (実保存はしない)
local function saveToGallery(link)
    log('SaveToGallery ->', tostring(link))
end
exports('SaveToGallery', saveToGallery)

exports('SetCameraComponent', function(data)
    data = data or {}
    local default = data.default or {}

    log('SetCameraComponent called (type=' .. tostring(default.type) ..
        ', camera=' .. tostring(default.camera) ..
        ', flash=' .. tostring(default.flash) .. ')')

    startCam(default.fov)

    -- 擬似撮影: saveToGallery 指定時は callback に mock link を返し、保存風ログを出す
    if data.saveToGallery then
        CreateThread(function()
            Wait(500) -- カメラ起動後に一度だけ撮影したことにする
            if not Mock.active then return end

            local src = 'mock://photo/test-image.png'
            log('simulated capture, src =', src)

            if type(data.cb) == 'function' then
                data.cb(src)
            end
            saveToGallery(src)
        end)
    end

    return 'mock://camera/component'
end)

exports('ToggleCameraFrozen', function()
    if not Mock.active then
        log('ToggleCameraFrozen ignored (camera not active)')
        return
    end
    Mock.frozen = not Mock.frozen
    log('camera frozen =', tostring(Mock.frozen))
end)

exports('EnableWalkableCam', function(selfieMode)
    -- 実カメラ起動は SetCameraComponent 側で行うため、ここではログのみ
    log('EnableWalkableCam(selfie=' .. tostring(selfieMode) .. ')')
end)

exports('DisableWalkableCam', function()
    log('DisableWalkableCam')
    cleanupCam()
end)

exports('IsWalkingCamEnabled', function()
    return Mock.active
end)

--------------------------------------------------------------------------------
-- resource stop cleanup
--------------------------------------------------------------------------------

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        cleanupCam()
    end
end)
