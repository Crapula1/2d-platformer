Add-Type -AssemblyName System.Drawing

# Auto-slice the castle/medieval pixel-art sheet into per-sprite PNGs.
#
# Background is solid ~RGB(11,24,33); threshold above that to mark foreground,
# then 8-connected component labelling (no dilation — sprites are spaced
# enough that a tight threshold separates them; dilation merges neighbors).
# Each component gets cropped to its bbox and saved with transparent bg.

$src = "C:\Users\brade\Downloads\c933b035-0101-475c-b05c-c3d9455b2723.png"
$outDir = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\castle_pack"
# Threshold: background's brightest channel is B=34. Anything above 40 in any
# channel is real sprite content.
$bgThreshold = 40
$minArea = 80       # px; smaller blobs are noise / leftover dots
$minSide = 8        # bbox must be at least this many px on each side

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }
Get-ChildItem -Path $outDir -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $outDir -Filter "*.png.import" -ErrorAction SilentlyContinue | Remove-Item -Force

$bmp = [System.Drawing.Bitmap]::new($src)
$w = $bmp.Width
$h = $bmp.Height
Write-Output ("source: {0}x{1}" -f $w, $h)

$data = $bmp.LockBits(
  [System.Drawing.Rectangle]::new(0, 0, $w, $h),
  [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
  [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)

$fg = New-Object byte[] ($w * $h)
for ($y = 0; $y -lt $h; $y++) {
  $rowOff = $y * $stride
  $maskOff = $y * $w
  for ($x = 0; $x -lt $w; $x++) {
    $i = $rowOff + $x * 4
    if ($bytes[$i] -gt $bgThreshold -or $bytes[$i+1] -gt $bgThreshold -or $bytes[$i+2] -gt $bgThreshold) {
      $fg[$maskOff + $x] = 1
    }
  }
}
Write-Output "foreground mask built"

# 8-connected component labelling.
$label = New-Object int[] ($w * $h)
$queue = New-Object int[] ($w * $h)
$components = @()
$compCount = 0
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    $idx = $y * $w + $x
    if ($fg[$idx] -eq 0 -or $label[$idx] -ne 0) { continue }
    $compCount++
    $label[$idx] = $compCount
    $head = 0; $tail = 0
    $queue[$tail] = $idx; $tail++
    $x0 = $x; $x1 = $x; $y0 = $y; $y1 = $y
    $size = 0
    while ($head -lt $tail) {
      $cur = $queue[$head]; $head++
      $size++
      $cx = $cur % $w
      $cy = [int][Math]::Floor($cur / $w)
      for ($dy = -1; $dy -le 1; $dy++) {
        $ny = $cy + $dy
        if ($ny -lt 0 -or $ny -ge $h) { continue }
        for ($dx = -1; $dx -le 1; $dx++) {
          if ($dx -eq 0 -and $dy -eq 0) { continue }
          $nx = $cx + $dx
          if ($nx -lt 0 -or $nx -ge $w) { continue }
          $n = $ny * $w + $nx
          if ($fg[$n] -ne 0 -and $label[$n] -eq 0) {
            $label[$n] = $compCount
            $queue[$tail] = $n; $tail++
            if ($nx -lt $x0) { $x0 = $nx }
            if ($nx -gt $x1) { $x1 = $nx }
            if ($ny -lt $y0) { $y0 = $ny }
            if ($ny -gt $y1) { $y1 = $ny }
          }
        }
      }
    }
    $components += [pscustomobject]@{ id = $compCount; x0 = $x0; y0 = $y0; x1 = $x1; y1 = $y1; size = $size }
  }
}
Write-Output ("found {0} raw components" -f $compCount)

# Filter by size + dimensions.
$keep = $components | Where-Object {
  $_.size -ge $minArea -and ($_.x1 - $_.x0 + 1) -ge $minSide -and ($_.y1 - $_.y0 + 1) -ge $minSide
}
# Sort by row band (so visually-aligned sprites get consecutive indices)
# then by left edge. 24-px band tolerates slight y-misalignment between
# sprites in the same visual row.
$bandH = 24
$keep = $keep | Sort-Object @{Expression = { [int][Math]::Floor($_.y0 / $bandH) }}, x0
$keptCount = ($keep | Measure-Object).Count
Write-Output ("keeping {0} components after filtering" -f $keptCount)

$i = 0
foreach ($c in $keep) {
  $cw = $c.x1 - $c.x0 + 1
  $ch = $c.y1 - $c.y0 + 1
  $out = [System.Drawing.Bitmap]::new($cw, $ch, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $od = $out.LockBits(
    [System.Drawing.Rectangle]::new(0, 0, $cw, $ch),
    [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $obytes = New-Object byte[] ($od.Stride * $ch)
  for ($y = 0; $y -lt $ch; $y++) {
    $srcY = $c.y0 + $y
    $srcRow = $srcY * $stride
    $maskRow = $srcY * $w
    $dstRow = $y * $od.Stride
    for ($x = 0; $x -lt $cw; $x++) {
      $srcX = $c.x0 + $x
      # Only copy pixels that belong to this component's blob; everything else
      # stays transparent.
      if ($label[$maskRow + $srcX] -ne $c.id) { continue }
      $si = $srcRow + $srcX * 4
      $di = $dstRow + $x * 4
      $obytes[$di]     = $bytes[$si]
      $obytes[$di + 1] = $bytes[$si + 1]
      $obytes[$di + 2] = $bytes[$si + 2]
      $obytes[$di + 3] = 255
    }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($obytes, 0, $od.Scan0, $obytes.Length)
  $out.UnlockBits($od)
  $i++
  $name = "sprite_{0:000}_{1}x{2}.png" -f $i, $cw, $ch
  $out.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
}
$bmp.Dispose()
Write-Output ("wrote {0} sprites to {1}" -f $i, $outDir)
