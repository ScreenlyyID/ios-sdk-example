# ios-sdk-example


Built with Xcode 16.2.

**Pre-reqs:** 
API Key created via the admin dashboard.

**High level overview of the steps in this app:**

1. Call the /instance/create API to generate a unique token and Url.
2. Initiate a webview using the Url and token from step 1.
3. Listen for the IDV_SESSION_COMPLETE event, to close the webview and continue app processing.
4. View the data and results in your admin dashboard. Coming soon: Webhooks to register for events and retreive results.

**Details**

LaunchViewController.swift
  - this file is the starter view of the app, which calls the instance API and creates the token and Url.

HomeViewController.swift
  - Contains 2 buttons, both of which open the webview with the URl from the instance controller, and initiates document collection.

ViewController.swift
  - Controls the webview and sets a listener for IDV_SESSION_COMPLETE.
  - Note configurations that are also set here to allow camera access.

SuccessViewController.swift
  - shows success message when the IDV_SESSION_COMPLETE event is received. This represents other pages in the onboarding flow of your app.

**Permissions**

Correct permissions need to be set for the ScreenlyyID document collection sdk to access the camera.
Note the permissions set in the Info.plist and the ViewController to ensure smooth camera access.
