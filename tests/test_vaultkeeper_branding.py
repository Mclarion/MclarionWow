"""Vaultkeeper branding must not rename established save owners."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ICON = r"Interface\AddOns\MclarionWow\VaultkeeperIcon.tga"

class BrandingTests(unittest.TestCase):
    def test_titles_alias_and_texture(self):
        main = (ROOT / "MclarionWow.toc").read_text()
        extra = (ROOT / "MclarionWowProgression/MclarionWowProgression.toc").read_text()
        self.assertIn("## Title: Vaultkeeper\n", main)
        self.assertIn("## Title: Vaultkeeper Progression\n", extra)
        self.assertIn("## SavedVariables: MclarionWowData\n", main)
        self.assertIn("## Dependencies: MclarionWow\n", extra)
        source = (ROOT / "MclarionWow.lua").read_text()
        self.assertIn('SLASH_MCLARIONWOWUI2 = "/vaultkeeper"', source)
        self.assertIn('SLASH_MCLARIONWOWUI1 = "/mhwowui"', source)
        self.assertIn(ICON.replace('\\', '\\\\'), source)
        self.assertNotIn('print("MclarionWow:', source)
        self.assertIn(ICON.replace('\\', '\\\\'), (ROOT / "DashboardUI.lua").read_text())

    def test_packaged_icon_is_uncompressed_rgba_tga(self):
        spec = importlib.util.spec_from_file_location("candidate", ROOT / "scripts/build_candidate.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "Vaultkeeper-0.12.5-candidate.zip"
            module.build(ROOT, output)
            first = output.read_bytes()
            module.build(ROOT, output)
            self.assertEqual(first, output.read_bytes())
            with zipfile.ZipFile(output) as archive:
                data = archive.read("MclarionWow/VaultkeeperIcon.tga")
                self.assertEqual(data, (ROOT / "Assets/VaultkeeperIcon.tga").read_bytes())
                self.assertEqual(data[1:3], bytes([0, 2]))
                self.assertEqual(struct.unpack_from('<HH', data, 12), (128, 128))
                self.assertEqual(data[16], 32)
                self.assertEqual(data[17] & 15, 8)
                self.assertGreaterEqual(len(data), 18 + 128 * 128 * 4)

if __name__ == '__main__':
    unittest.main()
