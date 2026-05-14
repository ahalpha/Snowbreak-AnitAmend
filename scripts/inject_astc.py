"""Inject an ASTC DDS file into a uasset, changing the pixel format from BC7/DXT to ASTC."""
import sys
import os

# Use UE4-DDS-Tools source
tool_src = os.path.join(os.path.dirname(__file__), "deps", "UE4-DDS-Tools-v0.6.1-Batch", "src")
sys.path.insert(0, tool_src)

from unreal.uasset import Uasset
from directx.dds import DDS

BLOCK_TO_PF = {
    (4, 4):   "PF_ASTC_4x4",
    (6, 6):   "PF_ASTC_6x6",
    (8, 8):   "PF_ASTC_8x8",
    (10, 10): "PF_ASTC_10x10",
    (12, 12): "PF_ASTC_12x12",
}

def inject(uasset_path, dds_path, version="4.26"):
    asset = Uasset(uasset_path, version=version)

    if not asset.has_textures():
        print(f"Skipped (no textures): {os.path.basename(uasset_path)}")
        return

    dds = DDS.load(dds_path)

    # Determine target PF from DXGI format name e.g. ASTC_4X4_UNORM -> PF_ASTC_4x4
    fmt_name = dds.header.dxgi_format.name  # e.g. "ASTC_4X4_UNORM"
    parts = fmt_name.replace("_UNORM", "").replace("_TYPELESS", "").split("_")
    # parts = ["ASTC", "4X4"] -> block = (4, 4)
    if len(parts) == 2 and parts[0] == "ASTC":
        dims = tuple(int(x) for x in parts[1].split("X"))
        pf = BLOCK_TO_PF.get(dims)
    else:
        pf = None

    if pf is None:
        print(f"Unknown ASTC format: {fmt_name}")
        sys.exit(1)

    for tex in asset.get_texture_list():
        tex.change_format(pf)

    for tex in asset.get_texture_list():
        tex.inject_dds(dds)

    asset.save(uasset_path)
    print(f"OK: {os.path.basename(uasset_path)} -> {pf}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: inject_astc.py input.uasset input.dds")
        sys.exit(1)
    inject(sys.argv[1], sys.argv[2])
