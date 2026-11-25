import errno
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from resolve_compat import convert


class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source = self.root / '中文 工程.drp'
        with zipfile.ZipFile(self.source, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr('project.xml', b'<!--DbAppVer="21.0.4.0005" DbPrjVer="17"--><ProjectVersion>17</ProjectVersion><ListMgt::Thing/>')
            z.writestr('media.dat', b'\x00\xffunchanged')
        self.before = self.source.read_bytes()

    def tearDown(self):
        self.tmp.cleanup()

    def test_preserves_payload_and_source(self):
        output = convert(self.source)
        with zipfile.ZipFile(output) as z:
            self.assertEqual(z.read('media.dat'), b'\x00\xffunchanged')
            self.assertIn(b'<ListMgt::Thing/>', z.read('project.xml'))
            self.assertIn(b'<ProjectVersion>15</ProjectVersion>', z.read('project.xml'))
        self.assertEqual(self.source.read_bytes(), self.before)

    def test_refuses_overwrite(self):
        out = convert(self.source)
        before = out.read_bytes()
        with self.assertRaises(ValueError):
            convert(self.source, out)
        self.assertEqual(out.read_bytes(), before)

    def test_mounted_volume_without_hardlinks(self):
        with patch('resolve_compat.os.link', side_effect=OSError(errno.ENOTSUP, 'not supported')):
            self.assertTrue(convert(self.source).is_file())
        self.assertEqual(self.source.read_bytes(), self.before)

    def test_resolve20_to19(self):
        source = self.root / 'Resolve20.drp'
        with zipfile.ZipFile(source, 'w') as z:
            z.writestr('project.xml', b'<!--DbAppVer="20.3.3.0010" DbPrjVer="15"--><ProjectVersion>15</ProjectVersion>')
            z.writestr('media.dat', b'unchanged')
        before = source.read_bytes()
        out = convert(source)
        self.assertIn('Resolve19', out.name)
        with zipfile.ZipFile(out) as z:
            self.assertIn(b'<ProjectVersion>14</ProjectVersion>', z.read('project.xml'))
            self.assertIn(b'DbPrjVer="14"', z.read('project.xml'))
            self.assertIn(b'DbAppVer="19.1.4.0011"', z.read('project.xml'))
            self.assertEqual(z.read('media.dat'), b'unchanged')
        self.assertEqual(source.read_bytes(), before)

    def test_manual21_to19(self):
        out = convert(self.source, target=19)
        with zipfile.ZipFile(out) as z:
            self.assertIn(b'<ProjectVersion>14</ProjectVersion>', z.read('project.xml'))
            self.assertIn(b'DbAppVer="19.1.4.0011"', z.read('project.xml'))
        self.assertIn('Resolve19', out.name)

    def test_archive_output_beside_archive(self):
        dra = self.root / '归档.dra'
        dra.mkdir()
        (dra / 'project.drp').write_bytes(self.before)
        out = convert(dra)
        self.assertEqual(out.parent, dra.parent.resolve())
        self.assertTrue(out.name.startswith('归档_Resolve20'))
        self.assertFalse((dra / out.name).exists())

    def test_refuses_same_version_target(self):
        source = self.root / 'Resolve20.drp'
        with zipfile.ZipFile(source, 'w') as z:
            z.writestr('project.xml', b'<ProjectVersion>15</ProjectVersion>')
        with self.assertRaises(ValueError):
            convert(source, target=20)

    def test_rejects_other_project_version(self):
        source = self.root / 'old.drp'
        with zipfile.ZipFile(source, 'w') as z:
            z.writestr('project.xml', b'<ProjectVersion>14</ProjectVersion>')
        with self.assertRaises(ValueError):
            convert(source)
        self.assertFalse((self.root / 'old_Resolve20_实验兼容.drp').exists())

if __name__ == '__main__':
    unittest.main()
