# `cordova-plugin-ionic-migrate-storage`

> Cordova plugin that migrates WebSQL, localStorage and IndexedDB data from UIWebview to Ionic's WkWebView (`cordova-plugin-ionic-webview`)

## Installation

Straight forward, just via `cordova plugin add`.

```
cordova plugin add https://github.com/pointmanhq/cordova-plugin-ionic-migrate-websql --save
```

Use the latest commit SHA if you need to keep it locked to a specific version.

## Gotchas

* This has been tested only with `cordova-plugin-ionic-webview@2.3.2`!
* Currently, this plugin does not work on simulators.
* IndexedDB copying may be buggy, a PR or two will be needed to make it better.
* This copy is uni-directional, from UIWebView to WkWebView. It does not go the other way around. So essentially, this plugin will run only once! To test this, you will have to do the following:
    - Delete the app from your device
    - Run `cordova plugin rm --save cordova-plugin-ionic-webview cordova-plugin-ionic-migrate-storage`
    - Build your app and run it. Store something in localStorage, WebSQL and IndexedDB.
    - Run `cordova plugin add --save cordova-plugin-ionic-webview@2.3.2 https://github.com/pointmanhq/cordova-plugin-ionic-migrate-websql`
    - Build your app and run it. The stored data must all exist!

## Thanks

Most of the code in this plugin was either adapted or inspired from a plethora of other sources. Creating this plugin would not have been possible if not for these repositories and their contributors:

* https://github.com/jairemix/cordova-plugin-migrate-localstorage/
* https://github.com/MaKleSoft/cordova-plugin-migrate-localstorage
* https://github.com/Telerik-Verified-Plugins/WKWebView/

## TODO 

* Publish this via `npm`
