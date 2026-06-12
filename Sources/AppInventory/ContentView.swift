import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var scanner = AppScanner()
    @State private var searchText = ""
    @State private var selectedArchFilter: AppInfo.Architecture? = nil
    @State private var selectedSourceFilter: AppInfo.AppSource? = nil
    @State private var sortOrder: [KeyPathComparator<AppInfo>] = [KeyPathComparator(\AppInfo.name)]
    @State private var selectedAppID: AppInfo.ID? = nil
    @State private var displayApps: [AppInfo] = []

    private var sortOrderBinding: Binding<[KeyPathComparator<AppInfo>]> {
        Binding(
            get: { sortOrder },
            set: { newOrder in
                sortOrder = newOrder
                recompute(order: newOrder)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if scanner.apps.isEmpty && !scanner.isScanning {
                emptyState
            } else {
                appTable
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 500)
        .onReceive(scanner.$apps) { newApps in
            recompute(source: newApps)
        }
        .onChange(of: searchText) { _ in recompute() }
        .onChange(of: selectedArchFilter) { _ in recompute() }
        .onChange(of: selectedSourceFilter) { _ in recompute() }
    }

    private func recompute(source: [AppInfo]? = nil, order: [KeyPathComparator<AppInfo>]? = nil) {
        let base = source ?? scanner.apps
        let effectiveOrder = order ?? sortOrder
        let filtered = base.filter { app in
            let matchesSearch = searchText.isEmpty
                || app.name.localizedCaseInsensitiveContains(searchText)
                || app.bundleID.localizedCaseInsensitiveContains(searchText)
            let matchesArch = selectedArchFilter == nil || app.architecture == selectedArchFilter
            let matchesSource = selectedSourceFilter == nil || app.source == selectedSourceFilter
            return matchesSearch && matchesArch && matchesSource
        }
        displayApps = filtered.sorted(using: effectiveOrder)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { scanner.scan() }) {
                Label(scanner.isScanning ? "Scanning…" : "Scan Apps", systemImage: "arrow.clockwise")
            }
            .disabled(scanner.isScanning)
            .keyboardShortcut("r", modifiers: .command)

            Divider().frame(height: 20)

            Menu(selectedArchFilter?.rawValue ?? "All Architectures") {
                Picker("Architecture", selection: $selectedArchFilter) {
                    Text("All Architectures").tag(Optional<AppInfo.Architecture>.none)
                    ForEach(AppInfo.Architecture.allCases, id: \.self) { arch in
                        Text(arch.rawValue).tag(Optional(arch))
                    }
                }
                .pickerStyle(.inline)
            }
            .frame(width: 180)

            Menu(selectedSourceFilter?.rawValue ?? "All Sources") {
                Picker("Source", selection: $selectedSourceFilter) {
                    Text("All Sources").tag(Optional<AppInfo.AppSource>.none)
                    ForEach(AppInfo.AppSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(Optional(source))
                    }
                }
                .pickerStyle(.inline)
            }
            .frame(width: 160)

            Spacer()

            if !scanner.apps.isEmpty {
                Button(action: exportCSV) {
                    Label("Export CSV", systemImage: "tablecells")
                }
                Button(action: exportJSON) {
                    Label("Export JSON", systemImage: "curlybraces")
                }
                Button(action: exportPDF) {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
                Button(action: copyToClipboard) {
                    Label("Copy List", systemImage: "doc.on.clipboard")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Apps Scanned Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Click \"Scan Apps\" to inventory your installed third-party applications.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan Apps") { scanner.scan() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appTable: some View {
        Table(displayApps, selection: $selectedAppID, sortOrder: sortOrderBinding) {
            TableColumn("Name", value: \.name) { app in
                HStack(spacing: 6) {
                    AppIconView(url: app.path)
                    Text(app.name)
                        .fontWeight(.medium)
                }
            }
            .width(min: 180, ideal: 220)

            TableColumn("Version", value: \.version)
                .width(min: 60, ideal: 80)

            TableColumn("Architecture", value: \.architecture.rawValue) { app in
                HStack(spacing: 4) {
                    Circle()
                        .fill(archColor(app.architecture))
                        .frame(width: 8, height: 8)
                    Text(app.architecture.rawValue)
                        .font(.callout)
                }
            }
            .width(min: 110, ideal: 130)

            TableColumn("Source", value: \.source.rawValue) { app in
                HStack(spacing: 4) {
                    Image(systemName: app.source.systemImage)
                        .foregroundColor(sourceColor(app.source))
                        .font(.callout)
                    Text(app.source.rawValue)
                        .font(.callout)
                }
            }
            .width(min: 130, ideal: 160)

            TableColumn("Signed By", value: \.developer) { app in
                Text(app.developer.isEmpty ? "—" : app.developer)
                    .font(.callout)
                    .foregroundColor(app.developer.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 120, ideal: 170)

            TableColumn("Website", value: \.website) { app in
                if let url = URL(string: app.website), !app.website.isEmpty {
                    Link(destination: url) {
                        Text(displayHost(app.website))
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(app.website)
                } else {
                    Text("—").font(.callout).foregroundColor(.secondary)
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("Bundle ID", value: \.bundleID) { app in
                Text(app.bundleID)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 180, ideal: 240)

            TableColumn("Path", value: \.path.path) { app in
                Text(app.path.path)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 200, ideal: 280)
        }
        .searchable(text: $searchText, prompt: "Search by name or bundle ID")
        .contextMenu(forSelectionType: AppInfo.ID.self) { ids in
            Button("Show in Finder") { showInFinder(ids) }
            Button("Open") { openApps(ids) }
            if appsMatching(ids).contains(where: { !$0.website.isEmpty }) {
                Button("Open Download Website") { openWebsites(ids) }
            }
            Divider()
            Button("Copy Path") { copyPaths(ids) }
            Button("Copy Bundle ID") { copyBundleIDs(ids) }
        } primaryAction: { ids in
            showInFinder(ids)
        }
    }

    /// Strips the scheme and a leading "www." for a compact, readable link label.
    private func displayHost(_ urlString: String) -> String {
        var s = urlString
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
        }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private func openWebsites(_ ids: Set<AppInfo.ID>) {
        for app in appsMatching(ids) where !app.website.isEmpty {
            if let url = URL(string: app.website) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func appsMatching(_ ids: Set<AppInfo.ID>) -> [AppInfo] {
        displayApps.filter { ids.contains($0.id) }
    }

    private func showInFinder(_ ids: Set<AppInfo.ID>) {
        let urls = appsMatching(ids).map(\.path)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func openApps(_ ids: Set<AppInfo.ID>) {
        for app in appsMatching(ids) {
            NSWorkspace.shared.open(app.path)
        }
    }

    private func copyPaths(_ ids: Set<AppInfo.ID>) {
        let text = appsMatching(ids).map { $0.path.path }.joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyBundleIDs(_ ids: Set<AppInfo.ID>) {
        let text = appsMatching(ids).map(\.bundleID).joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var statusBar: some View {
        HStack {
            if scanner.isScanning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
                Text(scanner.scanProgress)
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else if !scanner.apps.isEmpty {
                let total = scanner.apps.count
                let showing = displayApps.count
                Text(showing == total
                     ? "\(total) apps"
                     : "\(showing) of \(total) apps")
                    .font(.callout)
                    .foregroundColor(.secondary)

                if let date = scanner.lastScanDate {
                    Text("• Last scanned \(date.formatted(.relative(presentation: .named)))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                let intelCount = scanner.apps.filter { $0.architecture == .intel }.count
                let siliconCount = scanner.apps.filter { $0.architecture == .appleSilicon }.count
                let universalCount = scanner.apps.filter { $0.architecture == .universal }.count

                HStack(spacing: 16) {
                    statBadge("Apple Silicon", count: siliconCount, color: .green)
                    statBadge("Intel", count: intelCount, color: .orange)
                    statBadge("Universal", count: universalCount, color: .blue)
                }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func statBadge(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    private func archColor(_ arch: AppInfo.Architecture) -> Color {
        switch arch {
        case .appleSilicon: return .green
        case .intel: return .orange
        case .universal: return .blue
        case .unknown: return .gray
        }
    }

    private func sourceColor(_ source: AppInfo.AppSource) -> Color {
        switch source {
        case .appStore: return .blue
        case .developerID: return .green
        case .development: return .orange
        case .unsigned: return .red
        case .unknown: return .gray
        }
    }

    private func exportCSV() {
        let header = AppInfo.csvHeader + "\n"
        let rows = displayApps.map(\.csvRow).joined(separator: "\n")
        let content = header + rows

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "AppInventory.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(displayApps.map(\.exportItem)) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "AppInventory.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func exportPDF() {
        guard let data = PDFExporter.makePDF(apps: displayApps, lastScanDate: scanner.lastScanDate) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "AppInventory.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func copyToClipboard() {
        let lines = displayApps.map { app in
            "\(app.name) \(app.version) — \(app.architecture.rawValue) — \(app.source.rawValue)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines, forType: .string)
    }
}

struct AppIconView: View {
    let url: URL
    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
        }
        .onAppear {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}
