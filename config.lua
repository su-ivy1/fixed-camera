Config = {}

-- 依存する lb-phone リソース名
-- ローカルで挙動確認する場合は 'mock_lb_phone' に変更する
Config.PhoneResource = 'lb-phone'

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

-- デバッグログを F8 console に出す
Config.Debug = true
