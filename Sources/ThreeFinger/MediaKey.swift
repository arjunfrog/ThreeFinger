import AppKit

/// Sends the same events as the media keys on an Apple keyboard, so the system volume
/// overlay appears and whichever app is playing responds.
enum MediaKey: Int32 {
    // Key types from IOKit's ev_keymap.h.
    case volumeUp = 0     // NX_KEYTYPE_SOUND_UP
    case volumeDown = 1   // NX_KEYTYPE_SOUND_DOWN
    case playPause = 16   // NX_KEYTYPE_PLAY
    case next = 19        // NX_KEYTYPE_FAST, what F9 sends
    case previous = 20    // NX_KEYTYPE_REWIND, what F7 sends

    /// With `quarterStep`, volume keys move a quarter of a normal step, as Option-Shift does on a keyboard.
    func press(quarterStep: Bool = false) {
        let modifiers: NSEvent.ModifierFlags = quarterStep ? [.option, .shift] : []
        post(keyDown: true, modifiers: modifiers)
        post(keyDown: false, modifiers: modifiers)
    }

    private func post(keyDown: Bool, modifiers: NSEvent.ModifierFlags) {
        let state = keyDown ? 0xA : 0xB
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)).union(modifiers),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            data1: Int(rawValue) << 16 | state << 8,
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
