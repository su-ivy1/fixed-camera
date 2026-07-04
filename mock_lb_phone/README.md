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
   - `/phonecam` → 疑似カメラ起動（`MOCK CAM: LIVE`）＋ F8 に擬似撮影ログ・`SaveToGallery -> mock://photo/test-image.png`
   - `X` → `FROZEN` になり視点固定 / もう一度で `LIVE` に戻り追従再開
   - `/phonecam`（2回目）→ `DisableWalkableCam` でカメラ終了・通常視点へ
   - `restart mock_lb_phone` してもカメラが残らない
