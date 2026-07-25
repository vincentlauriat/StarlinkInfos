import SwiftUI

enum SidebarSelection: Hashable {
    case dashboard
    case article(String)
    case launch(String)
}

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var dishVM = DishViewModel()
    @State private var feedVM = FeedViewModel()
    @State private var selection: SidebarSelection? = .dashboard
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        NavigationSplitView {
            SidebarView(feedVM: feedVM, selection: $selection)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                #endif
        } detail: {
            switch selection {
            case .dashboard, nil:
                DishDashboardView(vm: dishVM)
            case .article(let id):
                if let article = feedVM.articles.first(where: { $0.id == id }) {
                    ArticleDetailView(article: article)
                } else {
                    EmptySelectionView()
                }
            case .launch(let id):
                if let launch = feedVM.launches.first(where: { $0.id == id }) {
                    LaunchDetailView(launch: launch)
                } else {
                    EmptySelectionView()
                }
            }
        }
        .task { await feedVM.load(lang: settings.effectiveLang) }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { feedVM.errorMessage != nil },
            set: { if !$0 { feedVM.errorMessage = nil } }
        )) {
            Button(settings.t("ok")) { feedVM.errorMessage = nil }
        } message: {
            Text(feedVM.errorMessage ?? "")
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environment(settings)
                    .navigationTitle(settings.t("settings_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t("ok")) { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var feedVM: FeedViewModel
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section(settings.t("section_connection")) {
                Label(settings.t("dashboard_row"), systemImage: "antenna.radiowaves.left.and.right")
                    .tag(SidebarSelection.dashboard)
            }

            Section {
                ForEach(feedVM.launches.prefix(8)) { launch in
                    LaunchRowView(launch: launch)
                        .tag(SidebarSelection.launch(launch.id))
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.t("section_launches"))
                    if let count = feedVM.satelliteCount {
                        // Source Celestrak (catalogue USSF) — attribution requise.
                        Text(settings.t("constellation_count") + " \(count) · Celestrak")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textCase(nil)
                    }
                }
            }

            Section(settings.t("section_news")) {
                ForEach(feedVM.filteredArticles) { article in
                    ArticleRowView(article: article)
                        .tag(SidebarSelection.article(article.id))
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $feedVM.searchText, placement: .sidebar,
                    prompt: settings.t("search_placeholder"))
        .navigationTitle(settings.t("app_name"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await feedVM.load(lang: settings.effectiveLang) }
                } label: {
                    if feedVM.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(feedVM.isLoading)
                .help(settings.t("refresh_help"))
            }
        }
    }
}

// MARK: - Lignes de la sidebar

struct ArticleRowView: View {
    @Environment(AppSettings.self) private var settings
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(article.title)
                .font(.body)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Text(article.dateFormatted(locale: settings.localeIdentifier))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !article.source.isEmpty {
                    Text("·").font(.caption).foregroundStyle(.tertiary)
                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct LaunchRowView: View {
    @Environment(AppSettings.self) private var settings
    let launch: StarlinkLaunch

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(launch.name)
                .font(.body)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text(launch.net, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·").font(.caption).foregroundStyle(.tertiary)
                Text(launch.statusAbbrev)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Détails

struct ArticleDetailView: View {
    @Environment(AppSettings.self) private var settings
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.largeTitle.bold())
                    HStack(spacing: 6) {
                        if !article.source.isEmpty {
                            Text(article.source).bold()
                        }
                        Text(article.dateFormatted(locale: settings.localeIdentifier))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Divider()

                Link(destination: article.link) {
                    Label(settings.t("open_in_browser"), systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(article.source.isEmpty ? settings.t("section_news") : article.source)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct LaunchDetailView: View {
    @Environment(AppSettings.self) private var settings
    let launch: StarlinkLaunch

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = launch.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(launch.name)
                        .font(.largeTitle.bold())
                    Text(launch.dateFormatted(locale: settings.localeIdentifier))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label(launch.statusName, systemImage: "flag")
                    if !launch.padName.isEmpty {
                        Label("\(launch.padName) — \(launch.locationName)", systemImage: "location")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                if launch.net > Date() {
                    Text(launch.net, style: .relative)
                        .font(.title2.monospacedDigit().bold())
                }

                if let description = launch.missionDescription, !description.isEmpty {
                    Divider()
                    Text(description)
                        .font(.body)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(launch.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
