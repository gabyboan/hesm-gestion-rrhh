"""Copia logica cifrada y restauracion sin red. No restaura en produccion.

Windows: la clave AES se protege con DPAPI CurrentUser y se guarda separada.
Los datos claros solo pasan por memoria y por tmpfs del contenedor de ensayo.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import traceback
import uuid
import urllib.request
import zipfile
from datetime import datetime, timezone

import psycopg
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

PROJECT = 'zdieotecewtkcxlxonpb'
IMAGE = 'supabase/postgres:17.6.1.054'
RESTORE_ADMIN = 'supabase_admin'
MAGIC = b'HESMBACKUP1\n'
ENTROPY = b'HESM-RRHH-database-backup-v1'


def emit(stage: str, **details):
    print(json.dumps({'etapa': stage, **details}, ensure_ascii=False), flush=True)


def restricted_dir(path: Path):
    path.mkdir(parents=True, exist_ok=True)
    # Los SID evitan depender del idioma de Windows. Nunca imprimir secretos.
    user = subprocess.check_output(['whoami', '/user', '/fo', 'csv', '/nh'], text=True)
    sid = re.search(r'S-1-5-[0-9-]+', user).group()
    result = subprocess.run(['icacls', str(path), '/inheritance:r', '/grant:r',
                             f'*{sid}:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F'], capture_output=True)
    if result.returncode:
        raise RuntimeError('No se pudo restringir la carpeta privada.')


class Blob(ctypes.Structure):
    _fields_ = [('cbData', wintypes.DWORD), ('pbData', ctypes.POINTER(ctypes.c_ubyte))]


def dpapi(data: bytes, decrypt=False) -> bytes:
    def blob(value):
        buf = (ctypes.c_ubyte * len(value)).from_buffer_copy(value)
        return Blob(len(value), buf), buf
    src, src_buf = blob(data)
    entropy, entropy_buf = blob(ENTROPY)
    dst = Blob()
    api = ctypes.windll.crypt32.CryptUnprotectData if decrypt else ctypes.windll.crypt32.CryptProtectData
    api.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.POINTER(Blob),
                    ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(Blob)]
    api.restype = wintypes.BOOL
    if not api(ctypes.byref(src), None, ctypes.byref(entropy), None, None, 1, ctypes.byref(dst)):
        raise RuntimeError('DPAPI no pudo proteger/recuperar la clave con esta cuenta Windows.')
    try:
        return ctypes.string_at(dst.pbData, dst.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(dst.pbData)


def seal(data: bytes, key: bytes, metadata: dict) -> bytes:
    header = json.dumps(metadata, sort_keys=True, separators=(',', ':')).encode()
    nonce = os.urandom(12)
    return MAGIC + len(header).to_bytes(4, 'big') + header + nonce + AESGCM(key).encrypt(nonce, data, header)


def unseal(data: bytes, key: bytes):
    if not data.startswith(MAGIC):
        raise ValueError('Formato de copia no reconocido.')
    start = len(MAGIC)
    size = int.from_bytes(data[start:start+4], 'big')
    if size > 65536:
        raise ValueError('Cabecera de copia invalida.')
    header = data[start+4:start+4+size]
    nonce_start = start+4+size
    clear = AESGCM(key).decrypt(data[nonce_start:nonce_start+12], data[nonce_start+12:], header)
    return clear, json.loads(header)


class Job:
    def __init__(self, output: Path, key_dir: Path, key_id: str | None = None):
        self.output = output.resolve()
        restricted_dir(self.output)
        self.key_dir = key_dir.resolve()
        restricted_dir(self.key_dir)
        self.key_id = key_id or str(uuid.uuid4())
        key_path = self.key_dir / (self.key_id+'.dpapi')
        if key_id:
            self.key = dpapi(key_path.read_bytes(), decrypt=True)
        else:
            self.key = AESGCM.generate_key(bit_length=256)
            key_path.write_bytes(dpapi(self.key))
        self.container = None

    def private_log(self, name: str, data: bytes):
        if data:
            (self.output/(name+'.aesgcm')).write_bytes(seal(data, self.key, {'key_id': self.key_id, 'tipo': 'log'}))

    def run(self, args, *, data=None, env=None, label='comando', timeout=180):
        result = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env=env, timeout=timeout)
        self.private_log(label+'-stderr', result.stderr)
        if result.returncode:
            raise RuntimeError(f'Fallo {label}; detalles guardados cifrados. Codigo {result.returncode}.')
        return result.stdout

    def docker_client(self, command, env=None, **kwargs):
        argv = ['docker','run','--rm','--network','bridge']
        argv += ['--mount',f'type=bind,source={self.output / "ca-publica.pem"},target=/tmp/supabase-ca.crt,readonly']
        for name in ['PGHOST','PGPORT','PGUSER','PGPASSWORD','PGDATABASE','PGSSLMODE','PGSSLROOTCERT','PGOPTIONS']:
            if env and name in env:
                argv += ['--env',name]
        return self.run(argv+['--entrypoint',command[0],IMAGE]+command[1:], env=env, **kwargs)

    def local(self, command, **kwargs):
        if not self.container:
            raise RuntimeError('No hay contenedor aislado para restaurar.')
        return self.run(['docker','exec','-i',self.container]+command, **kwargs)

    def local_sql(self, query, database='hesm_restore_test', label='sql-local', timeout=180):
        return self.local(['psql','-X','-q','-A','-t','-h','/tmp','-U',RESTORE_ADMIN,
                          '-d',database,'-v','ON_ERROR_STOP=1'], data=query.encode(), label=label, timeout=timeout)


def connection_env(path: Path | bytes):
    # La tarea semanal recibe el dry-run por memoria, sin persistir credenciales.
    raw = path if isinstance(path, bytes) else path.read_bytes()
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    values = {}
    for line in text.splitlines():
        if line.startswith('export PG'):
            for word in shlex.split(line.removeprefix('export ')):
                name, value = word.split('=',1)
                values[name] = value
    if not all(k in values for k in ['PGHOST','PGPORT','PGUSER','PGPASSWORD','PGDATABASE']):
        raise ValueError('Faltan los parametros temporales generados por la CLI.')
    if not values['PGHOST'].endswith(('.supabase.co','.pooler.supabase.com')) or values['PGDATABASE'] != 'postgres':
        raise ValueError('El origen no coincide con una base Supabase postgres.')
    if PROJECT not in values['PGUSER'] and PROJECT not in values['PGHOST']:
        raise ValueError('La conexion no corresponde al proyecto HESM autorizado.')
    values['PGSSLMODE'] = 'verify-full'
    values['PGSSLROOTCERT'] = '/tmp/supabase-ca.crt'
    values['PGOPTIONS'] = '-c default_transaction_read_only=on -c statement_timeout=180000'
    return values


def schema_grants(manifest: dict) -> str:
    """pg_dump omite algunos grants de esquemas pertenecientes a extensiones."""
    def ident(value):
        return '"'+value.replace('"','""')+'"'
    statements=[]
    for schema in manifest.get('esquemas',[]):
        for grantee,grantor,privilege,grantable in schema['acl'] or []:
            if privilege not in {'USAGE','CREATE'}:
                raise ValueError('Privilegio de esquema inesperado.')
            target='PUBLIC' if grantee=='PUBLIC' else ident(grantee)
            statements += ['SET ROLE '+ident(grantor)+';',
                'GRANT '+privilege+' ON SCHEMA '+ident(schema['nombre'])+' TO '+target+
                (' WITH GRANT OPTION' if grantable else '')+';','RESET ROLE;']
    return '\n'.join(statements)+'\n'


MANIFEST_SQL = r"""
with tablas as (
 select c.oid,n.nspname,c.relname,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind in ('r','p') and n.nspname not like 'pg_%' and n.nspname<>'information_schema'
), datos as materialized (
 select nspname,relname,query_to_xml(format(
  'select count(*) as filas,md5(coalesce(string_agg(h, '''' order by h),'''')) as huella from (select md5(to_jsonb(t)::text) as h from %I.%I t) x',
  nspname,relname),false,true,'') as x from tablas
), estructura as (
 select t.nspname as esquema,t.relname as tabla,pg_get_userbyid(t.relowner) as propietario,
  t.relrowsecurity as rls,t.relforcerowsecurity as rls_forzado,
  (select jsonb_agg(jsonb_build_object('grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
   'grantor',pg_get_userbyid(a.grantor),'privilegio',a.privilege_type,'opcion',a.is_grantable)
   order by case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,pg_get_userbyid(a.grantor),a.privilege_type)
   from aclexplode(coalesce(t.relacl,acldefault('r',t.relowner))) a) as acl,
  (select jsonb_agg(jsonb_build_object('nombre',a.attname,'tipo',format_type(a.atttypid,a.atttypmod),'no_nulo',a.attnotnull,
   'identidad',a.attidentity,'generada',a.attgenerated,'default',pg_get_expr(d.adbin,d.adrelid)) order by a.attnum)
   from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
   where a.attrelid=t.oid and a.attnum>0 and not a.attisdropped) as columnas
 from tablas t where not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass and d.objid=t.oid and d.deptype='e')
)
select jsonb_build_object(
 'datos',(select jsonb_agg(jsonb_build_object('esquema',nspname,'tabla',relname,
   'filas',((xpath('/row/filas/text()',x))[1]::text)::bigint,
   'huella',(xpath('/row/huella/text()',x))[1]::text) order by nspname,relname) from datos),
 'tablas',(select jsonb_agg(to_jsonb(e) order by esquema,tabla) from estructura e),
 'politicas',(select jsonb_agg(to_jsonb(p) order by schemaname,tablename,policyname) from pg_policies p
   where schemaname not like 'pg_%' and schemaname<>'information_schema'),
 'funciones',(select jsonb_agg(jsonb_build_object('esquema',n.nspname,'firma',p.oid::regprocedure::text,
   'definicion',md5(replace(pg_get_functiondef(p.oid),E'\r\n',E'\n')),'definer',p.prosecdef,
   'propietario',pg_get_userbyid(p.proowner),'config',p.proconfig,
   'acl',(select jsonb_agg(v order by v::text) from (
     select jsonb_build_array(case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       pg_get_userbyid(a.grantor),a.privilege_type,a.is_grantable) v
     from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a) q)) order by n.nspname,p.oid::regprocedure::text)
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname not like 'pg_%' and n.nspname<>'information_schema' and p.prokind='f'
   and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e')),
 'constraints',(select jsonb_agg(jsonb_build_object('esquema',n.nspname,'tabla',c.conrelid::regclass::text,
   'nombre',c.conname,'validada',c.convalidated,'definicion',pg_get_constraintdef(c.oid))
   order by n.nspname,c.conrelid::regclass::text,c.conname) from pg_constraint c
   join pg_namespace n on n.oid=c.connamespace where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
   and not exists(select 1 from pg_depend d where d.classid='pg_constraint'::regclass and d.objid=c.oid and d.deptype='e')),
 'indices',(select jsonb_agg(jsonb_build_object('esquema',n.nspname,'nombre',ix.relname,
   'valido',i.indisvalid,'definicion',pg_get_indexdef(i.indexrelid)) order by n.nspname,ix.relname)
   from pg_index i join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace
   join pg_class ix on ix.oid=i.indexrelid where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
   and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass and d.objid=i.indexrelid and d.deptype='e')),
 'vistas',(select jsonb_agg(jsonb_build_object('esquema',n.nspname,'nombre',c.relname,'opciones',c.reloptions,
   'propietario',pg_get_userbyid(c.relowner),
   'acl',(select jsonb_agg(v order by v::text) from (
     select jsonb_build_array(case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       pg_get_userbyid(a.grantor),a.privilege_type,a.is_grantable) v
     from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a) q),
   'definicion',md5(pg_get_viewdef(c.oid,true))) order by n.nspname,c.relname)
   from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('v','m')
   and n.nspname not like 'pg_%' and n.nspname<>'information_schema'
   and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e')),
 'esquemas',(select jsonb_agg(jsonb_build_object('nombre',n.nspname,'propietario',pg_get_userbyid(n.nspowner),
   'acl',(select jsonb_agg(v order by v::text) from (
     select jsonb_build_array(case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       pg_get_userbyid(a.grantor),a.privilege_type,a.is_grantable) v
     from aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a) q)) order by n.nspname)
   from pg_namespace n where n.nspname not like 'pg_%' and n.nspname<>'information_schema'),
 'permisos_futuros',(select jsonb_agg(jsonb_build_object('rol',pg_get_userbyid(d.defaclrole),
   'esquema',coalesce(n.nspname,''),'tipo',d.defaclobjtype,
   'acl',(select jsonb_agg(v order by v::text) from (
     select jsonb_build_array(case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
       pg_get_userbyid(a.grantor),a.privilege_type,a.is_grantable) v
     from aclexplode(d.defaclacl) a) q)) order by pg_get_userbyid(d.defaclrole),n.nspname,d.defaclobjtype)
   from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace),
 'roles',(select jsonb_agg(jsonb_build_object('nombre',rolname,'superuser',rolsuper,'hereda',rolinherit,
   'crea_rol',rolcreaterole,'crea_db',rolcreatedb,'login',rolcanlogin,'replica',rolreplication,
   'bypassrls',rolbypassrls,'limite',rolconnlimit,'config',rolconfig) order by rolname) from pg_roles),
 'membresias',(select jsonb_agg(jsonb_build_array(pg_get_userbyid(roleid),pg_get_userbyid(member),
   pg_get_userbyid(grantor),admin_option,inherit_option,set_option)
   order by pg_get_userbyid(roleid),pg_get_userbyid(member),pg_get_userbyid(grantor)) from pg_auth_members),
 'triggers',(select jsonb_agg(jsonb_build_object('esquema',n.nspname,'tabla',c.relname,'nombre',t.tgname,
   'habilitado',t.tgenabled,'definicion',pg_get_triggerdef(t.oid)) order by n.nspname,c.relname,t.tgname)
   from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
   where not t.tgisinternal and n.nspname not like 'pg_%'
   and not exists(select 1 from pg_depend d where d.classid='pg_trigger'::regclass and d.objid=t.oid and d.deptype='e')),
 'secuencias',(select jsonb_agg(to_jsonb(s)-'last_value' order by schemaname,sequencename) from pg_sequences s
   where schemaname not like 'pg_%'),
 'extensiones',(select jsonb_agg(jsonb_build_array(e.extname,e.extversion,n.nspname)
   order by e.extname) from pg_extension e join pg_namespace n on n.oid=e.extnamespace)
) as manifiesto;
"""


def source_backup(job: Job, script: Path | bytes):
    connection = connection_env(script)
    env = {**os.environ, **connection}
    with urllib.request.urlopen('https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt',timeout=30) as response:
        ca = response.read(65536)
    if b'-----BEGIN CERTIFICATE-----' not in ca:
        raise ValueError('No se recibio el certificado publico de Supabase.')
    ca_file=job.output/'ca-publica.pem'
    ca_file.write_bytes(ca)
    args = {k.lower().removeprefix('pg'):v for k,v in connection.items()
            if k in {'PGHOST','PGPORT','PGUSER','PGPASSWORD','PGDATABASE'}}
    args['dbname']=args.pop('database')
    emit('conectando_origen_tls_verificado')
    with psycopg.connect(**args, sslmode='verify-full', sslrootcert=str(ca_file),
                         connect_timeout=20, application_name='hesm_backup_readonly', autocommit=True) as db:
        db.execute('set role postgres')
        db.execute('begin isolation level repeatable read read only')
        db.execute("set local timezone='UTC'; set local search_path=public,extensions; set local statement_timeout='180s'")
        info=db.execute("""select jsonb_build_object('version',current_setting('server_version'),
          'db',current_database(),'collate',d.datcollate,'ctype',d.datctype,'provider',d.datlocprovider,
          'encoding',pg_encoding_to_char(d.encoding),'locale',to_jsonb(d)->>'datlocale',
          'postgres_super',(select rolsuper from pg_roles where rolname='postgres'),
          'vault_secrets',(select count(*) from vault.secrets),
          'storage_objects',(select count(*) from storage.objects),
          'large_objects',(select count(*) from pg_largeobject_metadata))
          from pg_database d where datname=current_database()""").fetchone()[0]
        if not info['version'].startswith('17.') or info['db']!='postgres':
            raise ValueError('Version/base de origen inesperada.')
        snapshot=db.execute('select pg_export_snapshot()').fetchone()[0]
        emit('calculando_inventario_consistente')
        manifest=db.execute(MANIFEST_SQL).fetchone()[0]
        emit('exportando_base_completa',tablas=len(manifest['datos']))
        dump=job.docker_client(['pg_dump','--role=postgres','--format=custom','--compress=6',
            '--lock-wait-timeout=5s','--snapshot='+snapshot],env=env,label='pg-dump',timeout=240)
        if not dump.startswith(b'PGDMP'):
            raise RuntimeError('El archivo recibido no es un archivo custom de pg_dump.')
        roles=job.docker_client(['pg_dumpall','--roles-only','--no-role-passwords','--role=postgres'],
                               env=env,label='roles',timeout=90)
        db.execute('rollback')
    info['project_ref']=PROJECT
    info['created_at_utc']=datetime.now(timezone.utc).isoformat()
    info['image']=IMAGE
    info['dump_sha256']=hashlib.sha256(dump).hexdigest()
    info['roles_sha256']=hashlib.sha256(roles).hexdigest()
    info['snapshot_consistente']=True
    buffer=io.BytesIO()
    with zipfile.ZipFile(buffer,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('database.dump',dump)
        z.writestr('roles.sql',roles)
        z.writestr('source.json',json.dumps(info,ensure_ascii=False))
        z.writestr('manifest.json',json.dumps(manifest,ensure_ascii=False))
        z.writestr('manifest-query.sql',MANIFEST_SQL)
        z.writestr('schema-grants.sql',schema_grants(manifest))
    archive=job.output/'HESM-SUPLENCIAS.hesmbackup'
    archive.write_bytes(seal(buffer.getvalue(),job.key,{'key_id':job.key_id,'project_ref':PROJECT,'tipo':'backup-logico'}))
    del dump,roles
    emit('copia_cifrada_guardada',archivo=str(archive),bytes=archive.stat().st_size)
    return archive


def restore_test(job: Job, archive: Path, after_restore=None):
    emit('verificando_cifrado')
    clear,header=unseal(archive.read_bytes(),job.key)
    if header['project_ref']!=PROJECT:
        raise ValueError('La copia corresponde a otro proyecto.')
    with zipfile.ZipFile(io.BytesIO(clear)) as z:
        dump=z.read('database.dump')
        roles=z.read('roles.sql')
        info=json.loads(z.read('source.json'))
        expected=json.loads(z.read('manifest.json'))
        manifest_query=z.read('manifest-query.sql').decode()
        grants=z.read('schema-grants.sql').decode() if 'schema-grants.sql' in z.namelist() else schema_grants(expected)
    if hashlib.sha256(dump).hexdigest()!=info['dump_sha256'] or hashlib.sha256(roles).hexdigest()!=info['roles_sha256']:
        raise ValueError('Los hashes internos de la copia no coinciden.')
    emit('iniciando_restauracion_aislada_sin_red')
    name='hesm-restore-'+uuid.uuid4().hex[:12]
    startup="""initdb -D /restore/data -U supabase_admin --auth-local=trust --auth-host=reject --encoding=UTF8 --locale=C.UTF-8 >/tmp/initdb.log 2>&1
exec postgres -D /restore/data -c listen_addresses='' -c unix_socket_directories=/tmp -c shared_preload_libraries=pg_stat_statements -c shared_buffers=64MB -c max_connections=20 -c log_min_messages=fatal -c log_min_error_statement=panic -c log_statement=none
"""
    job.run(['docker','run','-d','--name',name,'--network','none','--user','101:102',
      '--tmpfs','/restore:rw,nosuid,mode=0700,uid=101,gid=102,size=768m',
      '--tmpfs','/tmp:rw,nosuid,mode=1777,size=256m','--shm-size','128m','--memory','1536m',
      '--pids-limit','256','--entrypoint','bash',IMAGE,'-ceu',startup],label='crear-contenedor')
    job.container=name
    try:
        for _ in range(30):
            ready=subprocess.run(['docker','exec',name,'pg_isready','-h','/tmp','-U',RESTORE_ADMIN,'-d','postgres'],
                                 capture_output=True)
            if ready.returncode==0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('No inicio el PostgreSQL aislado.')
        # El grantor original de Supabase debe ser el bootstrap superuser (PG17).
        # El resto del SQL de roles y membresias se restaura sin cambios.
        globals_sql=roles.decode().replace('CREATE ROLE supabase_admin;','',1)
        job.local_sql(globals_sql,database='postgres',label='restaurar-roles')
        job.local_sql('alter role postgres superuser;',database='postgres',label='rol-ensayo')
        create=['createdb','-h','/tmp','-U',RESTORE_ADMIN,'--template=template0',
                '--encoding='+info['encoding'],'--lc-collate='+info['collate'],'--lc-ctype='+info['ctype']]
        if info['provider']=='i':
            create+=['--locale-provider=icu','--icu-locale='+info['locale']]
        job.local(create+['hesm_restore_test'],label='crear-base')
        job.local(['bash','-ceu','cat > /restore/database.dump'],data=dump,label='cargar-archivo')
        del dump
        job.local(['pg_restore','--exit-on-error','--single-transaction','--role=postgres',
                   '-h','/tmp','-U',RESTORE_ADMIN,'-d','hesm_restore_test','/restore/database.dump'],
                  label='restauracion',timeout=240)
        job.local_sql(grants,label='grants-esquemas-extension')
        if not info['postgres_super']:
            job.local_sql('alter role postgres nosuperuser;',database='postgres',label='restaurar-atributos')
        emit('comparando_datos_y_permisos')
        actual=json.loads(job.local_sql("set timezone='UTC';set search_path=public,extensions;"+manifest_query,
                                        label='manifiesto-restaurado',timeout=180).decode())
        differences=[]
        for section in expected:
            if expected[section]!=actual[section]:
                differences.append(section)
        job.private_log('comparacion',json.dumps({'origen':expected,'restaurado':actual}).encode())
        if differences:
            raise RuntimeError('La restauracion difiere en: '+','.join(differences))
        report={'project_ref':PROJECT,'database_version':info['version'],'snapshot_consistente':True,
          'cifrado':'AES-256-GCM','clave_protegida':'DPAPI CurrentUser, fuera del repositorio',
          'key_id':job.key_id,'archive':str(archive.resolve()),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
          'tablas_comparadas':len(expected['datos']),'filas_comparadas':sum(t['filas'] for t in expected['datos']),
          'secciones_iguales':list(expected),'storage_objects':info['storage_objects'],
          'vault_secrets':info['vault_secrets'],'large_objects':info['large_objects'],
          'restauracion_aislada_sin_red':True,'verificada':True,
          'created_at_utc':info['created_at_utc']}
        (job.output/'verificacion.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
        emit('restauracion_verificada',tablas=report['tablas_comparadas'],filas=report['filas_comparadas'])
        # Extension interna para comprobar cambios exclusivamente en esta copia aislada.
        # No agrega destinos remotos ni opciones SQL a la interfaz de linea de comandos.
        if after_restore is not None:
            after_restore(job)
        return report
    finally:
        removed=subprocess.run(['docker','rm','-f',name],capture_output=True)
        if removed.returncode:
            job.private_log('limpieza-stderr',removed.stderr)
            raise RuntimeError('No se pudo retirar el contenedor de ensayo: '+name)
        job.container=None


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['create','verify'])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--key-dir',type=Path,default=Path.home()/'.hesm-backup-keys')
    parser.add_argument('--connection-script',type=Path)
    parser.add_argument('--archive',type=Path)
    args=parser.parse_args()
    if args.action=='create' and not args.connection_script:
        parser.error('create requiere --connection-script.')
    if args.action=='verify' and not args.archive:
        parser.error('verify requiere --archive.')
    if args.action=='create' and (args.output/'HESM-SUPLENCIAS.hesmbackup').exists():
        parser.error('La carpeta ya contiene una copia: elegir una carpeta nueva.')
    if sys.platform!='win32':
        raise SystemExit('Esta variante usa DPAPI de Windows.')
    key_id=None
    if args.action=='verify':
        raw=args.archive.read_bytes()
        n=len(MAGIC)
        size=int.from_bytes(raw[n:n+4],'big')
        if not raw.startswith(MAGIC) or size>65536:
            raise SystemExit('Cabecera invalida.')
        key_id=json.loads(raw[n+4:n+4+size])['key_id']
        uuid.UUID(key_id)
    job=Job(args.output,args.key_dir,key_id)
    try:
        archive=source_backup(job,args.connection_script) if args.action=='create' else args.archive
        restore_test(job,archive)
    except Exception:
        job.private_log('error',traceback.format_exc().encode())
        emit('fallo',detalle='El diagnostico se guardo cifrado. No se modifico la base de origen.')
        return 1
    return 0


if __name__=='__main__':
    raise SystemExit(main())
