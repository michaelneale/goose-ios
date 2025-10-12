import SwiftUI
import WebKit

struct LivePreviewView: View {
    let htmlContent: String
    let cssContent: String
    let jsContent: String
    let onConsoleOutput: (String) -> Void
    
    @State private var webView: WKWebView?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Live Preview")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: refreshPreview) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Web view container
            WebViewContainer(
                htmlContent: htmlContent,
                cssContent: cssContent,
                jsContent: jsContent,
                onConsoleOutput: onConsoleOutput,
                isLoading: $isLoading,
                webView: $webView
            )
            .background(Color(.systemBackground))
        }
    }
    
    private func refreshPreview() {
        webView?.reload()
    }
}

struct WebViewContainer: UIViewRepresentable {
    let htmlContent: String
    let cssContent: String
    let jsContent: String
    let onConsoleOutput: (String) -> Void
    @Binding var isLoading: Bool
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable console logging
        let userContentController = WKUserContentController()
        
        // Inject console capture script
        let consoleScript = """
        (function() {
            var originalLog = console.log;
            var originalError = console.error;
            var originalWarn = console.warn;
            
            console.log = function() {
                var message = Array.prototype.slice.call(arguments).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: 'log',
                    message: message
                });
                originalLog.apply(console, arguments);
            };
            
            console.error = function() {
                var message = Array.prototype.slice.call(arguments).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: 'error',
                    message: message
                });
                originalError.apply(console, arguments);
            };
            
            console.warn = function() {
                var message = Array.prototype.slice.call(arguments).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: 'warn',
                    message: message
                });
                originalWarn.apply(console, arguments);
            };
            
            // Capture errors
            window.addEventListener('error', function(e) {
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: 'error',
                    message: 'Error: ' + e.message + ' at ' + e.filename + ':' + e.lineno
                });
            });
        })();
        """
        
        let script = WKUserScript(source: consoleScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(script)
        userContentController.add(context.coordinator, name: "consoleLog")
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Enable debugging features
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        self.webView = webView
        
        let fullHTML = generateFullHTML()
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateFullHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>GooseCode Preview</title>
            <style>
                \(cssContent)
            </style>
        </head>
        <body>
            \(extractBodyContent(from: htmlContent))
            <script>
                \(jsContent)
            </script>
        </body>
        </html>
        """
    }
    
    private func extractBodyContent(from html: String) -> String {
        // Simple extraction of body content
        if let bodyStart = html.range(of: "<body>"),
           let bodyEnd = html.range(of: "</body>") {
            let startIndex = html.index(bodyStart.upperBound, offsetBy: 0)
            let endIndex = bodyEnd.lowerBound
            return String(html[startIndex..<endIndex])
        }
        
        // If no body tags, return the HTML as-is (might be a fragment)
        return html
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.onConsoleOutput("Navigation failed: \(error.localizedDescription)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog",
               let body = message.body as? [String: Any],
               let level = body["level"] as? String,
               let messageText = body["message"] as? String {
                
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                let logEntry = "[\(timestamp)] \(level.uppercased()): \(messageText)"
                parent.onConsoleOutput(logEntry)
            }
        }
    }
}
