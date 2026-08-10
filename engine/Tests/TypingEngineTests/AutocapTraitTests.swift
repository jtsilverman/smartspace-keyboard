import Testing
import TypingEngine

// Stock honors the host field's autocapitalization trait per field
// (research wf_1ac9e72d-a76, axis 1, Apple UITextAutocapitalizationType,
// high confidence): .none never shifts (email/URL fields), .sentences
// follows the sentence rule, .words shifts at every word start,
// .allCharacters shifts everywhere. Caps lock never downgrades.

@Test func noneNeverArmsEvenAtASentenceStart() {
    var shift = ShiftState()
    shift.armAutoShift(for: "", trait: .none)
    #expect(shift.mode == .off)
    shift.armAutoShift(for: "Done. ", trait: .none)
    #expect(shift.mode == .off)
}

@Test func sentencesFollowsTheCapitalizationRule() {
    var shift = ShiftState()
    shift.armAutoShift(for: "Done. ", trait: .sentences)
    #expect(shift.mode == .oneShot)
    shift = ShiftState()
    shift.armAutoShift(for: "mid word", trait: .sentences)
    #expect(shift.mode == .off)
}

@Test func wordsArmAtEveryWordStart() {
    for context in ["", "hello ", "hi\n", "a\t"] {
        var shift = ShiftState()
        shift.armAutoShift(for: context, trait: .words)
        #expect(shift.mode == .oneShot, "context \(String(reflecting: context))")
    }
    var shift = ShiftState()
    shift.armAutoShift(for: "hello", trait: .words)
    #expect(shift.mode == .off)
}

@Test func allCharactersArmEverywhere() {
    var shift = ShiftState()
    shift.armAutoShift(for: "mid word", trait: .allCharacters)
    #expect(shift.mode == .oneShot)
}

@Test func capsLockNeverDowngradesUnderAnyTrait() {
    for trait in [AutocapTrait.none, .sentences, .words, .allCharacters] {
        var shift = ShiftState()
        shift.tapShift(at: 1.0)
        shift.tapShift(at: 1.1)
        #expect(shift.mode == .capsLock)
        shift.armAutoShift(for: "Done. ", trait: trait)
        #expect(shift.mode == .capsLock)
    }
}

@Test func defaultTraitStaysSentences() {
    var shift = ShiftState()
    shift.armAutoShift(for: "Done. ")
    #expect(shift.mode == .oneShot)
}
