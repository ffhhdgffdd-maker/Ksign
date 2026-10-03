import SwiftUI
import CoreData
import AltSourceKit
import NukeUI

/// Shared catalog: source order is stable and every row belongs to its original repository.
struct WolFoxCatalogEntry: Identifiable {
    let source: ASRepository
    let app: ASRepository.App
    var id: String { (source.id ?? source.name ?? "") + "|" + (app.id ?? app.uuid.uuidString) }
}

struct AppstoreView: View {
    var body: some View { WolFoxCatalogView(featured: false) }
}

struct WolFoxHomeView: View {
    var body: some View { WolFoxCatalogView(featured: true) }
}

private struct WolFoxCatalogView: View {
    let featured: Bool
    @StateObject private var model = SourcesViewModel.shared
    @State private var search = ""
    @State private var selectedSource = ""
    @State private var loading = false
    @FetchRequest(entity: AltSource.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)])
    private var sources: FetchedResults<AltSource>

    private var entries: [WolFoxCatalogEntry] {
        sources.compactMap { model.sources[$0] }.flatMap { repo in
            repo.apps.map { WolFoxCatalogEntry(source: repo, app: $0) }
        }.filter {
            (selectedSource.isEmpty || ($0.source.id ?? $0.source.name ?? "") == selectedSource) &&
            (search.isEmpty || $0.app.currentName.localizedCaseInsensitiveContains(search) ||
             ($0.app.id ?? "").localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if !featured {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            TextField("بحث باسم التطبيق أو الباندل", text: $search)
                                .autocorrectionDisabled()
                            if !search.isEmpty {
                                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if !featured {
                        NavigationLink { SourcesView() } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "globe").font(.largeTitle)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("مصادر WolFox").font(.title3.bold())
                                    Text("تصفح التطبيقات من المصادر المضافة")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                            }.padding(22)
                                .background(Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                sourceChip("الكل", id: "")
                                ForEach(sources) { source in
                                    sourceChip(source.name ?? "مصدر", id: model.sources[source]?.id ?? model.sources[source]?.name ?? "")
                                }
                            }
                        }
                        Text("\(entries.count) تطبيقات").font(.title3.bold())
                    }
                    if loading && entries.isEmpty { ProgressView("جارٍ تحميل التطبيقات…").frame(maxWidth: .infinity) }
                    if !loading && entries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "app.dashed").font(.largeTitle)
                            Text(search.isEmpty ? "لا توجد تطبيقات متاحة" : "لا توجد نتائج مطابقة").font(.headline)
                            Text("أضف مصدرًا أو حدّث القائمة وحاول مجددًا.").foregroundStyle(.secondary)
                            NavigationLink("إدارة المصادر") { SourcesView() }
                        }.padding(30).frame(maxWidth: .infinity)
                    }
                    ForEach(entries) { entry in
                        if featured {
                            WolFoxFeaturedCard(entry: entry)
                        } else {
                            HStack(spacing: 14) {
                                NavigationLink {
                                    SourceAppsDetailView(source: entry.source, app: entry.app)
                                } label: {
                                    HStack(spacing: 12) {
                                        WolFoxRemoteIcon(url: entry.app.iconURL, size: 60)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(entry.app.currentName).font(.headline).lineLimit(2)
                                            Text("\(entry.app.currentVersion ?? "") • \(entry.source.name ?? "")")
                                                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }.buttonStyle(.plain)
                                DownloadButtonView(app: entry.app)
                            }.padding(.vertical, 8)
                            Divider()
                        }
                    }
                }.padding(20)
            }
            .background(Color.black)
            .navigationTitle(featured ? "الرئيسية" : "التطبيقات")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await refresh() } } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }.disabled(loading)
                }
                if featured {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink { AppstoreView() } label: { Image(systemName: "magnifyingglass") }
                    }
                }
            }
            .refreshable { await refresh() }
            .task(id: Array(sources)) {
                loading = true
                await model.fetchSources(sources)
                loading = false
            }
        }
    }

    private func refresh() async {
        loading = true
        await model.fetchSources(sources, refresh: true)
        loading = false
    }

    private func sourceChip(_ title: String, id: String) -> some View {
        Button { selectedSource = id } label: {
            Text(title).font(.headline).padding(.horizontal, 20).padding(.vertical, 12)
                .foregroundStyle(selectedSource == id ? Color.black : Color.white)
                .background(selectedSource == id ? Color.white : Color(uiColor: .secondarySystemBackground), in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct WolFoxRemoteIcon: View {
    let url: URL?
    var size: CGFloat = 60
    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    Image(systemName: "app.fill").font(.title2).foregroundStyle(.secondary)
                }
            }
        }.frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .overlay(RoundedRectangle(cornerRadius: size * 0.22).stroke(Color.white.opacity(0.12)))
    }
}

private struct WolFoxFeaturedCard: View {
    let entry: WolFoxCatalogEntry
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LazyImage(url: entry.app.iconURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else { Color.blue.opacity(0.3) }
            }.frame(height: 220).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 12) {
                NavigationLink {
                    SourceAppsDetailView(source: entry.source, app: entry.app)
                } label: {
                    HStack(spacing: 12) {
                        WolFoxRemoteIcon(url: entry.app.iconURL, size: 58)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.app.currentName).font(.title3.bold()).lineLimit(2)
                            Text(entry.source.name ?? "تطبيق").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                DownloadButtonView(app: entry.app)
            }.padding(18)
        }.frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.12)))
    }
}
