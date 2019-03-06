
map-keys-on-attach
==================

binary and launchd property list to automatically remap keys of a certain USB keyboard when it is attached.


Build and Install
-----------------------

For building the binary `map-keys-on-attach`, do

```
xcodebuild
```

For install, 

```
xcodebuild install
```

which creates the binary and puts it in `/usr/local/bin/map-keys-on-attach`.  
Also, the `launchd` property list `local.map-keys-on-attach.plist` is copied to `~/Library/LaunchAgents/local.map-keys-on-attach.plist`.

There are no precautions, so be careful.

Usage
--------

Build/install and then

```
launchctl load ~/Library/LaunchAgents/local.map-keys-on-attach.plist
```

From then on, everything is ready.

Customization
--------------------

__You must adapt the keyboard identification__.   

  1. Find your `VendorID` and `ProductID` via `hidutil list`. Example:

   ```
   VendorID  ProductID  LocationID  PUsagePage  PUsage  RegistryID  Transport     Product
   1452       628       339738624   1           6       100000432   USB           "Apple Internal Keyboard / Trackpad"
   0          0         0           65280       23      100000321   Unknown       "Unknown"
   0          0         0           65280       4       1000004b9   Unknown       "Unknown"
   0          0         0           0           0       100000254   Unknown       "Unknown"
   1452       628       339738624   13          12      10000043a   USB           "Apple Internal Keyboard / Trackpad"
   0          0         0           0           0       100000253   Unknown       "Unknown"
   ```
   
  2. Change these values in `local.map-keys-on-attach.plist` (~line 31) and `main.m` (~line 24)
  3. Rebuild/install

__You may want to change the mappings__.
  
These are in `main.m` from line 42 onwards. Refer to the [Apple Technical Note TN2450](https://developer.apple.com/library/archive/technotes/tn2450/_index.html#//apple_ref/doc/uid/DTS40017618-CH1-KEY_TABLE_USAGES) and [the official USB Reference](https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf) to find you "usage IDs".   
_NOTE:_ the usage IDs do _not_ correspond to the standard Mac "key codes" nor ASCII character codes or such. Don't confuse them.
   
Then, rebuild.

Rationale
-------------

macOS 10.12 Sierra introduced the possibility to [remap keys on a system level](https://developer.apple.com/library/archive/technotes/tn2450/_index.html) without external programs.

With a filter, this can be done on a per-keyboard basis:

```
$ hidutil list
VendorID  ProductID  LocationID  PUsagePage  PUsage  RegistryID  Transport     Product    
1240       85        337641472   1           6       100115ea1   USB           "Keyboard Demo"
```

e.g., for an Apple internal keyboard (in the example, there is no mapping)

```
$ hidutil --filter {"VendorID":1452,"PrimaryUsagePage":1} --get "UserKeyMappings"
RegistryID  Key                   Value
100000432   UserKeyMappings   (null)
```

However, when using an external keyboard, any mapping set this way is forgotten when the keyboard is removed and reattached.
Apparently also, when an MB(P) wakes up.

Fortunately, we can us a [`launchd(8)`](man:lanuchd) service using a `LaunchEvent` to listen for USB attach events (see `IOMatchLaunchStream` in the man page).

Thus, every time the keyboard in question is attached, its keys are mapped as desired.

Stuff
-----
 * The license (in LICENSE) is ISC
 * I did this to swap backtick an the "Menu"  key on a [Maltron](https://www.maltron.com/) keyboard
