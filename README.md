# `cordova-plugin-ionic-migrate-storage`

> Cordova plugin that migrates WebSQL, localStorage and IndexedDB* data when you start using the `cordova-plugin-ionic-webview` plugin. This works for both Android and iOS!

_* Only on iOS_

## Installation

Straight forward, just via `cordova plugin add`.

```
cordova plugin add https://github.com/pointmanhq/cordova-plugin-ionic-migrate-storage#v0.1.0 --save
```

**The plugin uses [the `WKPort` preference supplied to the ionic webview](https://github.com/ionic-team/cordova-plugin-ionic-webview/tree/2.x#wkport). If that was not found, the default port is used (`8080`).**

## Testing

To test this, you will have to do the following:

* Delete the app from your device
* Remove the webview and migrate plugins from your app:

```
cordova plugin rm --save cordova-plugin-ionic-webview cordova-plugin-ionic-migrate-storage
```

* Build your app and run it. Store something in localStorage, WebSQL and IndexedDB.
* Add the plugins back:
        
```
cordova plugin add --save cordova-plugin-ionic-webview@2.3.2 https://github.com/pointmanhq/cordova-plugin-ionic-migrate-storage#v0.1.0
```

* Build your app and run it. The stored data must all exist!

## Caveats / Warnings / Gotchas

* Until the plugin reaches `v.1.0.0`, breaking changes will be introduced in every minor version upgrade! Use one of [the tags listed here](https://github.com/pointmanhq/cordova-plugin-ionic-migrate-storage/tags) if you want to lock it down to a specific changeset.
* **This has been tested only with `cordova-plugin-ionic-webview@2.3.2`!**
* Currently, this plugin does not work on simulators. PRs welcome!
* IndexedDB migration has not been implemented in Android, because [it looks tricky](https://stackoverflow.com/a/35142175).
* IndexedDB migration on iOS may be buggy, a PR or two will be needed to make it better. 
* This copy is uni-directional, from old webview to new webview. It does not go the other way around. So essentially, this plugin will run only once! 
* syedhusain: Modify to support ionic webview v4 (hardcoded the path to ionic_localhost_0)

## Thanks

Most of the code in this plugin was either adapted or inspired from a plethora of other sources. Creating this plugin would not have been possible if not for these repositories and their contributors:

* https://github.com/jairemix/cordova-plugin-migrate-localstorage/
* https://github.com/MaKleSoft/cordova-plugin-migrate-localstorage
* https://github.com/Telerik-Verified-Plugins/WKWebView/
* https://github.com/ccgus/fmdb
* https://github.com/jacek-marchwicki/leveldb-jni

## TODO 

* Pull out debug flags to make them platform specific and not rely on booleans in the code.
* Add some unit testing.
* Open source stuff - github issue templates, CONTRIBUTING doc, Local development doc etc.
* Publish this to `npm`.
