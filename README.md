Netmap
======

A small 'tool' to visualize the ongoing TCP connections by the use of a world map.

Made it after being inspired by Facepunch WAYWO, it was a fun project. It uses http://freegeoip.net to query to latitude, longitude and possible city of the ip, and plots it on the map.

![Preview of netmap](https://copy.com/aU7EgfaLLhGc/2015-02-28_11-10-14.png)

It has the option to automatically set and update the wallpaper each update period, you can do this by uncommenting in `netmap/setWallpaper.bat`.

There are a few settings at the top of `netmap/main.lua`, like the resolution.

By default, it will save only the latest update image to `%APPDATA%/Love/netmap`, it's possible to keep a 'log' and keep every update with a timestamp, you can do this by setting `SAVE_ALL` to true in `netmap/main.lua`.

The update period can also be changed, I found that anything below 5 seconds usually takes longer, and that windows wallpaper changing is fairly slow. 15 seconds may even been too quick for a background anyway.

Number of threads setting is the amount of worker threads that query geoip. Since most of the time was spent waiting on the connection, I had to use threads, because updates would take longer than the update time. Looking back now, if this is set to something like 2, the very first (warm up) update will take a while, but the rest should be fine since there isn't a lot of change.

lTCPConnections.dll is a module I wrote while I was learning C++ and it's likely to be broken, it also needs VC++2012 or 2013.

Due to the nature of the project, there is only a Windows (possibly only Windows 7) compatible version.

If you have any questions or problems feel free to leave an issue or contact me directly: kamil.zmich@gmail.com
