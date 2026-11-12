# HANDOFF

## Current branch
`main` (v0.1.2-alpha)

## Recent commit
`pending` — `fix(sig): area geser TTD + default 0.75 (v0.1.2-alpha)`

## Tag
`v0.1.2-alpha`

## Status
- ✅ Merge `work/sig-editor-fix` → `main` done
- ✅ `sigLayoutVersion = 9` (reset data lama ke default aman)
- ✅ `_sigDefaultScale = 0.75`
- ✅ Garis bantu editor menunjukkan area drag penuh (33 pt up)
- ✅ `flutter analyze`: No issues

## File changes (v0.1.1-alpha)
- `lib/main.dart`: `_loadSavedSigPosition()`, drag delta poin, `_cacheSignature()` sebelum `setState`
- `pubspec.yaml`: `version: 0.1.1-alpha+1`
- `CHANGELOG.md`: entri `v0.1.1-alpha`
- `docs/`: memori proyek lengkap

## Configuration
- `devtools_options.yaml`: committed
- `OUTPUT CONTOH INSPEKSI BULANAN.pdf`: reference output

## Commit convention
- Format: `<type>(sig): <descriptions> (<tag>)`
- Tag: `vX.X.X-alpha`
- Batal otomatis revert karena `_enterEditMode()` selalu baca ulang posisi dari data

## Guard pattern
- `sigMoveH.clamp(1.0, double.infinity)` dipakai di drag handler untuk mencegah pembagi nol (defensif, bukan bug).
