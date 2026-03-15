import SwiftUI
import Speech
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var speechInput = SpeechInputManager()
    @State private var isShowingPayload = false
    @State private var payloadJSONString = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("PhillyHelpJawn MVP")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Press and hold to speak. Release to preview the API payload generated from recognized speech.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            GroupBox {
                Text(speechInput.transcript.isEmpty ? "Transcript appears here." : speechInput.transcript)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            if let errorMessage = speechInput.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                // Press-and-hold behavior is handled by the gesture.
            } label: {
                Label(speechInput.isRecording ? "Listening..." : "Push To Talk", systemImage: speechInput.isRecording ? "waveform" : "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speechInput.isRecording {
                            speechInput.startRecording()
                        }
                    }
                    .onEnded { _ in
                        speechInput.stopRecording()
                        payloadJSONString = payloadJSON(from: speechInput.transcript)
                        isShowingPayload = true
                    }
            )

            Spacer()
        }
        .padding(.top, 40)
        .sheet(isPresented: $isShowingPayload) {
            PayloadPreviewView(payloadJSONString: payloadJSONString)
        }
    }

    private func payloadJSON(from queryText: String) -> String {
        let payload: [String: Any] = [
            "requestId": UUID().uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "inputModality": "voice_ptt",
            "queryText": queryText,
            "language": "en-US",
            "persona": "primary_low_literacy",
            "client": [
                "platform": "ios",
                "appVersion": "0.1.0",
                "buildNumber": "1"
            ]
        ]

        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            return "{ \"error\": \"Unable to build payload\" }"
        }

        return jsonString
    }
}

@MainActor
final class SpeechInputManager: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isStoppingManually = false

    func startRecording() {
        errorMessage = nil

        requestPermissionsIfNeeded { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.errorMessage = "Microphone and Speech permissions are required."
                return
            }
            self.beginRecognition()
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isStoppingManually = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not release audio session."
        }
    }

    private func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            let speechGranted = authStatus == .authorized
            AVAudioApplication.requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    completion(speechGranted && micGranted)
                }
            }
        }
    }

    private func beginRecognition() {
        guard !isRecording else { return }
        isStoppingManually = false
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable."
            return
        }

        do {
            try configureAudioSession()
            try startAudioEngine()
            isRecording = true
        } catch {
            errorMessage = "Unable to start speech recognition."
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
            self?.recognitionRequest?.append(buffer)
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
    }
}

private struct PayloadPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let payloadJSONString: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Payload Preview")
                    .font(.headline)

                ScrollView {
                    Text(payloadJSONString)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Payload")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
