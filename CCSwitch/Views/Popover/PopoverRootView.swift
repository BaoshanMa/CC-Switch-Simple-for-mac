import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigationPath = NavigationPath()
    // profileId 参数：nil 表示打开通用设置，non-nil 表示定位到指定 Profile
    let onOpenSettings: ((UUID?) -> Void)?

    init(onOpenSettings: ((UUID?) -> Void)? = nil) {
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProfileListView(onOpenSettings: { onOpenSettings?(nil) })
                .navigationDestination(for: Profile.self) { profile in
                    ProviderListView(profile: profile, onOpenSettings: { profileId in
                        onOpenSettings?(profileId)
                    })
                }
        }
        .frame(width: 300)
    }
}
