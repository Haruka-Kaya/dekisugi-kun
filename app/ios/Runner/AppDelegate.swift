import Flutter
import UIKit
import AVFAudio
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate
{
  private let narrationChannelName = "jp.dekisugi.dekisugi/local_narration"
  private let speechChannelName = "jp.dekisugi.dekisugi/on_device_speech_recognition"
  private let synthesizer = AVSpeechSynthesizer()
  private var pendingNarration: (utterance: AVSpeechUtterance, result: FlutterResult)?
  private var pendingBundledNarration: (player: AVAudioPlayer, result: FlutterResult)?
  private let recognitionAudioEngine = AVAudioEngine()
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var pendingRecognition: FlutterResult?
  private var recognitionCandidates: [String] = []
  private var recognitionTapInstalled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    synthesizer.delegate = self
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LocalNarration"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: narrationChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      switch call.method {
      case "playBundledHumanRecording":
        guard
          UIApplication.shared.applicationState == .active,
          let args = call.arguments as? [String: Any],
          let assetPath = args["assetPath"] as? String,
          self.isAllowedBundledNarrationPath(assetPath)
        else {
          result(false)
          return
        }
        self.playBundledHumanRecording(
          assetPath: assetPath,
          registrar: registrar,
          result: result
        )
      case "speak":
        guard
          UIApplication.shared.applicationState == .active,
          let args = call.arguments as? [String: Any],
          let text = args["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          text.count <= 800
        else {
          result(false)
          return
        }
        let language = args["language"] as? String ?? "ja-JP"
        guard let voice = AVSpeechSynthesisVoice(language: language) else {
          result(false)
          return
        }
        self.stopPending(completed: false)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if #available(iOS 14.0, *) {
          utterance.prefersAssistiveTechnologySettings = true
        }
        self.pendingNarration = (utterance, result)
        self.synthesizer.speak(utterance)
      case "stop":
        self.stopPending(completed: false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let speechChannel = FlutterMethodChannel(
      name: speechChannelName,
      binaryMessenger: registrar.messenger()
    )
    speechChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(["status": "failed"])
        return
      }
      switch call.method {
      case "recognize":
        guard
          self.pendingRecognition == nil,
          let args = call.arguments as? [String: Any],
          let language = args["language"] as? String,
          !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          language.count <= 35
        else {
          result(["status": "failed"])
          return
        }
        self.beginOnDeviceRecognition(language: language, result: result)
      case "stop":
        self.stopRecognitionInput()
        result(nil)
      case "cancel":
        self.finishRecognition(status: "cancelled")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginOnDeviceRecognition(language: String, result: @escaping FlutterResult) {
    pendingRecognition = result
    let continueAfterSpeechPermission: (SFSpeechRecognizerAuthorizationStatus) -> Void = {
      [weak self] status in
      DispatchQueue.main.async {
        guard let self, self.pendingRecognition != nil else { return }
        guard status == .authorized else {
          self.finishRecognition(status: "permissionDenied")
          return
        }
        self.requestMicrophoneAndStart(language: language)
      }
    }
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      requestMicrophoneAndStart(language: language)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization(continueAfterSpeechPermission)
    case .denied, .restricted:
      finishRecognition(status: "permissionDenied")
    @unknown default:
      finishRecognition(status: "failed")
    }
  }

  private func requestMicrophoneAndStart(language: String) {
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .granted:
      startOnDeviceRecognition(language: language)
    case .undetermined:
      session.requestRecordPermission { [weak self] granted in
        DispatchQueue.main.async {
          guard let self, self.pendingRecognition != nil else { return }
          if granted {
            self.startOnDeviceRecognition(language: language)
          } else {
            self.finishRecognition(status: "permissionDenied")
          }
        }
      }
    case .denied:
      finishRecognition(status: "permissionDenied")
    @unknown default:
      finishRecognition(status: "failed")
    }
  }

  private func startOnDeviceRecognition(language: String) {
    guard pendingRecognition != nil else { return }
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    guard
      let recognizer,
      recognizer.isAvailable,
      recognizer.supportsOnDeviceRecognition
    else {
      finishRecognition(status: "unavailable")
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    recognitionCandidates = []
    speechRecognizer = recognizer
    recognitionRequest = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let input = recognitionAudioEngine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        finishRecognition(status: "unavailable")
        return
      }
      input.installTap(onBus: 0, bufferSize: 1024, format: format) {
        [weak self] buffer, _ in
        // bufferはrequestへ渡したら保持しない。ファイルやFlutterへは出さない。
        self?.recognitionRequest?.append(buffer)
      }
      recognitionTapInstalled = true
      recognitionAudioEngine.prepare()
      try recognitionAudioEngine.start()
    } catch {
      finishRecognition(status: "failed")
      return
    }

    recognitionTask = recognizer.recognitionTask(with: request) {
      [weak self] result, error in
      DispatchQueue.main.async {
        guard let self, self.pendingRecognition != nil else { return }
        if let result {
          self.recognitionCandidates = result.transcriptions
            .map { $0.formattedString.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
          if result.isFinal {
            if self.recognitionCandidates.isEmpty {
              self.finishRecognition(status: "noSpeech")
            } else {
              self.finishRecognition(
                status: "recognized",
                candidates: Array(self.recognitionCandidates.prefix(10))
              )
            }
            return
          }
        }
        if error != nil {
          if self.recognitionCandidates.isEmpty {
            self.finishRecognition(status: "noSpeech")
          } else {
            self.finishRecognition(
              status: "recognized",
              candidates: Array(self.recognitionCandidates.prefix(10))
            )
          }
        }
      }
    }
  }

  private func stopRecognitionInput() {
    if recognitionAudioEngine.isRunning {
      recognitionAudioEngine.stop()
    }
    if recognitionTapInstalled {
      recognitionAudioEngine.inputNode.removeTap(onBus: 0)
      recognitionTapInstalled = false
    }
    recognitionRequest?.endAudio()
  }

  private func finishRecognition(status: String, candidates: [String] = []) {
    guard let result = pendingRecognition else { return }
    pendingRecognition = nil
    stopRecognitionInput()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    speechRecognizer = nil
    recognitionCandidates.removeAll(keepingCapacity: false)
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
    var payload: [String: Any] = ["status": status]
    if status == "recognized" {
      payload["candidates"] = candidates
    }
    result(payload)
  }

  private func isAllowedBundledNarrationPath(_ path: String) -> Bool {
    let prefix = "assets/audio/listening/"
    guard path.hasPrefix(prefix) else { return false }
    let filename = String(path.dropFirst(prefix.count))
    guard !filename.isEmpty, !filename.contains("/") else { return false }
    let suffix: String
    if filename.hasSuffix(".m4a") {
      suffix = ".m4a"
    } else if filename.hasSuffix(".wav") {
      suffix = ".wav"
    } else {
      return false
    }
    let basename = String(filename.dropLast(suffix.count))
    guard !basename.isEmpty else { return false }
    let allowed = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    )
    return basename.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private func playBundledHumanRecording(
    assetPath: String,
    registrar: FlutterPluginRegistrar,
    result: @escaping FlutterResult
  ) {
    stopPending(completed: false)
    let lookupKey = registrar.lookupKey(forAsset: assetPath)
    guard let filePath = Bundle.main.path(forResource: lookupKey, ofType: nil) else {
      result(false)
      return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio)
      try session.setActive(true)
      let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
      player.delegate = self
      guard player.prepareToPlay() else {
        player.delegate = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        result(false)
        return
      }
      pendingBundledNarration = (player, result)
      guard player.play() else {
        finishBundledNarration(player: player, completed: false)
        return
      }
    } catch {
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
      result(false)
    }
  }

  private func stopPending(completed: Bool) {
    if let pending = pendingBundledNarration {
      pendingBundledNarration = nil
      pending.player.stop()
      pending.player.delegate = nil
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
      pending.result(completed)
    }
    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }
    guard let pending = pendingNarration else { return }
    pendingNarration = nil
    pending.result(completed)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    finishBundledNarration(player: player, completed: flag)
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    finishBundledNarration(player: player, completed: false)
  }

  private func finishBundledNarration(player: AVAudioPlayer, completed: Bool) {
    guard
      let pending = pendingBundledNarration,
      pending.player === player
    else { return }
    pendingBundledNarration = nil
    player.stop()
    player.delegate = nil
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
    pending.result(completed)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    finish(utterance: utterance, completed: true)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    finish(utterance: utterance, completed: false)
  }

  private func finish(utterance: AVSpeechUtterance, completed: Bool) {
    guard let pending = pendingNarration, pending.utterance === utterance else { return }
    pendingNarration = nil
    pending.result(completed)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    stopPending(completed: false)
    finishRecognition(status: "cancelled")
    super.applicationDidEnterBackground(application)
  }
}
