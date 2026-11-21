// Runs the back end against a fake ScreenlyyID API, so it needs no key and no network: npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createServer } from "../server.mjs";

let fake, fakeUrl, app, appUrl;
const calls = [];
let resultStatus = 500;

before(async () => {
  fake = http.createServer((req, res) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      calls.push({ method: req.method, url: req.url, headers: req.headers, body: raw });
      const json = (s, b) => { res.writeHead(s, { "Content-Type": "application/json" }); res.end(b === undefined ? "" : JSON.stringify(b)); };
      if (req.url === "/api/v1/instance/create") {
        if (req.headers["x-api-key"] !== "test_good") return json(401);
        const body = JSON.parse(raw);
        if (!body.GlobalScreening?.length) return json(400);
        return json(200, { CorrelationId: "11111111-2222-3333-4444-555555555555", webEnrolmentUrl: "https://app.screenlyyid.com/idv/abc" });
      }
      if (req.url === "/api/v1/document/result") {
        if (req.headers["x-correlation-id"] !== "11111111-2222-3333-4444-555555555555") return json(404);
        return resultStatus === 200 ? json(200, { Decision: { Level: "Pass" } }) : json(resultStatus);
      }
      json(404);
    });
  });
  await new Promise((r) => fake.listen(0, r));
  fakeUrl = `http://localhost:${fake.address().port}`;
  app = createServer({ apiKey: "test_good", apiUrl: fakeUrl });
  await new Promise((r) => app.listen(0, r));
  appUrl = `http://localhost:${app.address().port}`;
});
after(() => { app.close(); fake.close(); });

const post = (path, body) => fetch(appUrl + path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });

test("refuses to start without an API key", () => {
  assert.throws(() => createServer({}), /SCREENLYYID_API_KEY/);
});

test("creates a session with the key added on the server, and never returns the key or the CorrelationId", async () => {
  const r = await post("/verifications", { firstName: "Jane", lastName: "Citizen" });
  assert.equal(r.status, 201);
  const body = await r.json();
  assert.deepEqual(Object.keys(body).sort(), ["verificationId", "webEnrolmentUrl"]);
  assert.equal(body.webEnrolmentUrl, "https://app.screenlyyid.com/idv/abc");
  assert.doesNotMatch(JSON.stringify(body), /11111111-2222|test_good/);
  const upstream = calls.at(-1);
  assert.equal(upstream.method, "POST"); assert.equal(upstream.headers["x-api-key"], "test_good");
  assert.deepEqual(JSON.parse(upstream.body), { GlobalScreening: ["idv"], CustomerIntelligence: [], FirstName: "Jane", LastName: "Citizen" });
});

test("reading a result sends x-api-key and the stored x-correlation-id; pending until the API says 200", async () => {
  const { verificationId } = await (await post("/verifications", {})).json();
  resultStatus = 500; // what the real API returns until the capture has finished
  let r = await fetch(`${appUrl}/verifications/${verificationId}`);
  assert.equal(r.status, 200); assert.deepEqual(await r.json(), { status: "pending" });
  resultStatus = 200;
  r = await fetch(`${appUrl}/verifications/${verificationId}`);
  assert.deepEqual(await r.json(), { status: "ready", result: { Decision: { Level: "Pass" } } });
  const upstream = calls.at(-1);
  assert.equal(upstream.url, "/api/v1/document/result");
  assert.equal(upstream.headers["x-api-key"], "test_good"); assert.equal(upstream.headers["x-correlation-id"], "11111111-2222-3333-4444-555555555555");
});

test("an unexpected status from ScreenlyyID is an error, not an endless pending", async () => {
  const { verificationId } = await (await post("/verifications", {})).json();
  resultStatus = 403;
  const r = await fetch(`${appUrl}/verifications/${verificationId}`);
  assert.equal(r.status, 502); assert.match((await r.json()).error, /HTTP 403/);
  resultStatus = 500;
});

test("unknown ids and unknown routes are 404, bad JSON is 400", async () => {
  assert.equal((await fetch(`${appUrl}/verifications/00000000-0000-0000-0000-000000000000`)).status, 404);
  assert.equal((await fetch(`${appUrl}/nope`)).status, 404);
  const r = await fetch(appUrl + "/verifications", { method: "POST", body: "{not json" });
  assert.equal(r.status, 400);
});

test("a rejected API key is reported as a server problem without echoing the key", async () => {
  const bad = createServer({ apiKey: "test_bad", apiUrl: fakeUrl });
  await new Promise((r) => bad.listen(0, r));
  const r = await fetch(`http://localhost:${bad.address().port}/verifications`, { method: "POST" });
  assert.equal(r.status, 502);
  const text = await r.text();
  assert.match(text, /API key was not accepted/); assert.doesNotMatch(text, /test_bad/);
  bad.close();
});
