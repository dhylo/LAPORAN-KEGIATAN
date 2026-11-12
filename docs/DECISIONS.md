# DECISIONS

## v0.2.0-alpha

- UI restyle penuh tanpa custom window chrome.
- Font Inter dibundle sebagai asset lokal.
- `ThemeMode.system` dengan tema light/dark macOS.
- Sidebar kiri 220px + toolbar 52px; navigasi tetap memakai `MaterialPageRoute`.
- Logika dan layout PDF `pw.*` tidak disentuh.

## v0.1.2-alpha

- Default scale TTD: `0.75` (slider 50%–115%).
- Slider memakai `divisions: 13` dan label persen.
- `_sigLayoutVersion = 9` agar layout posisi lama kembali ke default aman.
- Area garis bantu mencakup batas drag penuh: 33 pt di atas slot hingga 18 pt overlap nama.

## v0.1.1-alpha

- `_loadSavedSigPosition()` dibuat sebagai fungsi tunggal untuk memuat `(sigW, sigX, sigY)` dari data tersimpan atau default.
- `_enterEditMode()` selalu baca ulang posisi dari data → Batal otomatis revert posisi ke yang disimpan.
- `_cacheSignature()` dipindah sebelum `setState()` untuk menghindari 1 frame overlay kosong.
- `sigMoveH.clamp(1.0, double.infinity)` dipertahankan sebagai guard pembagi nol (defensif).
- `pubspec.yaml` versi naik ke `0.1.1-alpha+1`.
- `CHANGELOG.md` tambah entri v0.1.1-alpha.

## v0.1.0-alpha

- `_sigLayoutVersion = 8` (naik dari 6)
- `_sigOverlapPt = 18.0`, `_sigUpPt = 33.0`
- `sigMoveH` tanpa clamp tambahan (clamp hanya sebagai guard pembagi nol)
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
- Batal revert wajib karena state editor (posisi) terpisah dari state tersimpan
