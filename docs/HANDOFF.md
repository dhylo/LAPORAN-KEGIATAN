# HANDOFF

## Current branch
`main` (merge `work/sig-editor-fix`, commit `8208a26`)

## Recent commit
`8208a26` — `fix(sig): drag akurat saat zoom + state Batal + memori proyek (v0.1.1-alpha)`

## Tag
`v0.1.1-alpha`

## Status
- ✅ Merge `work/sig-editor-fix` → `main` done
- ✅ Push `main`, `work/sig-editor-fix`, tag `v0.1.1-alpha` ke `origin`
- ✅ `flutter analyze`: No issues
- ✅ `flutter build windows --debug`: sukses

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
