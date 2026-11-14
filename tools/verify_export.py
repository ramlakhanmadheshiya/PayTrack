"""Read the exported PCK directory and refuse reference/test/doc/data leakage."""
import pathlib, struct
path = pathlib.Path('build/web/index.pck')
with path.open('rb') as file:
    def u32(): return struct.unpack('<I',file.read(4))[0]
    if u32() != 0x43504447: raise SystemExit('Invalid PCK header')
    version = u32()
    if version == 4:
        file.seek(32)
        directory = struct.unpack('<Q',file.read(8))[0]
        file.seek(directory)
    elif version == 3:
        file.seek(96)
    else: raise SystemExit(f'Review unsupported PCK format {version}')
    count = u32()
    names = []
    for _ in range(count):
        size = u32()
        name = file.read(size).rstrip(b'\0').decode()
        if not name.startswith('res://'): name = 'res://' + name
        file.read(8+8+16+4)
        names.append(name)
allowed = ('res://scripts/','res://assets/','res://scenes/','res://.godot/','res://project.binary')
for name in names:
    if not name.startswith(allowed): raise SystemExit('Unexpected packaged file: '+name)
    if any(word in name.lower() for word in ['tests/','reference','plan.md','docs/','.json','.csv']):
        raise SystemExit('Private/reference content packaged: '+name)
for required in ['res://scripts/domain/payroll.gdc','res://scripts/services/payroll_service.gdc','res://scripts/storage/repository.gdc','res://scripts/ui/app.gdc']:
    if required not in names: raise SystemExit('Missing runtime dependency: '+required)
print(f'PASS: {count} exported resources; only runtime scripts, scenes, icon and engine metadata')
