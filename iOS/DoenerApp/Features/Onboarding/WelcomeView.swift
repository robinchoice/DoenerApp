import SwiftUI
import CoreLocation

struct WelcomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var locationManager = LocationManager()

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            WelcomePage {
                withAnimation { currentPage = 1 }
            }
            .tag(0)

            // Page 2: Location
            LocationPage(locationManager: locationManager) {
                withAnimation { currentPage = 2 }
            }
            .tag(1)

            // Page 3: Features
            FeaturesPage {
                withAnimation { currentPage = 3 }
            }
            .tag(2)

            // Page 4: Sign in
            SignInView {
                hasCompletedOnboarding = true
            }
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background {
            LinearGradient(
                colors: [.orange.opacity(0.12), .clear, .orange.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(.orange.opacity(0.08))
                    .frame(width: 180, height: 180)

                Text("🥙")
                    .font(.system(size: 64))
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("Döner App")
                    .font(.largeTitle.bold())

                Text("Finde, bewerte und sammle\ndeine liebsten Döner-Läden.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page 2: Location

struct LocationPage: View {
    let locationManager: LocationManager
    let onContinue: () -> Void
    @State private var permissionRequested = false

    private var isAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    private var isDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 140, height: 140)

                Image(systemName: isAuthorized ? "location.fill" : "location.slash")
                    .font(.system(size: 56))
                    .foregroundStyle(isAuthorized ? .green : .blue)
            }

            VStack(spacing: 12) {
                Text("Dein Standort")
                    .font(.title.bold())

                if isAuthorized {
                    Text("Standort freigegeben!")
                        .font(.body)
                        .foregroundStyle(.green)
                } else if isDenied {
                    Text("Standort abgelehnt.\nDu kannst das später in den Einstellungen ändern.\nFreiburg wird als Standard verwendet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Damit wir dir Döner-Läden\nin deiner Nähe zeigen können.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if !isAuthorized && !isDenied {
                    Button {
                        locationManager.requestPermission()
                        permissionRequested = true
                    } label: {
                        Text("Standort freigeben")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Button {
                    onContinue()
                } label: {
                    Text(isAuthorized || isDenied ? "Weiter" : "Ohne Standort fortfahren")
                        .font(isAuthorized || isDenied ? .headline : .subheadline)
                        .foregroundStyle(isAuthorized || isDenied ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isAuthorized || isDenied ? 16 : 8)
                        .background {
                            if isAuthorized || isDenied {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.orange.gradient)
                            }
                        }
                }
            }
            .padding(.bottom, 40)
        }
        .padding()
        .onChange(of: locationManager.authorizationStatus) {
            if permissionRequested && (isAuthorized || isDenied) {
                // Auto-advance after short delay so user sees the result
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onContinue()
                }
            }
        }
    }
}

// MARK: - Page 3: Features

struct FeaturesPage: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("So funktioniert's")
                    .font(.title.bold())
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "map.fill", color: .orange, title: "Entdecken", description: "Finde Döner-Läden in deiner Umgebung")
                FeatureRow(icon: "checkmark.circle.fill", color: .green, title: "Einchecken", description: "Markiere jeden Besuch — er zählt für deine Stempelkarte und erscheint im Feed")
                FeatureRow(icon: "fork.knife.circle.fill", color: .orange, title: "Bewerten", description: "Bewerte und teile deine Erfahrungen")
                FeatureRow(icon: "seal.fill", color: .purple, title: "Sammeln", description: "Sammle Stempel und schalte Erfolge frei")
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                onFinish()
            } label: {
                Text("Weiter")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
