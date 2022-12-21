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

## IDM Flatpak and Browser Integration with Firefox.  
```
flatpak install flathub org.winehq.Wine
```
Create a 32-Bit WINEPREFIX named "IDM".  
Install IDM in default location.  

put "idm-flatpak" as "idm" in ~/.local/share/bin/". Make it executable. Change username inside it.  
put idm.png icon in ~/.local/share/icons

create application launcher in ~/.local/share/applications  
`idm.desktop`
```
[Desktop Entry]
Name=Internet Download Manager
Exec=flatpak run --env="WINEPREFIX=/var/home/zihad/.var/app/org.winehq.Wine/data/wineprefixes/IDM/" org.winehq.Wine "/var/home/zihad/.var/app/org.winehq.Wine/data/wineprefixes/IDM/drive_c/Program Files/Internet Download Manager/IDMan.exe" @@u %U @@
Type=Application
Terminal=false
Categories=Internet;
Icon=idm.png
Comment=Launch Internet Download Manager.
StartupWMClass=Internet Download Manager
```





