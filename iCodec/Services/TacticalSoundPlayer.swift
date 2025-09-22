import Foundation
import AudioToolbox

final class TacticalSoundPlayer {
    static let shared = TacticalSoundPlayer()

    private init() {}

    func playNavigation() {
        AudioServicesPlaySystemSound(1104) // Tock navigation tick
    }

    func playAction() {
        AudioServicesPlaySystemSound(1156) // HUD style confirm
    }
}
