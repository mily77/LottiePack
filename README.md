# LottiePack

[English](#english) | [中文](#中文) | [日本語](#日本語)

## Table of Contents

- [English](#english)
  - [Features](#features)
  - [How It Works](#how-it-works)
  - [Usage](#usage)
  - [Tech Stack](#tech-stack)
- [中文](#中文)
  - [功能特性](#功能特性)
  - [工作流程](#工作流程)
  - [使用方式](#使用方式)
  - [技术栈](#技术栈)
- [日本語](#日本語)
  - [主な機能](#主な機能)
  - [動作フロー](#動作フロー)
  - [使い方](#使い方)
  - [技術スタック](#技術スタック)

## English

LottiePack is a macOS app for turning Lottie animation sources into `.lottie` packages in a clean batch workflow. It accepts animation folders, standalone `data.json` files, and `.zip` archives, then rewrites image assets, builds the required manifest, and exports ready-to-use `.lottie` files.

## Features

- Batch import folders, `data.json`, or `.zip` files
- Drag and drop input directly into the workspace
- Auto-detect animation JSON files inside folders and extracted archives
- Validate referenced image assets and surface warnings before export
- Auto-rename duplicate outputs to avoid overwriting existing files
- Optionally reveal the exported file in Finder after conversion

## How It Works

1. Import one or more Lottie sources.
2. Choose an export directory.
3. Start conversion.
4. LottiePack packages each task into a `.lottie` file with:
   - `manifest.json`
   - `animations/animation.json`
   - `images/`

During packaging, local image references in the source JSON are copied into the package and rewritten to use the internal `/images/` path.

## Usage

### In the App

1. Open the project in Xcode and run the `LottiePack` target.
2. Import sources with `Import Assets`, or drag files/folders into the drop zone.
3. Click `Select Export Directory` to choose where `.lottie` files should be saved.
4. Adjust options if needed:
   - `Reveal in Finder after conversion`
   - `Auto-rename duplicate outputs`
5. Click `Start Conversion`.
6. Check the task list, detail panel, and logs for results, warnings, or failures.

### App Language

- The app currently supports English, Simplified Chinese, and Japanese.
- You can switch language from `LottiePack > Settings...` or directly from the menu bar `Language` menu.
- The selected language is applied immediately and remembered for the next launch.

### Supported Inputs

- Folder containing Lottie files
- Single `data.json` or other Lottie JSON file
- `.zip` archive containing a Lottie folder structure

### Notes

- If a folder contains multiple JSON files, `data.json` is preferred when available.
- `manifest.json` files are ignored during import to avoid treating existing dotLottie packages as source animations.
- Missing external images do not always stop conversion, but they are reported as warnings.
- ZIP files are extracted to a temporary directory before conversion.

## Tech Stack

- Swift
- SwiftUI
- AppKit
- macOS file handling with `ditto`, `unzip`, and `zip`





## 中文

LottiePack 是一个 macOS 应用，用于将 Lottie 动画资源快速打包为 `.lottie` 文件，适合批量处理工作流。它支持导入动画文件夹、单独的 `data.json` 文件以及 `.zip` 压缩包，并会自动重写图片资源路径、生成必要的清单文件，最终导出可直接使用的 `.lottie` 文件。

## 功能特性

- 支持批量导入文件夹、`data.json` 或 `.zip` 文件
- 支持直接拖拽资源到工作区
- 自动识别文件夹或解压目录中的动画 JSON 文件
- 在导出前校验外部图片资源，并提示警告信息
- 输出重名时自动追加序号，避免覆盖已有文件
- 转换完成后可选择在 Finder 中定位导出文件

## 工作流程

1. 导入一个或多个 Lottie 资源。
2. 选择导出目录。
3. 开始转换。
4. LottiePack 会将每个任务打包成 `.lottie` 文件，包含：
   - `manifest.json`
   - `animations/animation.json`
   - `images/`

在打包过程中，源 JSON 中引用的本地图片资源会被复制进包内，并统一改写为 `/images/` 路径。

## 使用方式

### 在应用中使用

1. 用 Xcode 打开项目并运行 `LottiePack` target。
2. 点击 `Import Assets` 导入资源，或直接拖拽文件/文件夹到投放区域。
3. 点击 `Select Export Directory` 选择 `.lottie` 文件的保存位置。
4. 按需调整选项：
   - `Reveal in Finder after conversion`
   - `Auto-rename duplicate outputs`
5. 点击 `Start Conversion`。
6. 在任务列表、详情面板和日志中查看结果、警告或失败原因。

### 界面语言

- 应用当前支持 English、简体中文、日本语。
- 可通过 `LottiePack > Settings...` 或菜单栏里的 `Language` 菜单切换语言。
- 切换后立即生效，并会记住下次启动时的选择。

### 支持的输入类型

- 包含 Lottie 资源的文件夹
- 单个 `data.json` 或其他 Lottie JSON 文件
- 包含 Lottie 文件结构的 `.zip` 压缩包

### 说明

- 如果文件夹内存在多个 JSON 文件，程序会优先使用 `data.json`。
- 导入时会忽略 `manifest.json`，避免把现有 dotLottie 包误识别为源动画。
- 缺失的外部图片通常不会直接中断转换，但会以警告形式提示。
- ZIP 文件会先解压到临时目录，再进入转换流程。

## 技术栈

- Swift
- SwiftUI
- AppKit
- 使用 `ditto`、`unzip` 和 `zip` 进行 macOS 文件处理

## 日本語

LottiePack は、Lottie アニメーション素材を `.lottie` パッケージへまとめて変換するための macOS アプリです。アニメーションフォルダ、単体の `data.json`、`.zip` アーカイブを読み込み、画像アセットの参照を書き換え、必要なマニフェストを生成し、そのまま利用できる `.lottie` ファイルを書き出します。

## 主な機能

- フォルダ、`data.json`、`.zip` の一括読み込み
- ワークスペースへのドラッグ＆ドロップ対応
- フォルダ内や展開後アーカイブ内のアニメーション JSON を自動検出
- 外部画像アセットを検証し、書き出し前に警告を表示
- 同名ファイルの書き出し時に自動で連番を付与し、上書きを回避
- 変換完了後に Finder で出力ファイルを表示可能

## 動作フロー

1. 1 つ以上の Lottie ソースを読み込みます。
2. 書き出し先フォルダを選択します。
3. 変換を開始します。
4. LottiePack は各タスクを次の構成を持つ `.lottie` ファイルへまとめます。
   - `manifest.json`
   - `animations/animation.json`
   - `images/`

パッケージ化の際、元の JSON 内で参照されているローカル画像はパッケージ内へコピーされ、参照先は `/images/` に統一されます。

## 使い方

### アプリで使う

1. Xcode でプロジェクトを開き、`LottiePack` ターゲットを実行します。
2. `Import Assets` で素材を読み込むか、ファイルやフォルダをドロップ領域へ直接ドラッグします。
3. `Select Export Directory` をクリックして `.lottie` の保存先を選びます。
4. 必要に応じて次の設定を調整します。
   - `Reveal in Finder after conversion`
   - `Auto-rename duplicate outputs`
5. `Start Conversion` をクリックします。
6. タスクリスト、詳細パネル、ログで結果・警告・失敗内容を確認します。

### アプリの言語

- 現在、English・简体中文・日本語に対応しています。
- `LottiePack > Settings...` またはメニューバーの `Language` メニューから切り替えできます。
- 選択した言語はすぐに反映され、次回起動時にも保持されます。

### 対応入力形式

- Lottie 素材を含むフォルダ
- 単体の `data.json` またはその他の Lottie JSON
- Lottie フォルダ構成を含む `.zip` アーカイブ

### 補足

- フォルダ内に複数の JSON がある場合、`data.json` が優先されます。
- 既存の dotLottie パッケージを誤って入力扱いしないよう、`manifest.json` は読み込み時に除外されます。
- 外部画像が不足していても、必ずしも変換は停止しませんが、警告として表示されます。
- ZIP は変換前に一時ディレクトリへ展開されます。

## 技術スタック

- Swift
- SwiftUI
- AppKit
- `ditto`、`unzip`、`zip` を利用した macOS ファイル処理
