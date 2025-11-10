import Foundation

// MARK: - Sous Vide Cook Command Models
// Recreated after deletion. These support building the JSON request body you outlined.

struct CookCommand: Codable {
    let vesselId: Double
    let cookMode: Double
    let commandType: String
    let dataId: Double
    let foodType: Double
    let sousvideWaterTemperature: Double
    let initialWaterTemperature: Double
}

struct CookRequest: Codable {
    let command: CookCommand
    let deviceId: String
    let domainType: String
    let kind: String
    let serviceDeviceType: String
    let serviceType: String
}

extension CookRequest {
    static func build(sousVideTemp: Double, initialTemp: Double) -> CookRequest {
        let command = CookCommand(
            vesselId: 1.23456789E8,
            cookMode: 27.0,
            commandType: "cloud.smarthq.command.cooking.mode.multistage.sousvide.start",
            dataId: 3.3554433E7,
            foodType: 127.0,
            sousvideWaterTemperature: sousVideTemp,
            initialWaterTemperature: initialTemp
        )
        return CookRequest(
            command: command,
            deviceId: "00000000000000000000000000000000000000000000000000000000000000",
            domainType: "cloud.smarthq.domain.multistage.cookrequest.sousvide",
            kind: "service#command",
            serviceDeviceType: "cloud.smarthq.device.microwave.sousvide",
            serviceType: "cloud.smarthq.service.cooking.mode.multistage"
        )
    }
}

final class CookRequestSender {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func send(request: CookRequest, to url: URL, accessToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let body = try encoder.encode(request)
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = body

            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error = error { completion(.failure(error)); return }
                guard let http = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "CookRequestSender", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                    completion(.failure(NSError(domain: "CookRequestSender", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(bodyString)"])))
                    return
                }
                completion(.success(()))
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}
