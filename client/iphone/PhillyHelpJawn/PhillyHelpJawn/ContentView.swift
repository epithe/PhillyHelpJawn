import SwiftUI
import Speech
import AVFoundation
import Combine
import MapKit
import UIKit
import AudioToolbox

struct ContentView: View {
    @StateObject private var speechInput = SpeechInputManager()
    @StateObject private var responseViewModel = MockAssistResponseViewModel()
    @State private var isShowingMockResponse = false
    @State private var lastSubmittedRequestText = ""
    @State private var displayedRequestText = ""

    var body: some View {
        let listeningActive = speechInput.isRecording || speechInput.isPreparing
        let liveRequestText = listeningActive
            ? (speechInput.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? displayedRequestText : speechInput.transcript)
            : displayedRequestText
        let requestFontSize: CGFloat = {
            let count = liveRequestText.count
            if count > 160 { return 34 }
            if count > 110 { return 40 }
            if count > 70 { return 46 }
            return 52
        }()
        let talkBarBackground = speechInput.permissionDenied
            ? Color(red: 0.78, green: 0.79, blue: 0.86)
            : (speechInput.isRecording
                ? Color(red: 0.94, green: 0.44, blue: 0.45)
                : (speechInput.isPreparing
                    ? Color(red: 0.17, green: 0.78, blue: 0.39)
                    : Color(red: 0.30, green: 0.43, blue: 0.90)))
        let talkBarIconColor = speechInput.permissionDenied
            ? Color(red: 0.45, green: 0.47, blue: 0.52)
            : (speechInput.isRecording ? Color.white : Color(red: 0.92, green: 0.93, blue: 0.96))

        ZStack(alignment: .bottom) {
            Color(red: 0.90, green: 0.90, blue: 0.93).ignoresSafeArea()

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 16) {
                    (
                        Text("Philly")
                            .foregroundStyle(Color.red)
                        + Text("Help")
                            .foregroundStyle(Color(red: 0.17, green: 0.78, blue: 0.39))
                        + Text("Jawn")
                            .foregroundStyle(Color(red: 0.96, green: 0.72, blue: 0.31))
                    )
                    .font(.system(size: 36, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                    // Pin this block around the upper third of the screen.
                    Spacer()
                        .frame(height: geo.size.height * 0.13)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(liveRequestText.isEmpty ? "—" : liveRequestText)
                            .font(.system(size: requestFontSize, weight: .bold))
                            .foregroundStyle(Color(red: 0.04, green: 0.10, blue: 0.20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(6)
                            .minimumScaleFactor(0.55)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: false)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: listeningActive ? 240 : 140,
                        alignment: .topLeading
                    )
                    .padding(20)
                    .background(Color.white.opacity(0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.2), value: listeningActive)

                    if let responseError = responseViewModel.errorMessage {
                        Text(responseError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: max(120, geo.size.height * 0.20))
                }
            }

            Button {
                // Press-and-hold behavior is handled by the gesture.
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(talkBarIconColor)
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .background(talkBarBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
            }
            .disabled(speechInput.permissionDenied)
            .padding(.bottom, 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speechInput.isRecording {
                            speechInput.startRecording()
                        }
                    }
                    .onEnded { _ in
                        speechInput.stopRecording()
                        let capturedRequest = speechInput.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !capturedRequest.isEmpty {
                            lastSubmittedRequestText = capturedRequest
                            displayedRequestText = capturedRequest
                        } else if !displayedRequestText.isEmpty {
                            lastSubmittedRequestText = displayedRequestText
                        }
                        Task {
                            await responseViewModel.loadResponse(queryText: lastSubmittedRequestText)
                            if responseViewModel.response != nil {
                                isShowingMockResponse = true
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $isShowingMockResponse) {
            if let response = responseViewModel.response {
                MockResponseView(response: response, requestText: lastSubmittedRequestText)
            }
        }
        .onAppear {
            speechInput.preflightPermissions()
        }
    }
}

@MainActor
final class MockAssistResponseViewModel: ObservableObject {
    @Published var response: AssistResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let liveClient = AssistAPIClient(baseURL: URL(string: "https://phillyhelpjawn-production.up.railway.app")!)
    private let mockClient = MockAssistAPIClient()
    private let useMockFallback = true

    func loadResponse(queryText: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            response = try await liveClient.fetchResponse(queryText: queryText)
        } catch {
            if useMockFallback {
                do {
                    response = try mockClient.fetchMockResponse()
                    errorMessage = "Live API unavailable. Showing mock response."
                } catch {
                    errorMessage = "Unable to load response."
                }
            } else {
                errorMessage = "Unable to load response."
            }
        }
    }
}

struct AssistResponse: Decodable {
    let requestId: String
    let timestamp: String
    let message: String
    let resources: [AssistResource]
    let crisis: String?
    let actionPhone: String?
    let responseLanguage: String?
}

struct AssistResource: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let eligibility: String?
    let address: String
    let lat: Double
    let lng: Double
    let distanceKm: Double?
    let hours: String?
    let phone: String?
    let description: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct MockAssistAPIClient {
    func fetchMockResponse() throws -> AssistResponse {
        let data = Data(Self.sampleResponseJSON.utf8)
        return try JSONDecoder().decode(AssistResponse.self, from: data)
    }

    private static let sampleResponseJSON = """
    {
      "requestId": "9e5d4f53-0db8-4f77-b4e8-e38f73b6b2cc",
      "timestamp": "2026-03-15T16:42:12Z",
      "message": "Here are some places where you can get food tonight. Mount Tabor CEED Corporation is at 961 North 7th Street. They have a food cupboard open on Mondays. Breaking Bread on Broad is at 615 North Broad Street.",
      "resources": [
        {
          "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
          "name": "Mount Tabor CEED Corporation",
          "category": "Food",
          "eligibility": "Food cupboard",
          "address": "961-971 N 7th St",
          "lat": 39.9678,
          "lng": -75.1485,
          "distanceKm": 1.2,
          "hours": "Monday",
          "phone": null,
          "description": null
        },
        {
          "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
          "name": "Breaking Bread on Broad",
          "category": "Food",
          "eligibility": null,
          "address": "615 N Broad St",
          "lat": 39.9631,
          "lng": -75.1596,
          "distanceKm": 0.8,
          "hours": null,
          "phone": "215-555-0100",
          "description": null
        }
      ],
      "crisis": null,
      "actionPhone": null
    }
    """
}

struct AssistAPIClient {
    let baseURL: URL

    func fetchResponse(queryText: String) async throws -> AssistResponse {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmedQuery.isEmpty ? "I need food help" : trimmedQuery

        let requestBody = AssistQueryRequest(
            requestId: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            inputModality: "voice_ptt",
            queryText: query,
            language: "en-US",
            persona: "primary_low_literacy",
            client: .init(platform: "ios", appVersion: "0.1.0", buildNumber: "1")
        )

        guard let endpointURL = URL(string: "/v1/assist/query", relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AssistResponse.self, from: data)
    }
}

struct AssistQueryRequest: Encodable {
    struct Client: Encodable {
        let platform: String
        let appVersion: String
        let buildNumber: String
    }

    let requestId: String
    let timestamp: String
    let inputModality: String
    let queryText: String
    let language: String
    let persona: String
    let client: Client
}

final class SpeechOutputManager {
    static let shared = SpeechOutputManager()
    private let synthesizer = AVSpeechSynthesizer()
    private let preferredVoiceIdentifier = "com.apple.voice.compact.en-US.Samantha"

    private init() {}

    func speak(_ message: String) {
        guard !message.isEmpty else { return }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Switch from mic capture mode to spoken playback so TTS is audible.
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Keep going even if session configuration fails.
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(identifier: preferredVoiceIdentifier) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

final class CueFeedbackManager {
    private let startSoundID: SystemSoundID = 1113
    private let stopSoundID: SystemSoundID = 1114

    func listeningStarted() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(startSoundID)
    }

    func listeningStopped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AudioServicesPlaySystemSound(stopSoundID)
    }
}

@MainActor
final class SpeechInputManager: NSObject, ObservableObject {
    private enum PermissionState {
        case unknown
        case granted
        case denied
    }

    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isPreparing = false
    @Published var permissionDenied = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let cueFeedback = CueFeedbackManager()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isStoppingManually = false
    private var permissionState: PermissionState = .unknown

    func startRecording() {
        errorMessage = nil
        isPreparing = true

        if permissionState == .granted {
            beginRecognition()
            return
        }

        requestPermissionsIfNeeded { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.errorMessage = "Microphone and Speech permissions are required."
                self.permissionDenied = true
                self.isPreparing = false
                return
            }
            self.permissionDenied = false
            self.warmUpAudioSession()
            self.beginRecognition()
        }
    }

    func preflightPermissions() {
        guard permissionState == .unknown else { return }

        requestPermissionsIfNeeded { [weak self] granted in
            guard let self else { return }
            if granted {
                self.warmUpAudioSession()
            }
        }
    }

    func stopRecording() {
        guard isRecording else {
            isPreparing = false
            return
        }
        isStoppingManually = true

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        isPreparing = false
        cueFeedback.listeningStopped()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not release audio session."
        }
    }

    private func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        if permissionState != .unknown {
            completion(permissionState == .granted)
            return
        }

        SFSpeechRecognizer.requestAuthorization { authStatus in
            let speechGranted = authStatus == .authorized
            AVAudioApplication.requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    let granted = speechGranted && micGranted
                    self.permissionState = granted ? .granted : .denied
                    self.permissionDenied = !granted
                    completion(granted)
                }
            }
        }
    }

    private func warmUpAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Best effort only; warm-up failures should not block recording.
        }
    }

    private func beginRecognition() {
        guard !isRecording else { return }
        isStoppingManually = false
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable."
            isPreparing = false
            return
        }

        do {
            try configureAudioSession()
            try startAudioEngine()
            isRecording = true
            isPreparing = false
            cueFeedback.listeningStarted()
        } catch {
            errorMessage = "Unable to start speech recognition."
            isPreparing = false
            cleanupAfterFailure()
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startAudioEngine() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            let byteSize = buffer.audioBufferList.pointee.mBuffers.mDataByteSize
            if byteSize > 0 {
                self?.recognitionRequest?.append(buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if let error {
                let nsError = error as NSError
                let isExpectedCancel = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                if self.isStoppingManually || isExpectedCancel {
                    self.isStoppingManually = false
                    return
                }
                self.errorMessage = "Speech recognition failed. Please try again."
                self.stopRecording()
            }
        }
    }

    private func cleanupAfterFailure() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        isPreparing = false
    }
}

private struct MockResponseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let response: AssistResponse
    let requestText: String
    @State private var didSpeakMessage = false
    @State private var selectedResourceID: String?

    private var mapRegion: MKCoordinateRegion {
        guard !response.resources.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9526, longitude: -75.1652),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        }

        let lats = response.resources.map(\.lat)
        let lngs = response.resources.map(\.lng)
        let minLat = lats.min() ?? 39.9526
        let maxLat = lats.max() ?? 39.9526
        let minLng = lngs.min() ?? -75.1652
        let maxLng = lngs.max() ?? -75.1652
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLng + maxLng) / 2.0
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.03, (maxLat - minLat) * 1.6),
            longitudeDelta: max(0.03, (maxLng - minLng) * 1.6)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let actionPhone = response.actionPhone,
                           let actionURL = callURL(from: actionPhone)
                        {
                            VStack(alignment: .leading, spacing: 10) {
                                Link(destination: actionURL) {
                                    Label(primaryActionLabel(for: response), systemImage: "phone.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, minHeight: 68)
                                        .background(primaryActionColor(for: response))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                }

                                if response.crisis == "child_safety",
                                   actionPhone != "911",
                                   let emergencyURL = callURL(from: "911")
                                {
                                    Link(destination: emergencyURL) {
                                        Label("Call 911", systemImage: "exclamationmark.triangle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, minHeight: 56)
                                            .background(Color.red)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                            }
                        }

                        Map(initialPosition: .region(mapRegion)) {
                            ForEach(response.resources) { resource in
                                Annotation(resource.name, coordinate: resource.coordinate) {
                                    Button {
                                        selectedResourceID = resource.id
                                    } label: {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(selectedResourceID == resource.id ? .blue : .red)
                                    }
                                }
                            }
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        ForEach(response.resources) { resource in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(resource.name)
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(Color(red: 0.04, green: 0.10, blue: 0.20))

                                if let hours = resource.hours {
                                    Text("Hours: \(hours)")
                                        .font(.footnote)
                                }
                                HStack(spacing: 16) {
                                    Button {
                                        openURL(mapsURL(for: resource))
                                    } label: {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 40, weight: .regular))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, minHeight: 120)
                                            .background(Color(red: 0.17, green: 0.78, blue: 0.39))
                                            .clipShape(RoundedRectangle(cornerRadius: 28))
                                    }

                                    if let phone = resource.phone {
                                        if let phoneURL = callURL(from: phone) {
                                            Link(destination: phoneURL) {
                                                Image(systemName: "phone.fill")
                                                    .font(.system(size: 40, weight: .regular))
                                                    .foregroundStyle(.white)
                                                    .frame(maxWidth: .infinity, minHeight: 120)
                                                    .background(Color(red: 0.96, green: 0.72, blue: 0.31))
                                                    .clipShape(RoundedRectangle(cornerRadius: 28))
                                            }
                                        } else {
                                            Text("Phone: \(phone)")
                                                .font(.footnote)
                                        }
                                    }
                                }
                                Text(resource.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(8)
                            .background(Color.clear)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedResourceID == resource.id ? Color.blue : Color.clear, lineWidth: 2)
                            }
                            .id(resource.id)
                        }
                    }
                    .padding(24)
                }
                .onChange(of: selectedResourceID) { _, newID in
                    guard let newID else { return }
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .top)
                    }
                }
                .navigationTitle(requestText.isEmpty ? "Request" : requestText)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .onAppear {
                    if !didSpeakMessage {
                        SpeechOutputManager.shared.speak(response.message)
                        didSpeakMessage = true
                    }
                }
                .onDisappear {
                    SpeechOutputManager.shared.stop()
                }
            }
        }
    }

    private func mapsURL(for resource: AssistResource) -> URL {
        // daddr opens Apple Maps with routing toward the destination.
        // Use address first so route matches displayed card content, then fallback to coordinates.
        let trimmedAddress = resource.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination: String
        if trimmedAddress.isEmpty {
            destination = "\(resource.lat),\(resource.lng)"
        } else {
            destination = trimmedAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(resource.lat),\(resource.lng)"
        }
        let urlString = "http://maps.apple.com/?daddr=\(destination)&dirflg=w"
        return URL(string: urlString) ?? URL(string: "http://maps.apple.com/")!
    }

    private func callURL(from phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func primaryActionLabel(for response: AssistResponse) -> String {
        guard let phone = response.actionPhone else { return "Call" }
        switch response.crisis {
        case "suicide":
            return "Call or Text \(phone)"
        case "emergency":
            return "Call \(phone) Now"
        case "child_safety":
            return "Call Childline"
        default:
            return "Call \(phone)"
        }
    }

    private func primaryActionColor(for response: AssistResponse) -> Color {
        switch response.crisis {
        case "suicide", "emergency", "child_safety":
            return .red
        default:
            return Color(red: 0.96, green: 0.72, blue: 0.31)
        }
    }
}

#Preview {
    ContentView()
}
