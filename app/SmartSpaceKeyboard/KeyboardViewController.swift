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
    /// Stock-parity touch layer over the character keys (rolled multitouch,
    /// gutter hit zones); function keys stay plain buttons beneath it.
    private let touchSurface = KeyTouchSurface()
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
    private var rowsStack: UIView?
    private var backspaceTimer: Timer?
    private var backspaceRepeater = BackspaceRepeater()
    private var trailingAutoSpace = TrailingAutoSpace()
    private var alternatesView: UIView?
    private var characterButtons: [(button: UIButton, key: String)] = []
    private var shiftButton: UIButton?
    /// Every key button of the current plane by cell id ("__" = function).
    private var planeButtons: [String: UIButton] = [:]
    /// The laid-out hit cells, source of both key frames and touch zones.
    private var currentCells: [String: CGRect] = [:]

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

        let rows = PassthroughView()
        rows.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rows)
        rowsStack = rows

        // Below the rows (above would cull the buttons from the AX tree):
        // the surface is still the single touch resolver, because the rows
        // container claims nothing. Its zone map routes every touch to the
        // nearest key -- character keys it tracks itself, function zones it
        // hands to their button -- so no gutter anywhere is dead.
        touchSurface.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(touchSurface, belowSubview: rows)
        touchSurface.zoneProvider = { [weak self] in self?.buildZones() ?? [] }
        touchSurface.functionButtonProvider = { [weak self] id in self?.planeButtons[id] }
        // The bigram prior only applies on the letters plane: number and
        // symbol ids are non-letters and fall back to geometry anyway.
        touchSurface.contextProvider = { [weak self] in
            self?.textDocumentProxy.documentContextBeforeInput ?? ""
        }
        touchSurface.onTouchDown = { [weak self] key in
            guard let self else { return }
            self.keyTouchDown()
            if let button = self.characterButton(named: key) { self.showKeyPop(above: button) }
        }
        touchSurface.onTouchMoved = { [weak self] from, to in
            guard let self else { return }
            // Only this finger's pop moves; other fingers keep theirs.
            if let old = self.characterButton(named: from) { self.dismissKeyPop(for: old) }
            if let button = self.characterButton(named: to) { self.showKeyPop(above: button) }
        }
        touchSurface.onTouchExit = { [weak self] key in
            guard let self else { return }
            if let button = self.characterButton(named: key) { self.dismissKeyPop(for: button) }
        }
        touchSurface.onCommit = { [weak self] key in
            guard let self else { return }
            if let button = self.characterButton(named: key) { self.dismissKeyPop(for: button) }
            self.commitCharacter(key)
        }
        touchSurface.onCancel = { [weak self] in self?.dismissAllKeyPops() }
        touchSurface.onHold = { [weak self] key in
            guard let self, !self.emojiSearchActive,
                  let options = KeyboardLayout.alternates[key],
                  let button = self.characterButton(named: key) else { return false }
            self.dismissKeyPop(for: button)
            self.showAlternates(options, above: button,
                                shifted: self.layer == .letters && self.shift.isShifted)
            return true
        }
        touchSurface.onAlternateMoved = { [weak self] point in
            self?.highlightAlternate(atSurfacePoint: point)
        }
        touchSurface.onAlternateEnded = { [weak self] base, point in
            self?.commitAlternate(base: base, atSurfacePoint: point)
        }

        emojiPanel.isHidden = true
        emojiPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emojiPanel)

        NSLayoutConstraint.activate([
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: 44),
            // Full-width key area, flush to the view bottom: the cell grid
            // carries its own side inset, and stock leaves no extra pad.
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rows.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            // Measured: our input view's bottom sits 7pt above where stock
            // lands its key area, so the grid overhangs by that much to
            // line the rows up with stock against the system's globe/mic bar.
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 7),
            rows.heightAnchor.constraint(equalToConstant: StockLayoutMetrics.keyAreaHeight),
            emojiPanel.leadingAnchor.constraint(equalTo: rows.leadingAnchor),
            emojiPanel.trailingAnchor.constraint(equalTo: rows.trailingAnchor),
            emojiPanel.topAnchor.constraint(equalTo: rows.topAnchor),
            emojiPanel.bottomAnchor.constraint(equalTo: rows.bottomAnchor),
            touchSurface.leadingAnchor.constraint(equalTo: rows.leadingAnchor),
            touchSurface.trailingAnchor.constraint(equalTo: rows.trailingAnchor),
            touchSurface.topAnchor.constraint(equalTo: rows.topAnchor),
            touchSurface.bottomAnchor.constraint(equalTo: rows.bottomAnchor),
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
        case .completions(let typed, let completions, let quoted):
            // Stock quotes the literal only when a commit would correct it.
            suggestionBar.addArrangedSubview(barSlot(
                title: quoted ? "\u{201C}\(typed)\u{201D}" : typed,
                tag: 0, identifier: "completion-typed"))
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
    /// Deferred off the tap's touch-event cycle (stock-parity AC 5): the
    /// context read + spell-checker call + bar rebuild run after the runloop
    /// drains the touch, so fast typing never waits on them. Coalesced --
    /// only the newest pending refresh runs.
    private var pendingCompletionRefresh = 0
    private func refreshTypingCompletions() {
        guard settings.autocorrect else { return }
        pendingCompletionRefresh += 1
        let ticket = pendingCompletionRefresh
        DispatchQueue.main.async { [weak self] in
            guard let self, ticket == self.pendingCompletionRefresh else { return }
            self.autocorrect.typingUpdate(context: self.textDocumentProxy.documentContextBeforeInput ?? "")
            self.refreshSuggestionBar()
        }
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
    /// Buttons are created here and framed in layoutPlane() from the
    /// measured stock cell geometry (stock-parity AC 1).
    private func rebuildRows() {
        guard let rows = rowsStack else { return }
        dismissAlternates()
        dismissAllKeyPops()  // buttons are torn down; orphan pops would leak
        characterButtons = []
        shiftButton = nil
        planeButtons = [:]
        rows.subviews.forEach { $0.removeFromSuperview() }

        for keys in currentPlane() {
            for key in keys {
                let button = characterButton(for: key)
                planeButtons[key] = button
                rows.addSubview(button)
            }
        }

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
        planeButtons["__shift"] = leading

        let backspace = keyButton(title: "⌫")
        let press = UILongPressGestureRecognizer(target: self, action: #selector(backspaceHeld(_:)))
        press.minimumPressDuration = 0.4
        backspace.addGestureRecognizer(press)
        backspace.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        planeButtons["__delete"] = backspace

        let layerKey = keyButton(title: layer == .letters ? "123" : "ABC")
        layerKey.addTarget(self, action: #selector(layerTapped), for: .touchUpInside)
        planeButtons["__layer"] = layerKey

        // Stock draws the emoji key as a smiley glyph, not an emoji.
        let emojiKey = keyButton(symbol: "face.smiling")
        emojiKey.accessibilityIdentifier = "emoji-key"
        emojiKey.addTarget(self, action: #selector(emojiKeyTapped), for: .touchUpInside)
        planeButtons["__emoji"] = emojiKey

        if needsInputModeSwitchKey {
            let globe = keyButton(symbol: "globe")
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            planeButtons["__globe"] = globe
        }

        // Stock's space bar carries no label; the identifier keeps it
        // findable for accessibility and the UI suite.
        let space = keyButton(title: "")
        space.accessibilityIdentifier = "space"
        space.accessibilityLabel = "space"
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        let drag = UILongPressGestureRecognizer(target: self, action: #selector(spaceDragged(_:)))
        drag.minimumPressDuration = 0.4
        space.addGestureRecognizer(drag)
        planeButtons["__space"] = space

        // Stock shows the ⏎ glyph for a plain return and a word for the
        // action variants (Search, Go, Send).
        let returnTitle = ReturnKeyLabel.label(
            for: returnKeyTypeName(textDocumentProxy.returnKeyType ?? .default))
        let returnKey = returnTitle == "return"
            ? keyButton(symbol: "return")
            : keyButton(title: returnTitle)
        returnKey.accessibilityIdentifier = "return-key"
        returnKey.accessibilityLabel = returnTitle
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        planeButtons["__return"] = returnKey

        for (id, button) in planeButtons where id.hasPrefix("__") {
            rows.addSubview(button)
        }
        layoutPlane()
    }

    private func currentPlane() -> [[String]] {
        switch layer {
        case .letters: return KeyboardLayout.letterRows
        case .numbers: return KeyboardLayout.numberRows
        case .symbols: return KeyboardLayout.symbolRows
        }
    }

    /// Stock hit cells from the measured metrics; visible key = cell minus
    /// the stock visual insets. When the system wants a globe key it takes
    /// the emoji cell and the emoji key takes the leading slice of space.
    private func layoutPlane() {
        guard let rows = rowsStack, rows.bounds.width > 0 else { return }
        var cellRects: [String: CGRect] = [:]
        for c in StockLayoutMetrics.cells(width: rows.bounds.width, plane: currentPlane()) {
            cellRects[c.id] = CGRect(x: c.frame.x, y: c.frame.y,
                                     width: c.frame.width, height: c.frame.height)
        }
        if planeButtons["__globe"] != nil, let emoji = cellRects["__emoji"],
           var space = cellRects["__space"] {
            cellRects["__globe"] = emoji
            cellRects["__emoji"] = CGRect(x: space.minX, y: space.minY,
                                          width: emoji.width, height: emoji.height)
            space = CGRect(x: space.minX + emoji.width, y: space.minY,
                           width: space.width - emoji.width, height: space.height)
            cellRects["__space"] = space
        }
        currentCells = cellRects
        for (id, button) in planeButtons {
            guard let cell = cellRects[id] else { continue }
            // Visible cap inside the touch cell, measured off stock.
            let cap = StockLayoutMetrics.capFrame(in: Rect(
                x: cell.origin.x, y: cell.origin.y,
                width: cell.width, height: cell.height))
            button.frame = CGRect(x: cap.x, y: cap.y, width: cap.width, height: cap.height)
            // Function keys accept the gutter touches the surface routes to
            // them: hit area = full cell plus the zone-map tolerance, or
            // UIControl sees the touch as "outside" and drops the tap.
            if id.hasPrefix(KeyTouchSurface.passthroughPrefix), let key = button as? KeyButton {
                let tol = KeyZoneMap.tolerance
                key.hitOutset = UIEdgeInsets(
                    top: -(StockLayoutMetrics.capInsetTop + tol),
                    left: -(StockLayoutMetrics.capInsetSide + tol),
                    bottom: -(StockLayoutMetrics.capInsetBottom + tol),
                    right: -(StockLayoutMetrics.capInsetSide + tol))
            }
            button.layer.shadowPath = UIBezierPath(
                roundedRect: button.bounds,
                cornerRadius: StockLayoutMetrics.capCornerRadius).cgPath
        }
        touchSurface.invalidateZones()
    }

    /// Character keys are passive visuals: KeyTouchSurface owns their
    /// touches (rolled multitouch, gutters, hold-for-alternates).
    private func characterButton(for key: String) -> UIButton {
        let title = (layer == .letters && shift.isShifted) ? key.uppercased() : key
        let button = keyButton(title: title)
        button.isUserInteractionEnabled = false
        characterButtons.append((button, key))
        return button
    }

    private func characterButton(named key: String) -> UIButton? {
        characterButtons.first(where: { $0.key == key })?.button
    }

    /// Re-frame the plane whenever the container size settles.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPlane()
    }

    /// Touch zones are the same stock hit cells the buttons are framed
    /// from: character keys by name, "__" cells pass through to their
    /// interactive buttons.
    private func buildZones() -> [KeyZone] {
        currentCells.map { id, r in
            KeyZone(id: id, frame: Rect(x: r.origin.x, y: r.origin.y,
                                        width: r.width, height: r.height))
        }
    }

    /// Function keys that stock iOS draws as SF Symbols (globe, shift).
    /// Stock cap fill: white in light mode, mid-grey in dark. Measured off
    /// the stock keyboard (screenshot scan 2026-07-31) -- our old
    /// `.gray()` configuration read as grey-on-grey and made the keys look
    /// smaller than stock even at matching size.
    private static let capColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.42, alpha: 1)
            : .white
    }

    /// Shared cap chrome: fill, stock corner radius, and the 1pt bottom
    /// shadow stock draws under every key.
    private func styleAsKeyCap(_ button: UIButton) {
        // The radius must live on the configuration's background: a
        // configuration's default .dynamic corner style overrides
        // layer.cornerRadius and rounded our caps into pills.
        button.configuration?.cornerStyle = .fixed
        button.configuration?.background.cornerRadius = StockLayoutMetrics.capCornerRadius
        button.configuration?.background.backgroundColor = Self.capColor
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.28).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 0
        button.layer.shadowOpacity = 1
        button.addTarget(self, action: #selector(keyTouchDown), for: .touchDown)
    }

    private func keyButton(symbol: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        config.baseForegroundColor = .label
        config.contentInsets = .zero
        let button = KeyButton(configuration: config)
        styleAsKeyCap(button)
        return button
    }

    private func keyButton(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = .zero
        let button = KeyButton(configuration: config)
        // Stock letter caps are ~22pt regular; word keys (123, space,
        // return) sit smaller.
        let size: CGFloat = title.count == 1 ? 22 : 16
        button.titleLabel?.font = .systemFont(ofSize: size, weight: .regular)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        styleAsKeyCap(button)
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

    private func commitCharacter(_ key: String) {
        let title = (layer == .letters && shift.isShifted) ? key.uppercased() : key
        dismissAlternates()
        endSmartSpaceCycle()
        if emojiSearchActive {
            // Search mode: letters feed the query, never the document.
            // Shift is deliberately not consumed (query is case-insensitive).
            emojiQuery += title.lowercased()
            refreshEmojiSearchStrip()
            return
        }
        // Stock: an auto-inserted space yields to the sentence mark typed
        // after it, and sentence punctuation ends the word and commits any
        // pending correction before the mark lands (matrix rows "trailing
        // space absorption", "commit delimiters"). insertSmart reads the
        // document after these rewrites.
        if title.count == 1, let char = title.first {
            let context = textDocumentProxy.documentContextBeforeInput ?? ""
            for _ in 0..<trailingAutoSpace.deletions(forTyping: char, context: context) {
                textDocumentProxy.deleteBackward()
            }
            if AutocorrectController.isCommitDelimiter(char) {
                applyAutocorrectOnCommit()
            }
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
        trailingAutoSpace.disarm()
        textDocumentProxy.deleteBackward()
        refreshTypingCompletions()
        armAutoShiftIfSentenceStart()
    }

    @objc private func backspaceHeld(_ gesture: UILongPressGestureRecognizer) {
        guard !emojiSearchActive else { return }    // repeats edit the document
        switch gesture.state {
        case .began:
            backspaceRepeater.reset()
            trailingAutoSpace.disarm()
            scheduleBackspaceTimer(every: 0.1)
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

    /// Word-phase deletes pace slower than the character repeat, like stock.
    private static let wordDeleteInterval: TimeInterval = 0.45

    private func scheduleBackspaceTimer(every interval: TimeInterval) {
        backspaceTimer?.invalidate()
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let context = textDocumentProxy.documentContextBeforeInput ?? ""
            switch backspaceRepeater.tick(before: context) {
            case .characters(let n):
                for _ in 0..<n { textDocumentProxy.deleteBackward() }
            case .word(let n):
                for _ in 0..<n { textDocumentProxy.deleteBackward() }
                if interval != Self.wordDeleteInterval {
                    scheduleBackspaceTimer(every: Self.wordDeleteInterval)
                }
            }
        }
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
        // Slide-select (stock): the ongoing touch stays with the surface,
        // moves highlight an option, release commits it. The buttons are
        // passive visuals.
        for option in options {
            let alt = keyButton(title: shifted ? option.uppercased() : option)
            alt.isUserInteractionEnabled = false
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

    /// The alternate button under the finger's x, or nil for "base key".
    private func alternateButton(atSurfacePoint point: CGPoint) -> UIButton? {
        guard let bar = alternatesView as? UIStackView else { return nil }
        let inBar = bar.convert(view.convert(point, from: touchSurface), from: view)
        return bar.arrangedSubviews.compactMap { $0 as? UIButton }.first {
            // Stock is forgiving on y: only x picks the option.
            $0.frame.minX <= inBar.x && inBar.x < $0.frame.maxX
        }
    }

    private func highlightAlternate(atSurfacePoint point: CGPoint) {
        guard let bar = alternatesView as? UIStackView else { return }
        let selected = alternateButton(atSurfacePoint: point)
        for case let button as UIButton in bar.arrangedSubviews {
            button.configuration?.background.backgroundColor =
                button === selected ? .systemBlue : Self.capColor
            button.configuration?.baseForegroundColor =
                button === selected ? .white : .label
        }
    }

    /// Release during slide-select: type the highlighted option, or the
    /// held base key when the finger never reached the overlay (stock).
    private func commitAlternate(base: String, atSurfacePoint point: CGPoint) {
        let selected = alternateButton(atSurfacePoint: point)?.configuration?.title
        dismissAlternates()
        if let selected {
            endSmartSpaceCycle()
            insertSmart(selected)
            if layer == .letters { shift.didTypeLetter() }
            refreshTypingCompletions()
            refreshShiftAppearance()
        } else {
            commitCharacter(base)
        }
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
                // A space that auto-committed a correction is stock's
                // absorbable auto-space; a plain typed space is not.
                let replaced = applyAutocorrectOnCommit()
                textDocumentProxy.insertText(" ")
                if replaced { trailingAutoSpace.arm() } else { trailingAutoSpace.disarm() }
            case .insertPeriod:
                // The word was committed by the first space; swap that space
                // for ". " with no re-commit.
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                log.debug("stock double-space period")
            }
            armAutoShiftIfSentenceStart()
            returnToLettersAfterSpace()
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
            let replaced = applyAutocorrectOnCommit()
            textDocumentProxy.insertText(" ")
            if replaced { trailingAutoSpace.arm() } else { trailingAutoSpace.disarm() }
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
        returnToLettersAfterSpace()
    }

    /// Stock: a space typed on the 123 / #+= plane flips the keyboard back
    /// to letters (cycle taps land after the first space already flipped).
    private func returnToLettersAfterSpace() {
        guard layer != .letters else { return }
        layer.didTypeSpace()
        rebuildRows()
    }

    @objc private func returnTapped() {
        if emojiSearchActive {
            exitEmojiPanel()
            return
        }
        dismissAlternates()
        endSmartSpaceCycle()
        applyAutocorrectOnCommit()
        trailingAutoSpace.disarm()
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
            trailingAutoSpace.disarm()
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
        // Stock's space bar carries no label; the identifier keeps it
        // findable for accessibility and the UI suite.
        let space = keyButton(title: "")
        space.accessibilityIdentifier = "space"
        space.accessibilityLabel = "space"
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
        let button = KeyButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.accessibilityIdentifier = identifier
        return button
    }

    private func emojiCell(_ emoji: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = emoji
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        let button = KeyButton(configuration: config)
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
    /// Returns true when a correction was written into the document.
    @discardableResult
    private func applyAutocorrectOnCommit() -> Bool {
        guard settings.autocorrect else { return false }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let commit = autocorrect.wordCommitted(context: context)
        defer { refreshSuggestionBar() }
        guard case .replace(let original, let corrected, _) = commit else { return false }
        // Trailing punctuation ("teh)") detaches the word from the tail;
        // skip the edit rather than delete the wrong characters, and drop
        // the bar so it never advertises a correction that was not made.
        guard context.hasSuffix(original) else {
            autocorrect.backspace()
            return false
        }
        for _ in 0..<original.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(corrected)
        log.debug("autocorrect applied (\(original.count) -> \(corrected.count) chars)")
        return true
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
        case .completions(let typed, _, _):
            // Same guard class: the partial must still be the tail.
            guard context.hasSuffix(typed) else {
                autocorrect.invalidateBar()
                return
            }
            switch autocorrect.barTapped(slot: sender.tag) {
            case .acceptTyped:
                textDocumentProxy.insertText(" ")
                trailingAutoSpace.arm()
                log.debug("completion: typed word accepted")
            case .complete(let from, let to):
                for _ in 0..<from.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(to + " ")
                trailingAutoSpace.arm()
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

    /// Verdict goes to the system log only (stock-parity AC 4: no debug
    /// chrome on the keyboard surface). .notice so it persists on device.
    private func runAppGroupProbe() {
        let value = UserDefaults(suiteName: appGroupID)?.string(forKey: probeKey)
        let ok = value == probeValue
        log.notice("app-group probe: \(ok ? "OK" : "BLOCKED", privacy: .public)")
    }
}
