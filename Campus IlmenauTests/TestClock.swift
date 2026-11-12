import Foundation

/// Uhr, die nur vorläuft, wenn der Test sie vorstellt. So laufen die echten Zeiten (0,4 s, 0,6 s, 0,2 s, 8 s)
/// ohne Warten und ohne Abhängigkeit von der Last des Rechners. Alle zeitabhängigen Tests geben sie dem Code, den sie
/// prüfen (`clock:`), statt echte Sekunden zu messen.
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let id = UUID()
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []

    var now: Instant { lock.withLock { current } }

    /// Wie viele Timer gerade auf diese Uhr warten.
    var wartende: Int { lock.withLock { sleepers.count } }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = LockedBox<UUID?>(nil)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if deadline <= current {
                    lock.unlock()
                    continuation.resume()
                } else {
                    let sleeper = Sleeper(deadline: deadline, continuation: continuation)
                    id.value = sleeper.id
                    sleepers.append(sleeper)
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            let sleeper = sleepers.first { $0.id == id.value }
            sleepers.removeAll { $0.id == id.value }
            lock.unlock()
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Wartet, bis ein Timer mit dieser Frist (Abstand zum Start der Uhr) auf die Uhr wartet. So ist sicher, dass der
    /// Code das Limit gesetzt hat, das der Test prüft, bevor die Zeit vorläuft. Es gibt keine Frist in echter Zeit:
    /// Fehlt der Timer, greift das Zeitlimit des Tests (`.timeLimit`).
    func warte(bisFrist frist: Duration) async {
        while !lock.withLock({ sleepers.contains { $0.deadline.offset == frist } }) {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    /// Wartet, bis irgendein Timer auf die Uhr wartet.
    func warteBisTimer() async {
        while wartende == 0 { try? await Task.sleep(for: .milliseconds(2)) }
    }

    /// Stellt die Zeit in 50-ms-Schritten vor, damit nacheinander gestartete Timer ihre Fristen
    /// von der jeweils richtigen Zeit aus rechnen.
    func advance(by duration: Duration) async {
        // Erst die gerade gestarteten Timer ihre Frist eintragen lassen, dann läuft die Zeit.
        for _ in 0..<20 { await Task.yield() }
        var remaining = duration
        while remaining > .zero {
            let step = min(remaining, .milliseconds(50))
            remaining -= step
            let due: [Sleeper] = lock.withLock {
                current = current.advanced(by: step)
                let due = sleepers.filter { $0.deadline <= current }
                sleepers.removeAll { sleeper in due.contains { $0.id == sleeper.id } }
                return due
            }
            due.forEach { $0.continuation.resume() }
            for _ in 0..<20 { await Task.yield() }
        }
    }
}

final class LockedBox<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// Wartet, bis die Bedingung gilt. Ohne Frist in echter Zeit: Asynchrone Arbeit (Netz-Stubs) kommt irgendwann an, und
/// die Wartezeit hängt nicht von der Last des Rechners ab. Hängt ein Test, beendet ihn `.timeLimit` der Suite.
@MainActor
func warteBis(_ bedingung: @MainActor () -> Bool) async {
    while !bedingung() { try? await Task.sleep(for: .milliseconds(2)) }
}
