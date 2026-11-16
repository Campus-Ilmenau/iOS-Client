import SwiftUI
import AVFoundation
import Vision
import VisionKit

// Scanner für die Benutzernummer auf der Rückseite der Thoska (Barcode), nach `BibLogin.dc.html` (Ansicht „scan“).
// Die Nummer wird nur im Speicher gehalten, genau wie eine getippte. Es werden keine Bilder gespeichert, nichts geloggt
// und nichts im Schlüsselbund abgelegt.

// MARK: - Prüfung des gelesenen Werts

/// Prüft, ob ein gelesener Barcode eine Benutzernummer sein kann. Alles andere wird still ignoriert.
enum BenutzernummerFormat {
    /// Erlaubte Länge. Das Login-Feld prüft sonst nichts, daher gilt diese Regel (mit dir abgestimmt).
    static let digitCount = 8...14

    /// Entfernt Leerzeichen und gibt den Wert zurück, wenn er 8 bis 14 Zeichen lang ist, mit einer Ziffer beginnt
    /// und nur aus ASCII-Ziffern und -Buchstaben besteht (am Ende steht oft ein X), sonst `nil`.
    /// Nur bei Codabar (`isCodabar`) werden vorher die Start-/Stopp-Zeichen A–D vorn und hinten entfernt;
    /// bei anderen Codes wären das echte Buchstaben der Nummer.
    static func normalize(_ raw: String, isCodabar: Bool = false) -> String? {
        var text = raw.filter { !$0.isWhitespace }
        if isCodabar {
            if let first = text.first, isCodabarMark(first) { text.removeFirst() }
            if let last = text.last, isCodabarMark(last) { text.removeLast() }
        }
        guard digitCount.contains(text.count),
              text.first?.isASCII == true, text.first?.isNumber == true,
              text.allSatisfy({ $0.isASCII && ($0.isNumber || $0.isLetter) }) else { return nil }
        return text
    }

    private static func isCodabarMark(_ character: Character) -> Bool {
        "ABCDabcd".contains(character)
    }
}

// MARK: - Zustand und Hilfen

/// Was der Scanner gerade zeigt.
enum BenutzernummerScannerState: Equatable {
    /// Berechtigung wird geprüft bzw. das System fragt gerade.
    case checking
    case scanning
    /// Nummer erkannt; nach kurzer Pause schließt der Scanner.
    case found(String)
    /// Kein Zugriff auf die Kamera (abgelehnt oder eingeschränkt).
    case denied
    /// Kamera gerade nicht verfügbar, z. B. von einer anderen App belegt.
    case unavailable

    var showsCamera: Bool {
        switch self {
        case .scanning, .found: true
        case .checking, .denied, .unavailable: false
        }
    }
}

/// Taschenlampe der Kamera.
enum ScannerTorch {
    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    static func set(_ isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Ohne Zugriff bleibt die Lampe, wie sie ist.
        }
    }
}

// MARK: - Scanner

/// Vollbild-Scanner. `onScanned` bekommt die geprüfte Nummer, `onCancel` schließt ohne Nummer.
/// „Nummer selbst eingeben“ schließt über `onEnterManually` (ohne Angabe wie `onCancel`), damit das Feld den Fokus bekommt.
struct BenutzernummerScannerView: View {
    let onScanned: (String) -> Void
    let onCancel: () -> Void
    var onEnterManually: (() -> Void)?

    @State private var state: BenutzernummerScannerState = .checking
    @State private var torchOn = false
    @State private var hasTorch = ScannerTorch.isAvailable
    @State private var finishTask: Task<Void, Never>?

    @Environment(\.openURL) private var openURL

    private var foundValue: String? {
        if case .found(let value) = state { return value }
        return nil
    }

    var body: some View {
        BenutzernummerScannerContent(
            state: state,
            hasTorch: hasTorch,
            torchOn: $torchOn,
            onCancel: close(then: onCancel),
            onEnterManually: close(then: onEnterManually ?? onCancel),
            onOpenSettings: {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            },
            camera: { regionOfInterest in
                ScannerCameraView(
                    regionOfInterest: regionOfInterest,
                    isActive: state == .scanning,
                    onBarcode: found
                )
            }
        )
        .task { await prepare() }
        .onChange(of: torchOn) { _, isOn in ScannerTorch.set(isOn) }
        .onDisappear {
            finishTask?.cancel()
            ScannerTorch.set(false)
        }
        .sensoryFeedback(.success, trigger: foundValue)
    }

    // MARK: Berechtigung

    private func prepare() async {
        guard DataScannerViewController.isSupported else {
            state = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = DataScannerViewController.isAvailable ? .scanning : .unavailable
        case .notDetermined:
            // Das System fragt jetzt nach der Kamera.
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                state = DataScannerViewController.isAvailable ? .scanning : .unavailable
            } else {
                state = .denied
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }

    // MARK: Treffer

    private func found(_ value: String) {
        guard state == .scanning else { return }
        state = .found(value)
        torchOn = false
        ScannerTorch.set(false)
        AccessibilityNotification.Announcement("\(value) erkannt").post()
        finishTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            ScannerTorch.set(false)
            onScanned(value)
        }
    }

    /// Schließt den Scanner und schaltet vorher immer die Taschenlampe aus.
    private func close(then action: @escaping () -> Void) -> () -> Void {
        {
            finishTask?.cancel()
            torchOn = false
            ScannerTorch.set(false)
            action()
        }
    }
}

// MARK: - Oberfläche

/// Oberfläche des Scanners ohne Kamera und Berechtigung, damit sich alle Zustände als Preview zeigen lassen.
/// Der Inhalt ist immer dunkel, unabhängig vom Erscheinungsbild des Geräts.
struct BenutzernummerScannerContent<Camera: View>: View {
    let state: BenutzernummerScannerState
    let hasTorch: Bool
    @Binding var torchOn: Bool
    let onCancel: () -> Void
    let onEnterManually: () -> Void
    let onOpenSettings: () -> Void
    /// Das Kamerabild. Bekommt den Rahmen, in dem erkannt werden soll (`regionOfInterest`).
    @ViewBuilder let camera: (CGRect) -> Camera

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rahmen für den Barcode, in Koordinaten des ganzen Bildschirms.
    private func scanFrame(in size: CGSize) -> CGRect {
        let width = max(0, size.width - 88)
        let height: CGFloat = 110
        return CGRect(x: 44, y: size.height * 0.30, width: width, height: height)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.brandNight), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let frame = scanFrame(in: proxy.size)
                ZStack(alignment: .topLeading) {
                    if state.showsCamera {
                        camera(frame)
                        scanFrameOverlay(frame)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                switch state {
                case .denied:
                    problemBlock(
                        title: "Kein Zugriff auf die Kamera",
                        message: "Erlaube den Zugriff in den Einstellungen oder gib die Nummer selbst ein."
                    )
                case .unavailable:
                    problemBlock(
                        title: "Kamera gerade nicht verfügbar",
                        message: "Eine andere App nutzt die Kamera vielleicht gerade. Versuch es gleich noch einmal oder gib die Nummer selbst ein."
                    )
                case .checking, .scanning, .found:
                    Spacer(minLength: 0)
                    bottomControls
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
    }

    // MARK: Leiste oben

    private var topBar: some View {
        ZStack {
            Text("Benutzernummer scannen")
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 96)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onCancel) {
                    Text("Abbrechen")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: Rahmen, Scanlinie und Treffer

    @ViewBuilder
    private func scanFrameOverlay(_ frame: CGRect) -> some View {
        ZStack {
            ScanFrameCorners()
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityHidden(true)

            if state == .scanning {
                ScanLine(reduceMotion: reduceMotion)
                    .frame(width: max(0, frame.width - 16), height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .accessibilityHidden(true)
            }

            if case .found(let value) = state {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                    Text("\(value) erkannt")
                        .font(.body.weight(.bold))
                }
                .foregroundStyle(Color(.onGreen))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Color(.green), in: Capsule())
                .fixedSize()
                .position(x: frame.midX, y: frame.minY - 34)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(value) erkannt")
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state)
    }

    // MARK: Unten

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Text("Halte die Rückseite deiner Thoska so, dass der Barcode im Rahmen liegt.")
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            HStack(spacing: 10) {
                if hasTorch {
                    Button {
                        torchOn.toggle()
                    } label: {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(torchOn ? "Licht aus" : "Licht an")
                }
                glassButton("Nummer selbst eingeben", action: onEnterManually)
            }

            Text("Beim ersten Scan fragt dein iPhone, ob die App die Kamera benutzen darf.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .opacity(0.7)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    private func glassButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
    }

    // MARK: Kein Zugriff

    private func problemBlock(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .light))
                .opacity(0.7)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .multilineTextAlignment(.center)
                .opacity(0.8)
                .padding(.bottom, 16)
            glassButton("Einstellungen öffnen", action: onOpenSettings)
            glassButton("Nummer selbst eingeben", action: onEnterManually)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .accessibilityElement(children: .contain)
    }
}

/// Vier Eckwinkel mit abgerundeter Ecke (Radius 10) und je 28 pt Schenkellänge.
private struct ScanFrameCorners: Shape {
    var length: CGFloat = 28
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = length
        let r = radius

        // oben links
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        // oben rechts
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        // unten rechts
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        // unten links
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return path
    }
}

/// Scanlinie in `accent` mit Glow. Läuft 1,6 s auf und ab; bei „Bewegung reduzieren“ steht sie still in der Mitte.
private struct ScanLine: View {
    let reduceMotion: Bool

    @State private var isDown = false

    var body: some View {
        GeometryReader { proxy in
            let travel = max(0, proxy.size.height - 20)
            Capsule()
                .fill(Color(.accent))
                .frame(height: 2)
                .shadow(color: Color(.accent), radius: 6)
                .shadow(color: Color(.accent).opacity(0.6), radius: 12)
                .frame(maxWidth: .infinity)
                .offset(y: reduceMotion ? proxy.size.height / 2 - 1 : (isDown ? 10 + travel : 10))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { isDown = true }
        }
    }
}

// MARK: - Kamera

/// Kamerabild mit Barcode-Erkennung über `AVCaptureMetadataOutput`. Erkennt nur Barcodes, die Thoska-Nummern sein können,
/// und nur im Rahmen (`regionOfInterest`, in Koordinaten dieser Ansicht).
/// Der `DataScannerViewController` hat die dichten Strichcodes der Thoska nicht zuverlässig gelesen.
struct ScannerCameraView: UIViewControllerRepresentable {
    let regionOfInterest: CGRect
    let isActive: Bool
    let onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerCaptureController {
        let controller = ScannerCaptureController()
        controller.onBarcode = onBarcode
        return controller
    }

    func updateUIViewController(_ controller: ScannerCaptureController, context: Context) {
        controller.onBarcode = onBarcode
        controller.regionOfInterest = regionOfInterest
        controller.setRunning(isActive)
    }

    static func dismantleUIViewController(_ controller: ScannerCaptureController, coordinator: ()) {
        controller.setRunning(false)
    }
}

final class ScannerCaptureController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcode: ((String) -> Void)?
    var regionOfInterest: CGRect = .zero {
        didSet { if oldValue != regionOfInterest { applyRegion() } }
    }

    private let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    /// `startRunning()` blockiert und gehört nicht auf den Hauptthread.
    private let sessionQueue = DispatchQueue(label: "de.kai-gothe.Campus-Ilmenau.scanner")
    private var wantsRunning = false

    /// Barcodes, die eine Benutzernummer enthalten können. Codabar kennt AVFoundation nicht.
    private static let symbologies: [AVMetadataObject.ObjectType] = [
        .code39, .code39Mod43, .code93, .code128, .interleaved2of5, .itf14, .ean13, .ean8
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
        configureSession()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        applyRegion()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else { return }
        session.sessionPreset = .high
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = Self.symbologies.filter { output.availableMetadataObjectTypes.contains($0) }
        previewLayer.session = session

        // Dichte Strichcodes aus kurzer Entfernung: dauerhaft nachfokussieren, Nahbereich bevorzugen.
        if (try? device.lockForConfiguration()) != nil {
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            device.unlockForConfiguration()
        }
    }

    /// Übersetzt den gezeichneten Rahmen in den Erkennungsbereich der Kamera.
    private func applyRegion() {
        guard regionOfInterest != .zero, previewLayer.bounds.size != .zero else { return }
        output.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: regionOfInterest)
    }

    func setRunning(_ run: Bool) {
        guard run != wantsRunning else { return }
        wantsRunning = run
        sessionQueue.async { [session] in
            if run {
                if !session.isRunning { session.startRunning() }
            } else if session.isRunning {
                session.stopRunning()
            }
        }
        // Erst bei laufender Kamera stimmt die Umrechnung des Rahmens sicher.
        if run {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.applyRegion() }
        }
    }

    #if DEBUG
    /// Letzte Konsolenzeile, damit dieselbe Zeile nicht mehrmals pro Sekunde erscheint.
    private var lastLog: String?
    #endif

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        MainActor.assumeIsolated {
            handle(metadataObjects)
        }
    }

    /// Nimmt den ersten Barcode, der eine Benutzernummer sein kann. Anderes wird still ignoriert.
    private func handle(_ objects: [AVMetadataObject]) {
        for object in objects {
            guard let code = object as? AVMetadataMachineReadableCodeObject, let payload = code.stringValue else { continue }
            let number = BenutzernummerFormat.normalize(payload)
            #if DEBUG
            // Zum Klären des Strichcode-Formats mit der UB: Format, Rohwert und Ergebnis der Normalisierung.
            let line = "[Scanner] Format: \(code.type.rawValue) | Rohwert: \"\(payload)\" | Benutzernummer: \(number ?? "nicht erkannt")"
            if line != lastLog {
                lastLog = line
                print(line)
            }
            #endif
            guard let number else { continue }
            onBarcode?(number)
            return
        }
    }
}

// MARK: - Previews

#if DEBUG
private struct ScannerPreview: View {
    let state: BenutzernummerScannerState
    var hasTorch = true
    @State private var torchOn = false

    var body: some View {
        BenutzernummerScannerContent(
            state: state,
            hasTorch: hasTorch,
            torchOn: $torchOn,
            onCancel: {},
            onEnterManually: {},
            onOpenSettings: {},
            camera: { _ in
                // Kein Kamerabild in der Preview: dunkle Fläche mit Barcode-Andeutung.
                LinearGradient(colors: [Color(.brandDusk).opacity(0.5), Color(.brandNight)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        )
    }
}

#Preview("Scanner – sucht") { ScannerPreview(state: .scanning) }
#Preview("Scanner – sucht, Licht an") { ScannerPreview(state: .scanning, hasTorch: true) }
#Preview("Scanner – Treffer") { ScannerPreview(state: .found("0001234567")) }
#Preview("Scanner – Zugriff verweigert") { ScannerPreview(state: .denied) }
#Preview("Scanner – Kamera nicht verfügbar") { ScannerPreview(state: .unavailable) }
#Preview("Scanner – ohne Taschenlampe, xxxLarge") {
    ScannerPreview(state: .scanning, hasTorch: false).dynamicTypeSize(.xxxLarge)
}
#Preview("Scanner – Zugriff verweigert, xxxLarge") {
    ScannerPreview(state: .denied).dynamicTypeSize(.xxxLarge)
}
#endif
