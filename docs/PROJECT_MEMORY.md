# PROJECT MEMORY

## Setup
- Working directory: `C:\lapbulterbul`
- Flutter 3.13.3, SDK ^3.13.3
- Dependencies: `pdf ^3.11.3`, `printing ^5.14.2`, `image ^4.2.0`
- Remote: `https://github.com/dhylo/LAPORAN-KEGIATAN.git`
- Branch: `main` (current: `work/sig-editor-fix`)
- Commit: `pending` (v0.2.0-alpha)
- Tag: `v0.2.0-alpha`

## File structure
- `lib/main.dart` (2563 lines): single-file app dengan all logic
- `pubspec.yaml`: versi alpha (`0.1.1-alpha+1`)
- `CHANGELOG.md`: log rilis alpha
- `docs/`: memori proyek
- `OUTPUT CONTOH INSPEKSI BULANAN.pdf`: contoh output referensi
- `devtools_options.yaml`: config tooling (committed)

## Core data model
- `Inspection`: `sigX`, `sigY` (0–1), `sigW` (0.5–1.15), `sigLayoutVersion`, `sigAbsolute`, `sigPosV2`
- `sigLayoutVersion = 9`: area drag terlihat jelas, default layout lama di-reset
- UI `v0.2.0-alpha`: shell macOS, tema light/dark, font Inter bundled

## Signature layout (PDF)
- Slot size: `_pdfSigSlotW = 225.0`, `_pdfSigSlotH = 102.0` (pt)
- TTD base at `_sigNameTop = 90.0` pt di bawah slot top
- Overlap max: `_sigOverlapPt = 18.0` pt (base 90 → 108 pt)
- Move up: `_sigUpPt = 33.0` pt (sentuh baris "Mengetahui,")
- Signature page height: `_sigFooterH = 140.0` pt

## PDF page size
- `_pdfPageW = 595.28`, `_pdfPageH = 841.89` (A4 dalam pt)

## Raster config
- `_signatureRasterDpi = 110.0`

## Editor layout
- `_sigMinScale = 0.5`, `_sigDefaultScale = 0.75`, `_sigMaxScale = 1.15`
- TTD drag delta tidak dibagi zoom — koordinat poin child `InteractiveViewer`
- Child `InteractiveViewer`: `SizedBox(_pdfPageW, _pdfPageH)`
- Overlay posisi: koordinat poin (tanpa `* scale`)
- Raster `BoxFit.fill` untuk 1:1 mapping

## State variables (_PdfPageState)
- `_sigBytes`: `Uint8List?` (base64-decoded PNG signature)
- `_sigAspect`: `double` (width/height PNG)
- `_sigX`, `_sigY`: 0–1 (posisi relatif slot)
- `_sigW`: scale 0.5–1.15

## Key functions
- `_buildPageSigEditor()`: editor preview PDF + overlay TTD
- `_buildPageSignature()`: render TTD di PDF (baris 1857)
- `_defaultSignatureY(sig, scale)`: hitung posisi default Y dari scale
- `_signatureImageSizeFromAspect(aspect, scale)`: `[w, h]` pt dari PNG aspect dan scale
- `_loadSavedSigPosition()`: tuple `(sigW, sigX, sigY)` dari data tersimpan atau default

## Transform API
- `translateByDouble(tx, ty, 0, 1)` instead deprecated `translate(tx, ty)`
- `scaleByDouble(sx, sy, sz, 1)` instead deprecated `scale(sx, sy, sz)`

## Toolbar (editor mode)
- Ganti File (upload), Reset, Batal (cancel), Simpan (save)
- Slider ukuran TTD di area toolbar (vertical layout)

## Toolbar (preview mode)
- Upload TTD/Stempel di kanan
- `canChangeOrientation: false`, `canDebug: false`, `allowPrinting: true`, `allowSharing: true`

## Commit convention
- Format: `<type>(sig): <descriptions> (<tag>)`
- Tag: `vX.X.X-alpha`
- Batal otomatis revert karena `_enterEditMode()` selalu baca ulang posisi dari `widget.data`

## Guard pattern
- `sigMoveH.clamp(1.0, double.infinity)` dipakai di drag handler untuk mencegah pembagi nol (defensif, bukan bug).
