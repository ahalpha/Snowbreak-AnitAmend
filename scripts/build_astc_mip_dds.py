"""Build a mipmapped ASTC DDS from a source image."""
import argparse
import os
import struct
import subprocess
import sys
import tempfile

ASTC_MAGIC = 0x5CA1AB13

DXGI_ASTC = {
    (4, 4):   134,
    (6, 6):   150,
    (8, 8):   162,
    (10, 10): 178,
    (12, 12): 186,
}

def parse_block_size(value):
    try:
        x, y = value.lower().split("x")
        block = (int(x), int(y))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"Invalid ASTC block size: {value}") from exc
    if block not in DXGI_ASTC:
        valid = ", ".join(f"{x}x{y}" for x, y in DXGI_ASTC)
        raise argparse.ArgumentTypeError(f"Unsupported block size: {value}. Valid: {valid}")
    return block

def write_tga(path, width, height, rgba_bytes):
    """Write raw RGBA bytes as an uncompressed TGA file."""
    header = struct.pack("<BBBHHBHHHHBB",
        0, 0, 2,        # id_len, colormap_type, image_type (uncompressed RGB)
        0, 0,           # colormap origin, length
        0,              # colormap entry size
        0, 0,           # x, y origin
        width, height,  # dimensions
        32,             # bits per pixel
        0x28,           # image descriptor: top-left, 8 alpha bits
    )
    with open(path, "wb") as f:
        f.write(header)
        # TGA stores BGRA, convert from RGBA
        for i in range(0, len(rgba_bytes), 4):
            f.write(bytes([rgba_bytes[i+2], rgba_bytes[i+1], rgba_bytes[i], rgba_bytes[i+3]]))

def read_astc(path):
    with open(path, "rb") as f:
        data = f.read()
    if struct.unpack_from("<I", data, 0)[0] != ASTC_MAGIC:
        raise ValueError(f"Not a valid .astc file: {path}")
    bx, by = data[4], data[5]
    w = data[7] | (data[8] << 8) | (data[9] << 16)
    h = data[10] | (data[11] << 8) | (data[12] << 16)
    return bx, by, w, h, data[16:]

def write_astc_dds(path, block, width, height, mip_payloads):
    bx, by = block
    dxgi_fmt = DXGI_ASTC[block]
    mip_count = len(mip_payloads)
    top_size = ((width + bx - 1) // bx) * ((height + by - 1) // by) * 16

    flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000  # CAPS|HEIGHT|WIDTH|PIXELFORMAT|LINEARSIZE
    caps  = 0x1000  # DDSCAPS_TEXTURE
    if mip_count > 1:
        flags |= 0x20000  # DDSD_MIPMAPCOUNT
        caps  |= 0x8 | 0x400000  # DDSCAPS_COMPLEX | DDSCAPS_MIPMAP

    dds_header  = struct.pack("<7I", 124, flags, height, width, top_size, 1, mip_count)
    dds_header += b"\x00" * 44
    dds_header += struct.pack("<2I4s5I", 32, 0x4, b"DX10", 0, 0, 0, 0, 0)
    dds_header += struct.pack("<5I", caps, 0, 0, 0, 0)
    dxt10 = struct.pack("<5I", dxgi_fmt, 3, 0, 1, 0)

    with open(path, "wb") as f:
        f.write(b"DDS ")
        f.write(dds_header)
        f.write(dxt10)
        for _, _, payload in mip_payloads:
            f.write(payload)

def compress_mip(index, width, height, tga_path, astcenc, block_size_str, quality, temp_dir):
    astc_path = os.path.join(temp_dir, f"mip{index}.astc")
    cmd = [astcenc, "-cl", tga_path, astc_path, block_size_str, quality]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"astcenc failed for mip{index}:\n{result.stdout}")
    _, _, astc_w, astc_h, payload = read_astc(astc_path)
    if (astc_w, astc_h) != (width, height):
        raise RuntimeError(f"Mip{index} size mismatch: got {astc_w}x{astc_h}, expected {width}x{height}")
    return index, width, height, payload

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("src_image")
    parser.add_argument("out_dds")
    parser.add_argument("--astcenc",    required=True)
    parser.add_argument("--tool-src",   required=True)
    parser.add_argument("--block-size", default="4x4", type=parse_block_size)
    parser.add_argument("--quality",    default="medium")
    args = parser.parse_args()

    sys.path.insert(0, args.tool_src)
    from directx.dxgi_format import DXGI_FORMAT
    from directx.texconv import Texconv

    block       = args.block_size
    block_str   = f"{block[0]}x{block[1]}"
    quality     = args.quality if args.quality.startswith("-") else f"-{args.quality}"

    with tempfile.TemporaryDirectory() as temp_dir:
        # Step 1: TGA -> RGBA DDS with full mipchain via texconv
        texconv = Texconv()
        rgba_dds_path = texconv.convert_to_dds(
            args.src_image, DXGI_FORMAT.R8G8B8A8_UNORM,
            out=temp_dir, no_mip=False, verbose=False,
        )

        from directx.dds import DDS
        rgba_dds = DDS.load(rgba_dds_path)
        mip_sizes   = rgba_dds.mipmap_size_list
        all_rgba    = rgba_dds.slice_bin_list[0]

        # Step 2: Extract each mip as TGA directly (no texconv round-trip)
        src_name = os.path.splitext(os.path.basename(args.src_image))[0]
        mip_jobs = []
        offset = 0
        for index, (w, h) in enumerate(mip_sizes):
            size     = w * h * 4
            rgba     = all_rgba[offset:offset + size]
            offset  += size
            tga_path = os.path.join(temp_dir, f"{src_name}_mip{index}.tga")
            write_tga(tga_path, w, h, rgba)
            mip_jobs.append((index, w, h, tga_path))

        # Step 3: Compress all mips
        payloads = []
        for idx, w, h, tga in mip_jobs:
            _, w, h, payload = compress_mip(idx, w, h, tga, args.astcenc, block_str, quality, temp_dir)
            payloads.append((w, h, payload))

        # Step 4: Write combined ASTC DDS
        out_dir = os.path.dirname(args.out_dds)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        width, height, _ = payloads[0]
        write_astc_dds(args.out_dds, block, width, height, payloads)

    print(f"Built {os.path.basename(args.out_dds)} ({width}x{height}, {block_str}, mips={len(payloads)})")

if __name__ == "__main__":
    main()
