//
//  URL+scheme.swift
//  Feather
//
//  Created by samara on 8.05.2025.
//

import Foundation.NSURL

extension URL {
	func validatedScheme(after marker: String) -> String? {
		guard let range = absoluteString.range(of: marker) else { return nil }
		let path = String(absoluteString[range.upperBound...])
		guard let url = URL(string: path),
			  url.scheme?.lowercased() == "https",
			  let host = url.host?.lowercased(),
			  !host.isEmpty,
			  url.user == nil,
			  url.password == nil,
			  url.port == nil || url.port == 443,
			  host != "localhost",
			  host != "127.0.0.1",
			  host != "::1",
			  !host.hasSuffix(".local") else { return nil }
		return path
	}
}
