# fixed_phone_camera

[lb-phone](https://docs.lbscripts.com/phone/) 連携の **拡張リソース**。
lb-phone のスマホカメラ機能を呼び出して撮影し、画像を lb-phone のギャラリーへ
保存する。カメラ起動中は `X` キーでカメラ視点を固定 / 固定解除できる。

独自の `CreateCam` / `RenderScriptCams` は使わず、lb-phone の client exports に
委譲する方針。ESX / QBCore / ox_inventory には直接依存しない。

## 機能 (MVP)

- `/phonecam` … lb-phone の camera component を開く / 閉じる
  - Photo モード / rear camera / flash off をデフォルトに起動
  - `saveToGallery = true`（撮影画像はギャラリーへ保存）
  - 撮影後は callback で `src` を受け取り F8 console に print
- `X`（デフォルト）… カメラ起動中に `ToggleCameraFrozen()` を呼んで固定 / 固定解除
- resource stop 時に `DisableWalkableCam()` を呼んでクリーンアップ

## 依存関係

- **lb-phone**（必須）。`fxmanifest.lua` に `dependency 'lb-phone'` を宣言済み。
- lb-phone が起動していない場合はエラーにせず、`/phonecam` 実行時に通知 print する。

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

   > ⚠️ `start` する名前は **フォルダ名** です。リポジトリを `fixed-camera` の
   > まま置いた場合は名前を `fixed_phone_camera` に変更するか、その名前で start してください。

2. `server.cfg` に **lb-phone より後** で起動設定を追加する（下記）。
3. サーバー再起動、またはコンソールで `refresh` → `start fixed_phone_camera`。

## server.cfg への追加例（順番が重要）

```cfg
# 依存先を先に起動
ensure lb-phone

# 本リソースは lb-phone の後
ensure fixed_phone_camera
```

lb-phone の exports に依存するため、**必ず `lb-phone` を先に `ensure`** すること。

## 設定 (config.lua)

| キー | デフォルト | 説明 |
| --- | --- | --- |
| `Config.PhoneResource` | `'lb-phone'` | 依存する lb-phone のリソース名 |
| `Config.Command` | `'phonecam'` | カメラ開閉コマンド |
| `Config.ToggleFrozenKeyCommand` | `'+phonecam_freeze'` | 固定トグル用の内部コマンド |
| `Config.DefaultKey` | `'X'` | 固定トグルのデフォルトキー |
| `Config.CameraDefault` | Photo / flash off / rear | カメラ初期状態 |
| `Config.CameraPermissions` | toggleFlash / flipCamera / takePhoto = true | UI で許可する操作 |
| `Config.SaveToGallery` | `true` | 撮影画像をギャラリー保存 |
| `Config.UseWalkableCam` | `true` | 起動時に `EnableWalkableCam` を呼ぶ |
| `Config.WalkableSelfie` | `false` | `EnableWalkableCam(selfieMode)` の引数 |
| `Config.Debug` | `true` | F8 console にデバッグログを出す |

キーバインドは FiveM の **Settings → Key Bindings → FiveM** から変更可能。

## 使用している lb-phone exports

- `SetCameraComponent(data)` … カメラ UI を開く（`default` / `permissions` / `saveToGallery` / `cb`）
- `EnableWalkableCam(selfieMode)` … 歩けるカメラを有効化
- `DisableWalkableCam()` … 歩けるカメラを無効化（cleanup）
- `ToggleCameraFrozen()` … カメラ固定 / 固定解除

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
