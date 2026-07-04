Config = {}

-- 依存する電話リソース名。本番 / mock の切替はこの 1 行だけで完結する。
--   本番     : 'lb-phone'
--   ローカル : 'mock_lb_phone'
-- server.cfg では、ここで指定したリソースを本リソースより先に ensure すること。
Config.PhoneResource = 'mock_lb_phone'

-- カメラを開くコマンド
Config.Command = 'phonecam'

-- 固定 / 固定解除トグル用のコマンドとキーマッピング
-- RegisterKeyMapping 経由で登録し、ユーザーは Key Bindings から変更可能
Config.ToggleFrozenKeyCommand = '+phonecam_freeze'
Config.ToggleFrozenKeyDescription = 'Toggle phone camera frozen'
Config.DefaultMapper = 'keyboard'
Config.DefaultKey = 'X'

-- SetCameraComponent に渡す初期状態
-- type: "Photo" | "Video" | "Landscape"
-- camera: "rear" | "front"
Config.CameraDefault = {
    type = 'Photo',
    flash = false,
    camera = 'rear',
}

-- カメラ UI で許可する操作
Config.CameraPermissions = {
    toggleFlash = true,
    flipCamera = true,
    takePhoto = true,
    takeVideo = false,
    takeLandscapePhoto = false,
}

-- 撮影画像を lb-phone のギャラリーへ保存する
Config.SaveToGallery = true

-- カメラ起動時に EnableWalkableCam を呼ぶか
Config.UseWalkableCam = true
-- EnableWalkableCam(selfieMode) の selfieMode 引数 (false = rear 想定)
Config.WalkableSelfie = false

-- lb-phone の custom app として登録するか (Phase 2)
Config.UseCustomApp = true

-- AddCustomApp に渡すメタ情報
-- ui / icon の NUI パスはランタイムのリソース名にバインドされるため、
-- フォルダ名を決め打ちせず GetCurrentResourceName() から導出する。
local resourceName = GetCurrentResourceName()
Config.App = {
    identifier = 'fixed_phone_camera', -- lb-phone 内での一意な app ID (パスではない)
    name = 'Fixed Cam',
    description = 'lb-phone camera launcher with freeze toggle',
    developer = 'nichicoma',
    defaultApp = true, -- ホーム画面に最初から表示する
    ui = resourceName .. '/ui/index.html',
    icon = 'nui://' .. resourceName .. '/ui/icon.svg',
}

-- デバッグログを F8 console に出す
Config.Debug = true
