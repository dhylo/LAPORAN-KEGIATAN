# HANDOFF

## Current branch
`work/sig-editor-fix`

## Recent commit
`8a637a8` — `fix(sig): revert posisi saat Batal + sinkron dokumen (v0.1.1-alpha)`

## Tag
`v0.1.1-alpha`

## Next steps (user)
1. Merge ke `main`
2. Push tag `v0.1.1-alpha`
3. Build release Windows/Mac/Linux/Android/iOS
4. Test TTD drag accuracy di semua platform

## Known issues
- None

## File changes
- `lib/main.dart`: editor TTD, rendering layout baru, `_loadSavedSigPosition()`, urutan state/cache
- `pubspec.yaml`: `version: 0.1.1-alpha+1`
- `CHANGELOG.md`: entri `v0.1.1-alpha` (perbaikan Batal + guard)
- `docs/`: memori proyek lengkap

## Configuration
- `devtools_options.yaml`: already committed
- `OUTPUT CONTOH INSPEKSI BULANAN.pdf`: reference output

## Commit convention
- Format: `<type>(sig): <descriptions> (<tag>)`
- Tag: `vX.X.X-alpha`
- Batal otomatis revert karena `_enterEditMode()` selalu baca ulang posisi dari data

## Guard pattern
- `sigMoveH.clamp(1.0, double.infinity)` dipakai di drag handler untuk mencegah pembagi nol (defensif, bukan bug).
