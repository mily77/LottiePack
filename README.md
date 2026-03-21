# LottiePack

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





## LottiePark

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
