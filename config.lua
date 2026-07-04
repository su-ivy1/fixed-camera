Config = {}

-- /cam コマンド名
Config.Command = 'cam'

-- 固定 / 解除トグル用のコマンドとキーマッピング
-- RegisterKeyMapping 経由で登録し、ユーザーは FiveM の Key Bindings から変更可能
Config.ToggleFixedKeyCommand = '+fixedcam_toggle'
Config.ToggleFixedKeyDescription = 'Toggle fixed camera'
Config.DefaultMapper = 'keyboard'
Config.DefaultKey = 'X'

-- scripted camera の種類
Config.CameraName = 'DEFAULT_SCRIPTED_CAMERA'

-- カメラ挙動
Config.Fov = 50.0
Config.RotationSpeed = 6.0
Config.ZoomSpeed = 2.0

-- 手持ちカメラ prop (環境に存在しなくてもクラッシュしない設計)
Config.PropModel = 'prop_v_cam_01'

-- デバッグログを F8 console に出す
Config.Debug = false
