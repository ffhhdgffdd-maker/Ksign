import Foundation

struct CeresifyRemoteCertificate: Decodable {
    let p12: String?
    let provisioningProfile: String?
    let password: String?
    let name: String?
    let expiresAt: Int?

    enum CodingKeys: String, CodingKey {
        case devp12, devmp, p12, mobileprovision
        case p12Password = "p12_password"
        case password
        case devName = "dev_name"
        case name
        case expireTime = "expire_time"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        p12 = try c.decodeIfPresent(String.self, forKey: .devp12)
            ?? c.decodeIfPresent(String.self, forKey: .p12)
        provisioningProfile = try c.decodeIfPresent(String.self, forKey: .devmp)
            ?? c.decodeIfPresent(String.self, forKey: .mobileprovision)
        password = try c.decodeIfPresent(String.self, forKey: .p12Password)
            ?? c.decodeIfPresent(String.self, forKey: .password)
        name = try c.decodeIfPresent(String.self, forKey: .devName)
            ?? c.decodeIfPresent(String.self, forKey: .name)
        expiresAt = try c.decodeIfPresent(Int.self, forKey: .expireTime)
            ?? c.decodeIfPresent(Int.self, forKey: .expiresAt)
    }

    var hasValidPayload: Bool {
        guard let p12, let provisioningProfile, let password,
              !p12.isEmpty, !provisioningProfile.isEmpty, !password.isEmpty,
              let p12Data = Data(base64Encoded: p12, options: .ignoreUnknownCharacters),
              let provisionData = Data(base64Encoded: provisioningProfile, options: .ignoreUnknownCharacters),
              !p12Data.isEmpty, !provisionData.isEmpty else { return false }
        if let expiresAt, expiresAt > 0, Date(timeIntervalSince1970: TimeInterval(expiresAt)) <= Date() { return false }
        return true
    }

    var p12Data: Data? { p12.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) } }
    var provisionData: Data? { provisioningProfile.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) } }
}

enum CeresifyCertificateError: LocalizedError {
    case invalidIdentifier
    case invalidResponse
    case unavailable
    case invalidPayload
    case importFailed

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: return "A certificate ID is required."
        case .invalidResponse: return "The certificate API returned an invalid response."
        case .unavailable: return "No certificate was found for this certificate ID."
        case .invalidPayload: return "The certificate payload is incomplete or expired."
        case .importFailed: return "The certificate could not be imported."
        }
    }
}

enum CeresifyCertificateService {
    static let endpoint = URL(string: "https://api.nekoo.eu.org/certificate/public")!
    private static let maximumResponseBytes = 10 * 1024 * 1024

    static func fetch(certificateID: String, completion: @escaping (Result<CeresifyRemoteCertificate, Error>) -> Void) {
        let id = certificateID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.range(of: "^[A-Za-z0-9._-]{1,128}$", options: .regularExpression) != nil else {
            completion(.failure(CeresifyCertificateError.invalidIdentifier))
            return
        }
        guard endpoint.scheme == "https", endpoint.host == "api.nekoo.eu.org", endpoint.port == nil else {
            completion(.failure(CeresifyCertificateError.invalidResponse))
            return
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "certificate_id", value: id)]
        guard let url = components.url else {
            completion(.failure(CeresifyCertificateError.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async { completion(.failure(CeresifyCertificateError.invalidResponse)) }
                return
            }
            guard let http = response as? HTTPURLResponse,
                  http.url?.scheme == "https",
                  http.url?.host?.lowercased() == endpoint.host,
                  let data,
                  data.count <= maximumResponseBytes else {
                DispatchQueue.main.async { completion(.failure(CeresifyCertificateError.invalidResponse)) }
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                let result: CeresifyCertificateError = http.statusCode == 404 ? .unavailable : .invalidResponse
                DispatchQueue.main.async { completion(.failure(result)) }
                return
            }
            guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("json") == true else {
                DispatchQueue.main.async { completion(.failure(CeresifyCertificateError.invalidResponse)) }
                return
            }
            do {
                let certificate = try JSONDecoder().decode(CeresifyRemoteCertificate.self, from: data)
                guard certificate.hasValidPayload else { throw CeresifyCertificateError.invalidPayload }
                DispatchQueue.main.async { completion(.success(certificate)) }
            } catch let error as CeresifyCertificateError {
                DispatchQueue.main.async { completion(.failure(error)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(CeresifyCertificateError.invalidResponse)) }
            }
        }.resume()
    }

    static func importCertificate(certificateID: String, certificateName: String? = nil, completion: @escaping (Error?) -> Void) {
        fetch(certificateID: certificateID) { result in
            switch result {
            case .failure(let error): completion(error)
            case .success(let certificate):
                guard let p12Data = certificate.p12Data,
                      let provisionData = certificate.provisionData,
                      let password = certificate.password,
                      let p12URL = writeTemporary(p12Data, extension: "p12"),
                      let provisionURL = writeTemporary(provisionData, extension: "mobileprovision"),
                      FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL) else {
                    completion(CeresifyCertificateError.importFailed)
                    return
                }
                FR.handleCertificateFiles(
                    p12URL: p12URL,
                    provisionURL: provisionURL,
                    p12Password: password,
                    certificateName: certificateName ?? certificate.name ?? "Ceresify Remote Certificate"
                ) { error in completion(error) }
            }
        }
    }

    private static func writeTemporary(_ data: Data, extension: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(`extension`)
        do { try data.write(to: url, options: .completeFileProtection); return url } catch { return nil }
    }
}
