# ScreenlyyID iOS example

A small iOS app that adds ScreenlyyID identity verification the way the docs describe: create a session, open the hosted capture page in a `WKWebView`, and listen for the completion event.

- Docs: https://www.screenlyyid.com/docs/integrations/mobile-app/
- AI quickstart: https://www.screenlyyid.com/docs/ai-quickstart/
- All developer docs as Markdown: https://www.screenlyyid.com/docs/llms-full.txt

Built with Xcode 16.2 (iOS deployment target 15.6). This is an example, not a library: copy the parts you need.

## Before you run it

1. Create a **test** API key: register at https://admin.screenlyyid.com/register, then in the dashboard open **Integrations** and create a key in the test environment. Test keys start with `test_`.
2. Open `DemoCamera/LaunchViewController.swift` and set `DemoConfig.apiKey` to that key. `DemoConfig.apiBaseURL` is already `https://api.screenlyyid.com`.
3. Run on a **real device**. The capture page needs the camera, which the simulator does not have.

> **The API key in this app is for the demo only.** A real app must never contain an API key. In production your own back end calls `instance/create` and returns the `webEnrolmentUrl` to the app (and keeps the `CorrelationId`).

## What the app does

| Step | Where | What happens |
|---|---|---|
| 1. Create a session | `LaunchViewController.swift` | `POST /api/v1/instance/create` with the headers `x-api-key` and `Content-Type: application/json` and the body `{"GlobalScreening": ["idv"], "CustomerIntelligence": []}`. A `200` response has two properties, spelled exactly like this: `CorrelationId` and `webEnrolmentUrl`. `idv` (identity verification) must be activated on your account. A bad key returns `401`. A bad product code returns `400` with an empty body. |
| 2. Open the WebView | `HomeViewController.swift`, `ViewController.swift` | The app asks for camera permission, then loads `webEnrolmentUrl` in a `WKWebView`. The second button adds `?skipIntro=true` to go straight to image capture. |
| 3. Listen for events | `ViewController.swift` | The hosted page sends `postMessage` events shaped `{ "eventName": "", "isError": false, "error": "" }`. A user script forwards them to `userContentController(_:didReceive:)`. `IDV_SESSION_COMPLETE` means the document and selfie were collected, so the WebView can close. `ERROR` is a fatal error while processing the images. |
| 4. Get the results | **Your back end** | Send the `CorrelationId` from step 1 to your back end. It calls `GET /api/v1/document/data` and `GET /api/v1/document/result` with the headers `x-api-key` and `x-correlation-id`. The app itself does not fetch results. You can also see every verification in the dashboard under **Verifications**. |

Webhooks are not available yet, so poll the result endpoints from your back end. See https://www.screenlyyid.com/docs/data/webhooks/.

## Camera and microphone permissions

The capture page photographs the ID document and takes a selfie, so the WebView needs the camera.

- `Info.plist` must contain `NSCameraUsageDescription`. This project also sets `NSMicrophoneUsageDescription`; keep it unless you have confirmed your flow never needs it. Write text that tells the user why you need access.
- Request camera access **before** loading the page, as `HomeViewController.requestCameraAccess` does. If access was denied, send the user to Settings instead of loading a page that cannot capture.
- This project sets `allowsInlineMediaPlayback = true` on the `WKWebViewConfiguration` (see `ViewController.viewDidLoad`). Keep it so the camera preview plays inside the page.
- Test on a device. The simulator has no camera.

## Files

- `LaunchViewController.swift`: configuration, `instance/create`, error handling.
- `HomeViewController.swift`: camera permission and the two buttons.
- `ViewController.swift`: the `WKWebView`, the event listener, completion and error handling.
- `SuccessViewController.swift`: the screen shown after `IDV_SESSION_COMPLETE`, standing in for the next step of your app.
