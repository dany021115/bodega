Bodega for macOS (Apple Silicon)

1. Drag Bodega to the Applications folder.

2. The first time, macOS warns that it cannot verify the app. Right-click
   (or Control-click) Bodega in Applications and choose Open. Another option, in
   Terminal:

       xattr -cr /Applications/Bodega.app

3. Bodega needs Rosetta 2. If you don't have it, install it in Terminal:

       softwareupdate --install-rosetta --agree-to-license

4. On first launch, Bodega copies the engine to ~/Library/Application Support/Bodega.
   It takes a few seconds.

5. D3DMetal is not included. Each user imports their own copy.
