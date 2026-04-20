import sys

def patch_file():
    target_file = "lib/screens/my_store_qr_screen.dart"
    with open(target_file, "r", encoding="utf-8") as f:
        content = f.read()

    # Find where the `build` method starts
    dialog_start_tag = "// ── QR Verification Dialog"
    idx_dialog = content.find(dialog_start_tag)
    if idx_dialog == -1:
        print("Could not find dialog start")
        return
        
    with open("dialog.dart", "r", encoding="utf-8") as f:
        new_dialog = f.read()
        
    final_content = content[:idx_dialog] + new_dialog
    # also reduce the height of SizedBox around linked QRs.
    # Looking for:
    #                 _buildStickerCard(),
    #                 const SizedBox(height: 16),
    #                 _buildLinkedQRsList(isDesktop: false),
    final_content = final_content.replace(
        "                _buildStickerCard(),\n                const SizedBox(height: 16),\n                _buildLinkedQRsList(isDesktop: false),",
        "                _buildStickerCard(),\n                const SizedBox(height: 8),\n                _buildLinkedQRsList(isDesktop: false),"
    )
    
    with open(target_file, "w", encoding="utf-8") as f:
        f.write(final_content)
        
    print("Patched successfully")

if __name__ == "__main__":
    patch_file()
