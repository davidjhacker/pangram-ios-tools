import UIKit
import UniformTypeIdentifiers

class ActionViewController: UIViewController {

    private var apiKey: String { Pangram.apiKey }

    // MARK: - Views
    private let snippetLabel = UILabel()
    private let snippetCard = UIView()
    private let wordCountLabel = UILabel()
    private let verdictLabel = UILabel()
    private let percentLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let barTrack = UIView()
    private let barFill = UIView()
    private var barFillWidth: NSLayoutConstraint!
    private var snippetExpanded = false
    private var checkedText = ""

    private let orange = UIColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1)
    private let green  = UIColor(red: 0.22, green: 0.65, blue: 0.40, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSelectedText()
    }

    // MARK: - UI
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Text snippet card (tap to expand/collapse)
        snippetCard.backgroundColor = .secondarySystemBackground
        snippetCard.layer.cornerRadius = 12
        snippetCard.translatesAutoresizingMaskIntoConstraints = false
        snippetCard.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(toggleSnippet)))

        snippetLabel.numberOfLines = 3
        snippetLabel.font = .systemFont(ofSize: 15)
        snippetLabel.textColor = .secondaryLabel
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false

        wordCountLabel.font = .systemFont(ofSize: 13, weight: .medium)
        wordCountLabel.textColor = .tertiaryLabel
        wordCountLabel.translatesAutoresizingMaskIntoConstraints = false

        // Verdict + percentage
        verdictLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        verdictLabel.textAlignment = .center
        verdictLabel.text = "Checking…"
        verdictLabel.translatesAutoresizingMaskIntoConstraints = false

        percentLabel.font = .systemFont(ofSize: 64, weight: .bold)
        percentLabel.textAlignment = .center
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress bar
        barTrack.backgroundColor = .secondarySystemBackground
        barTrack.layer.cornerRadius = 5
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barFill.layer.cornerRadius = 5
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(barFill)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.addTarget(self, action: #selector(finish), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false

        snippetCard.addSubview(snippetLabel)
        [snippetCard, wordCountLabel, verdictLabel, percentLabel,
         subtitleLabel, barTrack, done].forEach(view.addSubview)

        barFillWidth = barFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            snippetCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            snippetCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            snippetCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            snippetLabel.topAnchor.constraint(equalTo: snippetCard.topAnchor, constant: 12),
            snippetLabel.leadingAnchor.constraint(equalTo: snippetCard.leadingAnchor, constant: 14),
            snippetLabel.trailingAnchor.constraint(equalTo: snippetCard.trailingAnchor, constant: -14),
            snippetLabel.bottomAnchor.constraint(equalTo: snippetCard.bottomAnchor, constant: -12),

            wordCountLabel.topAnchor.constraint(equalTo: snippetCard.bottomAnchor, constant: 8),
            wordCountLabel.trailingAnchor.constraint(equalTo: snippetCard.trailingAnchor),

            percentLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            percentLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            verdictLabel.bottomAnchor.constraint(equalTo: percentLabel.topAnchor, constant: -8),
            verdictLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            barTrack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            barTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            barTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            barTrack.heightAnchor.constraint(equalToConstant: 10),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            barFillWidth,

            done.topAnchor.constraint(equalTo: barTrack.bottomAnchor, constant: 40),
            done.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func toggleSnippet() {
        snippetExpanded.toggle()
        snippetLabel.numberOfLines = snippetExpanded ? 0 : 3
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    // MARK: - Data
    private func loadSelectedText() {
        guard let provider = (extensionContext?.inputItems.first as? NSExtensionItem)?
                .attachments?.first,
              provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else {
            return showError("No text selected")
        }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                let text: String?
                switch item {
                case let s as String: text = s
                case let d as Data:   text = String(data: d, encoding: .utf8)
                default:              text = nil
                }
                guard let text else { return self?.showError("No text selected") ?? () }
                Task { await self?.check(text) }
            }
    }
    
    private func check(_ text: String) async {
            checkedText = text
            guard !apiKey.isEmpty else {
                        await MainActor.run {
                            verdictLabel.text = "No API key"
                            verdictLabel.textColor = .secondaryLabel
                            percentLabel.text = "–"
                            percentLabel.textColor = .tertiaryLabel
                            subtitleLabel.text = "Open the Pangram app and add your key first"
                        }
                        return
            }
            let words = text.split(whereSeparator: \.isWhitespace).count
            await MainActor.run {
                snippetLabel.text = "“\(text)”"
                wordCountLabel.text = "\(words) word\(words == 1 ? "" : "s")"
            }
            guard words >= 50 else {
                await MainActor.run {
                    verdictLabel.text = "Too short"
                    verdictLabel.textColor = .secondaryLabel
                    percentLabel.text = "–"
                    percentLabel.textColor = .tertiaryLabel
                    subtitleLabel.text = "Pangram needs at least 50 words (\(words) selected)"
                }
                return
            }
            do {
                let r = try await Pangram.check(text, apiKey: apiKey)
                await MainActor.run { showResult(r) }
            } catch {
                showError(error.localizedDescription)
            }
        }

    private func showResult(_ r: Pangram.Result) {
        let pct = Int((r.fractionAI * 100).rounded())
        let isAI = r.fractionAI >= 0.5
        let color = isAI ? orange : green

        verdictLabel.text = r.prediction
        verdictLabel.textColor = color
        percentLabel.text = "\(pct)%"
        percentLabel.textColor = color
        subtitleLabel.text = "AI-Generated"
        barFill.backgroundColor = color

        view.layoutIfNeeded()
        barFillWidth.constant = barTrack.bounds.width * r.fractionAI
        UIView.animate(withDuration: 0.6, delay: 0,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.view.layoutIfNeeded()
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            self.verdictLabel.text = "Error"
            self.verdictLabel.textColor = .systemRed
            self.subtitleLabel.text = message
        }
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
