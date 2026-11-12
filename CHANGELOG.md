# Changelog

## v0.1.2-alpha

- Default ukuran TTD menjadi 75%, dengan slider rentang 50%–115%.
- Garis bantu editor diperluas untuk menampilkan seluruh area drag, termasuk batas naik 33 pt.
- Data posisi/layout lama di-reset ke default aman melalui `sigLayoutVersion = 9`.

## v0.1.1-alpha

- Perbaikan revert posisi saat tombol Batal: editor selalu baca posisi terakhir dari data tersimpan, bukan dari memori sementara.
- `_loadSavedSigPosition()` dibuat sebagai satu sumber kebenaran untuk `sigW`, `sigX`, `sigY` di `initState` dan `_enterEditMode()`.
- `_cacheSignature()` dipindah ke sebelum `setState` untuk menghindari 1 frame overlay kosong.
- Rapikan formatting di baris 2488.
- `sigMoveH.clamp(1.0, double.infinity)` dipertahankan sebagai guard pembagi nol (bukan bug, tapi defensif).

## v0.1.0-alpha

- Perbaikan editor posisi tanda tangan: preview PDF halaman 1 (tanpa TTD) dengan overlay TTD langsung.
- Drag TTD akurat saat zoom/pan menggunakan `InteractiveViewer` dan `TransformationController`.
- TTD boleh menimpa nama (overlap 18 pt) dan naik hingga menyentuh baris "Mengetahui," (up 33 pt).
- Tombol Upload TTD/Stempel ditambahkan di toolbar preview PDF.
- `sigLayoutVersion = 8` untuk kompatibilitas layout baru.
- Mode edit menampilkan slot outline dan garis bantu.
