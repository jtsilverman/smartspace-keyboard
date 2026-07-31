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
    /// Fallback when smart double-space is off: stock double-space-period.
    private var stockSpaceBar = StockDoubleSpace()
    private var autocorrect = AutocorrectController(checker: SystemSpellChecker())
    private var cursorDrag = SpacebarCursorDrag()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var keyPops: [UIButton: UIView] = [:]
    private var emojiPanelActive = false
    private var emojiSearchActive = false
    private var emojiQuery = ""
    /// nil = recents tab.
    private var selectedEmojiCategory: EmojiCategory?
    private var emojiRecents = EmojiRecents(store: DefaultsRecentsStore())
    private let emojiPanel = UIView()
    private var personal = PersonalRanking()
    private var outcomeTracker = OutcomeTracker()
    private var outcomeLog = OutcomeLog(store: AppGroupOutcomeStore())
    /// Re-read on every appearance: toggling in the host app applies the
    /// next time the keyboard comes up (spec host-app-settings AC 4).
    private var settings = KeyboardSettings(store: AppGroupSettingsStore())
    private var lastPrediction: Prediction?
    private var lastContextWordCount = 0
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
        // The candidate order adapts to this user's kept marks (2.4);
        // counters rebuild from the persisted text-free log.
        outcomeLog.records.forEach { personal.record($0) }
        // Contacts + text replacements: words the user owns are never
        // corrected away. Arrives async; the empty-lexicon controller
        // covers the gap.
        requestSupplementaryLexicon { [weak self] lexicon in
            let words = Set(lexicon.entries.map(\.userInput))
            DispatchQueue.main.async {
                self?.autocorrect.updateLexicon(words)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = KeyboardSettings(store: AppGroupSettingsStore())
        log.notice("settings: dsp=\(self.settings.smartDoubleSpace, privacy: .public) ac=\(self.settings.autocorrect, privacy: .public) cands=\(String(self.settings.enabledCandidates.sorted()), privacy: .public)")
        applyKeyboardAppearance()
        if settings.autoCapitalization {
            shift.armAutoShift(for: textDocumentProxy.documentContextBeforeInput ?? "")
        }
        rebuildRows()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyKeyboardAppearance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Send/dismiss mid-cycle still counts: the kept mark is whatever
        // was on screen when the keyboard went away.
        endSmartSpaceCycle()
    }

    /// A non-space key ends any smart-space cycle: close the double-tap
    /// window and finalize the pending outcome record (WORKPLAN 3.7 --
    /// counts and marks only, never text).
    private func endSmartSpaceCycle() {
        spaceBar.nonSpaceKey()
        stockSpaceBar.nonSpaceKey()
        let today = Int(Date().timeIntervalSince1970 / 86400)
        guard let record = outcomeTracker.finish(epochDay: today) else { return }
        outcomeLog.append(record)
        personal.record(record)
        // .notice persists to the log store (.debug does not), marks only.
        log.notice("outcome: rule=\(record.rule.rawValue, privacy: .public) taps=\(record.cycleTaps, privacy: .public) kept=\(record.kept, privacy: .public)")
    }

    /// The keyboard renders in the appearance the host field asks for, not
    /// the system's (a dark host field in a light app gets dark keys).
    private func applyKeyboardAppearance() {
        switch textDocumentProxy.keyboardAppearance {
        case .dark: view.overrideUserInterfaceStyle = .dark
        case .light: view.overrideUserInterfaceStyle = .light
        default: view.overrideUserInterfaceStyle = .unspecified
        }
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

        emojiPanel.isHidden = true
        emojiPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emojiPanel)

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
            emojiPanel.leadingAnchor.constraint(equalTo: rows.leadingAnchor),
            emojiPanel.trailingAnchor.constraint(equalTo: rows.trailingAnchor),
            emojiPanel.topAnchor.constraint(equalTo: rows.topAnchor),
            emojiPanel.bottomAnchor.constraint(equalTo: rows.bottomAnchor),
            probeBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            probeBadge.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
        ])
        rebuildRows()
    }

    /// Renders the controller's bar state. Correction: original first (tap
    /// to undo), then alternatives (tap to swap). Completions: the word as
    /// typed in quotes (tap to keep + protect), then completions (tap to
    /// finish the word). This function never changes state -- only the
    /// three typing trigger points call typingUpdate.
    private func refreshSuggestionBar() {
        suggestionBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch autocorrect.barContent {
        case .empty:
            break
        case .correction(let slots):
            for (index, word) in slots.enumerated() {
                suggestionBar.addArrangedSubview(
                    barSlot(title: word, tag: index, identifier: "suggestion-\(index)"))
            }
        case .completions(let typed, let completions):
            suggestionBar.addArrangedSubview(barSlot(
                title: "\u{201C}\(typed)\u{201D}", tag: 0, identifier: "completion-typed"))
            for (index, word) in completions.enumerated() {
                suggestionBar.addArrangedSubview(barSlot(
                    title: word, tag: index + 1, identifier: "completion-\(index + 1)"))
            }
        }
    }

    private func barSlot(title: String, tag: Int, identifier: String) -> UIButton {
        let slot = keyButton(title: title)
        slot.tag = tag
        slot.accessibilityIdentifier = identifier
        slot.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
        return slot
    }

    /// Typing trigger: refreshes mid-word completions from the live context.
    private func refreshTypingCompletions() {
        guard settings.autocorrect else { return }
        autocorrect.typingUpdate(context: textDocumentProxy.documentContextBeforeInput ?? "")
        refreshSuggestionBar()
    }

    /// Updates key titles in place -- button identity survives, so a
    /// double-tap's second touch still lands on the same shift button.
    private func refreshShiftAppearance() {
        shiftButton?.configuration?.image = UIImage(systemName: shiftSymbolName())
        guard layer == .letters else { return }
        for (button, key) in characterButtons {
            button.configuration?.title = shift.isShifted ? key.uppercased() : key
        }
    }

    /// Rebuilds the visible plane from pure layout data + current state.
    private func rebuildRows() {
        guard let rows = rowsStack else { return }
        dismissAlternates()
        dismissAllKeyPops()  // buttons are torn down; orphan pops would leak
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
                    leading = keyButton(symbol: shiftSymbolName())
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

        let emojiKey = keyButton(title: "😀")
        emojiKey.accessibilityIdentifier = "emoji-key"
        emojiKey.addTarget(self, action: #selector(emojiKeyTapped), for: .touchUpInside)

        let globe: UIButton?
        if needsInputModeSwitchKey {
            let key = keyButton(symbol: "globe")
            key.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            globe = key
        } else {
            globe = nil
        }

        let space = keyButton(title: "space")
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        let drag = UILongPressGestureRecognizer(target: self, action: #selector(spaceDragged(_:)))
        drag.minimumPressDuration = 0.4
        space.addGestureRecognizer(drag)

        let returnTitle = ReturnKeyLabel.label(
            for: returnKeyTypeName(textDocumentProxy.returnKeyType ?? .default))
        let returnKey = keyButton(title: returnTitle)
        returnKey.accessibilityIdentifier = "return-key"
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)

        bottomRow.addArrangedSubview(layerKey)
        bottomRow.addArrangedSubview(emojiKey)
        if let globe { bottomRow.addArrangedSubview(globe) }
        bottomRow.addArrangedSubview(space)
        bottomRow.addArrangedSubview(returnKey)
        layerKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.12).isActive = true
        emojiKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.1).isActive = true
        globe?.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.1).isActive = true
        returnKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.2).isActive = true
        rows.addArrangedSubview(bottomRow)
    }

    private func characterButton(for key: String) -> UIButton {
        let title = (layer == .letters && shift.isShifted) ? key.uppercased() : key
        let button = keyButton(title: title)
        button.addTarget(self, action: #selector(characterTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(characterTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(characterTouchEnded(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        if KeyboardLayout.alternates[key] != nil {
            let press = UILongPressGestureRecognizer(target: self, action: #selector(keyHeld(_:)))
            press.minimumPressDuration = 0.4
            button.addGestureRecognizer(press)
        }
        characterButtons.append((button, key))
        return button
    }

    /// Function keys that stock iOS draws as SF Symbols (globe, shift).
    private func keyButton(symbol: String) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(keyTouchDown), for: .touchDown)
        return button
    }

    private func keyButton(title: String) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.addTarget(self, action: #selector(keyTouchDown), for: .touchDown)
        return button
    }

    /// UX.md: every key press gets a haptic tick. Extensions without Full
    /// Access may silently no-op; accepted (device verification owed).
    @objc private func keyTouchDown() {
        guard settings.haptics else { return }
        haptic.impactOccurred()
    }

    /// Stock iOS shift glyphs: outline, filled while armed, caps-lock fill.
    private func shiftSymbolName() -> String {
        switch shift.mode {
        case .off: return "shift"
        case .oneShot: return "shift.fill"
        case .capsLock: return "capslock.fill"
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
        endSmartSpaceCycle()
        if emojiSearchActive {
            // Search mode: letters feed the query, never the document.
            // Shift is deliberately not consumed (query is case-insensitive).
            emojiQuery += title.lowercased()
            refreshEmojiSearchStrip()
            return
        }
        insertSmart(title)
        if layer == .letters, shift.mode == .oneShot {
            shift.didTypeLetter()
            refreshShiftAppearance()
        }
        refreshTypingCompletions()
    }

    /// Routes a typed key through SmartSymbols: curly quotes by position,
    /// -- collapses to an em dash, everything else inserts as typed.
    private func insertSmart(_ title: String) {
        guard settings.smartSymbols, title.count == 1, let char = title.first else {
            textDocumentProxy.insertText(title)
            return
        }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        switch SmartSymbols.decision(forTyping: char, before: context) {
        case .insert(let text):
            textDocumentProxy.insertText(text)
        case .replacePrevious(let text):
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(text)
        case .replaceLast(let n, let text):
            for _ in 0..<n { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(text)
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
        endSmartSpaceCycle()
        if emojiSearchActive {
            // Edits the query only; the document (and the autocorrect
            // session acting on it) is untouched.
            if !emojiQuery.isEmpty { emojiQuery.removeLast() }
            refreshEmojiSearchStrip()
            return
        }
        autocorrect.backspace()
        textDocumentProxy.deleteBackward()
        refreshTypingCompletions()
        armAutoShiftIfSentenceStart()
    }

    @objc private func backspaceHeld(_ gesture: UILongPressGestureRecognizer) {
        guard !emojiSearchActive else { return }    // repeats edit the document
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
            refreshTypingCompletions()
            armAutoShiftIfSentenceStart()
        default:
            break
        }
    }

    @objc private func keyHeld(_ gesture: UILongPressGestureRecognizer) {
        guard !emojiSearchActive,   // alternates insert into the document
              gesture.state == .began,
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
            endSmartSpaceCycle()
            insertSmart(title)
            if layer == .letters { shift.didTypeLetter() }
            refreshTypingCompletions()
        }
        dismissAlternates()
        refreshShiftAppearance()
    }

    private func dismissAlternates() {
        alternatesView?.removeFromSuperview()
        alternatesView = nil
    }

    @objc private func spaceTapped() {
        if emojiSearchActive {
            emojiQuery += " "
            refreshEmojiSearchStrip()
            return
        }
        dismissAlternates()
        // Smart double-space off: stock double-space-period (spec
        // host-app-settings, locked decision 1). The word-char check looks
        // past the space the first tap inserted.
        // No endSmartSpaceCycle here: it would close the stock double-tap
        // window on every space, and the smart machine is idle when the
        // setting is off (settings only change across appearances, and
        // disappearance finalizes any cycle).
        guard settings.smartDoubleSpace else {
            var context = textDocumentProxy.documentContextBeforeInput ?? ""
            if context.hasSuffix(" ") { context.removeLast() }
            let afterWordChar = context.last.map { $0.isLetter || $0.isNumber } == true
            switch stockSpaceBar.spaceTapped(at: CACurrentMediaTime(), afterWordChar: afterWordChar) {
            case .insertSpace:
                applyAutocorrectOnCommit()
                textDocumentProxy.insertText(" ")
            case .insertPeriod:
                // The word was committed by the first space; swap that space
                // for ". " with no re-commit.
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                log.debug("stock double-space period")
            }
            armAutoShiftIfSentenceStart()
            return
        }
        let decision = spaceBar.spaceTapped(at: CACurrentMediaTime()) {
            // Context minus the space the first tap inserted: the engine sees
            // the sentence as typed.
            var context = textDocumentProxy.documentContextBeforeInput ?? ""
            if context.hasSuffix(" ") { context.removeLast() }
            let prediction = punctuation.prediction(before: context)
            lastPrediction = prediction
            lastContextWordCount = context.split(whereSeparator: \.isWhitespace).count
            // Candidate-set setting: drop disabled marks, keep engine order.
            return personal.reranked(prediction).filter { candidate in
                candidate.text.count == 1 && candidate.text.first.map {
                    settings.enabledCandidates.contains($0)
                } == true
            }
        }
        switch decision {
        case .insertSpace:
            applyAutocorrectOnCommit()
            textDocumentProxy.insertText(" ")
            armAutoShiftIfSentenceStart()
        case .insertMark(let mark):
            textDocumentProxy.deleteBackward()          // the first space
            textDocumentProxy.insertText(mark.text + " ")
            if let prediction = lastPrediction {
                outcomeTracker.smartInsert(rule: prediction.rule,
                                           guess: mark.text,
                                           wordCount: lastContextWordCount)
            }
            log.debug("smart insert: \(mark.text, privacy: .public)")
            if mark.endsSentence { armShiftForSmartMark() }
        case .replaceMark(let mark, let previous):
            // The cursor may have moved since the insert; only edit if the
            // text still ends with the mark we placed.
            let context = textDocumentProxy.documentContextBeforeInput ?? ""
            guard context.hasSuffix(previous.text + " ") else {
                spaceBar.nonSpaceKey()
                // The cycle state and the document diverged: no record --
                // a kept mark the text never held would corrupt the counters.
                outcomeTracker.abandon()
                textDocumentProxy.insertText(" ")
                armAutoShiftIfSentenceStart()
                return
            }
            for _ in 0..<(previous.text.count + 1) {    // mark + trailing space
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(mark.text + " ")
            outcomeTracker.cycled(to: mark.text)
            log.debug("cycle to: \(mark.text, privacy: .public)")
            if mark.endsSentence { armShiftForSmartMark() } else if shift.mode == .oneShot {
                // Cycled to a non-terminal mark (,): the arm from the
                // previous terminal guess no longer applies.
                shift.didTypeLetter()
                refreshShiftAppearance()
            }
        }
    }

    @objc private func returnTapped() {
        if emojiSearchActive {
            exitEmojiPanel()
            return
        }
        dismissAlternates()
        endSmartSpaceCycle()
        applyAutocorrectOnCommit()
        textDocumentProxy.insertText("\n")
        armAutoShiftIfSentenceStart()
    }

    // MARK: - Spacebar cursor drag (WORKPLAN 3.5)

    /// Long-press space + slide = move the cursor. Recognition cancels the
    /// button's touch, so a drag never inserts a space.
    @objc private func spaceDragged(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            dismissAlternates()
            endSmartSpaceCycle()
            // Pending bar edits target the pre-move tail; drop them.
            autocorrect.invalidateBar()
            refreshSuggestionBar()
            cursorDrag.began(at: gesture.location(in: view).x)
        case .changed:
            let delta = cursorDrag.moved(to: gesture.location(in: view).x)
            if delta != 0 {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: delta)
            }
        case .ended, .cancelled, .failed:
            armAutoShiftIfSentenceStart()
        default:
            break
        }
    }

    // MARK: - Key-pop (WORKPLAN 3.5)

    /// Magnified preview above a touched character key, stock-style.
    /// Keyed per button: two-finger typing keeps each finger's pop
    /// independent (releasing one never removes the other's).
    private func showKeyPop(above button: UIButton) {
        dismissKeyPop(for: button)
        guard let title = button.configuration?.title else { return }
        let pop = UILabel()
        pop.text = title
        pop.font = .systemFont(ofSize: 32)
        pop.textAlignment = .center
        pop.backgroundColor = .systemBackground
        pop.layer.cornerRadius = 8
        pop.clipsToBounds = true
        pop.layer.borderWidth = 1
        pop.layer.borderColor = UIColor.separator.cgColor
        pop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pop)
        let center = pop.centerXAnchor.constraint(equalTo: button.centerXAnchor)
        center.priority = .defaultHigh  // yields at screen edges
        NSLayoutConstraint.activate([
            center,
            pop.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 2),
            pop.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -2),
            pop.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -2),
            pop.widthAnchor.constraint(equalTo: button.widthAnchor, multiplier: 1.4),
            pop.heightAnchor.constraint(equalToConstant: 50),
        ])
        keyPops[button] = pop
    }

    private func dismissKeyPop(for button: UIButton) {
        keyPops.removeValue(forKey: button)?.removeFromSuperview()
    }

    private func dismissAllKeyPops() {
        keyPops.values.forEach { $0.removeFromSuperview() }
        keyPops = [:]
    }

    @objc private func characterTouchDown(_ sender: UIButton) {
        showKeyPop(above: sender)
    }

    @objc private func characterTouchEnded(_ sender: UIButton) {
        dismissKeyPop(for: sender)
    }

    // MARK: - Emoji panel (WORKPLAN 3.6)

    private static let emojiTabGlyphs: [(EmojiCategory, String)] = [
        (.smileys, "😀"), (.people, "👋"), (.animals, "🐻"), (.food, "🍔"),
        (.activity, "⚽"), (.travel, "🚗"), (.objects, "💡"), (.symbols, "❤️"),
    ]

    @objc private func emojiKeyTapped() {
        dismissAlternates()
        dismissAllKeyPops()
        endSmartSpaceCycle()
        emojiPanelActive = true
        emojiSearchActive = false
        // Recents when there are any, else the first category.
        selectedEmojiCategory = emojiRecents.all.isEmpty ? .smileys : nil
        rebuildForEmojiState()
    }

    @objc private func emojiAbcTapped() {
        exitEmojiPanel()
    }

    private func exitEmojiPanel() {
        emojiPanelActive = false
        emojiSearchActive = false
        emojiQuery = ""
        rebuildForEmojiState()
        armAutoShiftIfSentenceStart()
    }

    /// One switch point for panel/search/letters visibility.
    private func rebuildForEmojiState() {
        if emojiPanelActive && !emojiSearchActive {
            rowsStack?.isHidden = true
            emojiPanel.isHidden = false
            buildEmojiPanel()
            refreshSuggestionBar()      // a live correction bar stays valid
        } else {
            emojiPanel.isHidden = true
            rowsStack?.isHidden = false
            if emojiSearchActive {
                refreshEmojiSearchStrip()
            } else {
                refreshSuggestionBar()
            }
        }
    }

    private func buildEmojiPanel() {
        emojiPanel.subviews.forEach { $0.removeFromSuperview() }

        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        tabs.spacing = 2
        tabs.translatesAutoresizingMaskIntoConstraints = false

        let search = tabButton(title: "🔍", identifier: "emoji-search")
        search.addTarget(self, action: #selector(emojiSearchTapped), for: .touchUpInside)
        tabs.addArrangedSubview(search)

        let recents = tabButton(title: "🕐", identifier: "emoji-cat-recents")
        recents.addTarget(self, action: #selector(emojiTabTapped(_:)), for: .touchUpInside)
        recents.tag = -1
        tabs.addArrangedSubview(recents)

        for (index, (category, glyph)) in Self.emojiTabGlyphs.enumerated() {
            let tab = tabButton(title: glyph, identifier: "emoji-cat-\(category.rawValue)")
            tab.tag = index
            tab.addTarget(self, action: #selector(emojiTabTapped(_:)), for: .touchUpInside)
            tabs.addArrangedSubview(tab)
        }

        let grid = UIScrollView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        let gridContent = UIStackView()
        gridContent.axis = .vertical
        gridContent.spacing = 2
        gridContent.translatesAutoresizingMaskIntoConstraints = false
        grid.addSubview(gridContent)

        let emoji: [String]
        if let category = selectedEmojiCategory {
            emoji = EmojiCatalog.entries(in: category).map(\.emoji)
        } else {
            emoji = emojiRecents.all
        }
        for chunk in stride(from: 0, to: emoji.count, by: 8) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            for item in emoji[chunk..<min(chunk + 8, emoji.count)] {
                row.addArrangedSubview(emojiCell(item))
            }
            // Pad the last row so cells keep uniform width.
            while row.arrangedSubviews.count < 8 {
                row.addArrangedSubview(UIView())
            }
            gridContent.addArrangedSubview(row)
        }

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 4
        bottom.translatesAutoresizingMaskIntoConstraints = false
        let abc = keyButton(title: "ABC")
        abc.accessibilityIdentifier = "emoji-abc"
        abc.addTarget(self, action: #selector(emojiAbcTapped), for: .touchUpInside)
        let space = keyButton(title: "space")
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        let returnKey = keyButton(title: ReturnKeyLabel.label(
            for: returnKeyTypeName(textDocumentProxy.returnKeyType ?? .default)))
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        bottom.addArrangedSubview(abc)
        bottom.addArrangedSubview(space)
        bottom.addArrangedSubview(returnKey)
        abc.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.15).isActive = true
        returnKey.widthAnchor.constraint(equalTo: bottom.widthAnchor, multiplier: 0.22).isActive = true

        emojiPanel.addSubview(tabs)
        emojiPanel.addSubview(grid)
        emojiPanel.addSubview(bottom)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: emojiPanel.topAnchor),
            tabs.leadingAnchor.constraint(equalTo: emojiPanel.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: emojiPanel.trailingAnchor),
            tabs.heightAnchor.constraint(equalToConstant: 36),
            grid.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 4),
            grid.leadingAnchor.constraint(equalTo: emojiPanel.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: emojiPanel.trailingAnchor),
            bottom.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 4),
            bottom.leadingAnchor.constraint(equalTo: emojiPanel.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: emojiPanel.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: emojiPanel.bottomAnchor),
            bottom.heightAnchor.constraint(equalToConstant: 44),
            gridContent.topAnchor.constraint(equalTo: grid.contentLayoutGuide.topAnchor),
            gridContent.bottomAnchor.constraint(equalTo: grid.contentLayoutGuide.bottomAnchor),
            gridContent.leadingAnchor.constraint(equalTo: grid.contentLayoutGuide.leadingAnchor),
            gridContent.trailingAnchor.constraint(equalTo: grid.contentLayoutGuide.trailingAnchor),
            gridContent.widthAnchor.constraint(equalTo: grid.frameLayoutGuide.widthAnchor),
        ])
    }

    private func tabButton(title: String, identifier: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.accessibilityIdentifier = identifier
        return button
    }

    private func emojiCell(_ emoji: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = emoji
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 26)
        button.accessibilityIdentifier = "emoji-item-\(emoji)"
        button.addTarget(self, action: #selector(emojiItemTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func emojiTabTapped(_ sender: UIButton) {
        selectedEmojiCategory = sender.tag >= 0 ? Self.emojiTabGlyphs[sender.tag].0 : nil
        buildEmojiPanel()
    }

    @objc private func emojiItemTapped(_ sender: UIButton) {
        guard let emoji = sender.configuration?.title else { return }
        endSmartSpaceCycle()
        textDocumentProxy.insertText(emoji)
        emojiRecents.record(emoji)
        if emojiSearchActive {
            exitEmojiPanel()    // a search insert is a completed errand
        }
    }

    @objc private func emojiSearchTapped() {
        emojiSearchActive = true
        emojiQuery = ""
        // The query strip takes over the correction bar's surface.
        autocorrect.invalidateBar()
        rebuildForEmojiState()
    }

    @objc private func emojiSearchCancelTapped() {
        exitEmojiPanel()
    }

    /// Query strip in the suggestion-bar area: query label, up to 5 results,
    /// cancel. Letter taps feed the query while this is up.
    private func refreshEmojiSearchStrip() {
        suggestionBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = "🔍 " + emojiQuery
        label.font = .systemFont(ofSize: 16)
        label.accessibilityIdentifier = "emoji-search-query"
        suggestionBar.addArrangedSubview(label)
        for emoji in EmojiSearch.results(for: emojiQuery).prefix(5) {
            let cell = emojiCell(emoji)
            suggestionBar.addArrangedSubview(cell)
        }
        let cancel = keyButton(title: "✕")
        cancel.accessibilityIdentifier = "emoji-search-cancel"
        cancel.addTarget(self, action: #selector(emojiSearchCancelTapped), for: .touchUpInside)
        suggestionBar.addArrangedSubview(cancel)
    }

    // MARK: - Autocorrect (WORKPLAN 3.4)

    /// Decides the correction for the word the space/return just committed
    /// and rewrites it in the document. Called BEFORE the separator is
    /// inserted so the word is still the exact document tail.
    private func applyAutocorrectOnCommit() {
        guard settings.autocorrect else { return }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let commit = autocorrect.wordCommitted(context: context)
        defer { refreshSuggestionBar() }
        guard case .replace(let original, let corrected, _) = commit else { return }
        // Trailing punctuation ("teh)") detaches the word from the tail;
        // skip the edit rather than delete the wrong characters, and drop
        // the bar so it never advertises a correction that was not made.
        guard context.hasSuffix(original) else {
            autocorrect.backspace()
            return
        }
        for _ in 0..<original.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(corrected)
        log.debug("autocorrect applied (\(original.count) -> \(corrected.count) chars)")
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        dismissAlternates()
        endSmartSpaceCycle()
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        defer { refreshSuggestionBar() }
        switch autocorrect.barContent {
        case .empty:
            break
        case .correction:
            // The correction must still be the document tail ("word" + the
            // separator that committed it). If the user typed on or moved
            // the cursor, drop the bar instead of editing the wrong text.
            guard let current = autocorrect.currentCorrected,
                  let separator = [" ", "\n"].first(where: { context.hasSuffix(current + $0) })
            else {
                autocorrect.invalidateBar()
                return
            }
            switch autocorrect.barTapped(slot: sender.tag) {
            case .undo(let original, let corrected):
                replaceTail(corrected, separator: separator, with: original)
                log.debug("autocorrect undone")
            case .swap(let from, let to):
                replaceTail(from, separator: separator, with: to)
                log.debug("autocorrect swapped")
            default:
                break
            }
        case .completions(let typed, _):
            // Same guard class: the partial must still be the tail.
            guard context.hasSuffix(typed) else {
                autocorrect.invalidateBar()
                return
            }
            switch autocorrect.barTapped(slot: sender.tag) {
            case .acceptTyped:
                textDocumentProxy.insertText(" ")
                log.debug("completion: typed word accepted")
            case .complete(let from, let to):
                for _ in 0..<from.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(to + " ")
                log.debug("completion applied")
            default:
                break
            }
            armAutoShiftIfSentenceStart()
        }
    }

    private func replaceTail(_ current: String, separator: String, with replacement: String) {
        for _ in 0..<(current.count + separator.count) {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(replacement + separator)
    }

    /// Auto-shift re-arms whenever the context now reads as a sentence start.
    /// A smart-space terminal mark is a sentence end by construction --
    /// context re-derivation would wrongly veto it after an abbreviation
    /// ("Ave." + smart period).
    private func armShiftForSmartMark() {
        guard settings.autoCapitalization else { return }
        let wasShifted = shift.isShifted
        shift.armOneShot()
        if shift.isShifted != wasShifted { refreshShiftAppearance() }
    }

    private func armAutoShiftIfSentenceStart() {
        guard settings.autoCapitalization else { return }
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
