# Changelog

## v0.2.1-alpha

- Tambah toggle tema (Terang, Gelap, Sistem) di sidebar dengan penyimpanan permanen.
- Tambah tombol kembali otomatis di toolbar dan shortcut `Esc`.
- Sederhanakan garis bantu editor TTD (satu kotak dashed + garis nama).
- Paksa tema terang pada area preview PDF dan editor TTD untuk kejelasan.
- Perbaikan layout form temuan untuk mencegah artefak visual (barcode/overflow).

## v0.2.0-alpha

- Restyle UI penuh bergaya macOS: sidebar, toolbar, grouped list, kartu, tombol, dialog, dan form.
- Tambah tema terang/gelap yang mengikuti sistem operasi.
- Bundle font Inter untuk tipografi konsisten lintas platform.
- Tambah token UI reusable di `lib/ui/`.
- Layout dan logika PDF tetap tidak berubah.

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
