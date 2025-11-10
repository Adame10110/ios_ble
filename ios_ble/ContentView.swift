import SwiftUI
import Foundation

// MARK: - Inline Cook Request Models (temporary)
// These are duplicated from CookRequestModels.swift to ensure they are in scope while
// the project file (file system synchronized group) indexes the new file. Remove this
// block once Xcode recognizes CookRequestModels.swift and the build succeeds.
// struct CookCommand: Codable {
//     let vesselId: Double
//     let cookMode: Double
//     let commandType: String
//     let dataId: Double
//     let foodType: Double
//     let sousvideWaterTemperature: Double
//     let initialWaterTemperature: Double
// }

// struct CookRequest: Codable {
//     let command: CookCommand
//     let deviceId: String
//     let domainType: String
//     let kind: String
//     let serviceDeviceType: String
//     let serviceType: String
// }

// extension CookRequest {
//     static func build(sousVideTemp: Double, initialTemp: Double) -> CookRequest {
//         let command = CookCommand(
//             vesselId: 1.23456789E8,
//             cookMode: 27.0,
//             commandType: "cloud.smarthq.command.cooking.mode.multistage.sousvide.start",
//             dataId: 3.3554433E7,
//             foodType: 127.0,
//             sousvideWaterTemperature: sousVideTemp,
//             initialWaterTemperature: initialTemp
//         )
//         return CookRequest(
//             command: command,
//             deviceId: "00000000000000000000000000000000000000000000000000000000000000",
//             domainType: "cloud.smarthq.domain.multistage.cookrequest.sousvide",
//             kind: "service#command",
//             serviceDeviceType: "cloud.smarthq.device.microwave.sousvide",
//             serviceType: "cloud.smarthq.service.cooking.mode.multistage"
//         )
//     }
// }

// final class CookRequestSender {
//     private let session: URLSession
//     init(session: URLSession = .shared) { self.session = session }
//     func send(request: CookRequest, to url: URL, accessToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
//         let encoder = JSONEncoder()
//         encoder.outputFormatting = [.sortedKeys]
//         do {
//             let body = try encoder.encode(request)
//             var urlRequest = URLRequest(url: url)
//             urlRequest.httpMethod = "POST"
//             urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//             urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
//             urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
//             urlRequest.httpBody = body
//             session.dataTask(with: urlRequest) { data, response, error in
//                 if let error = error { completion(.failure(error)); return }
//                 guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
//                     let http = response as? HTTPURLResponse
//                     let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
//                     completion(.failure(NSError(domain: "CookRequestSender", code: http?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: bodyString])))
//                     return
//                 }
//                 completion(.success(()))
//             }.resume()
//         } catch { completion(.failure(error)) }
//     }
// }

// let dict: [String: Any] = [
//   "command": [
//     "vesselId": 1.23456789E8,
//     "cookMode": 27.0,
//     "commandType": "cloud.smarthq.command.cooking.mode.multistage.sousvide.start",
//     "dataId": 3.3554433E7,
//     "foodType": 127.0,
//     "sousvideWaterTemperature": 150.0,
//     "initialWaterTemperature": 75.0
//   ],
//   "deviceId": "00000000000000000000000000000000000000000000000000000000000000",
//   "domainType": "cloud.smarthq.domain.multistage.cookrequest.sousvide",
//   "kind": "service#command",
//   "serviceDeviceType": "cloud.smarthq.device.microwave.sousvide",
//   "serviceType": "cloud.smarthq.service.cooking.mode.multistage"
// ]
// let body = try JSONSerialization.data(withJSONObject: dict)

let sender = CookRequestSender()

func submitSousVide() {
    // Parse user-entered desiredTemperature (F) from state. Fallback to 150 if invalid.
    // let sousVideTemp = Double(desiredTemperature.trimmingCharacters(in: .whitespaces)) ?? 150.0
    let sousVideTemp = 150.0
    let initialTemp = 75.0 // TODO: Replace with actual current water temp if available.
    let cookReq = CookRequest.build(sousVideTemp: sousVideTemp, initialTemp: initialTemp)
    guard let url = URL(string: "https://client.mysmarthq.com/v2/cook") else { return }
    let token = "ue1cphk81tnmbjkxbr66tj9zd813b51k" // TODO: Move to secure storage.
    sender.send(request: cookReq, to: url, accessToken: token) { result in
        DispatchQueue.main.async {
            print("Cook request result: \(result)")
        }
    }
}

func sendGETRequest()
    {
    let accessToken = "ue1cphk81tnmbjkxbr66tj9zd813b51k" //will need to replace as needed
    let url: URL = URL(string: "https://client.mysmarthq.com/v2/device")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            print("GET Response: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }
    task.resume()
}

struct ContentView: View {

    @State private var desiredTemperature: String = ""
    
    @StateObject private var vm = BluetoothViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text(vm.stateDescription).font(.headline)
            if let id = vm.discoveredPeripheralId { Text("Peripheral: \(id)") }
            if let rssi = vm.rssi { Text("RSSI: \(rssi)") }
            if let num = vm.lastNumberValue { Text("Last number: \(num)") }
            
            Spacer()
            HStack {
                Text("Current Temperature: ")
                Text("100 F")
            }
            Spacer()
            HStack {
                Text("Desired Temperature: ")
                TextField("150 F",text: $desiredTemperature).frame(width: 50)
            }
            Spacer()
            Spacer()
            
            Button(action: {
                print("Button tapped!")
                calculatePowerProfile()
            }) {
                Text("Submit: \(desiredTemperature)")
            }

            Spacer()
            
            HStack {
                Button(vm.isScanning ? "Stop Scan" : "Start Scan") { vm.toggleScan() }
                    .buttonStyle(.borderedProminent)
                if vm.isConnected {
                    Button("Disconnect") { vm.disconnect() }
                }
            }
            List(vm.hexValueHistory.reversed(), id: \.self) { value in
                Text(value).font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
    }
    
    func calculatePowerProfile() {
        print("Text: \(desiredTemperature)")
        sendGETRequest()
        submitSousVide()
        //format, just get ints from the text string of this guy
        //then run calculations, thatll get us a power profile output to send on
    }
    
}

#Preview {
    ContentView()
}
