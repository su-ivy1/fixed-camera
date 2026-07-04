# fixed_phone_camera

[lb-phone](https://docs.lbscripts.com/phone/) 連携の **拡張リソース**。
lb-phone のスマホカメラ機能を呼び出して撮影し、画像を lb-phone のギャラリーへ
保存する。カメラ起動中は `X` キーでカメラ視点を固定 / 固定解除できる。

独自の `CreateCam` / `RenderScriptCams` は使わず、lb-phone の client exports に
委譲する方針。ESX / QBCore / ox_inventory には直接依存しない。

## 機能

### custom app "Fixed Cam" (Phase 2)

- lb-phone のホーム画面に **Fixed Cam** アプリを追加（`AddCustomApp`）
- アプリ画面から「カメラを起動 / 固定・解除 / 終了」を操作
- カメラ状態（IDLE / LIVE / FROZEN）を `SendCustomAppMessage` で UI にリアルタイム反映
- resource stop 時に `RemoveCustomApp` でアプリを撤去

### カメラ機能 (Phase 1 / 共通)

- `/phonecam` … lb-phone の camera component を開く / 閉じる（コマンドからも利用可）
  - Photo モード / rear camera / flash off をデフォルトに起動
  - `saveToGallery = true`（撮影画像はギャラリーへ保存）
  - 撮影後は callback で `src` を受け取り F8 console に print
- `X`（デフォルト）… カメラ起動中に `ToggleCameraFrozen()` を呼んで固定 / 固定解除
- resource stop 時に `DisableWalkableCam()` を呼んでクリーンアップ

## 依存関係

- **lb-phone**（本番）または **mock_lb_phone**（ローカル）。どちらに依存するかは
  `config.lua` の **`Config.PhoneResource` 1 行だけ**で切り替える。
  - 本番: `Config.PhoneResource = 'lb-phone'`
  - ローカル: `Config.PhoneResource = 'mock_lb_phone'`
- `fxmanifest.lua` に `dependency` は宣言しない（特定リソース名に固定されると
  mock 単体起動を妨げるため）。起動順は `server.cfg` の `ensure` 順、存在確認は
  runtime の `GetResourceState` で担保する。
- 電話リソースが起動していない場合はエラーにせず、`/phonecam` 実行時に通知 print する。

## インストール

1. このリソースをサーバーの `resources` 配下に置く（フォルダ名 = リソース名）。

   ```txt
   resources/
     [local]/
       fixed_phone_camera/
         fxmanifest.lua
         config.lua
         client/
           main.lua
   ```

   > ℹ️ `start` する名前は **フォルダ名** です。custom app の UI / アイコンの
   > パスは `GetCurrentResourceName()` から導出されるため、フォルダ名は
   > `fixed_phone_camera` でも `fixed-camera` でも動作します。以降の例では
   > `fixed_phone_camera` を使いますが、実際のフォルダ名に読み替えてください。

2. `server.cfg` に **電話リソースより後** で起動設定を追加する（下記）。
3. サーバー再起動、またはコンソールで `refresh` → `start <フォルダ名>`。

## server.cfg への追加例（順番が重要）

```cfg
# 依存先 (Config.PhoneResource で指定したリソース) を先に起動
ensure lb-phone

# 本リソースは電話リソースの後
ensure fixed_phone_camera
```

`Config.PhoneResource` の exports に依存するため、**必ず電話リソースを先に
`ensure`** すること。ローカルで mock を使う場合は `ensure lb-phone` の行を
`ensure mock_lb_phone` に置き換える。

## 設定 (config.lua)

| キー | デフォルト | 説明 |
| --- | --- | --- |
| `Config.PhoneResource` | `'lb-phone'` | 依存する電話リソース名（**本番/mock 切替はここ 1 箇所**） |
| `Config.Command` | `'phonecam'` | カメラ開閉コマンド |
| `Config.ToggleFrozenKeyCommand` | `'+phonecam_freeze'` | 固定トグル用の内部コマンド |
| `Config.DefaultKey` | `'X'` | 固定トグルのデフォルトキー |
| `Config.CameraDefault` | Photo / flash off / rear | カメラ初期状態 |
| `Config.CameraPermissions` | toggleFlash / flipCamera / takePhoto = true | UI で許可する操作 |
| `Config.SaveToGallery` | `true` | 撮影画像をギャラリー保存 |
| `Config.UseWalkableCam` | `true` | 起動時に `EnableWalkableCam` を呼ぶ |
| `Config.WalkableSelfie` | `false` | `EnableWalkableCam(selfieMode)` の引数 |
| `Config.UseCustomApp` | `true` | lb-phone の custom app として登録する |
| `Config.App` | identifier / name / ui / icon など | custom app のメタ情報 |
| `Config.Debug` | `true` | F8 console にデバッグログを出す |

キーバインドは FiveM の **Settings → Key Bindings → FiveM** から変更可能。

## 使用している lb-phone exports

- `SetCameraComponent(data)` … カメラ UI を開く（`default` / `permissions` / `saveToGallery` / `cb`）
- `EnableWalkableCam(selfieMode)` … 歩けるカメラを有効化
- `DisableWalkableCam()` … 歩けるカメラを無効化（cleanup）
- `ToggleCameraFrozen()` … カメラ固定 / 固定解除
- `AddCustomApp(data)` / `RemoveCustomApp(identifier)` … custom app の登録 / 撤去
- `SendCustomAppMessage(identifier, data)` … app UI へ状態を送信

## custom app の UI

`ui/index.html`（自己完結の HTML/CSS/JS）を `ui_page` として配信し、lb-phone の
スマホ枠内に埋め込む。

- UI → client: `fetchNui('openCamera' | 'toggleFrozen' | 'closeCamera')`
- client → UI: `SendCustomAppMessage(id, { action='state', state='idle'|'live'|'frozen' })`

client 側は `RegisterNUICallback` で受け、カメラ操作へ橋渡しする。

参照: [LB Documentation / Client Exports](https://docs.lbscripts.com/phone/exports/client-exports/)

## ローカルテスト手順

1. `resources` に `lb-phone` と `fixed_phone_camera` を配置。
2. `server.cfg` に `ensure lb-phone` → `ensure fixed_phone_camera` の順で記載。
3. FXServer 起動 → FiveM から接続。
4. 動作確認:
   - `/phonecam` で lb-phone のカメラ UI が開く
   - 撮影すると F8 console に `captured src: ...` が出る
   - 撮影画像が lb-phone のギャラリーに保存される
   - カメラ起動中に `X` で視点が固定 / 固定解除される
   - もう一度 `/phonecam` でカメラを閉じる
   - `restart fixed_phone_camera` しても walkable cam が残らない
   - lb-phone を止めた状態で `/phonecam` → エラーにならず通知 print が出る
5. デバッグは `config.lua` の `Config.Debug = true`（デフォルト有効）。

## lb-phone なしでローカル確認する (mock)

本物の lb-phone が無い環境では、同梱の [`mock_lb_phone`](mock_lb_phone/README.md)
（behavior mock）で挙動確認できる。実際の scripted camera が起動し、`X` で視点が
固定されることを画面上で確認できる。

1. `config.lua` の `Config.PhoneResource` を `'mock_lb_phone'` に変更。
2. `server.cfg`:

   ```cfg
   ensure mock_lb_phone
   ensure fixed_phone_camera
   ```

3. `/phonecam` → `X`（固定/解除）→ `/phonecam`（終了）で動作を確認。

> 本番では `Config.PhoneResource = 'lb-phone'` に戻し、`mock_lb_phone` は start しないこと。

## ロードマップ

- **MVP (現状)**: `/phonecam` でカメラ開閉・撮影→ギャラリー保存・`X` で固定トグル・cleanup
- **今後**: lb-phone の custom app 化、撮影後の後処理、job / item 連携 など

詳細は [`docs/requirements.md`](docs/requirements.md) を参照。
