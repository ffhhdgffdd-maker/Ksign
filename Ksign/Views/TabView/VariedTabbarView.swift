import SwiftUI

struct VariedTabbarView: View {
    @AppStorage("Feather.userInterfaceStyle") private var style = 2
    var body: some View {
        TabbarView()
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(style == 0 ? nil : (style == 1 ? .light : .dark))
    }
}
