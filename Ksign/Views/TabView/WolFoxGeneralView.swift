import SwiftUI
import CoreData
import AltSourceKit

struct WolFoxGeneralView: View {
    @State private var addingSource = false
    @FetchRequest(entity: AltSource.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)])
    private var sources: FetchedResults<AltSource>
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        NavigationLink { SourcesView() } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("المصادر", systemImage: "globe").font(.title3.bold())
                                Text(sources.isEmpty ? "ابدأ بإضافة أول مصدر لك." : "\(sources.count) مصادر مضافة")
                                    .foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                        Spacer()
                        Button { addingSource = true } label: {
                            Image(systemName: "plus").font(.title2.bold()).padding(10)
                        }.accessibilityLabel("إضافة مصدر")
                    }.padding(22)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                    Text("المصادر المتاحة").font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(sources) { source in
                            NavigationLink {
                                SourceAppsView(object: [source], viewModel: SourcesViewModel.shared)
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    WolFoxRemoteIcon(url: source.iconURL, size: 64)
                                    Text(source.name ?? "مصدر").font(.headline).lineLimit(2)
                                    Text("عرض التطبيقات").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 160, alignment: .leading).padding(18)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("الأدوات").font(.title2.bold())
                    NavigationLink { FilesView() } label: { Label("إدارة الملفات", systemImage: "folder") }
                    NavigationLink { DownloaderView() } label: { Label("التنزيلات", systemImage: "arrow.down.circle") }
                }.padding(20)
            }.background(Color.black).navigationTitle("عام")
                .sheet(isPresented: $addingSource) { SourcesAddView().presentationDetents([.medium]) }
        }
    }
}
