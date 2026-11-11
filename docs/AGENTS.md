# AGENTS

## Proyek ini
Flutter desktop/mobile application untuk laporan inspeksi dengan fitur tanda tangan digital.

## Stack
- Flutter SDK ^3.13.3
- `pdf ^3.11.3`, `printing ^5.14.2`, `image ^4.2.0`

## Posisi TTD
- `sigX`, `sigY` (0–1) — posisi relatif terhadap slot
- `sigW` (0.5–1.15) — scale terhadap ukuran dasar
- `sigLayoutVersion = 8`

## Layout values
- Slot: 225×102 pt
- TTD base: 90 pt di bawah slot top
- Max overlap: 18 pt (base 108 pt)
- Max up: 33 pt (sentuh baris "Mengetahui,")

## Editor mode
- Preview PDF halaman 1 tanpa TTD
- Overlay TTD + nama
- `InteractiveViewer` untuk zoom/pan
- Toolbar: Upload/Ganti File, Reset, Batal, Simpan

## Commit convention
- Format: `<type>(sig): <descriptions> (<tag>)`
- Tag: `vX.X.X-alpha`
- Batal otomatis revert karena `_enterEditMode()` selalu baca ulang posisi dari data
