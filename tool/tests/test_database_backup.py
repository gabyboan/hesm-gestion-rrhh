"""Pruebas de los limites de seguridad y fallos de la tarea, sin acceso remoto."""
from contextlib import redirect_stdout
import io
import json
import msvcrt
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import backup_database as backup
import run_database_backup as scheduled


def connection(project=backup.PROJECT, host='aws-0-sa-east-1.pooler.supabase.com'):
    return (f'export PGHOST="{host}"\nexport PGPORT="5432"\n'
            f'export PGUSER="cli_login_postgres.{project}"\n'
            'export PGPASSWORD="test-secret-never-log"\nexport PGDATABASE="postgres"\n').encode()


class ConnectionTests(unittest.TestCase):
    def test_memory_input_preserves_tls_and_readonly_guards(self):
        result = backup.connection_env(connection())
        self.assertEqual(result['PGSSLMODE'], 'verify-full')
        self.assertIn('default_transaction_read_only=on', result['PGOPTIONS'])
        self.assertEqual(result['PGPASSWORD'], 'test-secret-never-log')

    def test_rejects_wrong_project_and_external_host(self):
        for raw in (connection(project='anotherproject'), connection(host='example.com')):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                backup.connection_env(raw)


class SchedulerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repodir = self.root / 'repo'
        linked = self.repodir / 'supabase' / '.temp' / 'project-ref'
        linked.parent.mkdir(parents=True)
        linked.write_text(backup.PROJECT, encoding='utf-8')
        self.output = self.root / 'backups'
        self.output.mkdir()
        self.keydir = self.root / 'keys'
        self.argv = ['run_database_backup.py', '--backup-root', str(self.output),
                     '--key-dir', str(self.keydir)]
        self.good = b'{"estado":"verificado","previous":"keep-me"}'
        (self.output / 'last-success.json').write_bytes(self.good)

    def invoke(self):
        captured = io.StringIO()
        with (patch.object(scheduled, 'REPO', self.repodir),
              patch.object(sys, 'argv', self.argv),
              patch.object(scheduled.shutil, 'which', side_effect=lambda name: name),
              redirect_stdout(captured)):
            result = scheduled.main()
        return result, captured.getvalue()

    def test_failure_keeps_last_good_copy_and_encrypts_diagnostics(self):
        with patch.object(scheduled, 'prepare_docker', side_effect=RuntimeError('private-test-detail')):
            result, output = self.invoke()
        self.assertEqual(result, 1)
        self.assertNotIn('private-test-detail', output)
        self.assertEqual((self.output / 'last-success.json').read_bytes(), self.good)
        status = json.loads((self.output / 'last-run.json').read_text(encoding='utf-8'))
        self.assertEqual(status['estado'], 'fallido')
        encrypted = next(self.output.glob('*/tarea-error.aesgcm')).read_bytes()
        self.assertNotIn(b'private-test-detail', encrypted)
        key = backup.dpapi(next(self.keydir.glob('*.dpapi')).read_bytes(), decrypt=True)
        clear, _ = backup.unseal(encrypted, key)
        self.assertIn(b'private-test-detail', clear)

    def test_second_process_cannot_start_overlapping_backup(self):
        with (self.output / '.backup.lock').open('w+b') as lock:
            lock.write(b'0')
            lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            try:
                with patch.object(scheduled, 'prepare_docker') as docker:
                    result, output = self.invoke()
                self.assertEqual(result, 0)
                self.assertIn('ejecucion_omitida', output)
                docker.assert_not_called()
                self.assertFalse((self.output / 'last-run.json').exists())
            finally:
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)

    def test_slow_docker_start_does_not_abort_backup(self):
        completed = subprocess.CompletedProcess([], 0, stdout=b'linux\n', stderr=b'')
        startup = subprocess.TimeoutExpired(['docker', 'info'], 10)
        with patch.object(scheduled, 'native', side_effect=[startup, completed, completed, completed]):
            scheduled.prepare_docker('docker', unittest.mock.Mock())


if __name__ == '__main__':
    unittest.main()
