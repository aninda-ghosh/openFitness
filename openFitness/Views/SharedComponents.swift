import SwiftUI

// MARK: - Timeframe Enum
enum Timeframe: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case year = "Y"
    var id: String { self.rawValue }
}

// MARK: - Timeframe Data Struct
struct TimeframeData {
    let points: [Double]
    let labels: [String]
    let average: Double
}

// MARK: - Custom Premium Segmented Picker
struct CustomSegmentedPicker: View {
    @Binding var selection: Timeframe
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases) { tf in
                Text(tf.rawValue)
                    .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                    .foregroundColor(selection == tf ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == tf ? Color.white.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                            selection = tf
                        }
                    }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - ECG Waveform Viewer Sheet
struct ECGDetailSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let waveformPoints: [ECGPoint]
    @State private var scale: CGFloat = 2.0 // Scaling factor for wave height
    @State private var scrollProgress: Double = 0.0
    
    // Grid settings matching standard ECG paper
    private let minorGridSpacing: CGFloat = 10.0 // pixels per minor grid
    private let majorGridSpacing: CGFloat = 50.0 // pixels per major grid
    
    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ECG Waveform")
                            .font(Theme.Typography.metricLabel(size: 24))
                            .foregroundColor(.white)
                        Text("Apple Watch Series 10 • Sinus Rhythm")
                            .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                
                // Live Stats Banner
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AVERAGE HR")
                            .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("72 bpm")
                            .font(Theme.Typography.valueLabel)
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.12)).frame(height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RECORDING LENGTH")
                            .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("30 sec")
                            .font(Theme.Typography.valueLabel)
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.12)).frame(height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAMPLE RATE")
                            .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("250 Hz")
                            .font(Theme.Typography.valueLabel)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.02))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.06)), alignment: .bottom)
                
                // Interactive Scrollable Canvas
                ScrollView(.horizontal, showsIndicators: false) {
                    let totalWidth = max(CGFloat(waveformPoints.count) * 2.5, 800)
                    
                    ZStack {
                        // 1. ECG Pink Graph Grid background
                        ECGBackgroundGrid(minorSpacing: minorGridSpacing, majorSpacing: majorGridSpacing)
                            .frame(width: totalWidth, height: 260)
                        
                        // 2. ECG Voltage Path
                        Canvas { context, size in
                            guard waveformPoints.count > 1 else { return }
                            
                            var path = Path()
                            let centerY = size.height / 2.0
                            
                            let startY = centerY - CGFloat(waveformPoints[0].voltage) * 60.0 * scale
                            path.move(to: CGPoint(x: 0, y: startY))
                            
                            for i in 1..<waveformPoints.count {
                                let x = CGFloat(i) * 2.5
                                let y = centerY - CGFloat(waveformPoints[i].voltage) * 60.0 * scale
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            context.stroke(
                                path,
                                with: .color(.black),
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                            )
                        }
                        .frame(width: totalWidth, height: 260)
                    }
                }
                .frame(height: 260)
                .background(Color(red: 0.98, green: 0.94, blue: 0.94))
                
                // Control Panel
                VStack(spacing: 12) {
                    HStack {
                        Text("Amplitude Gain:")
                            .font(Theme.Typography.roundedFont(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Slider(value: $scale, in: 0.5...4.0)
                            .accentColor(Theme.Colors.recoveryLow)
                        
                        Text(String(format: "%.1x", scale))
                            .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40)
                    }
                    .padding(.horizontal)
                    
                    Text("Swipe horizontally on the grid above to scan through the 30-second heart cycle record. Major squares represent 0.2s; minor squares represent 0.04s.")
                        .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                
                Spacer()
            }
        }
    }
}

// Background grid lines for ECG
struct ECGBackgroundGrid: View {
    let minorSpacing: CGFloat
    let majorSpacing: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let minorColor = Color(red: 0.95, green: 0.85, blue: 0.85)
            let majorColor = Color(red: 0.85, green: 0.65, blue: 0.65)
            
            var minorPath = Path()
            var x: CGFloat = 0
            while x < size.width {
                minorPath.move(to: CGPoint(x: x, y: 0))
                minorPath.addLine(to: CGPoint(x: x, y: size.height))
                x += minorSpacing
            }
            var y: CGFloat = 0
            while y < size.height {
                minorPath.move(to: CGPoint(x: 0, y: y))
                minorPath.addLine(to: CGPoint(x: size.width, y: y))
                y += minorSpacing
            }
            context.stroke(minorPath, with: .color(minorColor), lineWidth: 0.5)
            
            var majorPath = Path()
            x = 0
            while x < size.width {
                majorPath.move(to: CGPoint(x: x, y: 0))
                majorPath.addLine(to: CGPoint(x: x, y: size.height))
                x += majorSpacing
            }
            y = 0
            while y < size.height {
                majorPath.move(to: CGPoint(x: 0, y: y))
                majorPath.addLine(to: CGPoint(x: size.width, y: y))
                y += majorSpacing
            }
            context.stroke(majorPath, with: .color(majorColor), lineWidth: 1.2)
        }
    }
}

// MARK: - Reusable Custom Line Graph View with X-Axis labels
struct CustomLineGraph: View {
    let points: [Double]
    let labels: [String]
    let lineColor: Color
    let gradientColors: [Color]?
    
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                let rawMin = points.min() ?? 0.0
                let rawMax = points.max() ?? 10.0
                // Fix scaling for flat lines (e.g. all 0.0 strain) by forcing a standard scale range
                let minVal = rawMin == rawMax ? (rawMin > 0 ? rawMin * 0.8 : 0.0) : rawMin
                let maxVal = rawMin == rawMax ? (rawMin > 0 ? rawMin * 1.2 : 10.0) : rawMax
                let range = maxVal - minVal > 0 ? maxVal - minVal : 1.0
                
                // Helper to map a data point to y-coordinate with 15% padding top and bottom
                let yForVal: (Double) -> CGFloat = { val in
                    let pct = CGFloat((val - minVal) / range)
                    return height * 0.15 + (height * 0.7) * (1.0 - pct)
                }
                
                let xForIdx: (Int) -> CGFloat = { idx in
                    guard points.count > 1 else { return 0.0 }
                    return CGFloat(idx) / CGFloat(points.count - 1) * width
                }
                
                // Calculate rolling variance baseline boundaries (typical range envelope)
                let movingBounds: (upper: [Double], lower: [Double]) = {
                    guard !points.isEmpty else { return ([], []) }
                    var upper: [Double] = []
                    var lower: [Double] = []
                    let windowSize = 5
                    
                    for i in 0..<points.count {
                        let startIdx = max(0, i - windowSize + 1)
                        let subPoints = Array(points[startIdx...i])
                        let subAvg = subPoints.reduce(0, +) / Double(subPoints.count)
                        let subVar = subPoints.map { pow($0 - subAvg, 2) }.reduce(0, +) / Double(subPoints.count)
                        let subStd = sqrt(subVar)
                        
                        let dev = max(subStd * 0.8, subAvg * 0.1)
                        upper.append(subAvg + dev)
                        lower.append(subAvg - dev)
                    }
                    return (upper, lower)
                }()
                
                // 1. Smooth Path of the baseline variance envelope
                let envelopePath = Path { path in
                    guard points.count > 1, movingBounds.upper.count == points.count else { return }
                    
                    let yForUpper: (Int) -> CGFloat = { idx in
                        let val = max(minVal, min(maxVal, movingBounds.upper[idx]))
                        return yForVal(val)
                    }
                    
                    let yForLower: (Int) -> CGFloat = { idx in
                        let val = max(minVal, min(maxVal, movingBounds.lower[idx]))
                        return yForVal(val)
                    }
                    
                    path.move(to: CGPoint(x: xForIdx(0), y: yForUpper(0)))
                    for i in 0..<points.count - 1 {
                        let p0 = CGPoint(x: xForIdx(i), y: yForUpper(i))
                        let p1 = CGPoint(x: xForIdx(i+1), y: yForUpper(i+1))
                        let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x + 2.0 * (p1.x - p0.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: yForLower(points.count - 1)))
                    for i in (0..<points.count - 1).reversed() {
                        let p0 = CGPoint(x: xForIdx(i+1), y: yForLower(i+1))
                        let p1 = CGPoint(x: xForIdx(i), y: yForLower(i))
                        let cp1 = CGPoint(x: p0.x - (p0.x - p1.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x - 2.0 * (p0.x - p1.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                    path.closeSubpath()
                }
                
                // 2. Smooth Line Path
                let linePath = Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: xForIdx(0), y: yForVal(points[0])))
                    
                    for i in 0..<points.count - 1 {
                        let p0 = CGPoint(x: xForIdx(i), y: yForVal(points[i]))
                        let p1 = CGPoint(x: xForIdx(i+1), y: yForVal(points[i+1]))
                        let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x + 2.0 * (p1.x - p0.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                }
                
                // 3. Smooth Area Fill Path
                let fillPath = Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: xForIdx(0), y: height))
                    path.addLine(to: CGPoint(x: xForIdx(0), y: yForVal(points[0])))
                    
                    for i in 0..<points.count - 1 {
                        let p0 = CGPoint(x: xForIdx(i), y: yForVal(points[i]))
                        let p1 = CGPoint(x: xForIdx(i+1), y: yForVal(points[i+1]))
                        let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x + 2.0 * (p1.x - p0.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                
                ZStack(alignment: .topLeading) {
                    // 1. Ultra-thin clean solid gridlines
                    Path { p in
                        let divisions = 3
                        for i in 0...divisions {
                            let y = CGFloat(i) / CGFloat(divisions) * height
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    
                    // 2. Variance Envelope
                    if points.count > 1 {
                        envelopePath
                            .fill(lineColor.opacity(0.08))
                    }
                    
                    // 3. Area Gradient Fill
                    if let gradColors = gradientColors {
                        fillPath
                            .fill(LinearGradient(colors: gradColors, startPoint: .top, endPoint: .bottom))
                    }
                    
                    // 4. Line stroke
                    linePath
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                    
                    // 5. Stylized vertex nodes
                    if points.count <= 31 && points.count > 1 {
                        ForEach(0..<points.count, id: \.self) { i in
                            let x = xForIdx(i)
                            let y = yForVal(points[i])
                            
                            let pt = points[i]
                            let upper = movingBounds.upper.isEmpty ? 0.0 : movingBounds.upper[i]
                            let lower = movingBounds.lower.isEmpty ? 0.0 : movingBounds.lower[i]
                            
                            let dotColor: Color = {
                                guard !movingBounds.upper.isEmpty else { return lineColor }
                                if pt > upper { return Color.orange }
                                if pt < lower { return Color.red }
                                return lineColor
                            }()
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .overlay(Circle().stroke(dotColor, lineWidth: 2))
                                .shadow(color: dotColor.opacity(0.6), radius: 3)
                                .position(x: x, y: y)
                        }
                    }
                    
                    // 6. Max & Min value indicators
                    if points.count > 1 {
                        let maxVal_pt = points.max() ?? 0.0
                        let minVal_pt = points.min() ?? 0.0
                        
                        if let maxIdx = points.firstIndex(of: maxVal_pt) {
                            let x = xForIdx(maxIdx)
                            let y = yForVal(maxVal_pt)
                            
                            // Max dot (larger, highlighted)
                            Circle()
                                .fill(lineColor)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .shadow(color: lineColor.opacity(0.5), radius: 4)
                                .position(x: x, y: y)
                            
                            // Max value label
                            Text(maxVal_pt >= 10 ? String(format: "%.0f", maxVal_pt) : String(format: "%.1f", maxVal_pt))
                                .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(lineColor.opacity(0.85))
                                .cornerRadius(4)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .position(x: min(width - 18, max(18, x)), y: max(14, y - 14))
                        }
                        
                        if let minIdx = points.lastIndex(of: minVal_pt), maxVal_pt != minVal_pt {
                            let x = xForIdx(minIdx)
                            let y = yForVal(minVal_pt)
                            
                            // Min dot (larger, highlighted)
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(lineColor.opacity(0.6), lineWidth: 1.5))
                                .shadow(color: lineColor.opacity(0.3), radius: 4)
                                .position(x: x, y: y)
                            
                            // Min value label
                            Text(minVal_pt >= 10 ? String(format: "%.0f", minVal_pt) : String(format: "%.1f", minVal_pt))
                                .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(lineColor.opacity(0.3), lineWidth: 0.5))
                                .position(x: min(width - 18, max(18, x)), y: min(height - 14, y + 14))
                        }
                    }
                }
            }
            
            // X-Axis
            HStack(spacing: 0) {
                ForEach(0..<labels.count, id: \.self) { index in
                    Text(labels[index])
                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct HRZoneRowView: View {
    let zone: Int
    let range: String
    let duration: String
    let weight: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Z\(zone)")
                .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 20)
                .background(color.opacity(0.3))
                .cornerRadius(4)
            
            Text(range)
                .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(weight) / 5.0)
                }
            }
            .frame(width: 80, height: 6)
            .padding(.trailing, 4)
            
            Text(duration)
                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct SleepStageLegendRow: View {
    let color: Color
    let stage: String
    let duration: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stage)
                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text(duration)
                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(minWidth: 140, alignment: .leading)
    }
}

struct CardioBreakdownRow: View {
    let status: String
    let days: Int
    let percentage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text(status)
                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 90, alignment: .leading)
            
            Text("\(days)d")
                .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(percentage)%")
                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
}

struct SleepStageCard: View {
    let stageName: String
    let minutes: Double
    let percentage: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                    
                    Text(stageName)
                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Text("\(percentage)%")
                    .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            
            HStack(alignment: .bottom) {
                Text(formatMinutes(minutes))
                    .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 4)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(percentage) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func formatMinutes(_ mins: Double) -> String {
        let h = Int(mins) / 60
        let m = Int(mins) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}

struct SleepHypnogramChart: View {
    let samples: [SleepStageSample]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tonight's Sleep Cycles")
                    .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Hypnogram")
                    .font(Theme.Typography.roundedFont(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            if samples.isEmpty {
                Text("No sleep stage sequence available for today")
                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(height: 100)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let leftPadding: CGFloat = 45.0
                    let chartWidth = width - leftPadding
                    
                    let minTime = samples.map { $0.startDate.timeIntervalSince1970 }.min() ?? 0.0
                    let maxTime = samples.map { $0.endDate.timeIntervalSince1970 }.max() ?? 1.0
                    let timeRange = maxTime - minTime > 0 ? maxTime - minTime : 1.0
                    
                    let yForStage: (Int) -> CGFloat = { stage in
                        switch stage {
                        case 0: return height * 0.15
                        case 2: return height * 0.42
                        case 1: return height * 0.68
                        case 3: return height * 0.90
                        default: return height * 0.68
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        Path { p in
                            for yRatio in [0.15, 0.42, 0.68, 0.90] {
                                let y = height * CGFloat(yRatio)
                                p.move(to: CGPoint(x: leftPadding, y: y))
                                p.addLine(to: CGPoint(x: width, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [2]))
                        
                        Text("Awake")
                            .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                            .foregroundColor(Theme.Colors.sleepAwake)
                            .offset(x: 4, y: yForStage(0) - 6)
                        
                        Text("REM")
                            .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                            .foregroundColor(Theme.Colors.sleepREM)
                            .offset(x: 4, y: yForStage(2) - 6)
                        
                        Text("Light")
                            .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                            .foregroundColor(Theme.Colors.sleepLight)
                            .offset(x: 4, y: yForStage(1) - 6)
                        
                        Text("Deep")
                            .font(Theme.Typography.roundedFont(size: 8, weight: .bold))
                            .foregroundColor(Theme.Colors.sleepDeep)
                            .offset(x: 4, y: yForStage(3) - 6)
                        
                        Path { path in
                            guard samples.count > 0 else { return }
                            
                            let startX = leftPadding + CGFloat((samples[0].startDate.timeIntervalSince1970 - minTime) / timeRange) * chartWidth
                            let startY = yForStage(samples[0].stage)
                            path.move(to: CGPoint(x: startX, y: startY))
                            
                            for i in 0..<samples.count {
                                let x1 = leftPadding + CGFloat((samples[i].startDate.timeIntervalSince1970 - minTime) / timeRange) * chartWidth
                                let x2 = leftPadding + CGFloat((samples[i].endDate.timeIntervalSince1970 - minTime) / timeRange) * chartWidth
                                let y = yForStage(samples[i].stage)
                                
                                path.addLine(to: CGPoint(x: x1, y: y))
                                path.addLine(to: CGPoint(x: x2, y: y))
                                
                                if i < samples.count - 1 {
                                    let nextY = yForStage(samples[i+1].stage)
                                    path.addLine(to: CGPoint(x: x2, y: nextY))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(colors: [Theme.Colors.sleepLight, Theme.Colors.sleepREM, Theme.Colors.sleepDeep], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .frame(height: 120)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
