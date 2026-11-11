# DECISIONS

## v0.1.0-alpha
- `_sigLayoutVersion = 8` (naik dari 6)
- `_sigOverlapPt = 18.0`, `_sigUpPt = 33.0`
- `sigMoveH` tanpa clamp tambahan
- Tombol Upload TTD/Stempel di toolbar preview (bukan editor terpisah)
- `canChangeOrientation: false`, `canDebug: false`
- Variabel `_rasterWidthPx`, `_rasterHeightPx` dihapus (unused)
- `_rasterizePage1()` tanpa hitung raster px
- `_buildPageSigEditor()` pakai `TransformationController` + `LayoutBuilder` + `InteractiveViewer`
- Child `InteractiveViewer`: `SizedBox(_pdfPageW, _pdfPageH)` (koordinat poin)
- Drag delta langsung dipakai tanpa `/ zoom`
- `_loadSavedSigPosition()` rumus baru (parsing `sigAbsolute && sigPosV2 && sigLayoutVersion >= 8`)
- `_cacheSignature()` sebelum `setState` di `_enterEditMode()`
- `_txCtrl.value = Matrix4.identity()` di `_enterEditMode()`
- `Margin` dihapus dari `_buildPageSigEditor()` (unused)
- `_sigBytes`, `_sigAspect` cache PNG (hitung sekali)
- `_defaultSignatureY()` parameter tambah `sigScale`
- `sigY` di PDF fallback ke `_defaultSignatureY(data.signature, sigScale)`
- Label AppBar: `'Atur Posisi TTD'` (hapus `• build 8`)

## Rationale
- Layout slot fixed (225×102 pt), TTD relative 0–1, drag delta poin
- Raster 1:1 mapping dengan `BoxFit.fill` + `SizedBox(poin, poin)`
- Transform API baru untuk kompatibilitas Flutter modern
