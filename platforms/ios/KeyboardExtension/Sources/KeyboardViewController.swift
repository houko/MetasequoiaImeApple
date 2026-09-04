import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
  private let letterRows = [
    Array("qwertyuiop"),
    Array("asdfghjkl"),
    Array("zxcvbnm"),
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = MetasequoiaTheme.keyboardBackground
    installKeyboard()
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
      root.addArrangedSubview(makeLetterRow(row))
    }
    root.addArrangedSubview(makeActionRow())
  }

  private func makeCandidateStrip() -> UIView {
    let container = UIView()
    container.backgroundColor = MetasequoiaTheme.keyBackground.withAlphaComponent(0.82)
    container.layer.cornerRadius = 12

    let label = UILabel()
    label.text = "水杉输入法 · iOS 预览"
    label.font = .preferredFont(forTextStyle: .subheadline)
    label.textColor = MetasequoiaTheme.forestUIColor
    label.adjustsFontForContentSizeCategory = true
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)

    NSLayoutConstraint.activate([
      container.heightAnchor.constraint(equalToConstant: 38),
      label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
      label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -14),
      label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    return container
  }

  private func makeLetterRow(_ letters: [Character]) -> UIStackView {
    let row = makeRow()
    for letter in letters {
      let text = String(letter)
      row.addArrangedSubview(
        makeKey(title: text, accessibilityLabel: text.uppercased()) { [weak self] in
          self?.textDocumentProxy.insertText(text)
        })
    }
    return row
  }

  private func makeActionRow() -> UIStackView {
    let row = makeRow()
    row.addArrangedSubview(
      makeSymbolKey(symbol: "globe", accessibilityLabel: "下一个键盘") { [weak self] in
        self?.advanceToNextInputMode()
      })
    row.addArrangedSubview(
      makeSymbolKey(symbol: "delete.left", accessibilityLabel: "删除") { [weak self] in
        self?.textDocumentProxy.deleteBackward()
      })

    let space = makeKey(title: "空格", accessibilityLabel: "空格") { [weak self] in
      self?.textDocumentProxy.insertText(" ")
    }
    space.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
    row.addArrangedSubview(space)

    let enter = makeKey(title: "换行", accessibilityLabel: "换行", emphasized: true) { [weak self] in
      self?.textDocumentProxy.insertText("\n")
    }
    row.addArrangedSubview(enter)
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
