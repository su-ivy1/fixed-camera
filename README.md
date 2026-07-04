# fixed_camera

GTA5 / FiveM 向けの **standalone** カメラリソース。
`/cam` でカメラモードを開始し、`X` キーで現在のカメラ視点を固定 / 解除できる。

ESX / QBCore / ox_inventory には依存しない。NUI・映像同期は未実装（Phase 1 MVP）。

## 機能 (Phase 1)

- `/cam` … カメラモードの ON / OFF トグル
- `X`（デフォルト）… カメラモード中に視点を固定 / 解除
  - `handheld`（追従）↔ `fixed`（固定）を切り替え
- resource stop / restart 時に camera・prop・render state を安全にクリーンアップ

## インストール

1. このリソースを FiveM サーバーの `resources` 配下に置く。
   フォルダ名はリソース名と一致させる（例: `resources/[local]/fixed_camera`）。

   ```txt
   resources/
     [local]/
       fixed_camera/
         fxmanifest.lua
         config.lua
         client/
           main.lua
   ```

   > ⚠️ `start` する名前は **フォルダ名** です。リポジトリを `fixed-camera` の
   > まま置いた場合は `start fixed-camera` としてください。

2. `server.cfg` に起動設定を追加する（下記）。
3. サーバーを再起動、またはコンソールで `refresh` → `start fixed_camera`。

## server.cfg への追加例

```cfg
# fixed_camera (standalone)
ensure fixed_camera
```

`ensure` は「未起動なら start、起動済みなら restart」する推奨コマンド。

## 設定 (config.lua)

| キー | デフォルト | 説明 |
| --- | --- | --- |
| `Config.Command` | `'cam'` | カメラモードのコマンド名 |
| `Config.ToggleFixedKeyCommand` | `'+fixedcam_toggle'` | 固定トグル用の内部コマンド |
| `Config.DefaultMapper` | `'keyboard'` | キーマッパー |
| `Config.DefaultKey` | `'X'` | 固定トグルのデフォルトキー |
| `Config.CameraName` | `'DEFAULT_SCRIPTED_CAMERA'` | scripted camera 種別 |
| `Config.Fov` | `50.0` | 視野角 |
| `Config.RotationSpeed` | `6.0` | （Phase 2 用）回転速度 |
| `Config.ZoomSpeed` | `2.0` | （Phase 2 用）ズーム速度 |
| `Config.PropModel` | `'prop_v_cam_01'` | 手持ちカメラ prop |
| `Config.Debug` | `false` | F8 console にデバッグログを出す |

キーバインドは FiveM の **Settings → Key Bindings → FiveM** からユーザー側で変更可能。

## ローカルテスト手順

FXServer を使ったローカル 1 人テスト。

1. リソースを `resources/[local]/fixed_camera` に配置。
2. `server.cfg` に `ensure fixed_camera` を追加。
3. FXServer 起動 → FiveM から接続。
4. 動作確認:
   - `/cam` でカメラ視点に切り替わる
   - `X` で視点が固定される（プレイヤーが動いても追従しない）
   - もう一度 `X` で手持ち追従に戻る
   - `/cam` で通常視点に戻る
   - `restart fixed_camera` しても画面が固定されたままにならない
   - F8 console にエラーが出ない
5. デバッグ時は `config.lua` の `Config.Debug = true` にするとログが出る。

### 異常系の確認ポイント

- `/cam` 連打で camera / prop が増殖しない
- `fixed` 状態のまま `/cam` 終了 → 正常に後片付けされる
- `prop_v_cam_01` が存在しない環境でもクラッシュしない（prop なしで続行）

## 開発ロードマップ

- **Phase 1 (このMVP)**: `/cam`・視点 ON/OFF・`X` で固定/解除・cleanup・debug log
- **Phase 2**: prop の見た目改善・構えアニメ・画面エフェクト・zoom・操作説明
- **Phase 3**: job 制限・inventory 連携・他プレイヤー同期・NUI

詳細は [`docs/requirements.md`](docs/requirements.md) を参照。
