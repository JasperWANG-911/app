import SwiftUI
import CoreLocation

struct Post: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D // 经纬度
    let caption: String    // 文字内容
    let color: Color       // 气泡颜色
    let icon: String       // 图标名 (SF Symbol)
}
