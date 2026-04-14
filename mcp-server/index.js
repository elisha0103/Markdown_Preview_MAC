#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import net from "net";
import { z } from "zod";

const TCP_PORT = 52698;
const TCP_HOST = "127.0.0.1";

class AppConnection {
  constructor() {
    this.client = null;
    this.buffer = "";
    this.requestId = 0;
    this.pending = new Map();
  }

  async connect() {
    if (this.client) return;

    return new Promise((resolve, reject) => {
      const client = net.createConnection({ port: TCP_PORT, host: TCP_HOST });

      const timeout = setTimeout(() => {
        client.destroy();
        reject(
          new Error(
            "Connection timeout - is Markdown Preview app running? (port " +
              TCP_PORT +
              ")"
          )
        );
      }, 5000);

      client.on("connect", () => {
        clearTimeout(timeout);
        this.client = client;
        resolve();
      });

      client.on("data", (data) => {
        this.buffer += data.toString();
        const lines = this.buffer.split("\n");
        this.buffer = lines.pop() || "";

        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const response = JSON.parse(line);
            const p = this.pending.get(String(response.id));
            if (p) {
              p.resolve(response.result);
              this.pending.delete(String(response.id));
            }
          } catch {
            // ignore parse errors
          }
        }
      });

      client.on("error", (err) => {
        clearTimeout(timeout);
        this.client = null;
        // Reject all pending requests
        for (const [, p] of this.pending) {
          p.reject(err);
        }
        this.pending.clear();
        reject(err);
      });

      client.on("close", () => {
        this.client = null;
        for (const [, p] of this.pending) {
          p.reject(new Error("Connection closed"));
        }
        this.pending.clear();
      });
    });
  }

  async send(method, params = {}) {
    if (!this.client) {
      await this.connect();
    }

    const id = String(++this.requestId);
    const message = JSON.stringify({ id, method, params }) + "\n";

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timeout waiting for response: ${method}`));
      }, 10000);

      this.pending.set(id, {
        resolve: (result) => {
          clearTimeout(timeout);
          resolve(result);
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        },
      });

      this.client.write(message, (err) => {
        if (err) {
          clearTimeout(timeout);
          this.pending.delete(id);
          reject(err);
        }
      });
    });
  }
}

const app = new AppConnection();

const server = new McpServer({
  name: "markdown-preview",
  version: "1.0.0",
  description:
    "Bridge to Markdown Preview macOS app for real-time collaborative editing",
});

// --- Tools ---

server.tool(
  "get_editor_content",
  "Get the current markdown content and file path from the editor",
  {},
  async () => {
    try {
      const result = await app.send("get_editor_content");
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "set_editor_content",
  "Set the markdown content in the editor. Use this to update the document.",
  {
    content: z.string().describe("The full markdown content to set"),
  },
  async ({ content }) => {
    try {
      const result = await app.send("set_editor_content", { content });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_selection",
  "Get the text currently selected by the user in the editor, with start/end line numbers",
  {},
  async () => {
    try {
      const result = await app.send("get_selection");
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_file_info",
  "Get information about the currently open file (path, name)",
  {},
  async () => {
    try {
      const result = await app.send("get_file_info");
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_headings",
  "Get the document's table of contents (heading hierarchy)",
  {},
  async () => {
    try {
      const result = await app.send("get_headings");
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_changes",
  "Get tracked changes (diff) between the baseline and current content, optionally filtered by author",
  {
    author: z
      .enum(["user", "claude"])
      .optional()
      .describe("Filter changes by author: 'user' or 'claude'. Omit for all."),
  },
  async ({ author }) => {
    try {
      const params = {};
      if (author) params.author = author;
      const result = await app.send("get_changes", params);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_annotations",
  "Get user annotations (inline notes) attached to specific lines of the document",
  {},
  async () => {
    try {
      const result = await app.send("get_annotations");
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "export_pdf",
  "Export the current document as a PDF file",
  {
    outputPath: z
      .string()
      .describe("Absolute file path where the PDF will be saved"),
  },
  async ({ outputPath }) => {
    try {
      const result = await app.send("export_pdf", { outputPath });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "export_html",
  "Export the current document as a standalone HTML file",
  {
    outputPath: z
      .string()
      .describe("Absolute file path where the HTML will be saved"),
  },
  async ({ outputPath }) => {
    try {
      const result = await app.send("export_html", { outputPath });
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      };
    } catch (e) {
      return {
        content: [{ type: "text", text: `Error: ${e.message}` }],
        isError: true,
      };
    }
  }
);

// --- Start ---

const transport = new StdioServerTransport();
await server.connect(transport);
