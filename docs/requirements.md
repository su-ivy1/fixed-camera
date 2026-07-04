# FiveM lb-phone 連携カメラ 開発要件

## 概要

GTA5 / FiveM 向けに、[lb-phone](https://docs.lbscripts.com/phone/) のスマホカメラ
機能を呼び出して撮影し、画像を lb-phone のギャラリーへ保存する拡張リソースを開発する。
カメラ起動中は `X` キーでカメラ視点を固定 / 固定解除できる。

独自の `CreateCam` / `RenderScriptCams` は原則使わず、lb-phone の client exports に
委譲する。あわせて、lb-phone 本体が無いローカル環境でも挙動確認できるよう、
疑似 lb-phone（behavior mock）を同梱する。

---

## 最終ゴール

* `/phonecam` で lb-phone の camera component を開く / 閉じる
* 撮影した画像を lb-phone のギャラリーへ保存する（`saveToGallery = true`）
* 撮影後 callback で `src` を受け取り debug log を出す
* カメラ起動中に `X` を押すと、`ToggleCameraFrozen()` でカメラ視点を固定 / 固定解除する
* resource stop 時に `DisableWalkableCam()` を呼んで安全にクリーンアップする
* standalone 実装とし、ESX / QBCore / ox_inventory には直接依存しない

---

## 非ゴール（初期 MVP では実装しない）

* lb-phone の custom app 化（まずは `/phonecam` コマンドで確認）
* NUI による独自 UI
* 他プレイヤーへの映像同期
* inventory item 連携 / job 制限
* 録画・サーバー DB 保存・Discord webhook

---

## リソース構成

```txt
fixed_phone_camera/        -- 本体（lb-phone 連携 + custom app）
  fxmanifest.lua
  config.lua
  client/
    main.lua
  ui/                      -- custom app の UI (Phase 2)
    index.html
    icon.svg

mock_lb_phone/             -- ローカル開発用の lb-phone behavior mock
  fxmanifest.lua
  client/
    main.lua
  README.md
```

---

## fxmanifest.lua 要件（fixed_phone_camera）

* `fx_version 'cerulean'`
* `game 'gta5'`
* `dependency` は宣言しない（依存する電話リソースは `Config.PhoneResource` で
  切り替えるため、特定リソース名に固定しない。存在確認は runtime の
  `GetResourceState`、起動順は `server.cfg` の `ensure` 順で担保する）
* client scripts として `config.lua` と `client/main.lua` を読み込む

---

## 設定項目（config.lua）

| キー | デフォルト | 説明 |
| --- | --- | --- |
| `Config.PhoneResource` | `'lb-phone'` | 依存する電話リソース名（本番/mock 切替はここ 1 箇所。mock 時は `'mock_lb_phone'`） |
| `Config.Command` | `'phonecam'` | カメラ開閉コマンド |
| `Config.ToggleFrozenKeyCommand` | `'+phonecam_freeze'` | 固定トグル用の内部コマンド |
| `Config.DefaultKey` | `'X'` | 固定トグルのデフォルトキー |
| `Config.CameraDefault` | Photo / flash off / rear | カメラ初期状態 |
| `Config.CameraPermissions` | toggleFlash / flipCamera / takePhoto = true | UI で許可する操作 |
| `Config.SaveToGallery` | `true` | 撮影画像をギャラリー保存 |
| `Config.UseWalkableCam` | `true` | 起動時に `EnableWalkableCam` を呼ぶ |
| `Config.WalkableSelfie` | `false` | `EnableWalkableCam(selfieMode)` の引数 |
| `Config.Debug` | `true` | F8 console にデバッグログを出す |

---

## 使用する lb-phone exports

参照: [LB Documentation / Client Exports](https://docs.lbscripts.com/phone/exports/client-exports/)

```lua
-- カメラ UI を開く
---@field default { type: "Photo"|"Video"|"Landscape", flash: boolean, camera: "rear"|"front" }
---@field permissions { toggleFlash, flipCamera, takePhoto, takeVideo, takeLandscapePhoto: boolean }
---@field saveToGallery boolean
---@field cb fun(src: string)
exports["lb-phone"]:SetCameraComponent(data)

-- 歩けるカメラの有効化 / 無効化
exports["lb-phone"]:EnableWalkableCam(selfieMode)
exports["lb-phone"]:DisableWalkableCam()

-- カメラ固定 / 固定解除トグル
exports["lb-phone"]:ToggleCameraFrozen()
```

---

## 操作仕様

### `/phonecam`

カメラモードをトグルする。

OFF → ON:

* lb-phone 起動チェック（未起動なら通知 print して中断、エラーにしない）
* `EnableWalkableCam(Config.WalkableSelfie)`（`Config.UseWalkableCam` 時）
* `SetCameraComponent` を Photo / rear / flash off・permissions・`saveToGallery=true` で呼ぶ
* 撮影 callback で `src` を print

ON → OFF:

* `DisableWalkableCam()`
* 状態を off に戻す

### `X`（デフォルト）

* カメラ起動中のみ有効
* `ToggleCameraFrozen()` を呼ぶ
* カメラモード外では何もしない

---

## クリーンアップ

以下のタイミングで必ず `DisableWalkableCam()` を呼ぶ。

* `/phonecam` でカメラ終了
* `onClientResourceStop`（本リソース停止時）

lb-phone が起動していない場合は export を呼ばず、状態のみリセットする。

---

## 異常系 / 安全設計

* lb-phone 未起動時：`GetResourceState` で判定し、エラーにせず通知 print
* export 未定義時：`pcall` + 存在チェックで包み、F8 にエラーを出さない
* `/phonecam` 連打：`State.active` ガードで二重起動しない
* ESX / QBCore / ox_inventory に直接依存しない

---

## ローカル behavior mock（mock_lb_phone）

lb-phone 本体が無い環境で挙動確認するための疑似実装。

### 提供 export

| export | 挙動 |
| --- | --- |
| `SetCameraComponent(data)` | scripted camera を起動し GameplayCam を毎 tick ミラー追従。`saveToGallery=true` なら擬似撮影して `cb('mock://photo/test-image.png')` + `SaveToGallery` 風ログ |
| `ToggleCameraFrozen()` | 追従停止で座標・角度・FOV を固定 / 再度呼ぶと追従再開 |
| `EnableWalkableCam(selfie)` | ログのみ |
| `DisableWalkableCam()` | `RenderScriptCams(false, …)` + `DestroyCam` で終了・cleanup |
| `IsWalkingCamEnabled()` | 疑似カメラ起動中かを返す |
| `SaveToGallery(link)` | 実保存せず print |

### 視覚確認

* 起動中は画面下部に `MOCK CAM: LIVE`（緑）を表示
* `X` → `ToggleCameraFrozen()` で `FROZEN`（赤）に変わり、プレイヤーが動いても
  視点が追従しない → 固定が目視できる

> mock は開発用であり、本物の lb-phone と同時に start しないこと。

---

## テスト方針

### ローカル 1 人テスト（mock 利用）

1. `config.lua` の `Config.PhoneResource = 'mock_lb_phone'` に変更
2. `server.cfg` に `ensure mock_lb_phone` → `ensure fixed_phone_camera`
3. FXServer 起動 → FiveM 接続
4. 確認:
   * `/phonecam` で疑似カメラ起動（`MOCK CAM: LIVE`）＋ F8 に撮影ログ
   * `X` で `FROZEN` / `LIVE` を切替、固定中は視点が追従しない
   * `/phonecam`（2 回目）で終了・通常視点へ
   * `restart` でカメラが残らない
   * F8 console にエラーが出ない

### 本番（実 lb-phone）

1. `Config.PhoneResource = 'lb-phone'` に戻す
2. `server.cfg` に `ensure lb-phone` → `ensure fixed_phone_camera`（**順番厳守**）
3. `/phonecam` でスマホカメラ UI が開き、撮影がギャラリーへ保存されることを確認

---

## 受け入れ条件

* `/phonecam` で lb-phone のカメラ UI が開く
* `saveToGallery=true` で撮影画像がギャラリーに保存される
* 撮影後 callback で `src` が取得・print される
* カメラ起動中に `X` で視点が固定 / 固定解除される
* `/phonecam` 終了・resource stop で `DisableWalkableCam()` が呼ばれ後片付けされる
* lb-phone 未起動時にクラッシュせず通知 print が出る
* mock 利用時、`X` で画面上のカメラ固定が目視できる

---

## 開発優先度

### Phase 1: MVP（現状）

* `/phonecam` でカメラ開閉
* `saveToGallery` によるギャラリー保存
* 撮影 callback の debug log
* `X` で `ToggleCameraFrozen`
* cleanup
* mock による挙動確認

### Phase 2: custom app 化（実装済み）

* lb-phone のホーム画面に custom app "Fixed Cam" を追加（`AddCustomApp`）
* アプリ UI（`ui/index.html`）からカメラ起動 / 固定・解除 / 終了を操作
* `RegisterNUICallback` で UI → client を受け、カメラ操作へ橋渡し
* `SendCustomAppMessage` で client → UI に状態（idle / live / frozen）を反映
* resource stop 時に `RemoveCustomApp` でアプリを撤去

### Phase 3: RP 向け拡張

* 撮影後の後処理・高度な UI
* job / item 連携
* 他プレイヤー向け同期

---

## custom app 要件（Phase 2）

参照: [LB Documentation / Custom Apps](https://docs.lbscripts.com/phone/custom-apps/)

### fxmanifest

* `ui_page 'ui/index.html'`
* `files { 'ui/index.html', 'ui/icon.svg' }`

### 登録 / 撤去

* 自リソース起動時、および lb-phone 起動時に `AddCustomApp` で登録（多重登録しない）
* `AddCustomApp` の主なフィールド: `identifier` / `name` / `description` /
  `developer` / `defaultApp` / `ui` / `icon`
* resource stop で `RemoveCustomApp(identifier)`

### 双方向通信

* UI → client: `fetchNui('openCamera' | 'toggleFrozen' | 'closeCamera')`
  （lb-phone が iframe に注入する helper。未注入時は標準 NUI fetch にフォールバック）
* client → UI: `SendCustomAppMessage(identifier, { action = 'state', state = ... })`
* client は `RegisterNUICallback` で受け、既存のカメラ操作関数へ委譲する

### 受け入れ条件（Phase 2）

* lb-phone ホーム画面に Fixed Cam が表示される
* アプリからカメラ起動・固定・終了ができる
* カメラ状態が UI（IDLE / LIVE / FROZEN）に反映される
* resource stop / restart でアプリが二重登録・残留しない
