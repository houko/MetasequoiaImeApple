import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
  private let session = MetasequoiaInputSessionBridge()
  private let preeditLabel = UILabel()
  private let candidateScrollView = UIScrollView()
  private let candidateStack = UIStackView()
  private let languageModeButton = UIButton()
  private var letterRowViews: [UIView] = []
  private var symbolRowViews: [UIView] = []
  private var layoutToggleButton: UIButton?
  private var isChineseMode = true
  private var showsSymbols = false

  private let letterRows = [
    Array("qwertyuiop"),
    Array("asdfghjkl"),
    Array("zxcvbnm"),
  ]
  private let symbolRows = [
    Array("1234567890").map(String.init),
    [",", ".", "?", "!", ";", ":", "'", "\""],
    ["(", ")", "[", "]", "<", ">", "\\", "-"],
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = MetasequoiaTheme.keyboardBackground
    installKeyboard()
    updateCandidateStrip(preedit: "", candidates: [])
  }

  override func textWillChange(_ textInput: UITextInput?) {
    super.textWillChange(textInput)
    render(session.cancel())
  }

  private func installKeyboard() {
    let root = UIStackView()
    root.axis = .vertical
    root.spacing = 7
    root.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(root)

    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
      root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
      root.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
      root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -7),
      view.heightAnchor.constraint(greaterThanOrEqualToConstant: 270),
    ])

    root.addArrangedSubview(makeCandidateStrip())
    for row in letterRows {
      let rowView = makeLetterRow(row)
      letterRowViews.append(rowView)
      root.addArrangedSubview(rowView)
    }
    for row in symbolRows {
      let rowView = makeSymbolRow(row)
      rowView.isHidden = true
      symbolRowViews.append(rowView)
      root.addArrangedSubview(rowView)
    }
    root.addArrangedSubview(makeActionRow())
  }

  private func makeCandidateStrip() -> UIView {
    let container = UIView()
    container.backgroundColor = MetasequoiaTheme.keyBackground.withAlphaComponent(0.82)
    container.layer.cornerRadius = 12

    preeditLabel.font = .preferredFont(forTextStyle: .subheadline)
    preeditLabel.textColor = MetasequoiaTheme.forestUIColor
    preeditLabel.adjustsFontForContentSizeCategory = true
    preeditLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

    updateLanguageModeButton()
    languageModeButton.addAction(
      UIAction { [weak self] _ in self?.toggleInputMode() }, for: .primaryActionTriggered)
    languageModeButton.widthAnchor.constraint(equalToConstant: 36).isActive = true

    candidateStack.axis = .horizontal
    candidateStack.spacing = 6
    candidateStack.translatesAutoresizingMaskIntoConstraints = false
    candidateScrollView.showsHorizontalScrollIndicator = false
    candidateScrollView.addSubview(candidateStack)

    let content = UIStackView(
      arrangedSubviews: [languageModeButton, preeditLabel, candidateScrollView])
    content.axis = .horizontal
    content.alignment = .center
    content.spacing = 12
    content.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(content)

    NSLayoutConstraint.activate([
      container.heightAnchor.constraint(equalToConstant: 38),
      content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      content.topAnchor.constraint(equalTo: container.topAnchor),
      content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      candidateStack.leadingAnchor.constraint(
        equalTo: candidateScrollView.contentLayoutGuide.leadingAnchor),
      candidateStack.trailingAnchor.constraint(
        equalTo: candidateScrollView.contentLayoutGuide.trailingAnchor),
      candidateStack.topAnchor.constraint(
        equalTo: candidateScrollView.contentLayoutGuide.topAnchor),
      candidateStack.bottomAnchor.constraint(
        equalTo: candidateScrollView.contentLayoutGuide.bottomAnchor),
      candidateStack.heightAnchor.constraint(
        equalTo: candidateScrollView.frameLayoutGuide.heightAnchor),
    ])
    return container
  }

  private func makeLetterRow(_ letters: [Character]) -> UIStackView {
    let row = makeRow()
    for letter in letters {
      let text = String(letter)
      row.addArrangedSubview(
        makeKey(title: text, accessibilityLabel: text.uppercased()) { [weak self] in
          self?.handleCharacter(text)
        })
    }
    return row
  }

  private func makeSymbolRow(_ symbols: [String]) -> UIStackView {
    let row = makeRow()
    for symbol in symbols {
      row.addArrangedSubview(
        makeKey(title: symbol, accessibilityLabel: "符号 \(symbol)") { [weak self] in
          self?.handleSymbol(symbol)
        })
    }
    return row
  }

  private func makeActionRow() -> UIStackView {
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .fill
    row.distribution = .fill
    row.spacing = 6

    let layoutToggle = makeKey(title: "123", accessibilityLabel: "切换到数字和符号") {
      [weak self] in self?.toggleLayout()
    }
    if var configuration = layoutToggle.configuration {
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 0, leading: 4, bottom: 0, trailing: 4)
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
        attributes in
        var attributes = attributes
        attributes.font = .systemFont(ofSize: 17, weight: .medium)
        return attributes
      }
      layoutToggle.configuration = configuration
    }
    layoutToggle.titleLabel?.adjustsFontSizeToFitWidth = true
    layoutToggle.titleLabel?.minimumScaleFactor = 0.7
    layoutToggle.titleLabel?.lineBreakMode = .byClipping
    layoutToggleButton = layoutToggle
    row.addArrangedSubview(layoutToggle)

    let globe = makeSymbolKey(symbol: "globe", accessibilityLabel: "下一个键盘") { [weak self] in
      self?.switchToNextKeyboard()
    }
    row.addArrangedSubview(globe)

    let delete = makeSymbolKey(symbol: "delete.left", accessibilityLabel: "删除") { [weak self] in
      self?.handleBackspace()
    }
    row.addArrangedSubview(delete)

    let space = makeKey(title: "空格", accessibilityLabel: "空格") { [weak self] in
      self?.handleSpace()
    }
    row.addArrangedSubview(space)

    let enter = makeKey(title: "换行", accessibilityLabel: "换行", emphasized: true) { [weak self] in
      self?.handleReturn()
    }
    row.addArrangedSubview(enter)

    NSLayoutConstraint.activate([
      layoutToggle.widthAnchor.constraint(equalTo: globe.widthAnchor, multiplier: 1.1),
      delete.widthAnchor.constraint(equalTo: globe.widthAnchor),
      space.widthAnchor.constraint(equalTo: globe.widthAnchor, multiplier: 1.8),
      enter.widthAnchor.constraint(equalTo: globe.widthAnchor, multiplier: 1.35),
      globe.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    return row
  }

  private func makeRow() -> UIStackView {
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .fill
    row.distribution = .fillEqually
    row.spacing = 6
    return row
  }

  private func handleCharacter(_ character: String) {
    if isChineseMode {
      render(session.handleCharacter(character))
    } else {
      textDocumentProxy.insertText(character)
    }
  }

  private func handleSymbol(_ symbol: String) {
    if !isChineseMode {
      textDocumentProxy.insertText(symbol)
      return
    }

    if symbol.count == 1, symbol >= "1", symbol <= "9" {
      let snapshot = session.handleCandidateKey(symbol)
      if !snapshot.isHandled && snapshot.preedit.isEmpty {
        textDocumentProxy.insertText(symbol)
      }
      render(snapshot)
      return
    }

    if symbol == "'" {
      let separatorSnapshot = session.handleCharacter(symbol)
      if separatorSnapshot.isHandled {
        render(separatorSnapshot)
        return
      }
    }

    let snapshot = session.handlePunctuation(symbol)
    if snapshot.isHandled {
      render(snapshot)
      return
    }

    render(session.commitRaw())
    textDocumentProxy.insertText(symbol)
  }

  private func toggleInputMode() {
    let snapshot = isChineseMode ? session.commitCandidate() : session.cancel()
    isChineseMode.toggle()
    updateLanguageModeButton()
    render(snapshot)
  }

  private func updateLanguageModeButton() {
    var configuration = UIButton.Configuration.filled()
    configuration.title = isChineseMode ? "中" : "英"
    configuration.baseForegroundColor = .white
    configuration.baseBackgroundColor = MetasequoiaTheme.forestUIColor
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 3, leading: 5, bottom: 3, trailing: 5)
    configuration.background.cornerRadius = 8
    languageModeButton.configuration = configuration
    languageModeButton.accessibilityIdentifier = "languageModeButton"
    languageModeButton.accessibilityLabel =
      isChineseMode ? "切换到英文输入" : "切换到中文输入"
    languageModeButton.accessibilityValue = isChineseMode ? "中文输入" : "英文输入"
  }

  private func toggleLayout() {
    showsSymbols.toggle()
    letterRowViews.forEach { $0.isHidden = showsSymbols }
    symbolRowViews.forEach { $0.isHidden = !showsSymbols }
    if var configuration = layoutToggleButton?.configuration {
      configuration.title = showsSymbols ? "ABC" : "123"
      layoutToggleButton?.configuration = configuration
    }
    layoutToggleButton?.accessibilityLabel =
      showsSymbols ? "切换到字母" : "切换到数字和符号"
  }

  private func handleBackspace() {
    let snapshot = session.handleBackspace()
    if !snapshot.isHandled {
      textDocumentProxy.deleteBackward()
    }
    render(snapshot)
  }

  private func handleSpace() {
    let snapshot = session.commitCandidate()
    if !snapshot.isHandled {
      textDocumentProxy.insertText(" ")
    }
    render(snapshot)
  }

  private func handleReturn() {
    render(session.commitCandidate())
    textDocumentProxy.insertText("\n")
  }

  private func switchToNextKeyboard() {
    render(session.commitRaw())
    advanceToNextInputMode()
  }

  private func render(_ snapshot: MetasequoiaInputSnapshot) {
    if let commitText = snapshot.commitText {
      textDocumentProxy.insertText(commitText)
    }
    updateCandidateStrip(preedit: snapshot.preedit, candidates: snapshot.candidates)
  }

  private func updateCandidateStrip(preedit: String, candidates: [String]) {
    preeditLabel.text =
      preedit.isEmpty ? (isChineseMode ? "水杉输入法" : "英文输入") : preedit
    for view in candidateStack.arrangedSubviews {
      candidateStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }

    for (index, candidate) in candidates.prefix(9).enumerated() {
      candidateStack.addArrangedSubview(
        makeCandidateButton(candidate: candidate, number: index + 1))
    }
    candidateScrollView.isHidden = candidates.isEmpty
  }

  private func makeCandidateButton(candidate: String, number: Int) -> UIButton {
    var configuration = UIButton.Configuration.plain()
    configuration.title = "\(number)  \(candidate)"
    configuration.baseForegroundColor = .label
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: 4, leading: 9, bottom: 4, trailing: 9)
    configuration.background.backgroundColor = MetasequoiaTheme.keyBackground
    configuration.background.strokeColor = MetasequoiaTheme.forestUIColor.withAlphaComponent(0.22)
    configuration.background.strokeWidth = 1
    configuration.background.cornerRadius = 9

    let button = UIButton(
      configuration: configuration,
      primaryAction: UIAction { [weak self] _ in
        guard let self else { return }
        self.render(self.session.selectCandidate(at: UInt(number - 1)))
      })
    button.accessibilityLabel = "候选词 \(number)：\(candidate)"
    button.accessibilityIdentifier = "candidate-\(number)"
    return button
  }

  private func makeSymbolKey(
    symbol: String, accessibilityLabel: String, action: @escaping () -> Void
  ) -> UIButton {
    var configuration = UIButton.Configuration.plain()
    configuration.image = UIImage(systemName: symbol)
    configuration.baseForegroundColor = .label
    configuration.background.backgroundColor = MetasequoiaTheme.keyBackground
    configuration.background.cornerRadius = 8
    let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
    button.accessibilityLabel = accessibilityLabel
    return button
  }

  private func makeKey(
    title: String,
    accessibilityLabel: String,
    emphasized: Bool = false,
    action: @escaping () -> Void
  ) -> UIButton {
    var configuration = UIButton.Configuration.plain()
    configuration.title = title
    configuration.baseForegroundColor = emphasized ? .white : .label
    configuration.background.backgroundColor =
      emphasized
      ? UIColor(red: 167 / 255, green: 103 / 255, blue: 59 / 255, alpha: 1)
      : MetasequoiaTheme.keyBackground
    configuration.background.cornerRadius = 8
    configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
      attributes in
      var attributes = attributes
      attributes.font = .preferredFont(forTextStyle: .title3)
      return attributes
    }
    let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
    button.accessibilityLabel = accessibilityLabel
    return button
  }
}
