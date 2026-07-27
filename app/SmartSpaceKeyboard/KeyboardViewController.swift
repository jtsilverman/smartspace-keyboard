import UIKit
import os
import TypingEngine

/// Thin shell over TypingEngine: renders KeyboardLayout, forwards taps to
/// textDocumentProxy. All decision logic stays in the tested packages.
final class KeyboardViewController: UIInputViewController {
    private let log = Logger(subsystem: "com.jtsilverman.smartspace.keyboard", category: "keyboard")

    private var shift = ShiftState()
    private var letterButtons: [UIButton] = []
    private var shiftButton: UIButton?
    private let probeBadge = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        runAppGroupProbe()
    }

    // MARK: - Layout

    private func buildKeyboard() {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rows)

        for (index, letters) in KeyboardLayout.letterRows.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 4
            for letter in letters {
                let button = keyButton(title: letter)
                button.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
                letterButtons.append(button)
                row.addArrangedSubview(button)
            }
            if index == KeyboardLayout.letterRows.count - 1 {
                let shiftKey = keyButton(title: "⇧")
                shiftKey.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
                shiftButton = shiftKey
                row.insertArrangedSubview(shiftKey, at: 0)

                let backspace = keyButton(title: "⌫")
                backspace.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
                row.addArrangedSubview(backspace)
            }
            rows.addArrangedSubview(row)
        }

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 4

        let globe = keyButton(title: "🌐")
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let space = keyButton(title: "space")
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let returnKey = keyButton(title: "return")
        returnKey.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)

        bottomRow.addArrangedSubview(globe)
        bottomRow.addArrangedSubview(space)
        bottomRow.addArrangedSubview(returnKey)
        globe.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.12).isActive = true
        returnKey.widthAnchor.constraint(equalTo: bottomRow.widthAnchor, multiplier: 0.22).isActive = true
        rows.addArrangedSubview(bottomRow)

        probeBadge.font = .systemFont(ofSize: 10, weight: .semibold)
        probeBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(probeBadge)

        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            rows.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            rows.heightAnchor.constraint(equalToConstant: 216),
            probeBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            probeBadge.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
        ])
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

    // MARK: - Keys

    @objc private func letterTapped(_ sender: UIButton) {
        guard let letter = sender.configuration?.title else { return }
        let text = shift.isShifted ? letter.uppercased() : letter
        textDocumentProxy.insertText(text)
        shift.didTypeLetter()
        log.debug("letter: \(text, privacy: .public)")
        refreshShiftAppearance()
    }

    @objc private func shiftTapped() {
        shift.tapShift()
        log.debug("shift armed: \(self.shift.isShifted)")
        refreshShiftAppearance()
    }

    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }

    private func refreshShiftAppearance() {
        shiftButton?.configuration?.baseBackgroundColor = shift.isShifted ? .systemBlue : nil
        for button in letterButtons {
            guard var config = button.configuration, let title = config.title else { continue }
            config.title = shift.isShifted ? title.uppercased() : title.lowercased()
            button.configuration = config
        }
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
