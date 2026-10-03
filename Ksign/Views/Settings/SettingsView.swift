import SwiftUI
import CoreData
import NimbleViews
import UIKit

struct SettingsView: View {
    @AppStorage("feather.selectedCert") private var selectedCert = 0
    @FetchRequest(entity: CertificatePair.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)])
    private var certificates: FetchedResults<CertificatePair>

    private var certificate: CertificatePair? {
        certificates.indices.contains(selectedCert) ? certificates[selectedCert] : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { WolFoxDeviceView() } label: {
                        Label("معلومات الجهاز", systemImage: "iphone")
                    }
                    NavigationLink { WolFoxCertificateView(cert: certificate) } label: {
                        Label("شهادتي", systemImage: "checkmark.seal")
                    }
                } footer: {
                    Text("معلومات جهازك والشهادة المستخدمة في التوقيع.")
                }
                Section {
                    NavigationLink { AppearanceView() } label: {
                        Label("التفضيلات", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink { WolFoxNotificationSettings() } label: {
                        Label("الإشعارات", systemImage: "bell.badge")
                    }
                }
                Section("ميزات التطبيق") {
                    NavigationLink { AppFeaturesView() } label: {
                        Label("ميزات التطبيق", systemImage: "sparkles")
                    }
                    NavigationLink { ConfigurationView() } label: {
                        Label("خيارات التوقيع", systemImage: "signature")
                    }
                    NavigationLink { ArchiveView() } label: {
                        Label("الأرشفة وفك الضغط", systemImage: "archivebox")
                    }
                    NavigationLink { InstallationView() } label: {
                        Label("التثبيت", systemImage: "server.rack")
                    }
                    NavigationLink { LogsView(manager: LogsManager.shared) } label: {
                        Label("السجلات", systemImage: "terminal")
                    }
                }
                Section("روابط المشروع والمصادر") {
                    Link(destination: URL(string: "https://repo.p3nd.fun")!) {
                        Label("مستودع WolFox", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://repo.p3nd.fun/fakegps.json")!) {
                        Label("FakeGPS", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://repo.p3nd.fun/ipa-plus.json")!) {
                        Label("IPA Plus", systemImage: "globe")
                    }
                }
                Section("إدارة التطبيق") {
                    NavigationLink { CertificatesView() } label: {
                        Label("إدارة الشهادات", systemImage: "key")
                    }
                    NavigationLink { AppIconView() } label: {
                        Label("أيقونة التطبيق", systemImage: "app.badge")
                    }
                    NavigationLink { SourcesView() } label: {
                        Label("إدارة المصادر", systemImage: "globe")
                    }
                    NavigationLink { ResetView() } label: {
                        Label("إعادة الضبط", systemImage: "arrow.counterclockwise")
                    }
                }
            }.navigationTitle("الإعدادات")
        }
    }
}

struct WolFoxDeviceView: View {
    private var modelIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "iphone").font(.system(size: 64))
                    Text(UIDevice.current.name).font(.title2.bold())
                    Text(UIDevice.current.model).foregroundStyle(.secondary)
                    Text("معلومات الجهاز الحالي").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 28)
            }.listRowBackground(Color.clear)
            Section {
                LabeledContent("اسم الجهاز", value: UIDevice.current.name)
                LabeledContent("الموديل", value: UIDevice.current.model)
                LabeledContent("معرّف الموديل", value: modelIdentifier)
                LabeledContent("إصدار iOS", value: UIDevice.current.systemVersion)
                LabeledContent("التطبيق", value: "WolFox")
                LabeledContent("الإصدار", value: Bundle.main.version)
                LabeledContent("الباندل", value: Bundle.main.bundleIdentifier ?? "")
            }
        }.navigationTitle("معلومات الجهاز").navigationBarTitleDisplayMode(.inline)
    }
}

struct WolFoxCertificateView: View {
    let cert: CertificatePair?
    @State private var showPassword = false
    @State private var share: WolFoxShareItem?
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 72))
                    Text("شهادتي").font(.title.bold())
                    Text(cert?.nickname ?? "لا توجد شهادة محددة").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 28)
            }.listRowBackground(Color.clear)
            if let cert {
                Section {
                    fileRow("الشهادة", type: .certificate, cert: cert)
                    fileRow("ملف البروفايل", type: .provision, cert: cert)
                    HStack {
                        Label("كلمة المرور", systemImage: "lock")
                        Spacer()
                        Text(showPassword ? (cert.password ?? "") : "••••••")
                            .textSelection(.enabled)
                            .environment(\.layoutDirection, .leftToRight)
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }.buttonStyle(.borderless).accessibilityLabel("إظهار أو إخفاء كلمة المرور")
                    }
                } footer: { Text("استخدم الشهادة والبروفايل وكلمة المرور للتوقيع.") }
                Section {
                    if let expiration = cert.expiration {
                        LabeledContent("انتهاء الشهادة", value: expiration.formatted(date: .abbreviated, time: .omitted))
                    }
                    if cert.revoked { Label("الشهادة ملغاة", systemImage: "xmark.octagon").foregroundStyle(.red) }
                    NavigationLink { CertificatesInfoView(cert: cert) } label: {
                        Label("تفاصيل الشهادة", systemImage: "info.circle")
                    }
                }
            }
            Section {
                NavigationLink { CertificatesView() } label: { Label("إدارة الشهادات", systemImage: "key") }
            }
        }.navigationTitle("شهادتي").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $share) { WolFoxShareSheet(items: $0.urls) }
    }
    private func fileRow(_ title: String, type: Storage.FileRequest, cert: CertificatePair) -> some View {
        HStack {
            Label(title, systemImage: type == .certificate ? "key.fill" : "doc.badge.gearshape")
            Spacer()
            if let url = Storage.shared.getFile(type, from: cert) {
                Button { share = WolFoxShareItem(urls: [url]) } label: {
                    Image(systemName: "square.and.arrow.up")
                }.buttonStyle(.borderless).accessibilityLabel("مشاركة \(title)")
            } else {
                Text("غير متاح").foregroundStyle(.secondary)
            }
        }
    }
}

private struct WolFoxShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}
private struct WolFoxShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WolFoxNotificationSettings: View {
    var body: some View {
        Form {
            Section {
                Text("تنبيهات اكتمال التنزيل تُدار من ميزات التطبيق.")
                NavigationLink { AppFeaturesView() } label: {
                    Label("إعدادات التنبيهات", systemImage: "bell")
                }
            }
            Section {
                Button("إعدادات إشعارات iOS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }.navigationTitle("الإشعارات").navigationBarTitleDisplayMode(.inline)
    }
}
