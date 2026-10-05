#!/usr/bin/env python3
"""Build and validate the offline two-addon 0.12.0 candidate ZIP.

No player files, network, installation or consumer edits.
"""
import argparse
from pathlib import Path
import zipfile

FILES = (
    "MclarionWow/MclarionWow.lua",
    "MclarionWow/MclarionWow.toc",
    "MclarionWowProgression/MclarionWowProgression.toc",
    "MclarionWowProgression/QuestCapture.lua",
    "MclarionWowProgression/ReputationCapture.lua",
    "MclarionWowProgression/WealthCapture.lua",
    "MclarionWowProgression/HonorTitleCapture.lua",
)
FIXED_TIME = (2020, 1, 1, 0, 0, 0)


def field(toc, name):
    values = [line.partition(":")[2].strip() for line in toc.splitlines()
              if line.startswith("## " + name + ":")]
    if len(values) > 1:
        raise ValueError("duplicate " + name)
    return [value.strip() for value in values[0].split(",") if value.strip()] if values else []


def saved_variables(toc):
    return field(toc, "SavedVariables")


def dependencies(toc):
    return field(toc, "Dependencies")


def runtime_files(toc):
    return [line.strip() for line in toc.splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def validate_archive(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if names != list(FILES) or len(names) != len(set(names)):
            raise ValueError("archive must contain precisely the seven declared runtime files")
        main = archive.read("MclarionWow/MclarionWow.toc").decode("utf-8")
        extra = archive.read("MclarionWowProgression/MclarionWowProgression.toc").decode("utf-8")
        if saved_variables(main) != ["MclarionWowData"] or dependencies(main):
            raise ValueError("legacy save owner or dependency changed")
        if saved_variables(extra) != ["MclarionWowQuestData", "MclarionWowReputationData", "MclarionWowWealthData", "MclarionWowHonorTitleData"] or dependencies(extra) != ["MclarionWow"]:
            raise ValueError("progression must own all four companion data roots and require legacy addon")
        for folder, toc, expected in (("MclarionWow", main, ["MclarionWow.lua"]),
                                       ("MclarionWowProgression", extra, ["QuestCapture.lua", "ReputationCapture.lua", "WealthCapture.lua", "HonorTitleCapture.lua"])):
            if runtime_files(toc) != expected:
                raise ValueError("unexpected or missing runtime script for " + folder)
            for script in runtime_files(toc):
                if folder + "/" + script not in names:
                    raise ValueError("missing runtime script " + script)
        for filename in names:
            if not archive.read(filename):
                raise ValueError("empty runtime file " + filename)
        if archive.testzip() is not None:
            raise ValueError("corrupt package")


def build(root, output):
    root, output = Path(root), Path(output)
    data = {
        "MclarionWow/MclarionWow.lua": (root / "MclarionWow.lua").read_bytes(),
        "MclarionWow/MclarionWow.toc": (root / "MclarionWow.toc").read_bytes(),
        "MclarionWowProgression/MclarionWowProgression.toc":
            (root / "MclarionWowProgression" / "MclarionWowProgression.toc").read_bytes(),
        "MclarionWowProgression/QuestCapture.lua": (root / "QuestCapture.lua").read_bytes(),
        "MclarionWowProgression/ReputationCapture.lua": (root / "ReputationCapture.lua").read_bytes(),
        "MclarionWowProgression/WealthCapture.lua": (root / "WealthCapture.lua").read_bytes(),
        "MclarionWowProgression/HonorTitleCapture.lua": (root / "HonorTitleCapture.lua").read_bytes(),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w") as archive:
        for name in FILES:
            entry = zipfile.ZipInfo(name, FIXED_TIME)
            entry.compress_type = zipfile.ZIP_STORED
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, data[name])
    validate_archive(output)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="offline candidate ZIP path")
    args = parser.parse_args()
    result = build(Path(__file__).resolve().parents[1], args.output)
    print(result.resolve())
