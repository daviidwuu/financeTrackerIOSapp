import SwiftUI

struct TrendGraph: View {
    var points: [Double]
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard points.count > 1 else { return }
                
                let minPoint = points.min() ?? 0
                let maxPoint = points.max() ?? 1
                let range = maxPoint - minPoint == 0 ? 1 : maxPoint - minPoint
                
                let stepX = geometry.size.width / CGFloat(points.count - 1)
                
                for i in 0..<points.count {
                    let normalizedY = 1 - CGFloat((points[i] - minPoint) / range)
                    let x = CGFloat(i) * stepX
                    let y = normalizedY * geometry.size.height
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}
