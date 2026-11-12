import Foundation
import Testing
@testable import Campus_Ilmenau

/// Zeitverhalten der Ladeanzeige mit den echten Zeiten aus der Übergabe und den künstlichen
/// Antwortzeiten 0,2 s, 2 s und 10 s.
@MainActor
struct LoadingGateTests {
    private func makeGate() -> (LoadingGate, ManualClock) {
        let clock = ManualClock()
        let gate = LoadingGate(isLoading: true, clock: clock)
        gate.setLoading(true)
        return (gate, clock)
    }

    @Test func startsActiveButInvisible() {
        let (gate, _) = makeGate()
        #expect(gate.isActive)
        #expect(!gate.isVisible)
        #expect(!gate.isSlow)
    }

    /// 0,2 s: schneller als die Verzögerung von 0,4 s, die Ziege erscheint nie.
    @Test func fastResponseNeverShowsTheGoat() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .milliseconds(200))
        #expect(!gate.isVisible)
        gate.setLoading(false)
        #expect(!gate.isActive)     // Inhalt sofort, ohne Zwischenstand
        await clock.advance(by: .seconds(2))
        #expect(!gate.isVisible)
        #expect(!gate.isActive)
    }

    @Test func goatFadesInAfterFourHundredMilliseconds() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .milliseconds(350))
        #expect(!gate.isVisible)
        await clock.advance(by: .milliseconds(100))
        #expect(gate.isVisible)
        #expect(!gate.isSlow)
    }

    /// 2 s: Ziege seit 0,4 s sichtbar, Mindestdauer längst um, nach der Antwort 0,2 s Ausblenden.
    @Test func mediumResponseShowsGoatThenFadesOut() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .seconds(2))
        #expect(gate.isVisible)
        #expect(!gate.isSlow)
        gate.setLoading(false)
        #expect(!gate.isVisible)    // Ausblenden beginnt
        #expect(gate.isActive)      // Deckkraft läuft noch 0,2 s
        await clock.advance(by: .milliseconds(150))
        #expect(gate.isActive)
        await clock.advance(by: .milliseconds(100))
        #expect(!gate.isActive)
    }

    /// Antwort bei 0,5 s: sichtbar seit 0,4 s, bleibt bis 1,0 s, blendet bis 1,2 s aus.
    @Test func goatStaysAtLeastSixHundredMillisecondsAfterShowing() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .milliseconds(500))
        #expect(gate.isVisible)
        gate.setLoading(false)
        #expect(gate.isVisible)
        #expect(gate.isActive)
        await clock.advance(by: .milliseconds(450))     // 0,95 s
        #expect(gate.isVisible)
        await clock.advance(by: .milliseconds(100))     // 1,05 s: Ausblenden
        #expect(!gate.isVisible)
        #expect(gate.isActive)
        await clock.advance(by: .milliseconds(200))     // 1,25 s
        #expect(!gate.isActive)
    }

    /// 10 s: ab 8 s kommt der Hinweis „Das dauert länger als sonst.“.
    @Test func slowHintAppearsAfterEightSeconds() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .milliseconds(7_950))
        #expect(gate.isVisible)
        #expect(!gate.isSlow)
        await clock.advance(by: .milliseconds(100))
        #expect(gate.isSlow)
        await clock.advance(by: .milliseconds(1_950))   // 10 s
        #expect(gate.isSlow)
        gate.setLoading(false)
        await clock.advance(by: .milliseconds(300))
        #expect(!gate.isActive)
        #expect(!gate.isSlow)
    }

    @Test func retryAfterFinishRestartsTheTimeline() async {
        let (gate, clock) = makeGate()
        await clock.advance(by: .seconds(1))
        gate.setLoading(false)
        await clock.advance(by: .seconds(1))
        #expect(!gate.isActive)
        gate.setLoading(true)
        #expect(gate.isActive)
        #expect(!gate.isVisible)    // wieder erst nach der Verzögerung
        await clock.advance(by: .milliseconds(450))
        #expect(gate.isVisible)
    }

    @Test func gateWithoutLoadingStaysInactive() async {
        let clock = ManualClock()
        let gate = LoadingGate(isLoading: false, clock: clock)
        gate.setLoading(false)
        await clock.advance(by: .seconds(1))
        #expect(!gate.isActive)
        #expect(!gate.isVisible)
    }
}
