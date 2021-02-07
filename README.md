# idm-linux
Setup Internet Download Manager in Linux with Wine. Extension working.
Working version: Internet Download Manager 6.36 Build 5

step 1: Setup wine (on Archlinux)
```
$ sudo pacman -S wine wine-mono wine_gecko winetricks
$ sudo pacman -S lib32-gnutls [for https support]
```

step 2: Setup IDM 
https://www.internetdownloadmanager.com/download.html

step 3: Install browser extension (available for firefox and chrome)
https://add0n.com/download-by.html

step 4: Setup bridge between extension and OS. Download the idm file.
```
$ sudo chmod +x idm
$ sudo mv idm /usr/local/bin/
$ idm
```
