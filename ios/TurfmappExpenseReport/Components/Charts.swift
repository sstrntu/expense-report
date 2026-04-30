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
    struct Bar: Hashable { let label: String; let value: Double }
    let bars: [Bar]
    var color: Color = Tokens.slate500
    var height: CGFloat = 110

    var body: some View {
        let maxV = bars.map(\.value).max() ?? 1
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(bars, id: \.self) { b in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(4, CGFloat(b.value / maxV) * (height - 18)))
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
