# ブロック型ターミナル
## macOS向けアプリケーション仕様書（統合版 v2.0）

---

## 1. 目的

本アプリケーションは、macOS上で動作する**フル機能ターミナルエミュレータ**であり、以下を両立することを目的とする。

1. 既存ターミナルと同等の完全互換機能
2. コマンド＋出力を「ブロック」として扱うUI
3. ブロック単位コピーとCopy Stack機能
4. テーマ切替（Liquid Glass風含む）
5. タブによる複数セッション管理

ブロックUIは**ターミナル互換性を損なわない上位抽象レイヤー**として設計する。

---

## 2. 対象環境

- 対応OS: macOS 13以降
- 実装技術: SwiftUI + 必要に応じてAppKit
- シェル: zsh（デフォルト）、bash等も動作可能
- 配布形式: `.app`

---

## 3. 全体アーキテクチャ

```text
UI Layer (SwiftUI)
├─ TabBar
├─ BlockListView
├─ RawTerminalOverlay
└─ CopyStackDrawer

Block Abstraction Layer
├─ PromptDetector
├─ BlockBoundaryManager
└─ OutputBuffer

Terminal Emulation Layer
├─ ANSI Parser
├─ ScreenBuffer
├─ CursorState
└─ ScrollbackBuffer

PTY Layer
├─ posix_openpt
├─ fork / exec
└─ read / write

Shell (zsh / bash)
```

---

## 4. ターミナル互換要件（最低要件）

### 4.1 ANSI / VT100対応

最低限以下をサポートする。

- カーソル移動（CSI）
- SGR（色・装飾）
- 8 / 16 / 256色
- クリアスクリーン
- 行削除
- スクロール領域
- Alternate Screen Buffer

### 4.2 Screen Buffer設計

```swift
struct ScreenCell {
    var character: Character
    var foreground: Color
    var background: Color
    var attributes: TextAttributes
}

class ScreenBuffer {
    var rows: Int
    var columns: Int
    var grid: [[ScreenCell]]
    var cursorPosition: (row: Int, col: Int)
}
```

- ウィンドウリサイズ時に再構築
- Alternate Buffer対応

### 4.3 対話型アプリ対応（必須）

正常動作対象:

- `vim` / `nvim`
- `less`
- `top` / `htop`
- `man`
- `ssh`
- `tmux`

要件:

- Alternate Screen有効
- Rawモード切替
- 終了時Blockモード復帰

## 5. セッション仕様

### 5.1 セッション定義

```swift
struct Session {
    id: UUID
    shellPath: String
    blocks: [Block]
    activeBlock: Block?
    workingDirectory: URL?
    createdAt: Date
    isAlive: Bool
}
```

- タブ = 1セッション
- 各セッションは独立PTY

## 6. ブロック仕様

### 6.1 Block構造

```swift
struct Block {
    id: UUID
    command: String
    stdout: String
    stderr: String
    startedAt: Date
    finishedAt: Date?
    exitCode: Int?
    status: BlockStatus
}

enum BlockStatus {
    case running
    case success
    case failure
    case interrupted
}
```

### 6.2 ブロック確定方式

正式仕様:

1. ユーザー入力送信
2. シェルが新プロンプトを表示
3. プロンプト検出で前Block確定

### 6.3 プロンプト検出（推奨方式）

シェルに専用PS1を設定:

```bash
export PS1="<<<BLOCK_PROMPT>>> "
```

出力ストリーム内の特定文字列検出によりBlock境界を確定する。

## 7. 表示モード

```swift
enum DisplayMode {
    case blockMode
    case rawMode
}
```

- `blockMode`: 通常ブロック表示
- `rawMode`: Alternate Screen有効時

## 8. UI仕様

### 8.1 メイン構成

- 上部: タブバー
- 中央: ブロックリスト
- 下部: 入力バー
- 右側: Copy Stackドロワー

### 8.2 ブロックUI構造

```text
✓ 12:31:22        [Copy]
$ ls -la
---------------------------
total 32
drwxr-xr-x ...
```

要素:

- ステータス表示
- 実行時刻
- Copyボタン
- コマンド（強調）
- 出力（等幅フォント）

## 9. Copy Stack仕様

### 9.1 データ構造

```swift
struct CopiedBlock {
    id: UUID
    formattedText: String
    copiedAt: Date
}

class CopyQueueManager {
    var items: [CopiedBlock]
}
```

### 9.2 コピー仕様

単体コピー:

- `NSPasteboard` へ書き込み
- `CopyQueue` に追加

Copy All:

- 順序通り連結
- クリップボードへ書き込み

### 9.3 フォーマット例

```text
--- BLOCK ---
$ git status

On branch main
Your branch is up to date with 'origin/main'.
```

## 10. 入力仕様（完全互換）

対応キー:

- `Ctrl+C` -> `SIGINT`
- `Ctrl+Z` -> `SIGTSTP`
- `Ctrl+D` -> `EOF`
- `Ctrl+L` -> `clear`
- `Tab` -> 補完
- `↑ ↓` -> 履歴（シェル管理）

## 11. スクロールバック

- 最低10,000行保持
- リングバッファ方式
- Rawモード時も保持

## 12. ウィンドウリサイズ

- `SIGWINCH`送信
- `ScreenBuffer`再構築
- 即時再描画

## 13. テーマ仕様

### 13.1 Theme構造

```swift
struct Theme {
    backgroundMaterial: MaterialType
    blockBackgroundColor: Color
    blockBorderColor: Color
    fontColor: Color
    errorColor: Color
    cornerRadius: CGFloat
}
```

### 13.2 Defaultテーマ

- 単色背景
- ダーク/ライト

### 13.3 Glassテーマ

- `NSVisualEffectView`
- `material: .hudWindow`
- 半透明ブロック
- 薄い境界線
- `cornerRadius` 16以上

## 14. パフォーマンス要件

- 60fps維持
- 出力10MBでもクラッシュしない
- 描画バッチ処理
- UI更新はフレーム単位で制御

## 15. エラー処理

- シェル終了時: `isAlive = false`
- `Ctrl+C`: `interrupted`状態
- 異常終了メッセージ表示

## 16. 永続化（MVPでは未対応）

将来:

- Block JSON保存
- セッション復元

## 17. MVP完成条件（最終定義）

以下すべて満たす:

- macOSで正常起動
- 3タブ以上安定動作
- コマンド1回 = 1Block
- Copy Stack順序保持
- `vim`正常動作
- `top`正常動作
- `ssh`可能
- `tmux`可能
- 10,000行スクロール
- Rawモード自動切替
- Glassテーマ適用可能

## 18. 技術的リスク

- ANSI実装難易度
- Alternate Screen処理
- プロンプト検出精度
- 大量出力負荷

## 19. 実装戦略（推奨）

- 既存ターミナルエミュレーション実装の流用を検討
- 自前実装は高コスト
- その上にBlock抽象レイヤーを構築

## 20. 結論

本設計は:

- フルターミナル互換
- ブロックUI抽象
- Raw/Blockモード共存
- Copy Stack機能搭載
- テーマ切替対応

単なるUI変更ではなく、完全なターミナルエミュレータの上に構築される拡張UXである。
