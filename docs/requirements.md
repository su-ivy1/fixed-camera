# FiveM 固定カメラスクリプト 開発要件

## 概要

GTA5 / FiveM向けに、手持ちカメラ使用中に特定キーを押すと、現在のカメラ位置・角度・FOVを固定し、プレイヤーがその固定カメラ視点を維持できるリソースを開発する。

イメージとしては、RPサーバーで見かける「カメラを構えた状態でXキーを押すと、カメラ視点がその場に固定される」挙動に近いものを目指す。

ただし、既存サーバー固有の実装をコピーするのではなく、FiveMの標準的なclient script / native functionsを利用して独自実装する。

---

## 最終ゴール

以下を満たすFiveMリソースを作成する。

* `/cam` でカメラモードを開始 / 終了できる
* カメラモード中にカメラpropをプレイヤーの手元に表示する
* カメラモード中はファインダー風のカメラ視点に切り替わる
* カメラモード中に `X` を押すと、その瞬間のカメラ座標・角度・FOVで視点が固定される
* 固定中にもう一度 `X` を押すと、手持ちカメラ視点に戻る
* `/cam` を終了したら、カメラ・prop・状態をすべて安全にクリーンアップする
* resource restart / stop 時にもカメラやpropが残らない
* まずはスタンドアロン実装とし、ESX / QBCore / ox_inventory などには依存しない

---

## 非ゴール

初期MVPでは以下は実装しない。

* ニュース番組のような配信UI
* 他プレイヤーが同じカメラ映像を見る機能
* inventory item連携
* job制限
* 録画・スクリーンショット保存
* NUIによる高度なUI
* サーバーDB保存
* Discord webhook投稿
* ストグラ固有仕様の完全再現

---

## 技術方針

### 言語

Luaで実装する。

理由:

* FiveMの小規模client scriptではLuaが扱いやすい
* fxmanifest.luaとの相性が良い
* Claude Codeで生成・修正しやすい

---

## 想定リソース名

`fixed_camera`

---

## ファイル構成

```txt
fixed_camera/
  fxmanifest.lua
  config.lua
  client/
    main.lua
    camera.lua
    prop.lua
    controls.lua
```

シンプルにする場合は、初期実装では `client/main.lua` にまとめてもよい。
ただし、状態管理が複雑になりそうなら上記のように分割する。

---

## fxmanifest.lua 要件

* `fx_version 'cerulean'`
* `game 'gta5'`
* client scriptsとして `config.lua` と `client/*.lua` を読み込む
* standalone resourceとして動作すること

---

## 設定項目

`config.lua` に以下を用意する。

```lua
Config = {}

Config.Command = 'cam'

Config.ToggleFixedKeyCommand = '+fixedcam_toggle'
Config.ToggleFixedKeyDescription = 'Toggle fixed camera'
Config.DefaultMapper = 'keyboard'
Config.DefaultKey = 'X'

Config.CameraName = 'DEFAULT_SCRIPTED_CAMERA'

Config.Fov = 50.0
Config.RotationSpeed = 6.0
Config.ZoomSpeed = 2.0

Config.PropModel = 'prop_v_cam_01'

Config.Debug = false
```

prop modelは環境によって存在しない可能性があるため、モデル読み込みに失敗した場合でもリソース全体がクラッシュしないようにする。

---

## 操作仕様

### `/cam`

カメラモードをトグルする。

カメラモードOFF時:

* プレイヤーにカメラpropを持たせる
* scripted cameraを作成する
* カメラ視点に切り替える
* 状態を `handheld` にする

カメラモードON時:

* fixed / handheld の状態に関係なく終了処理を行う
* scripted cameraを破棄する
* propを削除する
* 通常視点に戻す
* 状態を `off` にする

---

### `X`

カメラモード中のみ有効。

`handheld` 状態で押した場合:

* 現在のカメラ座標・角度・FOVを取得
* カメラをその座標・角度・FOVで固定
* 状態を `fixed` にする

`fixed` 状態で押した場合:

* プレイヤー追従の手持ちカメラ視点に戻す
* 状態を `handheld` にする

カメラモード外で押した場合:

* 何もしない

---

## 状態管理

以下の状態を持つ。

```lua
State = {
  active = false,
  fixed = false,
  cam = nil,
  prop = nil,
  currentFov = Config.Fov
}
```

状態の意味:

* `active = false`

  * カメラモードOFF
* `active = true, fixed = false`

  * 手持ちカメラモード
* `active = true, fixed = true`

  * 固定カメラモード

---

## 実装方針

### 1. コマンド登録

`RegisterCommand` で `/cam` を登録する。

```lua
RegisterCommand(Config.Command, function()
  ToggleCameraMode()
end, false)
```

---

### 2. キーバインド登録

`RegisterKeyMapping` を使い、デフォルトキーを `X` にする。

```lua
RegisterCommand(Config.ToggleFixedKeyCommand, function()
  ToggleFixedCamera()
end, false)

RegisterKeyMapping(
  Config.ToggleFixedKeyCommand,
  Config.ToggleFixedKeyDescription,
  Config.DefaultMapper,
  Config.DefaultKey
)
```

FiveMの公式Cookbookでは `RegisterCommand` と `RegisterKeyMapping` を組み合わせたキー割り当て例が紹介されている。キー割り当てはユーザー側のKey Bindingsから編集できる想定。
参照: FiveM Docs / Using the new console key bindings

---

### 3. 手持ちカメラモード

`/cam` 実行時に以下を行う。

* player pedを取得
* prop modelをRequestModelする
* propをCreateObjectする
* propをプレイヤーの手・腕付近のboneにAttachEntityToEntityする
* scripted cameraをCreateCamする
* RenderScriptCamsでscripted cameraを有効化する
* 毎tick、プレイヤーの位置・向き・GameplayCamの角度などをもとにcamera位置を更新する

実装のコツ:

* 手持ちカメラの追従は、最初から完璧にしなくてよい
* MVPではGameplayCamの座標・角度を取得してscripted cameraに反映する方式でよい
* 見た目よりも「Xで固定できる」挙動を優先する

---

### 4. 固定カメラモード

`X` 押下時に以下を行う。

* 現在のscripted cameraの座標を取得
* 現在のscripted cameraの角度を取得
* 現在のFOVを取得
* カメラ追従更新を停止する
* 取得した座標・角度・FOVをscripted cameraに設定する
* fixed状態にする

固定中は、カメラがプレイヤーの動きに追従しないこと。

---

### 5. 固定解除

固定中に `X` を押したら以下を行う。

* fixed状態を解除
* 再び手持ちカメラ追従処理を有効化する
* scripted cameraは再利用してもよい
* 必要ならcameraを作り直してもよいが、DestroyCam漏れに注意する

---

### 6. クリーンアップ

以下のタイミングで必ずクリーンアップする。

* `/cam` でカメラモード終了
* `onClientResourceStop`
* プレイヤー死亡時、必要なら終了
* player pedが存在しない場合
* prop作成失敗時
* camera作成失敗時

クリーンアップ内容:

* RenderScriptCams(false, ...)
* DestroyCam
* DeleteEntity(prop)
* ClearPedTasks
* 状態変数を初期化

---

## 使用を検討するNative Functions

FiveMのnative functionsは、ゲーム内の描画・入力・UI・プレイヤー操作などを扱うための関数群。クライアント側nativeはプレイヤーの視点操作や入力処理などに使う。
参照: FiveM Docs / Understanding and Using Native Functions

候補:

```lua
-- camera
CreateCam
SetCamActive
RenderScriptCams
DestroyCam
DoesCamExist
SetCamCoord
SetCamRot
SetCamFov
GetCamCoord
GetCamRot
GetCamFov

-- gameplay camera
GetGameplayCamCoord
GetGameplayCamRot
GetGameplayCamFov

-- player / entity
PlayerPedId
GetEntityCoords
GetEntityHeading
AttachEntityToEntity
DeleteEntity
DoesEntityExist
RequestModel
HasModelLoaded
CreateObject
SetModelAsNoLongerNeeded

-- controls / commands
RegisterCommand
RegisterKeyMapping
CreateThread
Wait
```

---

## 受け入れ条件

### 基本動作

* `/cam` でカメラモードに入れる
* `/cam` を再実行すると通常視点に戻る
* カメラモード中に `X` を押すと視点が固定される
* 固定後にプレイヤーが移動してもカメラ視点が追従しない
* 固定中にもう一度 `X` を押すと手持ちカメラ視点に戻る
* `/cam` 終了時に画面が通常視点へ戻る
* propやcameraが残らない

### 異常系

* resource restartしても画面がscripted cameraに固定されたままにならない
* prop model読み込み失敗時にクラッシュしない
* `/cam` を連打してもcamera / propが増殖しない
* fixed状態で `/cam` 終了しても正常に後片付けされる
* player pedが取得できない場合は安全に終了する

### 操作性

* `X` はカメラモード中のみ反応する
* キーバインドはFiveMのKey Bindingsから変更可能
* Configでデフォルトキーを変更できる

---

## テスト方針

### ローカル1人テスト

まずはローカルFXServerで以下を確認する。

* リソースが起動する
* `/cam` が使える
* `X` で固定 / 解除できる
* resource restartで状態が壊れない
* F8 consoleにエラーが出ない

FiveM公式では、`resources/[local]` にリソースを置き、`refresh` / `start` / `restart` で動作確認する流れが説明されている。
参照: FiveM Docs / Creating your first script in Lua

### 2クライアントテスト

必要になったら2クライアントで以下を確認する。

* 他プレイヤーから見てpropが見えるか
* propが手元に正しく表示されるか
* 固定カメラ中のプレイヤーの見た目が不自然すぎないか

FiveM公式には、2つ目のFiveMショートカットに `-cl2` を付けて2クライアント起動する方法がある。
参照: FiveM Docs / Running two FiveM clients

---

## 開発優先度

### Phase 1: MVP

* `/cam`
* カメラ視点ON/OFF
* `X`で固定 / 解除
* cleanup
* debug log

### Phase 2: 見た目改善

* カメラpropを手に持たせる
* カメラ構えアニメーション
* 画面エフェクト
* zoom in / zoom out
* 操作説明表示

### Phase 3: RP向け拡張

* job制限
* item使用連携
* ox_inventory / QBCore / ESX対応
* 他プレイヤー向け同期
* カメラマン状態の表示
* ニュースUI / NUI

---

## Claude Codeへの依頼内容

以下を実装してください。

* FiveM用Luaリソース `fixed_camera` を作成する
* standaloneで動くこと
* `/cam` でカメラモードをtoggleする
* カメラモード中、`X` で現在のカメラ視点を固定する
* 固定中、もう一度 `X` で手持ちカメラ視点に戻す
* `RegisterKeyMapping` を使ってキー設定可能にする
* `config.lua` でcommand名、default key、FOV、prop model、debugを変更できるようにする
* resource stop時に必ずcamera / prop / render stateをcleanupする
* F8 consoleにエラーが出ないようにnil checkと存在チェックを入れる
* ESX / QBCore / ox_inventoryには依存させない
* まずはMVPとして、他プレイヤーへの映像同期やNUIは実装しない
* 実装後、ローカルテスト手順もREADMEにまとめる

---

## READMEに含める内容

* インストール方法
* `server.cfg` への追加例
* `/cam` の使い方
* `X` で固定 / 解除できる説明
* configの変更方法
* 既知の制限
* ローカルテスト手順
* トラブルシュート

---

## 注意点

* 既存サーバー固有の実装をコピーしない
* FiveM native functionsを使って独自に実装する
* カメラ固定中にプレイヤー操作を完全に止めるかどうかはConfigで切り替えられるとよい
* まずは「動くMVP」を優先し、見た目の完成度は後で上げる
* prop / camera / threadの後片付け漏れを最優先で防ぐ
