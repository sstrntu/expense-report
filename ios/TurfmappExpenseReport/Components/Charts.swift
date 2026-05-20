import SwiftUI

struct Sparkline: View {
    let data: [Double]
    var color: Color = Tokens.slate500

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxV = (data.max() ?? 1)
            let minV = (data.min() ?? 0)
            let range = max(maxV - minV, 1)
            let points: [CGPoint] = data.enumerated().map { i, v in
                let x = CGFloat(i) / CGFloat(max(data.count - 1, 1)) * w
                let y = h - CGFloat((v - minV) / range) * (h - 8) - 4
                return CGPoint(x: x, y: y)
            }

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in
                    p.move(to: points.first ?? .zero)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct DonutChart: View {
    struct Segment: Hashable { let value: Double; let color: Color; let label: String }
    let segments: [Segment]
    var thickness: CGFloat = 18

    var body: some View {
        let total = segments.reduce(0) { $0 + $1.value }
        ZStack {
            let layout = segments.reduce(into: [(Segment, Double, Double)]()) { acc, s in
                let start = acc.last.map { $0.1 + $0.2 } ?? 0
                acc.append((s, start, s.value / total))
            }
            ForEach(Array(layout.enumerated()), id: \.offset) { _, item in
                let (seg, start, frac) = item
                Circle()
                    .trim(from: start, to: start + frac)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct BarsChart: View {
    struct Segment: Hashable {
        let value: Double
        let color: Color
    }
    struct Bar: Hashable {
        let label: String
        let segments: [Segment]

        /// Legacy single-segment + projected initializer kept so existing
        /// call sites don't have to change. Treats `value` as one segment
        /// and `projected` as a second stacked segment above it.
        init(label: String, value: Double, projected: Double = 0,
             color: Color = Tokens.slate500, projectedColor: Color = Tokens.purchased) {
            self.label = label
            var segs: [Segment] = []
            if value > 0 { segs.append(Segment(value: value, color: color)) }
            if projected > 0 { segs.append(Segment(value: projected, color: projectedColor)) }
            self.segments = segs
        }

        /// Multi-segment initializer. Segments stack bottom-to-top in the
        /// order given.
        init(label: String, segments: [Segment]) {
            self.label = label
            self.segments = segments
        }

        var value: Double { segments.reduce(0) { $0 + $1.value } }
    }
    let bars: [Bar]
    var height: CGFloat = 110

    var body: some View {
        let maxV = bars.map(\.value).max() ?? 1
        let chartH = height - 18
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(bars, id: \.self) { b in
                let totalH = max(0, CGFloat(b.value / maxV) * chartH)
                VStack(spacing: 6) {
                    if b.segments.isEmpty {
                        // Empty placeholder so bars without data still take their column.
                        Color.clear.frame(height: 4)
                    } else {
                        VStack(spacing: 0) {
                            // Segments stack top-to-bottom visually, so reverse to
                            // render the first-added segment on the bottom.
                            ForEach(Array(b.segments.reversed().enumerated()), id: \.offset) { _, seg in
                                Rectangle()
                                    .fill(LinearGradient(colors: [seg.color, seg.color.opacity(0.65)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .frame(height: max(0, CGFloat(seg.value / maxV) * chartH))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(height: max(4, totalH))
                    }
                    Text(b.label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}
