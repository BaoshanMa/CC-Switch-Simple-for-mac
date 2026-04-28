import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProfileId: UUID?
    var initialProfileId: UUID?

    var selectedProfile: Profile? {
        appState.profiles.first { $0.id == selectedProfileId }
    }

    var body: some View {
        HSplitView {
            ProfileSidebarView(selectedProfileId: $selectedProfileId)
                .frame(minWidth: 200, maxWidth: 220)
            if let profile = selectedProfile {
                ProviderListPanelView(profile: profile)
            } else {
                Text("请选择一个配置目录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if let id = initialProfileId {
                selectedProfileId = id
            } else if selectedProfileId == nil {
                selectedProfileId = appState.profiles.first?.id
            }
        }
    }
}
