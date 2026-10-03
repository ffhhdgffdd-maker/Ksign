//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import UIKit

final class ZsignHandler {
    var hadError: Error?
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty || _options.removeInjectedGPSLibraries == true else {
			return
		}
		
		try removeSelectedGPSLibraries()
        let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		let loaded = Set(Zsign.listDylibs(appExecutable: execPath).map { $0 as String })
        let remaining = _options.disInjectionFiles.filter { loaded.contains($0) }
        if !remaining.isEmpty && !Zsign.removeDylibs(appExecutable: execPath, using: remaining) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}
	
    private func removeSelectedGPSLibraries() throws {
        func normalized(_ path: String) -> String {
            URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                .lowercased().filter { $0.isLetter || $0.isNumber }
        }
        var selected = Set(_options.disInjectionFiles.filter {
            let name = normalized($0)
            return name.contains("fakegps") || name.contains("gpsplus")
        }.map { normalized($0) })
        let removeAllGPS = _options.removeInjectedGPSLibraries == true
        guard !selected.isEmpty || removeAllGPS else { return }

        let root = _appUrl.standardizedFileURL.resolvingSymlinksInPath()
        let manager = FileManager.default
        var executables = Set<URL>()
        var libraries = Set<URL>()
        if let executable = Bundle(url: _appUrl)?.executableURL { executables.insert(executable) }
        guard let enumerator = manager.enumerator(at: _appUrl,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]) else {
            throw SigningFileHandlerError.disinjectFailed
        }
        for case let file as URL in enumerator {
            let resolved = file.standardizedFileURL.resolvingSymlinksInPath()
            guard resolved.path.hasPrefix(root.path + "/") else {
                enumerator.skipDescendants()
                continue
            }
            if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            let ext = file.pathExtension.lowercased()
            if ["app", "appex", "framework", "bundle"].contains(ext),
               let executable = Bundle(url: file)?.executableURL {
                executables.insert(executable)
            }
            if ext == "dylib" { executables.insert(file) }
            let name = normalized(file.path)
            let namedGPS = name.contains("fakegps") || name.contains("gpsplus")
            if ["dylib", "framework", "bundle", "plist"].contains(ext),
               selected.contains(name) || (removeAllGPS && namedGPS) {
                libraries.insert(file)
                if ext == "dylib" || ext == "framework" { selected.insert(name) }
            }
        }
        // Remove matching load commands from every executable before deleting any library.
        for executable in executables {
            let resolved = executable.standardizedFileURL.resolvingSymlinksInPath()
            guard resolved.path.hasPrefix(root.path + "/"),
                  manager.fileExists(atPath: resolved.path) else {
                throw SigningFileHandlerError.disinjectFailed
            }
            let paths = Zsign.listDylibs(appExecutable: executable.path).map { $0 as String }
            if removeAllGPS {
                for path in paths {
                    let name = normalized(path)
                    if name.contains("fakegps") || name.contains("gpsplus") { selected.insert(name) }
                }
            }
            let removals = paths.filter { selected.contains(normalized($0)) }
            guard removals.isEmpty || Zsign.removeDylibs(appExecutable: executable.path, using: removals) else {
                throw SigningFileHandlerError.disinjectFailed
            }
            let remaining = Zsign.listDylibs(appExecutable: executable.path).map { $0 as String }
            guard !remaining.contains(where: { selected.contains(normalized($0)) }) else {
                throw SigningFileHandlerError.disinjectFailed
            }
        }
        for library in libraries.sorted(by: { $0.path.count > $1.path.count }) {
            if manager.fileExists(atPath: library.path) { try manager.removeItem(at: library) }
        }
    }

	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}
		
        let _ = Zsign.sign(
            appPath: _appUrl.relativePath,
            provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
            p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
            p12Password: cert.password ?? "",
            entitlementsPath: _options.appEntitlementsFile?.path ?? "",
            customIdentifier: _options.appIdentifier ?? "",
            customName: _options.appName ?? "",
            customVersion: _options.appVersion ?? "",
            removeProvision: !_options.removeProvisioning,
            completion: { _, error in
                self.hadError = error
            }
        )
    }
	
	func adhocSign() async throws {
        let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			customIdentifier: _options.appIdentifier ?? "",
			customName: _options.appName ?? "",
			customVersion: _options.appVersion ?? "",
			adhoc: true,
            removeProvision: !_options.removeProvisioning,
            completion: { _, error in
                self.hadError = error
            }
        )
             
	}
}
