# ---------------------------------------------------------------------------
# prepare_kenney_assets.ps1
#
# Merapikan pack Kenney yang sudah diekstrak ke `assets/kenney/<pack>/`:
#   1. menyalin palet warna `Textures/colormap.png` ke samping GLB-nya
#      (GLB Kenney memakai tekstur EKSTERNAL — tanpa ini meshnya putih polos),
#   2. memangkas mesh yang tidak dipakai game supaya .pck tetap ramping.
#
# Semua pack Kenney berstatus CC0 (public domain), jadi tidak ada kewajiban
# lisensi, tapi tetap kita simpan License.txt di dalam repo.
#
# Cara pakai (dari root project):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare_kenney_assets.ps1
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$kenney = Join-Path $root 'assets\kenney'

# Peta: folder pack di project -> folder pack di folder unduhan %TEMP%\kenney_dl
#   (folder project disederhanakan: suburban/roads/food)
$packMap = [ordered]@{
	'mini'       = 'mini'
	'commercial' = 'commercial'
	'suburban'   = 'city-kit-suburban'
	'roads'      = 'city-kit-roads'
	'food'       = 'food-kit'
	'furniture'  = 'furniture-kit'
}
# Folder format model di dalam pack (furniture-kit memakai "GLTF format").
$formatMap = @{
	'mini'       = 'GLB format'
	'commercial' = 'GLB format'
	'suburban'   = 'GLB format'
	'roads'      = 'GLB format'
	'food'       = 'GLB format'
	'furniture'  = 'GLTF format'
}
$srcRoot = Join-Path $env:TEMP 'kenney_dl'

# Daftar mesh yang dipertahankan per pack.
$keep = @{
	'mini' = @(
		'character-male-a.glb','character-male-b.glb','character-male-c.glb',
		'character-male-d.glb','character-male-e.glb','character-male-f.glb',
		'character-female-a.glb','character-female-b.glb','character-female-c.glb',
		'character-female-d.glb','character-female-e.glb','character-female-f.glb'
	)
	'commercial' = @(
		'building-a.glb','building-b.glb','building-c.glb','building-d.glb',
		'building-e.glb','building-f.glb','building-g.glb','building-h.glb',
		'building-i.glb','building-j.glb','building-k.glb','building-l.glb',
		'building-m.glb','building-n.glb',
		'building-skyscraper-a.glb','building-skyscraper-b.glb','building-skyscraper-c.glb',
		'building-skyscraper-d.glb','building-skyscraper-e.glb',
		'detail-awning.glb','detail-awning-wide.glb',
		'detail-overhang.glb','detail-overhang-wide.glb',
		'detail-parasol-a.glb','detail-parasol-b.glb'
	)
	'suburban' = @(
		'building-type-a.glb','building-type-b.glb','building-type-c.glb',
		'building-type-d.glb','building-type-e.glb','building-type-f.glb',
		'building-type-g.glb','building-type-h.glb','building-type-i.glb',
		'building-type-j.glb','building-type-k.glb','building-type-l.glb',
		'building-type-m.glb','building-type-n.glb','building-type-o.glb',
		'building-type-p.glb','building-type-q.glb','building-type-r.glb',
		'building-type-s.glb','building-type-t.glb','building-type-u.glb',
		'driveway-long.glb','driveway-short.glb',
		'fence.glb','fence-low.glb','fence-1x2.glb','fence-1x3.glb','fence-1x4.glb',
		'fence-2x2.glb','fence-2x3.glb','fence-3x2.glb','fence-3x3.glb',
		'path-long.glb','path-short.glb','path-stones-long.glb','path-stones-short.glb',
		'planter.glb','tree-large.glb','tree-small.glb'
	)
	'roads' = @(
		'road-straight.glb','road-straight-half.glb','road-straight-barrier.glb',
		'road-straight-barrier-end.glb','road-straight-barrier-half.glb',
		'road-crossing.glb','road-crossroad.glb','road-crossroad-line.glb',
		'road-crossroad-path.glb','road-crossroad-barrier.glb',
		'road-intersection.glb','road-intersection-line.glb',
		'road-intersection-path.glb','road-intersection-barrier.glb',
		'road-split.glb','road-split-barrier.glb',
		'road-end.glb','road-end-round.glb','road-end-barrier.glb','road-end-round-barrier.glb',
		'road-side.glb','road-side-barrier.glb','road-side-entry.glb','road-side-exit.glb',
		'road-bend.glb','road-bend-sidewalk.glb','road-bend-square.glb',
		'road-curve.glb','road-curve-pavement.glb','road-curve-intersection.glb',
		'road-sign-empty.glb','road-sign-object-stop.glb','road-sign-object-street.glb',
		'road-sign-object-warning.glb','road-sign-stop.glb','road-sign-street.glb',
		'road-sign-warning.glb','road-sign-empty-hanging.glb'
	)
	'furniture' = @(
		'bench.glb','benchCushion.glb',
		'chair.glb','chairCushion.glb','chairDesk.glb','chairModernCushion.glb',
		'chairModernFrameCushion.glb','chairRounded.glb',
		'desk.glb','stoolBar.glb','stoolBarSquare.glb',
		'sideTable.glb','sideTableDrawers.glb',
		'table.glb','tableCloth.glb','tableRound.glb','tableCross.glb','tableCrossCloth.glb',
		'plantSmall1.glb','plantSmall2.glb','plantSmall3.glb','pottedPlant.glb',
		'lampRoundFloor.glb','lampSquareFloor.glb',
		'rugDoormat.glb','rugRectangle.glb',
		'trashcan.glb','cardboardBoxClosed.glb','cardboardBoxOpen.glb',
		'bookcaseOpen.glb','computerScreen.glb','radio.glb','speaker.glb'
	)
	'food' = @(
		'bag.glb','bag-flat.glb','barrel.glb','bowl.glb','bowl-soup.glb','plate.glb',
		'cup.glb','cup-tea.glb','cup-coffee.glb','cup-saucer.glb','mug.glb',
		'ice-cream-cup.glb','ice-cream.glb','popsicle.glb','popsicle-chocolate.glb',
		'glass.glb','soda-glass.glb','soda-bottle.glb','soda-can.glb','can.glb','carton.glb',
		'lollypop.glb','candy-bar.glb','cookie.glb','donut.glb','cupcake.glb',
		'apple.glb','banana.glb','orange.glb','lemon.glb','watermelon.glb',
		'pineapple.glb','strawberry.glb','bread.glb','sandwich.glb','fries.glb',
		'rice-ball.glb','egg-cup.glb','cooking-spoon.glb','cooking-fork.glb',
		'cooking-knife.glb','cutting-board.glb','cutting-board-japanese.glb',
		'pepper-mill.glb','shaker-salt.glb','shaker-pepper.glb','whisk.glb',
		'pot.glb','pan.glb','chopstick.glb'
	)
}

# --- 1. Salin palet warna (WAJIB: GLB Kenney menunjuk tekstur eksternal) ---
foreach ($pack in $packMap.Keys) {
	$srcTex = Join-Path $srcRoot ($packMap[$pack] + '\Models\' + $formatMap[$pack] + '\Textures')
	$dstTex = Join-Path $kenney ($pack + '\Textures')
	if (Test-Path $srcTex) {
		New-Item -ItemType Directory -Force -Path $dstTex | Out-Null
		Copy-Item -Path (Join-Path $srcTex '*.png') -Destination $dstTex -Force
		Write-Host ("[{0}] palet warna -> {1}" -f $pack, $dstTex)
	} else {
		Write-Host ("[{0}] tidak ada folder Textures (warna dari baseColorFactor)" -f $pack)
	}
}

# --- 2. Buang folder sisa yang tidak dipakai ---
foreach ($stray in @('city-kit-roads', 'city-kit-suburban', 'food-kit')) {
	$path = Join-Path $kenney $stray
	if (Test-Path $path) {
		Remove-Item $path -Recurse -Force
		Write-Host ("[buang] folder sisa {0}" -f $stray)
	}
}

# --- 3. Pangkas mesh yang tidak dipakai ---
foreach ($pack in $keep.Keys) {
	$dir = Join-Path $kenney $pack
	if (-not (Test-Path $dir)) {
		Write-Host "[SKIP] pack tidak ada: $pack"
		continue
	}
	$files = Get-ChildItem -Path $dir -Filter '*.glb' -File
	$kept = 0
	$removed = 0
	foreach ($f in $files) {
		if ($keep[$pack] -contains $f.Name) {
			$kept++
		} else {
			Remove-Item $f.FullName -Force
			$removed++
		}
	}
	Write-Host ("[{0}] disimpan {1}, dihapus {2}" -f $pack, $kept, $removed)
}

# Total akhir
$total = (Get-ChildItem -Path $kenney -Recurse -Filter '*.glb' -File)
$bytes = ($total | Measure-Object -Property Length -Sum).Sum
$tex = (Get-ChildItem -Path $kenney -Recurse -Filter '*.png' -File)
$tbytes = ($tex | Measure-Object -Property Length -Sum).Sum
Write-Host ("TOTAL: {0} file .glb ({1:N0} B) + {2} tekstur ({3:N0} B)" -f $total.Count, $bytes, $tex.Count, $tbytes)

# Paksa re-import: hapus .import GLB supaya Godot memuat ulang palet warna.
Get-ChildItem -Path $kenney -Recurse -Filter '*.glb.import' | Remove-Item -Force
Write-Host "[import] .glb.import dihapus, jalankan: godot --headless --path . --import"
