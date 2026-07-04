# mock_lb_phone

`fixed_phone_camera` をローカルで動作確認するための **lb-phone behavior mock**。
本物の lb-phone が無い環境でも、呼ばれる export の挙動を実際の FiveM scripted
camera で再現する。

> ⚠️ これは開発用の疑似実装です。本物の lb-phone の代替ではありません。
> 本物のスマホ UI・ギャラリー保存・映像同期は再現しません。
> **本物の `lb-phone` と同時に start しないでください。**

## 提供する export

| export | 挙動 |
| --- | --- |
| `SetCameraComponent(data)` | scripted camera を起動し、GameplayCam を毎 tick ミラー追従。`saveToGallery=true` なら擬似撮影して `data.cb('mock://photo/test-image.png')` を呼び、`SaveToGallery` 風ログを出す |
| `ToggleCameraFrozen()` | 追従を停止して現在の座標・角度・FOV で固定 / 再度呼ぶと追従再開 |
| `EnableWalkableCam(selfie)` | ログのみ（実カメラ起動は `SetCameraComponent` 側） |
| `DisableWalkableCam()` | `RenderScriptCams(false, …)` + `DestroyCam` でカメラ終了・cleanup |
| `IsWalkingCamEnabled()` | 疑似カメラ起動中かを boolean で返す |
| `SaveToGallery(link)` | 実保存せず link を print |
| `AddCustomApp(data)` / `RemoveCustomApp(id)` | custom app 登録 / 撤去（ログのみ、UI は描画しない） |
| `SendCustomAppMessage(id, data)` | app UI への状態送信（ログのみ） |

> mock には実スマホ UI が無いため、custom app の画面描画は確認できません。
> custom app の UI 確認は実 lb-phone が必要です。mock では export 配線と
> カメラ挙動（LIVE / FROZEN）の確認に利用してください。

## 視覚的な確認ポイント

- カメラ起動中は画面下部に `MOCK CAM: LIVE`（緑）を表示。
- `ToggleCameraFrozen()`（= `fixed_phone_camera` の `X`）で `MOCK CAM: FROZEN`（赤）に変わり、
  プレイヤーが動いてもカメラ視点が追従しなくなる → **固定されたことが目視できる**。

## ローカルテスト手順

1. `fixed_phone_camera/config.lua` の `Config.PhoneResource` を `'mock_lb_phone'` に変更。
2. `server.cfg` で mock を先に起動：

   ```cfg
   ensure mock_lb_phone
   ensure fixed_phone_camera
   ```

3. FiveM 接続後：
   - サーバー参加直後は Fixed Cam UI が **表示されない**（フォーカスも無い）
   - `/phonecam` → 疑似カメラ起動（`MOCK CAM: LIVE`）＋ F8 に擬似撮影ログ・`SaveToGallery -> mock://photo/test-image.png`
   - `X` → `FROZEN` になり視点固定 / もう一度で `LIVE` に戻り追従再開
   - `/phonecam`（2回目）→ `DisableWalkableCam` でカメラ終了・通常視点へ
   - `/openfixedapp` → **その時だけ** Fixed Cam ランチャー UI が開き、マウス
     カーソルでボタンを操作できる（`SetNuiFocus(true, true)`）
   - ランチャーの「カメラを起動」→ UI が閉じフォーカス解放され、疑似カメラ起動
   - `restart mock_lb_phone` してもカメラ・NUI フォーカスが残らない

> mock には本物のスマホ UI が無いため、`/openfixedapp` は「アプリアイコンの
> タップ」を代替するコマンドです（`fixed_phone_camera:openApp` を TriggerEvent）。
