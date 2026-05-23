import UIKit
import PDFKit

/// Builds a bank-statement-style PDF for a filtered set of expenses.
///
/// Layout:
///   Page 1+ — header, period summary, totals, then a paginated line-item
///             table (date · merchant · project · category · status · amount).
///   Page N+ — receipts appendix: one expense per page, with a header line
///             ("#3 · 1/7 · Hotel · $312") and the receipt image fitted to
///             the printable area. Expenses without receipts are skipped from
///             the appendix entirely (their row in the table stays).
///
/// US Letter, 36pt margins. Built with `UIGraphicsPDFRenderer` so the output
/// is real vector PDF, not a flattened bitmap — selectable text in the
/// statement portion, image-quality receipts in the appendix.
struct ReportPDFRenderer {
    struct Row {
        let expense: DomainExpense
        let projectName: String
        let categoryName: String
        let receiptImage: UIImage?
    }

    struct Context {
        let workspaceName: String
        let aggregationCurrency: String
        let dateRange: ClosedRange<Date>?
        let rows: [Row]
        let totalInAggregationCurrency: Double
    }

    // US Letter @ 72dpi
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let margin: CGFloat = 36

    static func render(_ context: Context) -> Data {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { ctx in
            var cursor = drawHeader(context: context, in: bounds, ctx: ctx)
            cursor = drawTotals(context: context, startY: cursor, in: bounds, ctx: ctx)
            cursor = drawTable(context: context, startY: cursor, in: bounds, ctx: ctx)
            drawReceiptsAppendix(context: context, in: bounds, ctx: ctx)
        }
    }

    // MARK: – Page 1 header

    private static func drawHeader(context: Context, in bounds: CGRect, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        let title = NSLocalizedString("reports.pdf.statement_title", comment: "")
        title.draw(at: CGPoint(x: margin, y: margin), withAttributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.label
        ])

        let workspace = context.workspaceName
        workspace.draw(at: CGPoint(x: margin, y: margin + 30), withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ])

        let periodText: String
        if let range = context.dateRange {
            let df = DateFormatter()
            df.dateStyle = .medium
            periodText = String(format: NSLocalizedString("reports.pdf.period", comment: ""),
                                df.string(from: range.lowerBound),
                                df.string(from: range.upperBound))
        } else {
            periodText = "All time"
        }
        periodText.draw(at: CGPoint(x: margin, y: margin + 50), withAttributes: [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ])

        let genDF = DateFormatter()
        genDF.dateStyle = .medium
        genDF.timeStyle = .short
        let generated = String(format: NSLocalizedString("reports.pdf.generated", comment: ""), genDF.string(from: Date()))
        let genSize = (generated as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        generated.draw(at: CGPoint(x: bounds.width - margin - genSize.width, y: margin + 4), withAttributes: [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel
        ])

        return margin + 80
    }

    private static func drawTotals(context: Context, startY: CGFloat, in bounds: CGRect, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        // Four-column metric strip: Expenses · Total · Reimbursed · Pending.
        // Reimbursed = rows in .reimbursed state. Pending = anything still moving
        // through the workflow (submitted through ready-for-reimbursement). Rejected,
        // cancelled, archived, and drafts are excluded from the pending bucket so
        // the two sub-totals add up to "total amount in flight" cleanly.
        let pendingStatuses: Set<ExpenseWorkflowStatus> = [
            .submitted, .pendingManagerApproval, .approved, .purchaseConfirmed,
            .pendingFinanceReview, .readyForReimbursement
        ]
        let reimbursed = context.rows.filter { $0.expense.status == .reimbursed }
        let pending = context.rows.filter { pendingStatuses.contains($0.expense.status) }
        let reimbursedTotal = reimbursed.reduce(0) { $0 + $1.expense.amount.decimalValue }
        let pendingTotal = pending.reduce(0) { $0 + $1.expense.amount.decimalValue }

        let metrics: [(label: String, value: String)] = [
            ("EXPENSES", "\(context.rows.count)"),
            ("TOTAL", formatCurrency(context.totalInAggregationCurrency, code: context.aggregationCurrency)),
            ("REIMBURSED", "\(reimbursed.count) · " + formatCurrency(reimbursedTotal, code: context.aggregationCurrency)),
            ("PENDING", "\(pending.count) · " + formatCurrency(pendingTotal, code: context.aggregationCurrency))
        ]

        let stripHeight: CGFloat = 44
        let columnWidth = (bounds.width - 2 * margin) / CGFloat(metrics.count)

        // Faint background tint behind the strip — gives it the bank-statement feel.
        let stripRect = CGRect(x: margin, y: startY, width: bounds.width - 2 * margin, height: stripHeight)
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: stripRect, cornerRadius: 6).fill()

        for (index, metric) in metrics.enumerated() {
            let x = margin + CGFloat(index) * columnWidth
            metric.label.draw(at: CGPoint(x: x + 10, y: startY + 6), withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: UIColor.tertiaryLabel,
                .kern: 0.6
            ])
            metric.value.draw(at: CGPoint(x: x + 10, y: startY + 20), withAttributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.label
            ])
            // Thin vertical separator between columns (skip after the last one).
            if index < metrics.count - 1 {
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: x + columnWidth, y: startY + 8))
                sep.addLine(to: CGPoint(x: x + columnWidth, y: startY + stripHeight - 8))
                UIColor.separator.setStroke()
                sep.lineWidth = 0.5
                sep.stroke()
            }
        }
        return startY + stripHeight + 16
    }

    // MARK: – Table (page 1..N)

    /// Column widths sum to (pageWidth − 2 * margin) = 540pt at Letter.
    /// Date: 60, Merchant: 130, Project: 100, Category: 90, Status: 80, Amount: 80 → 540.
    private static let columnWidths: [CGFloat] = [60, 130, 100, 90, 80, 80]

    private static func drawTable(context: Context, startY: CGFloat, in bounds: CGRect, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        let headers = [
            NSLocalizedString("reports.pdf.col_date", comment: ""),
            NSLocalizedString("reports.pdf.col_merchant", comment: ""),
            NSLocalizedString("reports.pdf.col_project", comment: ""),
            NSLocalizedString("reports.pdf.col_category", comment: ""),
            NSLocalizedString("reports.pdf.col_status", comment: ""),
            NSLocalizedString("reports.pdf.col_amount", comment: "")
        ]

        var y = startY
        let rowHeight: CGFloat = 22
        let bottomMargin: CGFloat = margin + 24

        drawTableHeader(headers: headers, y: y, in: bounds)
        y += rowHeight

        let df = DateFormatter()
        df.dateFormat = "MMM d"

        for row in context.rows {
            if y + rowHeight > bounds.height - bottomMargin {
                ctx.beginPage()
                y = margin
                drawTableHeader(headers: headers, y: y, in: bounds)
                y += rowHeight
            }

            let exp = row.expense
            let date = exp.purchaseDate ?? exp.submittedAt ?? exp.createdAt
            let amount = formatCurrency(exp.amount.decimalValue, code: exp.amount.currency)
            let cells = [
                df.string(from: date),
                truncate(exp.merchant, max: 22),
                truncate(row.projectName, max: 16),
                truncate(row.categoryName, max: 14),
                statusShortLabel(exp.status),
                amount
            ]
            drawTableRow(cells: cells, y: y, in: bounds)
            y += rowHeight
        }

        return y
    }

    private static func drawTableHeader(headers: [String], y: CGFloat, in bounds: CGRect) {
        var x = margin
        for (i, header) in headers.enumerated() {
            let isAmount = (i == headers.count - 1)
            let width = columnWidths[i]
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = isAmount ? .right : .left
            var headerAttrs = attrs
            headerAttrs[.paragraphStyle] = paragraph
            (header.uppercased() as NSString).draw(
                in: CGRect(x: x, y: y, width: width, height: 16),
                withAttributes: headerAttrs
            )
            x += width
        }
        // Header underline
        let underline = UIBezierPath()
        underline.move(to: CGPoint(x: margin, y: y + 17))
        underline.addLine(to: CGPoint(x: bounds.width - margin, y: y + 17))
        UIColor.separator.setStroke()
        underline.lineWidth = 0.5
        underline.stroke()
    }

    private static func drawTableRow(cells: [String], y: CGFloat, in bounds: CGRect) {
        var x = margin
        for (i, cell) in cells.enumerated() {
            let isAmount = (i == cells.count - 1)
            let width = columnWidths[i]
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = isAmount ? .right : .left
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: isAmount ? .semibold : .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
            (cell as NSString).draw(
                in: CGRect(x: x, y: y, width: width, height: 18),
                withAttributes: attrs
            )
            x += width
        }
    }

    // MARK: – Receipts appendix

    private static func drawReceiptsAppendix(context: Context, in bounds: CGRect, ctx: UIGraphicsPDFRendererContext) {
        let rowsWithReceipts = context.rows.enumerated().filter { $0.element.receiptImage != nil }
        guard !rowsWithReceipts.isEmpty else { return }

        // Each receipt gets its own clean page. We don't draw a separate
        // "Receipts" intro page — the first-page table already establishes
        // what the rest of the document contains, and an extra header just
        // ended up overlapping with the first receipt's heading.
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"

        for (index, row) in rowsWithReceipts {
            ctx.beginPage()

            let exp = row.expense
            let date = exp.purchaseDate ?? exp.submittedAt ?? exp.createdAt
            let amount = formatCurrency(exp.amount.decimalValue, code: exp.amount.currency)
            let heading = "[\(index + 1)] \(df.string(from: date)) · \(exp.merchant) · \(amount)"
            heading.draw(at: CGPoint(x: margin, y: margin), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.label
            ])

            let metaParts = [row.projectName, row.categoryName, exp.businessPurpose]
                .filter { !$0.isEmpty }
            let meta = metaParts.joined(separator: " · ")
            meta.draw(at: CGPoint(x: margin, y: margin + 22), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ])

            if let image = row.receiptImage {
                let imageTopY = margin + 50
                let availableRect = CGRect(
                    x: margin,
                    y: imageTopY,
                    width: bounds.width - 2 * margin,
                    height: bounds.height - imageTopY - margin
                )
                let fitted = aspectFit(imageSize: image.size, into: availableRect)
                image.draw(in: fitted)
            }
        }
    }

    // MARK: – Helpers

    private static func aspectFit(imageSize: CGSize, into rect: CGRect) -> CGRect {
        guard imageSize.width > 0 && imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.minY  // top-aligned looks cleaner than centered for portrait receipts
        )
        return CGRect(origin: origin, size: size)
    }

    private static func truncate(_ s: String, max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }

    private static func formatCurrency(_ value: Double, code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
    }

    private static func statusShortLabel(_ status: ExpenseWorkflowStatus) -> String {
        switch status {
        case .draft:                  return "Draft"
        case .submitted:              return "Submitted"
        case .scanProcessing:         return "Scanning"
        case .scanFailed:             return "Scan failed"
        case .pendingManagerApproval: return "Mgr review"
        case .approved:               return "Approved"
        case .purchaseConfirmed:      return "Purchased"
        case .pendingFinanceReview:   return "Fin review"
        case .readyForReimbursement:  return "Ready"
        case .reimbursed:             return "Reimbursed"
        case .rejected:               return "Rejected"
        case .cancelled:              return "Cancelled"
        case .archived:               return "Archived"
        }
    }
}
