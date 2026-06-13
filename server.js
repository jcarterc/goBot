// Minimal static server for the Godot web build.
// Sets cross-origin isolation headers so SharedArrayBuffer/threads work if enabled,
// and the correct MIME types for .wasm / .pck.
const http = require("http");
const fs = require("fs");
const path = require("path");

// index.wasm is stored pre-gzip-compressed to keep it under GitHub's 25MB limit.
// We signal this to the browser with Content-Encoding: gzip so it decompresses
// transparently before handing it to the WebAssembly engine.
const ROOT = path.join(__dirname, "build");
const PORT = process.env.PORT || 8060;

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".json": "application/json",
  ".svg": "image/svg+xml",
};

http
  .createServer((req, res) => {
    let urlPath = decodeURIComponent(req.url.split("?")[0]);
    if (urlPath === "/") urlPath = "/index.html";
    const filePath = path.join(ROOT, urlPath);
    if (!filePath.startsWith(ROOT)) {
      res.writeHead(403);
      return res.end("Forbidden");
    }
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        return res.end("Not found");
      }
      const ext = path.extname(filePath);
      const headers = {
        "Content-Type": MIME[ext] || "application/octet-stream",
        "Cross-Origin-Opener-Policy": "same-origin",
        "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "cross-origin",
      };
      // The WASM is stored gzip-compressed. Tell the browser so it decompresses.
      if (ext === ".wasm") headers["Content-Encoding"] = "gzip";
      res.writeHead(200, headers);
      res.end(data);
    });
  })
  .listen(PORT, () => console.log(`serving build/ on http://localhost:${PORT}`));
