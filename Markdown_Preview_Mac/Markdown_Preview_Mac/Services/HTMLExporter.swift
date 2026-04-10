import Foundation

struct HTMLExporter {
    static func exportStandaloneHTML(markdown: String) -> String {
        let markedJS = loadResource("marked.min", ext: "js")
        let highlightJS = loadResource("highlight.min", ext: "js")
        let markdownCSS = loadResource("github-markdown.min", ext: "css")
        let highlightLightCSS = loadResource("github-highlight-light.min", ext: "css")
        let highlightDarkCSS = loadResource("github-highlight-dark.min", ext: "css")

        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(markdownCSS)</style>
            <style media="(prefers-color-scheme: light)">\(highlightLightCSS)</style>
            <style media="(prefers-color-scheme: dark)">\(highlightDarkCSS)</style>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.css">
            <style>
                body {
                    margin: 0; padding: 24px;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                }
                @media (prefers-color-scheme: light) { body { background-color: #ffffff; } }
                @media (prefers-color-scheme: dark) { body { background-color: #0d1117; } }
                .markdown-body { max-width: 980px; margin: 0 auto; }
                .katex-block { text-align: center; margin: 16px 0; overflow-x: auto; }
                .katex-error { color: #d1242f; font-size: 0.9em; }
                .mermaid-container { text-align: center; margin: 16px 0; }
                .mermaid-container svg { max-width: 100%; }
            </style>
            <script>\(markedJS)</script>
            <script>\(highlightJS)</script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
        </head>
        <body>
            <article class="markdown-body" id="content"></article>
            <script>
                // KaTeX extensions for marked
                var katexBlockExt = {
                    name: 'katexBlock', level: 'block',
                    start: function(src) { return src.indexOf('$$'); },
                    tokenizer: function(src) {
                        var m = src.match(/^\\$\\$([\\s\\S]+?)\\$\\$/);
                        if (m) return { type: 'katexBlock', raw: m[0], text: m[1].trim() };
                    },
                    renderer: function(t) {
                        try { return '<div class="katex-block">' + katex.renderToString(t.text, {displayMode:true,throwOnError:false}) + '</div>'; }
                        catch(e) { return '<div class="katex-error">' + e.message + '</div>'; }
                    }
                };
                var katexInlineExt = {
                    name: 'katexInline', level: 'inline',
                    start: function(src) { var i=src.indexOf('$'); return (i>0&&src[i-1]==='$')?-1:i; },
                    tokenizer: function(src) {
                        var m = src.match(/^\\$([^\\$\\n]+?)\\$/);
                        if (m) return { type: 'katexInline', raw: m[0], text: m[1].trim() };
                    },
                    renderer: function(t) {
                        try { return katex.renderToString(t.text, {displayMode:false,throwOnError:false}); }
                        catch(e) { return '<span class="katex-error">' + e.message + '</span>'; }
                    }
                };
                marked.use({ extensions: [katexBlockExt, katexInlineExt] });
                marked.setOptions({ gfm: true, breaks: false });

                mermaid.initialize({ startOnLoad: false, theme: window.matchMedia('(prefers-color-scheme:dark)').matches ? 'dark' : 'default', securityLevel: 'loose' });

                (async function() {
                    var el = document.getElementById('content');
                    el.innerHTML = marked.parse(`\(escapedMarkdown)`);
                    el.querySelectorAll('pre code').forEach(function(block) {
                        if (!block.classList.contains('language-mermaid')) hljs.highlightElement(block);
                    });
                    var mc = 0;
                    var blocks = el.querySelectorAll('code.language-mermaid');
                    for (var i = 0; i < blocks.length; i++) {
                        var pre = blocks[i].parentElement;
                        try {
                            var r = await mermaid.render('m-' + (++mc), blocks[i].textContent);
                            var d = document.createElement('div');
                            d.className = 'mermaid-container';
                            d.innerHTML = r.svg;
                            pre.replaceWith(d);
                        } catch(e) {}
                    }
                })();
            </script>
        </body>
        </html>
        """
    }

    private static func loadResource(_ name: String, ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return content
    }
}
