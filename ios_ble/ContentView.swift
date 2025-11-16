import SwiftUI
import Foundation

// url
// token
// 

let accessToken = "ue1cpj89k75owkiw6wefuxu3v3pg6ddy"

let sender = CookRequestSender()

// Submit a sous vide cook request using current sensor temperature from the Bluetooth view model.
// - Parameters:
//   - vm: BluetoothViewModel providing lastNumberValue (current water temp) if available.
//   - desiredTemp: Desired target temperature (F). If nil, defaults to 150F.
func submitSousVide(using vm: BluetoothViewModel, desiredTemp: Double?) {
    let sousVideTemp = desiredTemp ?? 150.0
    let initialTemp = Double(vm.lastNumberValue ?? 75) // fallback if sensor not yet available

    print("Desired Temp \(sousVideTemp)", sousVideTemp)
    print("Initial Temp \(initialTemp)", initialTemp)

    let cookReq = CookRequest.build(sousVideTemp: sousVideTemp, initialTemp: initialTemp)
    guard let url = URL(string: "https://client.mysmarthq.com/v2/cook") else { return }
    // let token = "ue1cphk81tnmbjkxbr66tj9zd813b51k" // TODO: Move to secure storage.
    let token = accessToken

    //format JSON for output

    /*
    mode (enum: has a value of 0 or 27)
    food-type (enum: 0 = Any and 255 = Invalid)
    vessel-id (integer: u32)
    initial-water-temperature (integer: u16)
    sous-vide-temperature (integer: u16)
    https://geappliances.atlassian.net/wiki/spaces/SHSCT/pages/3815178585/GSP+-+Microwave+Sous+Vide+SmartHQ+Services
    */

    sender.send(request: cookReq, to: url, accessToken: token) { result in
        DispatchQueue.main.async {
            print("Cook request result: \(result)")
        }
    }
}

func sendGETRequest()
    {
    // let accessToken = "ue1cphk81tnmbjkxbr66tj9zd813b51k" //will need to replace as needed //ow
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
    @FocusState private var tempFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text(vm.stateDescription).font(.headline)
            if let id = vm.discoveredPeripheralId { Text("Peripheral: \(id)") }
            if let rssi = vm.rssi { Text("RSSI: \(rssi)") }
            // if let num = vm.lastNumberValue { Text("Last number: \(num)") }
            
            Spacer()
            HStack {
                Text("Current Temperature: ")
                if let num = vm.lastNumberValue {
                    Text("\(num) F")
                        .accessibilityLabel("Current temperature \(num) Fahrenheit")
                } else {
                    Text("-- F")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Current temperature unavailable")
                }
            }
            Spacer()
            HStack {
                Text("Desired Temperature: ")
                TextField("150", text: numericBinding)
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .focused($tempFieldFocused)
                    .onSubmit { tempFieldFocused = false; clampDesired() }
                    .accessibilityLabel("Desired temperature in Fahrenheit")
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
        .toolbar { // iOS 15+ keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { tempFieldFocused = false; clampDesired() }
            }
        }
    }
    
    func calculatePowerProfile() {
        print("Text: \(desiredTemperature)")
        sendGETRequest()
        let parsedDesired = Double(desiredTemperature.trimmingCharacters(in: .whitespaces))
        submitSousVide(using: vm, desiredTemp: parsedDesired)
        //format, just get ints from the text string of this guy
        //then run calculations, thatll get us a power profile output to send on
    }
    
}

#Preview {
    ContentView()
}

// MARK: - Numeric Input Helpers
private extension ContentView {
    var numericBinding: Binding<String> {
        Binding<String>(
            get: { desiredTemperature },
            set: { newValue in
                let filtered = sanitizeNumeric(input: newValue)
                desiredTemperature = filtered
            }
        )
    }

    func sanitizeNumeric(input: String) -> String {
        // Allow digits and at most one decimal point; drop other characters
        var result = ""
        var hasDecimal = false
        for ch in input { 
            if ch.isNumber { result.append(ch); continue }
            if ch == "." && !hasDecimal { result.append(ch); hasDecimal = true }
        }
        // Avoid leading '.' without a zero
        if result == "." { return "0." }
        return result
    }

    func clampDesired() {
        // Optional: ensure within reasonable cooking range 32F - 212F
        guard let v = Double(desiredTemperature) else { return }
        let clamped = min(max(v, 32), 450)
        if v != clamped { desiredTemperature = String(format: "%.0f", clamped) }
    }
}
