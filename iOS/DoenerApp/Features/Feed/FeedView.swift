import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ContentUnavailableView(
                    "Noch keine Aktivität",
                    systemImage: "person.2",
                    description: Text("Füge Freunde hinzu, um ihre Döner-Abenteuer hier zu sehen.")
                )
            }
            .navigationTitle("Feed")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}

#Preview {
    FeedView()
}
