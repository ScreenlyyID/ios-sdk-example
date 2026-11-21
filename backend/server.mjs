// Example back end for the ScreenlyyID iOS example. No dependencies: Node 18 or later.
//
//   SCREENLYYID_API_KEY=test_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx node server.mjs
//
// Why this exists: every ScreenlyyID API call carries your API key, so every call must come from a server you control, never from the app.
// The app talks only to this server. The key and the CorrelationId (the session token) stay here.
//
//   app --> POST /verifications        --> this server --> POST https://api.screenlyyid.com/api/v1/instance/create
//   app <-- { verificationId, webEnrolmentUrl }
//   (the app opens webEnrolmentUrl in a WebView and waits for the IDV_SESSION_COMPLETE event)
//   app --> GET /verifications/:id     --> this server --> GET  https://api.screenlyyid.com/api/v1/document/result
//   app <-- { status: "pending" } or { status: "ready", result }
//
// DEMO ONLY: this server has no authentication of its own. A real back end must check who is asking before it creates or reads a verification,
// must store the CorrelationId in a database (not in memory), and must decide what is safe to send back to the app.
import http from "node:http";
import { randomUUID } from "node:crypto";

export function createServer({ apiKey, apiUrl = "https://api.screenlyyid.com", ttlMs = 60 * 60 * 1000 } = {}) {
  if (!apiKey) throw new Error("SCREENLYYID_API_KEY is not set");
  const base = apiUrl.replace(/\/+$/, "");
  /** verificationId -> { correlationId, createdAt }. In memory for the demo; use a database in a real back end. */
  const sessions = new Map();

  const upstream = (path, options = {}) =>
    fetch(base + path, { ...options, signal: AbortSignal.timeout(30_000) });

  const send = (res, status, body) => {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
  };

  const readJson = (req) =>
    new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on("data", (c) => {
        size += c.length;
        if (size > 10_000) { reject(Object.assign(new Error("body too large"), { status: 413 })); req.destroy(); }
        else chunks.push(c);
      });
      req.on("end", () => {
        if (!chunks.length) return resolve({});
        try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
        catch { reject(Object.assign(new Error("body must be JSON"), { status: 400 })); }
      });
      req.on("error", reject);
    });

  // Step 1: create a verification session. The API key is added here, on the server.
  async function createVerification(req, res) {
    const input = await readJson(req);
    const body = { GlobalScreening: ["idv"], CustomerIntelligence: [] }; // "idv" must be activated on your account
    if (typeof input.firstName === "string") body.FirstName = input.firstName.slice(0, 100);
    if (typeof input.lastName === "string") body.LastName = input.lastName.slice(0, 100);

    const r = await upstream("/api/v1/instance/create", {
      method: "POST",
      headers: { "x-api-key": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (r.status === 401) return send(res, 502, { error: "The ScreenlyyID API key was not accepted. Check SCREENLYYID_API_KEY." });
    if (r.status === 400) return send(res, 502, { error: "ScreenlyyID rejected the request. Check that the idv product is activated on your account." });
    if (!r.ok) return send(res, 502, { error: `ScreenlyyID instance/create failed (HTTP ${r.status}).` });

    // The property names are exactly CorrelationId and webEnrolmentUrl.
    const { CorrelationId, webEnrolmentUrl } = await r.json();
    if (!CorrelationId || !webEnrolmentUrl) return send(res, 502, { error: "Unexpected response from instance/create." });

    const verificationId = randomUUID();
    sessions.set(verificationId, { correlationId: CorrelationId, createdAt: Date.now() });
    // Send the app only what it needs. The CorrelationId stays on the server.
    return send(res, 201, { verificationId, webEnrolmentUrl });
  }

  // Step 4: read the result. Call this after the app reports IDV_SESSION_COMPLETE.
  async function getVerification(res, verificationId) {
    const session = sessions.get(verificationId);
    if (!session) return send(res, 404, { error: "Unknown verification." });

    const headers = { "x-api-key": apiKey, "x-correlation-id": session.correlationId };
    const r = await upstream("/api/v1/document/result", { headers });
    if (r.status === 401) return send(res, 502, { error: "The ScreenlyyID API key was not accepted." });
    // Webhooks are not available, so the result is polled. Anything other than 200 is treated as "not ready yet" (to be confirmed with a test key).
    if (!r.ok) return send(res, 200, { status: "pending" });

    const result = await r.json();
    // GET /api/v1/document/data returns the data read from the ID (OCR and MRZ). It holds personal data, so fetch it here
    // on the server if you need it, store it yourself, and send the app only what it needs:
    //   await upstream("/api/v1/document/data", { headers });
    return send(res, 200, { status: "ready", result });
  }

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, "http://localhost");
      const match = url.pathname.match(/^\/verifications\/([0-9a-f-]{36})$/);
      if (req.method === "POST" && url.pathname === "/verifications") return await createVerification(req, res);
      if (req.method === "GET" && match) return await getVerification(res, match[1]);
      return send(res, 404, { error: "Not found." });
    } catch (e) {
      if (e.status) return send(res, e.status, { error: e.message });
      console.error("request failed:", e.name, e.message); // never log the API key
      return send(res, 502, { error: "Could not reach ScreenlyyID." });
    }
  });

  // forget old sessions
  const timer = setInterval(() => {
    for (const [id, s] of sessions) if (Date.now() - s.createdAt > ttlMs) sessions.delete(id);
  }, 60_000);
  timer.unref();
  server.on("close", () => clearInterval(timer));
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 3000);
  try {
    createServer({ apiKey: process.env.SCREENLYYID_API_KEY, apiUrl: process.env.SCREENLYYID_API_URL }).listen(port, () =>
      console.log(`Example back end listening on http://localhost:${port}`));
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}
