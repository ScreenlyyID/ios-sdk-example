# ScreenlyyID iOS example

An iOS app **and the back end it needs**, showing how to add ScreenlyyID identity verification: create a session, open the hosted capture page in a `WKWebView`, listen for the completion event, and read the result.

- Docs: https://www.screenlyyid.com/docs/integrations/mobile-app/
- AI quickstart: https://www.screenlyyid.com/docs/ai-quickstart/
- All developer docs as Markdown: https://www.screenlyyid.com/docs/llms-full.txt

This is an example, not a library: copy the parts you need. Built with Xcode 16.2 (iOS 15.6 or later).

## The structure: every ScreenlyyID API call is made by a back end

```
iOS app (DemoCamera/)            your back end (backend/)                 ScreenlyyID
------------------------         ----------------------------------       ------------------------------------
POST /verifications        -->   POST /api/v1/instance/create        -->  x-api-key: <key>
                           <--   { CorrelationId, webEnrolmentUrl }   <--
  <-- { verificationId, webEnrolmentUrl }
open webEnrolmentUrl in a WKWebView ... the person captures the document and a selfie ...
IDV_SESSION_COMPLETE event
GET /verifications/:id     -->   GET /api/v1/document/result         -->  x-api-key: <key>
                                                                          x-correlation-id: <CorrelationId>
  <-- { status, result }   <--
```

- **The API key and the `CorrelationId` live only in `backend/`.** The app contains neither. Anything inside an app can be extracted, so an API key there is a leaked key.
- **The app calls only your back end** (`DemoConfig.backendURL`). It never calls `api.screenlyyid.com`.
- The back end is deliberately tiny and has no dependencies (Node 18 or later). Copy its two routes into whatever server you already run.

## Run it

1. **Get a test API key.** Register at https://admin.screenlyyid.com/register, open **Integrations** in the dashboard and create a key in the test environment. Test keys start with `test_`.
2. **Start the back end:**
   ```bash
   cd backend
   SCREENLYYID_API_KEY=test_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx node server.mjs
   ```
   `npm test` runs its tests against a fake ScreenlyyID API (no key needed).
3. **Point the app at it.** Set `DemoConfig.backendURL` in `DemoCamera/LaunchViewController.swift`. The camera needs a **real device**, so `localhost` will not work (it is the phone itself): use your Mac's address on the same Wi-Fi, for example `http://192.168.1.20:3000`. The app's `Info.plist` allows plain HTTP to local addresses for this demo only; a real back end uses HTTPS.
4. Run the app on a device.

> **Demo only:** the back end has no authentication of its own. A real back end must check who is asking before it creates or reads a verification, store the `CorrelationId` in a database (this one keeps it in memory), and decide what is safe to send back to the app.

## What happens, step by step

| Step | Where | What happens |
|---|---|---|
| 1. Create a session | `backend/server.mjs` (called from `LaunchViewController.swift`) | The back end sends `POST /api/v1/instance/create` with the headers `x-api-key` and `Content-Type: application/json` and the body `{"GlobalScreening": ["idv"], "CustomerIntelligence": []}`. A `200` response has two properties, spelled exactly like this: `CorrelationId` and `webEnrolmentUrl`. The back end keeps the `CorrelationId` and sends the app only a `verificationId` and the `webEnrolmentUrl`. `idv` (identity verification) must be activated on your account. A missing or bad key returns `401` and a bad product code returns `400`, both with a problem-details JSON body. |
| 2. Open the WebView | `HomeViewController.swift`, `ViewController.swift` | The app asks for camera permission, then loads `webEnrolmentUrl` in a `WKWebView`. The second button adds `?skipIntro=true` to go straight to image capture. |
| 3. Listen for events | `ViewController.swift` | The hosted page sends `postMessage` events shaped `{ "eventName": "", "isError": false, "error": "" }`. A user script forwards them to `userContentController(_:didReceive:)`. `IDV_SESSION_COMPLETE` means the document and selfie were collected. `ERROR` is a fatal error while processing the images. |
| 4. Get the result | `backend/server.mjs` (asked from `SuccessViewController.swift`) | The app asks the back end `GET /verifications/:id`. The back end calls `GET /api/v1/document/result` with the headers `x-api-key` and `x-correlation-id`, and answers `pending` if it is asked too early (before the capture has finished, the API returns HTTP 500 with `{"error":"internal_error"}`). `IDV_SESSION_COMPLETE` is sent only after the results are stored, so one request after the event is enough: there is no polling. It can also call `GET /api/v1/document/data` (the data read from the ID): that holds personal data, so keep it on the server and send the app only what it needs. |

The `IDV_SESSION_COMPLETE` event tells the app when to ask for the result. You can also see every verification in the dashboard under **Verifications**.

## Camera and microphone permissions

The capture page photographs the ID document and takes a selfie, so the WebView needs the camera.

- `Info.plist` must contain `NSCameraUsageDescription`. This project also sets `NSMicrophoneUsageDescription`; keep it unless you have confirmed your flow never needs it. Write text that tells the user why you need access.
- Request camera access **before** loading the page, as `HomeViewController.requestCameraAccess` does. If access was denied, send the user to Settings instead of loading a page that cannot capture.
- This project sets `allowsInlineMediaPlayback = true` on the `WKWebViewConfiguration` (see `ViewController.viewDidLoad`). Keep it so the camera preview plays inside the page.
- Test on a device. The simulator has no camera.

## Files

- `backend/server.mjs`: the example back end. `backend/test/server.test.mjs`: its tests.
- `DemoCamera/LaunchViewController.swift`: configuration, and the app's calls to your back end.
- `DemoCamera/HomeViewController.swift`: camera permission and the two buttons.
- `DemoCamera/ViewController.swift`: the `WKWebView`, the event listener, completion and error handling.
- `DemoCamera/SuccessViewController.swift`: asks the back end for the result once, standing in for the next step of your app.
