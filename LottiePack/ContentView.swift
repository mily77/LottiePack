import SwiftUI
import UniformTypeIdentifiers

/// 主界面：负责组合任务列表、设置面板、详情与日志区域。
struct ContentView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 1080, minHeight: 720)
        .background(windowBackground)
        .alert("转换失败", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.alertMessage = nil
                }
            }
        )) {
            Button("好") {
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                actionCard
                taskList
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(sidebarBackground)
        .navigationSplitViewColumnWidth(min: 320, ideal: 360)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryGrid
                settingsCard
                selectedDetailCard
                logCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(detailBackground)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("LottiePack")
            } icon: {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(heroAccentColor)
            }
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(heroPrimaryTextColor)
            Text("把 Lottie 资源目录、`data.json` 或 `.zip` 快速转换成 `.lottie` 文件。")
                .font(.subheadline)
                .foregroundStyle(heroSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            DropZoneView(isTargeted: $viewModel.isDropTargeted) { urls in
                Task {
                    await viewModel.handleDroppedURLs(urls)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: heroGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(heroBorderColor, lineWidth: 1)
        )
        .shadow(color: heroShadowColor, radius: 24, x: 0, y: 16)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            Task {
                await viewModel.handleDroppedURLs(urls)
            }
            return true
        } isTargeted: { targeted in
            viewModel.isDropTargeted = targeted
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("操作", subtitle: "导入资源、选择导出目录并启动转换")
            Button {
                viewModel.importItems()
            } label: {
                Label("导入资源", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandButtonStyle(role: .primary))

            Button {
                viewModel.selectExportDirectory()
            } label: {
                Label(viewModel.exportDirectory == nil ? "选择导出目录" : "更换导出目录", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandButtonStyle(role: .secondary))

            Button {
                Task {
                    await viewModel.convertAll()
                }
            } label: {
                Label(viewModel.isConverting ? "转换中..." : "开始转换", systemImage: "sparkles.rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandButtonStyle(role: .primary))
            .disabled(!viewModel.canConvert)

            if let exportDirectory = viewModel.exportDirectory {
                MetadataStripView(title: "导出目录", value: exportDirectory.path, icon: "folder.fill")
            }
        }
        .padding(18)
        .background(PanelCard())
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("任务列表", subtitle: viewModel.items.isEmpty ? "等待导入动画资源" : "已导入 \(viewModel.items.count) 个任务")
                Spacer()
                if !viewModel.items.isEmpty {
                    Button("清空") {
                        viewModel.clearItems()
                    }
                    .buttonStyle(BrandButtonStyle(role: .ghost))
                }
            }

            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "还没有导入任务",
                    systemImage: "tray",
                    description: Text("支持文件夹、`data.json`、`.zip`，也支持直接拖拽。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.items) { item in
                        Button {
                            viewModel.selectedItemID = item.id
                        } label: {
                            TaskRow(item: item, isSelected: item.id == viewModel.selectedItemID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(PanelCard())
    }

    private var summaryGrid: some View {
        HStack(spacing: 16) {
            SummaryCard(title: "已导入", value: "\(viewModel.items.count)", subtitle: "待处理资源", tint: .blue)
            SummaryCard(title: "成功", value: "\(viewModel.items.filter { $0.status == .success }.count)", subtitle: "已生成 .lottie", tint: .green)
            SummaryCard(title: "警告", value: "\(viewModel.items.reduce(0) { $0 + $1.warnings.count })", subtitle: "需人工确认", tint: .orange)
            SummaryCard(title: "失败", value: "\(viewModel.items.filter { if case .failed = $0.status { return true } else { return false } }.count)", subtitle: "需要重试", tint: .red)
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("导出设置", subtitle: "控制 Finder 行为和重名处理策略")
            Toggle("转换完成后在 Finder 中显示", isOn: $viewModel.revealInFinder)
            Toggle("输出重名时自动追加序号", isOn: $viewModel.autoRenameConflicts)
            Text("当前支持导入资源目录、单个 `data.json` 和 `.zip` 包。ZIP 会先解压到临时目录再转换。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(PanelCard())
    }

    private var selectedDetailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("任务详情", subtitle: "查看来源、状态和导出结果")

            if let item = viewModel.selectedItem {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(.title3.weight(.semibold))
                        Text(item.sourceTypeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: item.status)
                }

                DetailSection(title: "来源", icon: "tray.and.arrow.down.fill") {
                    MetadataStripView(title: "资源路径", value: item.sourceURL.path, icon: "folder")
                }

                DetailSection(title: "状态", icon: "gauge.with.needle.fill") {
                    MetadataStripView(title: "当前状态", value: item.status.label, icon: item.status.icon)
                }

                if let outputURL = item.outputURL {
                    DetailSection(title: "导出文件", icon: "shippingbox.fill") {
                        MetadataStripView(title: "文件位置", value: outputURL.path, icon: "doc.fill")
                    }
                }

                if !item.warnings.isEmpty {
                    DetailSection(title: "警告", icon: "exclamationmark.triangle.fill") {
                        ForEach(item.warnings, id: \.self) { warning in
                            WarningRowView(text: warning)
                        }
                    }
                }

                if let failure = item.failureMessage {
                    DetailSection(title: "失败原因", icon: "xmark.octagon.fill") {
                        WarningRowView(text: failure, tint: .red, icon: "xmark.octagon.fill")
                    }
                }
            } else {
                Text("选择一个任务查看详情。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(PanelCard())
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("运行日志", subtitle: "帮助排查导入或转换过程中的问题")
            if viewModel.logs.isEmpty {
                Text("暂无日志")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.logs.indices, id: \.self) { index in
                            Text(viewModel.logs[index])
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: 140)
            }
        }
        .padding(18)
        .background(PanelCard())
    }

    private var heroGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.15, green: 0.19, blue: 0.24),
                Color(red: 0.18, green: 0.24, blue: 0.20)
            ]
        }

        return [
            Color(red: 0.92, green: 0.96, blue: 0.99),
            Color(red: 0.95, green: 0.96, blue: 0.92)
        ]
    }

    private var heroPrimaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.88)
    }

    private var heroSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62)
    }

    private var heroAccentColor: Color {
        colorScheme == .dark ? Color(red: 0.45, green: 0.74, blue: 1.0) : .blue
    }

    private var heroBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.45)
    }

    private var heroShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color(red: 0.42, green: 0.55, blue: 0.70).opacity(0.18)
    }

    private var windowBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: backgroundGlowColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(colorScheme == .dark ? 0.55 : 0.8)
        }
    }

    private var sidebarBackground: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.015) : Color.white.opacity(0.35))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                    .frame(width: 1)
            }
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [Color.clear, Color.white.opacity(0.01)] : [Color.white.opacity(0.18), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundGlowColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.10, green: 0.14, blue: 0.19), Color(red: 0.11, green: 0.18, blue: 0.16), Color.clear]
        }

        return [Color(red: 0.93, green: 0.97, blue: 1.0), Color(red: 0.97, green: 0.98, blue: 0.94), Color.clear]
    }

    @ViewBuilder
    /// 统一渲染分区标题与副标题，保持卡片头部风格一致。
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

}

/// 顶部摘要卡：展示总任务、成功、告警和失败统计。
private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.95 : 0.9))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 14, x: 0, y: 8)
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.88)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : tint.opacity(0.08)
    }
}

/// 通用卡片背景容器：提供一致的填充、描边和阴影样式。
private struct PanelCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 18, x: 0, y: 12)
    }

    private var fillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.028) : Color.white.opacity(0.78)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.black.opacity(0.06)
    }
}

/// 任务行视图：展示单个任务的名称、来源和状态概览。
private struct TaskRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: ConversionItemViewData
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.status.icon)
                .foregroundStyle(statusColor)
                .font(.headline)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.sourceTypeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.warnings.isEmpty {
                    Text("\(item.warnings.count) 个警告")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
    }

    private var rowFillColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.accentColor.opacity(0.20) : Color.accentColor.opacity(0.10)
        }

        return colorScheme == .dark ? Color.white.opacity(0.02) : Color.white.opacity(0.70)
    }

    private var rowBorderColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.accentColor.opacity(0.45) : Color.accentColor.opacity(0.18)
        }

        return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }

    private var statusColor: Color {
        switch item.status {
        case .pending:
            return .secondary
        case .converting:
            return .accentColor
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
}

/// 详情卡片中的分组容器：带图标标题和自定义内容区。
private struct DetailSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let content: AnyView

    /// 初始化详情分组并做类型擦除，便于统一存储内容视图。
    init<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = AnyView(content())
    }

    var body: some View {
        let fill = colorScheme == .dark ? Color.white.opacity(0.02) : Color.white.opacity(0.55)
        let stroke = colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            content
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

/// 键值信息条：用于显示路径、状态等可复制文本信息。
private struct MetadataStripView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let icon: String

    var body: some View {
        let fill = colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.72)
        let stroke = colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

/// 告警行视图：用于展示警告或失败原因。
private struct WarningRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var tint: Color = .orange
    var icon: String = "exclamationmark.triangle.fill"

    var body: some View {
        let fill = tint.opacity(colorScheme == .dark ? 0.12 : 0.08)
        let stroke = tint.opacity(colorScheme == .dark ? 0.28 : 0.18)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

/// 状态徽章：将转换状态映射为颜色和图标标签。
private struct StatusBadge: View {
    let status: ConversionStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
            Text(status.label)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foregroundColor)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: return .secondary
        case .converting: return .accentColor
        case .success: return .green
        case .failed: return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var borderColor: Color {
        foregroundColor.opacity(0.2)
    }
}

/// 应用内统一按钮样式，按角色区分主次交互层级。
private struct BrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    enum Role {
        case primary
        case secondary
        case ghost
    }

    @Environment(\.colorScheme) private var colorScheme
    let role: Role

    /// 构建按钮外观并根据按压/禁用状态反馈视觉变化。
    func makeBody(configuration: Configuration) -> some View {
        let foreground = foregroundColor(configuration: configuration)
        let background = backgroundColor(configuration: configuration)
        let border = borderColor(configuration: configuration)

        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        switch role {
        case .primary: return .white.opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.82)
        case .secondary: return colorScheme == .dark ? .white.opacity(isEnabled ? 0.92 : 0.62) : .black.opacity(isEnabled ? 0.86 : 0.5)
        case .ghost: return .secondary
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        switch role {
        case .primary:
            return Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.10 : 0.08) : 0.04) : Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.88 : 0.72) : 0.45)
        case .ghost:
            return colorScheme == .dark ? Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.07 : 0.04) : 0.03) : Color.black.opacity(isEnabled ? (configuration.isPressed ? 0.08 : 0.04) : 0.03)
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch role {
        case .primary:
            return Color.accentColor.opacity(configuration.isPressed ? 0.3 : 0.16)
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        case .ghost:
            return Color.clear
        }
    }
}

/// 拖拽投放区域：负责拖拽态反馈和可投放内容提示。
private struct DropZoneView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isTargeted: Bool
    let onDropURLs: ([URL]) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? dropAccentColor.opacity(0.12) : dropBackgroundColor)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                .foregroundStyle(isTargeted ? dropAccentColor : dropBorderColor)
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 24))
                    .foregroundStyle(dropAccentColor)
                Text("拖拽资源到这里")
                    .font(.headline)
                    .foregroundStyle(dropPrimaryTextColor)
                Text("支持动画目录、`data.json`、`.zip`")
                    .font(.caption)
                    .foregroundStyle(dropSecondaryTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dropPrimaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85)
    }

    private var dropSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.58)
    }

    private var dropAccentColor: Color {
        colorScheme == .dark ? Color(red: 0.45, green: 0.74, blue: 1.0) : .accentColor
    }

    private var dropBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.18)
    }

    private var dropBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.28)
    }
}

#Preview {
    ContentView()
}
