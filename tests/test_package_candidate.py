"""Offline, deterministic two-addon packaging contract."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "build_candidate.py"


class CandidatePackageTests(unittest.TestCase):
    def test_two_distinct_saved_variable_owners_and_complete_runtime(self):
        spec = importlib.util.spec_from_file_location("build_candidate", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "candidate.zip"
            module.build(ROOT, output)
            first = output.read_bytes()
            module.build(ROOT, output)
            self.assertEqual(first, output.read_bytes(), "identical source gives identical archive")
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                self.assertEqual(names, [
                    "MclarionWow/DashboardSummary.lua", "MclarionWow/DashboardDetails.lua", "MclarionWow/DashboardUI.lua",
                    "MclarionWow/MclarionWow.lua", "MclarionWow/MclarionWow.toc",
                    "MclarionWowProgression/MclarionWowProgression.toc",
                    "MclarionWowProgression/QuestCapture.lua",
                    "MclarionWowProgression/ReputationCapture.lua",
                    "MclarionWowProgression/WealthCapture.lua",
                    "MclarionWowProgression/HonorTitleCapture.lua",
                ])
                main = archive.read("MclarionWow/MclarionWow.toc").decode()
                progression = archive.read("MclarionWowProgression/MclarionWowProgression.toc").decode()
                self.assertEqual(module.saved_variables(main), ["MclarionWowData"])
                self.assertEqual(module.saved_variables(progression), ["MclarionWowQuestData", "MclarionWowReputationData", "MclarionWowWealthData", "MclarionWowHonorTitleData"])
                self.assertEqual(module.dependencies(progression), ["MclarionWow"])
                self.assertEqual(module.runtime_files(main), ["DashboardSummary.lua", "DashboardDetails.lua", "DashboardUI.lua", "MclarionWow.lua"])
                self.assertIn("## Version: 0.12.4-candidate", main)
                self.assertIn("## Version: 0.12.4-candidate", progression)
                self.assertEqual(module.runtime_files(progression), ["QuestCapture.lua", "ReputationCapture.lua", "WealthCapture.lua", "HonorTitleCapture.lua"])
                for folder, toc in (("MclarionWow", main), ("MclarionWowProgression", progression)):
                    for script in module.runtime_files(toc):
                        self.assertIn(folder + "/" + script, names)
                for script in ("QuestCapture.lua", "ReputationCapture.lua",
                               "WealthCapture.lua", "HonorTitleCapture.lua"):
                    self.assertEqual(archive.read("MclarionWowProgression/" + script),
                                     (ROOT / script).read_bytes())
                for script in ("DashboardSummary.lua", "DashboardDetails.lua", "DashboardUI.lua", "MclarionWow.lua"):
                    self.assertEqual(archive.read("MclarionWow/" + script),
                                     (ROOT / script).read_bytes())
                module.validate_archive(output)

    def test_missing_dependency_is_rejected(self):
        spec = importlib.util.spec_from_file_location("build_candidate", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            broken = Path(directory) / "broken.zip"
            with zipfile.ZipFile(broken, "w") as archive:
                archive.writestr("MclarionWowProgression/MclarionWowProgression.toc",
                                 "## SavedVariables: MclarionWowQuestData\n## Dependencies: MclarionWow\nQuestCapture.lua\n")
                archive.writestr("MclarionWowProgression/QuestCapture.lua", b"-- dummy")
            with self.assertRaises(ValueError):
                module.validate_archive(broken)


if __name__ == "__main__":
    unittest.main()
