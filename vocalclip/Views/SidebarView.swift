import SwiftUI
import SwiftData

struct SidebarView: View {
    var onClose: () -> Void
    var onSelectHistory: (ReadingHistory) -> Void

    @State private var route: Route = .menu

    enum Route: Hashable {
        case menu
        case history
        case settings
        case userInfo
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.6)
                content
            }
        }
    }

    private var header: some View {
        HStack {
            if route != .menu {
                Button {
                    route = .menu
                } label: {
                    Label("返回", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(height: 48)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .menu: menuList
        case .history:
            HistoryListView(onSelect: onSelectHistory)
        case .settings:
            SettingsView()
        case .userInfo:
            UserInfoView()
        }
    }

    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarItem(icon: "person.crop.circle", title: "用户信息") { route = .userInfo }
            sidebarItem(icon: "clock.arrow.circlepath", title: "历史记录") { route = .history }
            sidebarItem(icon: "gearshape", title: "设置") { route = .settings }
            Spacer()
            Text("VocalClip · v1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)
        }
    }

    private func sidebarItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                Text(title)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
