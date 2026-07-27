import UIKit
import os
import PunctuationEngine
import TypingEngine

/// Thin shell over TypingEngine: renders KeyboardLayout planes, forwards taps
/// to textDocumentProxy. All decision logic stays in the tested packages.
final class KeyboardViewController: UIInputViewController {
    private let log = Logger(subsystem: "com.jtsilverman.smartspace.keyboard", category: "keyboard")

    private var shift = ShiftState()
    private var layer = KeyboardLayer.letters
    private let punctuation = PunctuationEngine()
    private var spaceBar = SmartSpaceBar()
    private var autocorrect = AutocorrectController(checker: SystemSpellChecker())
    private let suggestionBar = UIStackView()
    private var rowsStack: UIStackView?
    private let probeBadge = UILabel()
    private var backspaceTimer: Timer?
    private var backspaceRepeats = 0
    private var alternatesView: UIView?
    private var characterButtons: [(button: UIButton, key: String)] = []
    private var shiftButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        runAppGroupProbe()
        // Contacts + text replacements: words the user owns are never
        // corrected away. Arrives async; the empty-lexicon controller
        // covers the gap.
        requestSupplementaryLexicon { [weak self] lexicon in
            let words = Set(lexicon.entries.map(\.userInput))
            DispatchQueue.main.async {
                self?.autocorrect = AutocorrectController(
                    checker: SystemSpellChecker(), lexicon: words)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shift.armAutoShift(for: textDocumentProxy.documentContextBeforeInput ?? "")
        rebuildRows()
    }

    // MARK: - Layout

    private func buildKeyboard() {
        suggestionBar.axis = .horizontal
        suggestionBar.distribution = .fillEqually
        suggestionBar.spacing = 4
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestionBar)

        let rows = UIStackView()
        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rows)
        rowsStack = rows

        probeBadge.font = .systemFont(ofSize: 10, weight: .semibold)
        probeBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(probeBadge)

        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            suggestionBar.heightAnchor.constraint(equalToConstant: 40),
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            rows.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor, constant: 4),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            rows.heightAnchor.constraint(equalToConstant: 216),
            probeBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            probeBadge.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
        ])
        rebuildRows()
    }

    /// Rebuilds the suggestion-bar slots from controller state: original
    /// word first (tap to undo), then alternatives (tap to swap).
    private func refreshSuggestionBar() {
        suggestionBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, word) in autocorrect.barSlots.enumerated() {
            let slot = keyButton(title: word)
            slot.tag = index
            slot.accessibilityIdentifier = "suggestion-\(index)"
            slot.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            suggestionBar.addArrangedSubview(slot)
        }
    }

    /// Updates key titles in place -- button identity survives, so a
    /// double-tap's second touch still lands on the same shift button.
    private func refreshShiftAppearance() {
        shiftButton?.configuration?.title = shiftTitle()
        guard layer == .letters else { return }
        for (button, key) in characterButtons {
            button.configuration?.title = shift.isShifted ? key.uppercased() : key
        }
    }

    /// Rebuilds the visible plane from pure layout data + current state.
    private func rebuildRows() {
        guard let rows = rowsStack else { return }
        dismissAlternates()
        characterButtons = []
        shiftButton = nil
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let plane: [[String]]
        switch layer {
        case .letters: plane = KeyboardLayout.letterRows
        case .numbers: plane = KeyboardLayout.numberRows
        case .symbols: plane = KeyboardLayout.symbolRows
        }

        for (index, keys) in plane.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 4
            for key in keys {
                row.addArrangedSubview(characterButton(for: key))
            }
            if index == plane.count - 1 {
                let leading: UIButton
                if layer == .letters {
                    leading = keyButton(title: shiftTitle())
                    leading.accessibilityIdentifier = "shift"
                    leading.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
                    shiftButton = leading
                } else {
                    leading = keyButton(title: layer == .numbers ? "#+=" : "123")
                    leading.addTarget(self, action: #selector(subLayerTapped), for: .touchUpInside)
                }
                row.insertArrangedSubview(leading, at: 0)

                let backspace = keyButton(title: "⌫")
                let press = UILongPressGestureRecognizer(target: self, action: #selector(backspaceHeld(_:)))
                press.minimumPressDuration = 0.4
                backspace.addGestureRecognizer(press)
                backspace.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
                row.addArrangedSubview(backspace)
            }
            rows.addArrangedSubview(row)
        }

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 4

        let layerKey = keyButton(title: layer == .letters ? "123" : "ABC")
        layerKey.addTarget(self, action: #selector(layerTapped), for: .touchUpInside)

        let globe = keyButton(title: "🌐")
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let space = keyButton(title: "space")
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let returnTitle = ReturnKeyLabel.label(
            for: returnKeyTypeName(textDocumentProxy.returnKeyType ?? .default))
        let returnKey = keyButton(title: returnTitle)
        returnKey.accessibilityIdentifier = "return-key"
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)

        bottomRow.addArrangedSubview(layerKey)
        bottomRow.addArrangedSubview(globe)
        bottomRow.addArrangedSubview(space)
        bottomRow.addArrangedSubview(returnKey)
        layerKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.12).isActive = true
        globe.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.12).isActive = true
        returnKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.22).isActive = true
        rows.addArrangedSubview(bottomRow)
    }

    private func characterButton(for key: String) -> UIButton {
        let title = (layer == .letters && shift.isShifted) ? key.uppercased() : key
        let button = keyButton(title: title)
        button.addTarget(self, action: #selector(characterTapped(_:)), for: .touchUpInside)
        if KeyboardLayout.alternates[key] != nil {
            let press = UILongPressGestureRecognizer(target: self, action: #selector(keyHeld(_:)))
            press.minimumPressDuration = 0.4
            button.addGestureRecognizer(press)
        }
        characterButtons.append((button, key))
        return button
    }

    private func keyButton(title: String) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        return button
    }

    private func shiftTitle() -> String {
        switch shift.mode {
        case .off: return "⇧"
        case .oneShot: return "⬆"
        case .capsLock: return "⇪"
        }
    }

    private func returnKeyTypeName(_ type: UIReturnKeyType) -> String {
        switch type {
        case .search: return "search"
        case .go: return "go"
        case .send: return "send"
        case .done: return "done"
        case .next: return "next"
        case .join: return "join"
        case .google: return "google"
        case .yahoo: return "yahoo"
        case .route: return "route"
        case .continue: return "continue"
        case .emergencyCall: return "emergencycall"
        default: return "default"
        }
    }

    // MARK: - Keys

    @objc private func characterTapped(_ sender: UIButton) {
        guard let title = sender.configuration?.title else { return }
        dismissAlternates()
        spaceBar.nonSpaceKey()
        textDocumentProxy.insertText(title)
        if layer == .letters, shift.mode == .oneShot {
            shift.didTypeLetter()
            refreshShiftAppearance()
        }
    }

    @objc private func shiftTapped() {
        dismissAlternates()
        shift.tapShift(at: CACurrentMediaTime())
        log.debug("shift mode: \(String(describing: self.shift.mode))")
        refreshShiftAppearance()
    }

    @objc private func layerTapped() {
        layer.tapPrimary()
        rebuildRows()
    }

    @objc private func subLayerTapped() {
        layer.tapSecondary()
        rebuildRows()
    }

    @objc private func backspaceTapped() {
        dismissAlternates()
        spaceBar.nonSpaceKey()
        autocorrect.backspace()
        refreshSuggestionBar()
        textDocumentProxy.deleteBackward()
        armAutoShiftIfSentenceStart()
    }

    @objc private func backspaceHeld(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            backspaceRepeats = 0
            backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                backspaceRepeats += 1
                textDocumentProxy.deleteBackward()
                // accelerate after ~1.5s of holding
                if backspaceRepeats > 15 { textDocumentProxy.deleteBackward() }
            }
        case .ended, .cancelled, .failed:
            backspaceTimer?.invalidate()
            backspaceTimer = nil
            autocorrect.backspace()
            refreshSuggestionBar()
            armAutoShiftIfSentenceStart()
        default:
            break
        }
    }

    @objc private func keyHeld(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let button = gesture.view as? UIButton,
              let title = button.configuration?.title,
              let options = KeyboardLayout.alternates[title.lowercased()] else { return }
        showAlternates(options, above: button, shifted: layer == .letters && shift.isShifted)
    }

    private func showAlternates(_ options: [String], above button: UIButton, shifted: Bool) {
        dismissAlternates()
        let bar = UIStackView()
        bar.axis = .horizontal
        bar.spacing = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = .systemBackground
        bar.layer.cornerRadius = 8
        bar.layer.borderWidth = 1
        bar.layer.borderColor = UIColor.separator.cgColor
        for option in options {
            let alt = keyButton(title: shifted ? option.uppercased() : option)
            alt.addTarget(self, action: #selector(alternateTapped(_:)), for: .touchUpInside)
            bar.addArrangedSubview(alt)
        }
        view.addSubview(bar)
        let center = bar.centerXAnchor.constraint(equalTo: button.centerXAnchor)
        center.priority = .defaultHigh  // yields at screen edges
        NSLayoutConstraint.activate([
            center,
            bar.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 4),
            bar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -4),
            bar.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -4),
            bar.heightAnchor.constraint(equalToConstant: 44),
        ])
        alternatesView = bar
    }

    @objc private func alternateTapped(_ sender: UIButton) {
        if let title = sender.configuration?.title {
            spaceBar.nonSpaceKey()
            textDocumentProxy.insertText(title)
            if layer == .letters { shift.didTypeLetter() }
        }
        dismissAlternates()
        refreshShiftAppearance()
    }

    private func dismissAlternates() {
        alternatesView?.removeFromSuperview()
        alternatesView = nil
    }

    @objc private func spaceTapped() {
        dismissAlternates()
        let decision = spaceBar.spaceTapped(at: CACurrentMediaTime()) {
            // Context minus the space the first tap inserted: the engine sees
            // the sentence as typed.
            var context = textDocumentProxy.documentContextBeforeInput ?? ""
            if context.hasSuffix(" ") { context.removeLast() }
            return punctuation.candidates(before: context)
        }
        switch decision {
        case .insertSpace:
            applyAutocorrectOnCommit()
            textDocumentProxy.insertText(" ")
            armAutoShiftIfSentenceStart()
        case .insertMark(let mark):
            textDocumentProxy.deleteBackward()          // the first space
            textDocumentProxy.insertText(mark.text + " ")
            log.debug("smart insert: \(mark.text, privacy: .public)")
            if mark.endsSentence { armAutoShiftIfSentenceStart() }
        case .replaceMark(let mark, let previous):
            // The cursor may have moved since the insert; only edit if the
            // text still ends with the mark we placed.
            let context = textDocumentProxy.documentContextBeforeInput ?? ""
            guard context.hasSuffix(previous.text + " ") else {
                spaceBar.nonSpaceKey()
                textDocumentProxy.insertText(" ")
                armAutoShiftIfSentenceStart()
                return
            }
            for _ in 0..<(previous.text.count + 1) {    // mark + trailing space
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(mark.text + " ")
            log.debug("cycle to: \(mark.text, privacy: .public)")
            if mark.endsSentence { armAutoShiftIfSentenceStart() }
        }
    }

    @objc private func returnTapped() {
        dismissAlternates()
        spaceBar.nonSpaceKey()
        applyAutocorrectOnCommit()
        textDocumentProxy.insertText("\n")
        armAutoShiftIfSentenceStart()
    }

    // MARK: - Autocorrect (WORKPLAN 3.4)

    /// Decides the correction for the word the space/return just committed
    /// and rewrites it in the document. Called BEFORE the separator is
    /// inserted so the word is still the exact document tail.
    private func applyAutocorrectOnCommit() {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let commit = autocorrect.wordCommitted(context: context)
        defer { refreshSuggestionBar() }
        guard case .replace(let original, let corrected, _) = commit else { return }
        // Trailing punctuation ("teh)") detaches the word from the tail;
        // skip the edit rather than delete the wrong characters. Bar taps
        // are suffix-guarded the same way, so a shown-but-unapplied bar
        // cannot corrupt text.
        guard context.hasSuffix(original) else { return }
        for _ in 0..<original.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(corrected)
        log.debug("autocorrect applied (\(original.count) -> \(corrected.count) chars)")
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        dismissAlternates()
        spaceBar.nonSpaceKey()
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        // The correction must still be the document tail ("word" + the
        // separator that committed it). If the user typed on or moved the
        // cursor, drop the bar instead of editing the wrong text.
        guard let current = autocorrect.currentCorrected,
              let separator = [" ", "\n"].first(where: { context.hasSuffix(current + $0) })
        else {
            autocorrect.backspace()
            refreshSuggestionBar()
            return
        }
        switch autocorrect.barTapped(slot: sender.tag) {
        case .none:
            break
        case .undo(let original, let corrected):
            replaceTail(corrected, separator: separator, with: original)
            log.debug("autocorrect undone")
        case .swap(let from, let to):
            replaceTail(from, separator: separator, with: to)
            log.debug("autocorrect swapped")
        }
        refreshSuggestionBar()
    }

    private func replaceTail(_ current: String, separator: String, with replacement: String) {
        for _ in 0..<(current.count + separator.count) {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(replacement + separator)
    }

    /// Auto-shift re-arms whenever the context now reads as a sentence start.
    private func armAutoShiftIfSentenceStart() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let wasShifted = shift.isShifted
        shift.armAutoShift(for: before)
        if shift.isShifted != wasShifted { refreshShiftAppearance() }
    }

    // MARK: - App-group probe (WORKPLAN 3.1)

    private func runAppGroupProbe() {
        let value = UserDefaults(suiteName: appGroupID)?.string(forKey: probeKey)
        let ok = value == probeValue
        probeBadge.text = ok ? "AG:OK" : "AG:BLOCKED"
        probeBadge.textColor = ok ? .systemGreen : .systemRed
        log.debug("app-group probe: \(ok ? "OK" : "BLOCKED", privacy: .public)")
    }
}
