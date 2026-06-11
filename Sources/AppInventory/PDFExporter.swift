import AppKit

/// Renders an app inventory into a paginated, landscape US-Letter PDF using
/// Core Graphics — a title block, repeating column headers, and page numbers.
enum PDFExporter {
    private static let pageSize = CGSize(width: 792, height: 612) // Letter, landscape
    private static let margin: CGFloat = 36
    private static let rowH: CGFloat = 16
    private static let headerRowH: CGFloat = 20
    private static let footerH: CGFloat = 24
    private static let titleBlockH: CGFloat = 48

    // Fixed print colors. Semantic colors like .labelColor resolve against the
    // current appearance (white in Dark Mode) and don't render in a bare PDF
    // context, so a printable document must use explicit ink colors.
    private static let inkPrimary = NSColor(white: 0.10, alpha: 1)
    private static let inkSecondary = NSColor(white: 0.35, alpha: 1)
    private static let inkMuted = NSColor(white: 0.60, alpha: 1)

    private struct Column {
        let title: String
        let width: CGFloat
        let value: (AppInfo) -> String
    }

    private static let columns: [Column] = [
        Column(title: "Name", width: 150) { $0.name },
        Column(title: "Version", width: 60) { $0.version },
        Column(title: "Architecture", width: 95) { $0.architecture.rawValue },
        Column(title: "Source", width: 110) { $0.source.rawValue },
        Column(title: "Signed By", width: 145) { $0.developer },
        Column(title: "Website", width: 160) { stripScheme($0.website) },
    ]

    static func makePDF(apps: [AppInfo], lastScanDate: Date?) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let pages = paginate(apps)
        let generated = Date().formatted(date: .abbreviated, time: .shortened)

        for (pageIndex, slice) in pages.enumerated() {
            ctx.beginPDFPage(nil)
            ctx.saveGState()
            // Flip to a top-left origin so AppKit text draws upright.
            ctx.translateBy(x: 0, y: pageSize.height)
            ctx.scaleBy(x: 1, y: -1)
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx

            var y = margin
            if pageIndex == 0 {
                y = drawTitleBlock(appCount: apps.count, lastScanDate: lastScanDate)
            }
            y = drawHeaderRow(at: y)
            for app in slice {
                drawDataRow(app, at: y)
                y += rowH
            }
            drawFooter(page: pageIndex + 1, of: pages.count, generated: generated)

            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return data as Data
    }

    // MARK: - Pagination

    private static func paginate(_ apps: [AppInfo]) -> [ArraySlice<AppInfo>] {
        guard !apps.isEmpty else { return [apps[0..<0]] }
        let bottomLimit = pageSize.height - footerH
        let firstCap = max(1, Int((bottomLimit - (margin + titleBlockH + headerRowH)) / rowH))
        let otherCap = max(1, Int((bottomLimit - (margin + headerRowH)) / rowH))

        var pages: [ArraySlice<AppInfo>] = []
        var i = 0
        while i < apps.count {
            let cap = pages.isEmpty ? firstCap : otherCap
            let end = min(i + cap, apps.count)
            pages.append(apps[i..<end])
            i = end
        }
        return pages
    }

    // MARK: - Drawing

    private static func drawTitleBlock(appCount: Int, lastScanDate: Date?) -> CGFloat {
        draw("App Inventory",
             in: CGRect(x: margin, y: margin, width: pageSize.width - 2 * margin, height: 24),
             font: .boldSystemFont(ofSize: 18), color: inkPrimary)

        var subtitle = "\(appCount) applications"
        if let date = lastScanDate {
            subtitle += " • Last scanned \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        draw(subtitle,
             in: CGRect(x: margin, y: margin + 26, width: pageSize.width - 2 * margin, height: 14),
             font: .systemFont(ofSize: 10), color: inkSecondary)

        return margin + titleBlockH
    }

    private static func drawHeaderRow(at y: CGFloat) -> CGFloat {
        // Light background band behind the header.
        NSColor(white: 0.93, alpha: 1).setFill()
        CGRect(x: margin, y: y, width: contentWidth, height: headerRowH).fill()

        var x = margin
        for col in columns {
            draw(col.title,
                 in: CGRect(x: x + 3, y: y + 4, width: col.width - 6, height: headerRowH - 6),
                 font: .boldSystemFont(ofSize: 9.5), color: inkPrimary)
            x += col.width
        }
        strokeHairline(y: y + headerRowH)
        return y + headerRowH
    }

    private static func drawDataRow(_ app: AppInfo, at y: CGFloat) {
        var x = margin
        for col in columns {
            let text = col.value(app)
            draw(text.isEmpty ? "—" : text,
                 in: CGRect(x: x + 3, y: y + 3, width: col.width - 6, height: rowH - 3),
                 font: .systemFont(ofSize: 9),
                 color: text.isEmpty ? inkMuted : inkPrimary)

            // Make the Website cell a clickable link to the full URL.
            if col.title == "Website", !app.website.isEmpty,
               let url = URL(string: app.website) {
                addLink(url, cellX: x, cellTopY: y, width: col.width)
            }
            x += col.width
        }
        strokeHairline(y: y + rowH, color: NSColor(white: 0.9, alpha: 1))
    }

    /// Registers a PDF link annotation over a cell. `cellTopY` is in our flipped
    /// (top-left) drawing space; link rects must be in the page's default
    /// (bottom-left origin) space, so the y is converted here.
    private static func addLink(_ url: URL, cellX: CGFloat, cellTopY: CGFloat, width: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = CGRect(x: cellX, y: pageSize.height - (cellTopY + rowH),
                          width: width, height: rowH)
        ctx.setURL(url as CFURL, for: rect)
    }

    private static func drawFooter(page: Int, of total: Int, generated: String) {
        let text = "App Inventory  •  Page \(page) of \(total)  •  Generated \(generated)"
        draw(text,
             in: CGRect(x: margin, y: pageSize.height - footerH + 6,
                        width: contentWidth, height: 14),
             font: .systemFont(ofSize: 8), color: inkMuted, alignment: .center)
    }

    // MARK: - Helpers

    private static var contentWidth: CGFloat { columns.reduce(0) { $0 + $1.width } }

    private static func draw(_ string: String, in rect: CGRect, font: NSFont,
                             color: NSColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        (string as NSString).draw(in: rect, withAttributes: attrs)
    }

    private static func strokeHairline(y: CGFloat, color: NSColor = NSColor(white: 0.8, alpha: 1)) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.line(to: CGPoint(x: margin + contentWidth, y: y))
        path.lineWidth = 0.5
        color.setStroke()
        path.stroke()
    }

    private static func stripScheme(_ url: String) -> String {
        var s = url
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
