# ブロック型ターミナル
## macOS向けアプリケーション仕様書（統合版 v3.0）

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
- シェル: zsh（デフォルト）
- 配布形式: `.app`
- ターミナルエミュレーション: **libvtermを使用**

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

Terminal Emulator Layer
├─ libvterm (C library)
├─ TerminalEmulator wrapper
└─ ScreenBuffer abstraction

PTY Layer
├─ posix_openpt
├─ fork / exec
└─ read / write

Shell (zsh)
```

---

## 4. ターミナル互換要件（最低要件）

### 4.1 ANSI / VT100対応

ANSI解釈は**libvtermに委譲する**。

最低限以下が動作すること:

- カーソル移動（CSI）
- SGR（色・装飾）
- 8 / 16 / 256色
- クリアスクリーン
- 行削除
- スクロール領域
- Alternate Screen Buffer

### 4.2 Screen Buffer設計

libvtermの内部バッファをSwift側で抽象化する。

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

1. ユーザー入力送信
2. シェルが新プロンプトを表示
3. プロンプト検出で前Block確定

### 6.3 プロンプト検出方式

PS1マーカー戦略を使用する。

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

- `blockMode`: ブロック表示
- `rawMode`: Alternate Screen時

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

## 10. 入力仕様

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

## 12. ウィンドウリサイズ

- `SIGWINCH`送信
- libvterm resize反映
- 再描画

## 13. テーマ仕様

### 13.1 Glassテーマ

- `NSVisualEffectView`
- `material: .hudWindow`
- 半透明ブロック
- `cornerRadius` 16以上

## 14. パフォーマンス要件

- 60fps維持
- 10MB出力でクラッシュしない
- バッチ描画

## 15. エラー処理

- シェル終了時: `isAlive = false`
- `Ctrl+C`: `interrupted`状態

## 16. MVP完成条件

以下すべて満たす:

- `vim`正常動作
- `top`正常動作
- `ssh`可能
- `tmux`可能
- 10,000行スクロール
- Rawモード自動切替
- Glassテーマ適用可能
- Copy Stack順序保持

## 17. 実装戦略（確定）

- libvtermを使用
- ANSI自前実装は禁止
- レイヤー分離で実装
- 一度に1レイヤーのみ実装

## 18. 結論

本設計は:

- libvtermによるフル互換エミュレータ
- その上にBlock抽象
- Raw/Block共存
- macOSネイティブUI

完全なターミナルエミュレータの上に構築される拡張UXである。
