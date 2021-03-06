import Cocoa
import WebKit

class RenderViewController: NSViewController {
  @IBOutlet weak var openButton: NSButton!
  @IBOutlet weak var metadataLabel: NSTextField!

  lazy var webView: WebView = {
    return WebView(frame: self.view.bounds)
  }()

  var viewModel: RenderViewModel? {
    didSet {
      guard let HTML = viewModel?.fullPageString,
        let URL = viewModel?.baseURL
        else { return }
      onMain {
        self.webView.update(HTML, baseURL: URL)
        self.metadataLabel?.stringValue = self.viewModel!.metadata
      }
    }
  }

  fileprivate var markdownDocument: MarkdownDocument? {
    return view.window?.windowController?.document as? MarkdownDocument
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupWebView()
    openButton.toolTip = "Open with \(PreferencesController().defaultEditor.name)"
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    listenToDocumentChangeSignal()
    registerWindowName()

    guard let document = markdownDocument else { return }
    self.viewModel = RenderViewModel(document: document)
  }

  fileprivate func listenToDocumentChangeSignal() {
    guard let windowController = view.window?.windowController as? WindowController else { return }

    windowController.documentChangeSignal.observeResult { output in
      guard let document = self.markdownDocument,
      let html = output.value else { return }
      self.viewModel = RenderViewModel(filePath: document.path, HTMLString: html)
    }
  }

  fileprivate func setupWebView() {
    view.addSubview(webView, positioned: .below, relativeTo: view.subviews[0])
    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self

    view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|",
      options: NSLayoutConstraint.FormatOptions(),
      metrics: nil,
      views: ["webView": webView]))
    view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[webView]|",
      options: NSLayoutConstraint.FormatOptions(),
      metrics: nil,
      views: ["webView": webView]))
  }

  fileprivate func registerWindowName() {
    guard let window = view.window,
      let document = document
      else { return }
    window.setFrameAutosaveName(document.path)
  }

  fileprivate var document: MarkdownDocument? {
    guard let windowController = view.window?.windowController as? WindowController,
      let document = windowController.markdownDocument
      else { return nil }
    return document
  }
}

extension RenderViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    switch navigationAction.navigationType {
    case .linkActivated:
      guard let url = navigationAction.request.url else { return }
      let localPageURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Template")!
      let urlStringWithoutFragment = url.absoluteString.replacingOccurrences(of: "#" + (url.fragment ?? ""), with: "")
      if urlStringWithoutFragment == localPageURL.absoluteString {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
        NSWorkspace.shared.open(url)
      }
    default:
      decisionHandler(.allow)
    }
  }
}
