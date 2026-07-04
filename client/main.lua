--[[
    fixed_camera / client/main.lua  (Phase 1 MVP)

    状態:
      active=false            -> カメラモード OFF
      active=true, fixed=false -> 手持ちカメラ (GameplayCam 追従)
      active=true, fixed=true  -> 固定カメラ (追従停止)
]]

local State = {
    active = false,
    fixed = false,
    cam = nil,
    prop = nil,
    currentFov = Config.Fov,
}

--------------------------------------------------------------------------------
-- utils
--------------------------------------------------------------------------------

local function dbg(...)
    if Config.Debug then
        print('[fixed_camera]', ...)
    end
end

-- prop モデルを安全にロードする。失敗しても nil を返すだけでクラッシュしない。
local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)

    if not IsModelValid(hash) then
        dbg('invalid prop model:', model)
        return nil
    end

    RequestModel(hash)

    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do -- 最大 ~1s 待つ
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(hash) then
        dbg('prop model load timeout:', model)
        return nil
    end

    return hash
end

--------------------------------------------------------------------------------
-- prop
--------------------------------------------------------------------------------

local function attachProp(ped)
    local hash = loadModel(Config.PropModel)
    if not hash then
        return nil -- prop なしでもカメラ機能は続行する
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)

    if not DoesEntityExist(prop) then
        dbg('failed to create prop object')
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    -- 右手ボーン (SKEL_R_Hand = 28422) に取り付け
    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(
        prop, ped, bone,
        0.14, 0.02, -0.02,   -- offset
        -90.0, 20.0, 0.0,    -- rotation
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(hash)
    return prop
end

--------------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------------

local function cleanup()
    -- render を通常視点へ戻す (1000ms かけて補間)
    RenderScriptCams(false, false, 0, true, true)

    if State.cam ~= nil and DoesCamExist(State.cam) then
        SetCamActive(State.cam, false)
        DestroyCam(State.cam, false)
    end
    State.cam = nil

    if State.prop ~= nil and DoesEntityExist(State.prop) then
        DeleteEntity(State.prop)
    end
    State.prop = nil

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
    end

    State.active = false
    State.fixed = false
    State.currentFov = Config.Fov

    dbg('cleanup done')
end

--------------------------------------------------------------------------------
-- camera mode
--------------------------------------------------------------------------------

local function startCameraMode()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        dbg('no valid ped, abort start')
        return
    end

    -- GameplayCam の現在値を初期パラメータとして cam を作成
    local coords = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)

    State.currentFov = Config.Fov
    State.cam = CreateCam(Config.CameraName, true)

    if State.cam == nil or not DoesCamExist(State.cam) then
        dbg('failed to create cam')
        cleanup()
        return
    end

    SetCamCoord(State.cam, coords.x, coords.y, coords.z)
    SetCamRot(State.cam, rot.x, rot.y, rot.z, 2)
    SetCamFov(State.cam, State.currentFov)
    SetCamActive(State.cam, true)
    RenderScriptCams(true, false, 0, true, true)

    State.prop = attachProp(ped)

    State.active = true
    State.fixed = false

    -- 手持ち追従スレッド: fixed の間は更新をスキップして視点を固定する
    CreateThread(function()
        while State.active do
            if not State.fixed and State.cam ~= nil and DoesCamExist(State.cam) then
                local c = GetGameplayCamCoord()
                local r = GetGameplayCamRot(2)
                SetCamCoord(State.cam, c.x, c.y, c.z)
                SetCamRot(State.cam, r.x, r.y, r.z, 2)
                SetCamFov(State.cam, State.currentFov)
            end
            Wait(0)
        end
    end)

    dbg('camera mode ON (handheld)')
end

local function ToggleCameraMode()
    if State.active then
        cleanup()
        dbg('camera mode OFF')
    else
        startCameraMode()
    end
end

--------------------------------------------------------------------------------
-- fixed toggle
--------------------------------------------------------------------------------

local function ToggleFixedCamera()
    if not State.active then
        return -- カメラモード外では何もしない
    end

    if State.cam == nil or not DoesCamExist(State.cam) then
        dbg('cam missing on fixed toggle')
        return
    end

    if not State.fixed then
        -- 現在の座標・角度・FOV をそのまま固定
        local coords = GetCamCoord(State.cam)
        local rot = GetCamRot(State.cam, 2)
        local fov = GetCamFov(State.cam)

        SetCamCoord(State.cam, coords.x, coords.y, coords.z)
        SetCamRot(State.cam, rot.x, rot.y, rot.z, 2)
        SetCamFov(State.cam, fov)

        State.fixed = true
        dbg('camera FIXED')
    else
        -- 手持ち追従へ復帰 (スレッドが自動的に更新再開)
        State.fixed = false
        dbg('camera UNFIXED (handheld)')
    end
end

--------------------------------------------------------------------------------
-- registration
--------------------------------------------------------------------------------

RegisterCommand(Config.Command, function()
    ToggleCameraMode()
end, false)

RegisterCommand(Config.ToggleFixedKeyCommand, function()
    ToggleFixedCamera()
end, false)

RegisterKeyMapping(
    Config.ToggleFixedKeyCommand,
    Config.ToggleFixedKeyDescription,
    Config.DefaultMapper,
    Config.DefaultKey
)

--------------------------------------------------------------------------------
-- resource stop cleanup
--------------------------------------------------------------------------------

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        cleanup()
    end
end)
