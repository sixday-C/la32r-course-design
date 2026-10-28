#!/usr/bin/env python3
"""用同一套 openXC7 工具生成远程板卡的演示 bitstream。"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
TOOLS = Path(os.environ.get("OPENXC7_TOOLS", REPO.parent / "bitstream-openxc7/tools"))
BUILD = HERE / "build"
OUT = HERE / "out"
BUILD.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)

ports = {"clk_50M", "reset_btn", "dip_sw", "touch_btn", "leds",
         "dpy0", "dpy1", "txd", "rxd"}
xdc_source = REPO.parent / "bitstream-openxc7/remote-reference/loongson_remote.xdc"
lines = []
for original in xdc_source.read_text().splitlines():
    match = re.search(r"set_property -dict \{([^}]+)\} \[get_ports (.+)\]", original)
    if not match:
        continue
    port = match.group(2).strip("{}")
    if port.split("[")[0] not in ports:
        continue
    values = match.group(1).split()
    properties = dict(zip(values[::2], values[1::2]))
    for key in ("PACKAGE_PIN", "IOSTANDARD"):
        lines.append(f"set_property {key} {properties[key]} [get_ports {{{port}}}]")
lines.append("create_clock -period 20.000 -name clk_50M [get_ports clk_50M]")
(BUILD / "remote.xdc").write_text("\n".join(lines) + "\n")


def run(name: str, command: list[str]) -> None:
    log = BUILD / f"{name}.log"
    print(name, flush=True)
    with log.open("w") as output:
        subprocess.run(command, cwd=REPO, stdout=output,
                       stderr=subprocess.STDOUT, check=True)


def check_rom_init() -> None:
    # 仿真能读到 hex，不代表综合后的 ROM 仍有这些指令。
    source = (HERE / "synth.ys").read_text().splitlines()
    read_verilog = next(line for line in source if line.startswith("read_verilog "))
    rom_json = BUILD / "rom_check.json"
    script = BUILD / "rom_check.ys"
    script.write_text("\n".join([
        read_verilog,
        "hierarchy -top looongson_remote_top",
        "proc",
        "opt",
        "memory_collect",
        f"write_json {rom_json.relative_to(REPO)}",
    ]) + "\n")
    run("rom-check", [str(TOOLS / "oss-cad-suite/bin/yosys"),
                      "-Q", "-T", str(script)])
    modules = json.loads(rom_json.read_text())["modules"]
    soc = next(module for name, module in modules.items()
               if name.endswith("\\soc_demo_top"))
    rom = soc["cells"]["inst_rom"]
    init = rom["parameters"]["INIT"]
    width = int(rom["parameters"]["WIDTH"], 2)
    expected = [int(line, 16) for line in
                (REPO / "labs/lab01/mycpu_env/examples/peripherals/perf_demo.hex")
                .read_text().splitlines() if line.strip()]
    actual = [int(init[-(index + 1) * width:][:width], 2)
              for index in range(len(expected))]
    if width != 32 or actual != expected:
        raise RuntimeError("综合后的指令 ROM 与 perf_demo.hex 不一致")


if "--check-rom" in sys.argv:
    check_rom_init()
    sys.exit(0)

if "--resume-frames" not in sys.argv:
    check_rom_init()
    run("synthesis", [str(TOOLS / "oss-cad-suite/bin/yosys"), "-Q", "-T",
                      str(HERE / "synth.ys")])
    run("place-route", [str(TOOLS / "openxc7/bin/nextpnr-xilinx"),
                        "--chipdb", str(TOOLS / "chipdb/xc7a200tfbg676.bin"),
                        "--json", str(BUILD / "soc.json"),
                        "--xdc", str(BUILD / "remote.xdc"),
                        "--freq", "25", "--placer", "heap", "--seed", "3",
                        "--fasm", str(BUILD / "remote.fasm"),
                        "--report", str(BUILD / "timing.json")])
database = TOOLS / "openxc7/share/nextpnr/external/prjxray-db/artix7"
part = "xc7a200tfbg676-1"
bitstream = OUT / "perf_demo_25MHz.bit"
with tempfile.TemporaryDirectory(prefix="mycpu-openxc7-") as temporary:
    ascii_path = Path(temporary)
    (ascii_path / "remote.fasm").symlink_to(BUILD / "remote.fasm")
    (ascii_path / "database").symlink_to(database, target_is_directory=True)
    run("frames", [str(TOOLS / "openxc7/bin/fasm2frames"),
                   "--db-root", str(ascii_path / "database"), "--part", part,
                   str(ascii_path / "remote.fasm"),
                   str(ascii_path / "remote.frames")])
    shutil.copy2(ascii_path / "remote.frames", BUILD / "remote.frames")
    run("bitstream", [str(TOOLS / "openxc7/bin/xc7frames2bit"),
                      "--part_file", str(ascii_path / "database" / part / "part.yaml"),
                      "--part_name", part,
                      "--frm_file", str(ascii_path / "remote.frames"),
                      "--output_file", str(ascii_path / "perf_demo.bit")])
    shutil.copy2(ascii_path / "perf_demo.bit", bitstream)
print(bitstream)
