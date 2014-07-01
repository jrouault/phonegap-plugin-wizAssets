# phonegap-plugin-wizAssets

- PhoneGap Version : 3.0
- last update : 15/11/2013

# Description

PhoneGap plugin for managing application assets with javascript asset maps. Includes( iOS background threaded) downloadFile, getFileURI, getFileURIs, deleteFile.


## Install (with Plugman)

	cordova plugin add https://github.com/Wizcorp/phonegap-plugin-wizAssets
	cordova build ios

	< or >

	phonegap local plugin add https://github.com/Wizcorp/phonegap-plugin-wizAssets
	phonegap build ios



## APIs

### downloadFile()

**wizAssets.downloadFile(String URL, String filePathToBeStoredWithFilename, Function success, Function fail);**

- downloads a file to native App directory @ ./ + gameDir+ / +filePathToBeStoredWithFilename <br />
- A success returns URI string like; file://documents/settings/img/cards/card001.jpg <br />
- example;

```
wizAssets.downloadFile("http://google.com/logo.jpg", "img/ui/logo.jpg", successCallback, failCallback);
```

###  deleteFile()

**wizAssets.deleteFile(string URI, Function success, Function fail);**

- deletes the file specified by the URI <br />
- if the URI does not exist fail will be called with error NotFoundError <br />
- if the URI cannot be deleted (i.e. file resides in read-only memory) fail will be called with error NotModificationAllowedError

```
wizAssets.deleteFile("file://documents/settings/img/cards/card001.jpg", successCallback, failCallback);
```

### deleteFiles()

**wizAssets.deleteFiles(Array manyURIs, Function success, Function fail );**

- delete all URIs in Array like; [ "file://documents/settings/img/cards/card001.jpg", "file://documents/settings/img/cards/card002.jpg " .. ] <br />
- if you do not specify a filename only dir, then all contents of dir will be deleted; file://documents/settings/img/cards <br />
- the array CAN contain one URI string

### getFileURI()

**wizAssets.getFileURI(String filePathWithFilename, Function success, Function fail);**

- A success returns URI string like file://documents/settings/img/cards/card001.jpg <br />
- example;

```
wizAssets.getFileURI("img/ui/logo.jpg", successCallback, failCallback);
```

### getFileURIs()

**wizAssets.getFileURIs(Function success, Function fail);**

- A success returns URI hashmap such as

```
{

    "img/ui/loader.gif"  : "/sdcard/<appname>/img/ui/loading.gif",
    "img/cards/card001.jpg" : "file://documents/settings/img/cards/card001.jpg"

}
```

### getAssetsVersion()

**wizAssets.getAssetsVersion(Function success, Function fail);**

- A success returns a string representing the version of the assets

### upgradeAssets()

**wizAssets.upgradeAssets(String version, Array filesToRemove, Function success, Function fail);**

- example;

```
wizAssets.upgradeAssets("1.2", [ "tutorial/", "level1/background.png" ], successCallback, failCallback);
```
