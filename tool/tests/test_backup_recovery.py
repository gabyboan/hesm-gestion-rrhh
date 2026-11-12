import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import uuid
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import backup_recovery as recovery


class RecoveryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = tempfile.TemporaryDirectory()
        cls.root = Path(cls.folder.name)
        cls.public = cls.root / 'public.pem'
        cls.private = cls.root / 'private.pem'
        cls.password = 'fixture-recovery-passphrase-2026'
        recovery.generate_keys(cls.public, cls.private, cls.password)

    @classmethod
    def tearDownClass(cls):
        cls.folder.cleanup()

    def test_key_can_be_recovered_without_the_original_windows_profile(self):
        key = bytes(range(32))
        key_id = str(uuid.uuid4())
        packet = recovery.wrap_key(key, key_id, self.public.read_bytes())
        self.assertNotIn(key.hex(), json.dumps(packet))
        self.assertEqual(recovery.unwrap_key(packet, self.private.read_bytes(), self.password), key)
        with self.assertRaises(ValueError):
            recovery.unwrap_key(packet, self.private.read_bytes(), 'wrong-password')

    def test_tampering_and_changing_key_id_are_rejected(self):
        packet = recovery.wrap_key(bytes(32), str(uuid.uuid4()), self.public.read_bytes())
        packet['key_id'] = str(uuid.uuid4())
        with self.assertRaises(ValueError):
            recovery.unwrap_key(packet, self.private.read_bytes(), self.password)

    def test_external_copy_is_identical_and_has_a_completion_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'local' / 'run-1'
            source.mkdir(parents=True)
            archive = source / 'fixture.hesmbackup'
            archive.write_bytes(b'fixture-encrypted-backup-bytes')
            result = recovery.copy_external(archive, bytes(32), str(uuid.uuid4()),
                {'destination': str(root / 'external'), 'public_key': str(self.public)})
            output = Path(result['destination'])
            self.assertEqual((output / archive.name).read_bytes(), archive.read_bytes())
            self.assertEqual(json.loads((output / 'complete.json').read_text())['sha256'],
                hashlib.sha256(archive.read_bytes()).hexdigest())
            packet = json.loads((output / 'recovery.json').read_text())
            self.assertEqual(recovery.unwrap_key(packet, self.private.read_bytes(), self.password), bytes(32))

    def test_failed_copy_does_not_claim_completion_or_delete_local_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'local' / 'run-2'
            source.mkdir(parents=True)
            archive = source / 'fixture.hesmbackup'
            archive.write_bytes(b'fixture-encrypted-backup')
            with patch.object(recovery, '_copy_verified', side_effect=OSError('fixture offline')):
                with self.assertRaises(OSError):
                    recovery.copy_external(archive, bytes(32), str(uuid.uuid4()),
                        {'destination': str(root / 'external'), 'public_key': str(self.public)})
            self.assertTrue(archive.exists())
            self.assertFalse((root / 'external' / 'run-2' / 'complete.json').exists())


if __name__ == '__main__':
    unittest.main()
