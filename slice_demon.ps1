Add-Type -AssemblyName System.Drawing

# Slice the GreaterDemon sprite sheet.
# Hand-tuned for the 1536x1024 sheet:
#   C:\Users\brade\Downloads\8170d524-6985-44f5-8048-bf8e638d78e2 (1).png
#
# Two-pass: pass 1 crops + cleans each frame and locates the demon-body
# anchor (bbox center of the largest blob). Pass 2 paints every frame onto
# a shared canvas with that anchor at a shared point, so the demon body
# stays put across frames and across direction flips.
$src = "C:\Users\brade\Downloads\a697a877-f7b2-484e-98e3-9e1d6d1e6552.png"
$outDir = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\greater_demon"
$threshold = 8
$nearRadius = 8

# Bounding boxes were auto-derived from per-column opaque-pixel histograms
# of each row in the source sheet, then padded ~4 px. Each frame fully
# encloses one demon silhouette; the cleanup pass below keeps the largest
# connected blob and discards adjacent-frame bleed.
$frames = @{
  idle = @(
    @{x0=100; x1=290; y0=34; y1=158},
    @{x0=313; x1=504; y0=34; y1=158},
    @{x0=535; x1=720; y0=34; y1=158},
    @{x0=747; x1=937; y0=34; y1=158}
  )
  walk = @(
    @{x0=91;   x1=259;  y0=176; y1=275},
    @{x0=305;  x1=471;  y0=176; y1=275},
    @{x0=520;  x1=687;  y0=176; y1=275},
    @{x0=761;  x1=928;  y0=176; y1=275},
    @{x0=1014; x1=1180; y0=176; y1=275},
    @{x0=1212; x1=1379; y0=176; y1=275}
  )
  run = @(
    @{x0=86;   x1=273;  y0=312; y1=426},
    @{x0=297;  x1=488;  y0=312; y1=426},
    @{x0=518;  x1=711;  y0=312; y1=426},
    @{x0=747;  x1=935;  y0=312; y1=426},
    @{x0=986;  x1=1181; y0=312; y1=426},
    @{x0=1214; x1=1404; y0=312; y1=426}
  )
  lunge = @(
    @{x0=118;  x1=274;  y0=443; y1=546},
    @{x0=341;  x1=558;  y0=443; y1=546},
    @{x0=594;  x1=822;  y0=443; y1=546},
    @{x0=854;  x1=1062; y0=443; y1=546}
  )
  lunge_impact = @(
    @{x0=80; x1=337; y0=555; y1=702}
  )
  cleave = @(
    @{x0=609;  x1=735;  y0=555; y1=702},
    @{x0=765;  x1=961;  y0=555; y1=702},
    @{x0=976;  x1=1144; y0=555; y1=702},
    @{x0=1177; x1=1385; y0=555; y1=702}
  )
  hurt = @(
    @{x0=71;  x1=246; y0=708; y1=836},
    @{x0=254; x1=382; y0=708; y1=836},
    @{x0=422; x1=559; y0=708; y1=836}
  )
  die = @(
    @{x0=93;   x1=252;  y0=862; y1=966},
    @{x0=310;  x1=457;  y0=862; y1=966},
    @{x0=501;  x1=656;  y0=862; y1=966},
    @{x0=717;  x1=882;  y0=862; y1=966},
    @{x0=924;  x1=1101; y0=862; y1=966},
    @{x0=1163; x1=1374; y0=862; y1=966}
  )
}

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }
Get-ChildItem -Path $outDir -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $outDir -Filter "*.png.import" -ErrorAction SilentlyContinue | Remove-Item -Force

$bmp = [System.Drawing.Bitmap]::new($src)

# ---------------------------------------------------------------------------
# Pass 1 — crop, clean, find anchor + kept-pixel extents.
# ---------------------------------------------------------------------------
$processed = @()
foreach ($name in $frames.Keys) {
  $list = $frames[$name]
  for ($i = 0; $i -lt $list.Count; $i++) {
    $f = $list[$i]
    $fw = $f.x1 - $f.x0 + 1
    $fh = $f.y1 - $f.y0 + 1
    $out = [System.Drawing.Bitmap]::new($fw, $fh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.DrawImage($bmp,
      [System.Drawing.Rectangle]::new(0, 0, $fw, $fh),
      [System.Drawing.Rectangle]::new($f.x0, $f.y0, $fw, $fh),
      [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    $od = $out.LockBits(
      [System.Drawing.Rectangle]::new(0,0,$fw,$fh),
      [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
      [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $obytes = New-Object byte[] ($od.Stride * $fh)
    [System.Runtime.InteropServices.Marshal]::Copy($od.Scan0, $obytes, 0, $obytes.Length)
    $stride2 = $od.Stride

    # Knock out background; record opaque mask.
    $opaque = New-Object bool[] ($fw * $fh)
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $i2 = $yy * $stride2 + $xx * 4
        $b = $obytes[$i2]; $gr = $obytes[$i2+1]; $r = $obytes[$i2+2]
        if ($r -le $threshold -and $gr -le $threshold -and $b -le $threshold) {
          $obytes[$i2+3] = 0
        } else {
          $opaque[$yy * $fw + $xx] = $true
        }
      }
    }

    # 8-connected components.
    $label = New-Object int[] ($fw * $fh)
    $compSizes = @()
    $compCount = 0
    $queue = New-Object int[] ($fw * $fh)
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $idx = $yy * $fw + $xx
        if (-not $opaque[$idx] -or $label[$idx] -ne 0) { continue }
        $compCount++
        $label[$idx] = $compCount
        $head = 0; $tail = 0
        $queue[$tail] = $idx; $tail++
        $size = 0
        while ($head -lt $tail) {
          $cur = $queue[$head]; $head++
          $size++
          $cx2 = $cur % $fw; $cy2 = [int][Math]::Floor($cur / $fw)
          for ($dy = -1; $dy -le 1; $dy++) {
            $ny = $cy2 + $dy
            if ($ny -lt 0 -or $ny -ge $fh) { continue }
            for ($dx = -1; $dx -le 1; $dx++) {
              if ($dx -eq 0 -and $dy -eq 0) { continue }
              $nx = $cx2 + $dx
              if ($nx -lt 0 -or $nx -ge $fw) { continue }
              $n = $ny * $fw + $nx
              if ($opaque[$n] -and $label[$n] -eq 0) {
                $label[$n] = $compCount; $queue[$tail] = $n; $tail++
              }
            }
          }
        }
        $compSizes += $size
      }
    }

    $maxLabel = 0; $maxSize = 0
    for ($k = 0; $k -lt $compSizes.Count; $k++) {
      if ($compSizes[$k] -gt $maxSize) { $maxSize = $compSizes[$k]; $maxLabel = $k + 1 }
    }

    # Decide kept blobs: largest + anything within $nearRadius of it.
    $near = New-Object bool[] ($fw * $fh)
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        if ($label[$yy * $fw + $xx] -ne $maxLabel) { continue }
        $y0d = [Math]::Max(0, $yy - $nearRadius)
        $y1d = [Math]::Min($fh - 1, $yy + $nearRadius)
        $x0d = [Math]::Max(0, $xx - $nearRadius)
        $x1d = [Math]::Min($fw - 1, $xx + $nearRadius)
        for ($ay = $y0d; $ay -le $y1d; $ay++) {
          for ($ax = $x0d; $ax -le $x1d; $ax++) {
            $near[$ay * $fw + $ax] = $true
          }
        }
      }
    }
    $keepBlob = New-Object bool[] ($compCount + 1)
    $keepBlob[$maxLabel] = $true
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $idx = $yy * $fw + $xx
        $lab = $label[$idx]
        if ($lab -eq 0 -or $keepBlob[$lab]) { continue }
        if ($near[$idx]) { $keepBlob[$lab] = $true }
      }
    }
    # Clear alpha of dropped blobs.
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $idx = $yy * $fw + $xx
        $lab = $label[$idx]
        if ($lab -ne 0 -and -not $keepBlob[$lab]) {
          $obytes[$yy * $stride2 + $xx * 4 + 3] = 0
        }
      }
    }

    # Bbox of all kept pixels → canvas extents.
    # Anchor = densest column/row of the LARGEST blob. The demon's torso is
    # the fattest vertical bar in the silhouette (much fatter than wings or
    # sword); locating it column-by-column gives an anchor that sticks to
    # the body across frames and survives direction-flips without jumping.
    $kx0 = $fw; $ky0 = $fh; $kx1 = -1; $ky1 = -1
    $colC = New-Object int[] $fw
    $rowC = New-Object int[] $fh
    for ($yy = 0; $yy -lt $fh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $idx = $yy * $fw + $xx
        $lab = $label[$idx]
        if ($lab -eq 0 -or -not $keepBlob[$lab]) { continue }
        if ($xx -lt $kx0) { $kx0 = $xx }
        if ($yy -lt $ky0) { $ky0 = $yy }
        if ($xx -gt $kx1) { $kx1 = $xx }
        if ($yy -gt $ky1) { $ky1 = $yy }
        if ($lab -eq $maxLabel) {
          $colC[$xx]++; $rowC[$yy]++
        }
      }
    }
    # Pick the centroid of the top-N% densest columns/rows for a smoother
    # anchor than the single peak (less sensitive to one-pixel ties).
    $maxCol = 0
    for ($xx = 0; $xx -lt $fw; $xx++) { if ($colC[$xx] -gt $maxCol) { $maxCol = $colC[$xx] } }
    $colThresh = [int]($maxCol * 0.85)
    $axNum = 0; $axDen = 0
    for ($xx = 0; $xx -lt $fw; $xx++) {
      if ($colC[$xx] -ge $colThresh) { $axNum += $xx * $colC[$xx]; $axDen += $colC[$xx] }
    }
    $anchorX = [int]($axNum / $axDen)

    $maxRow = 0
    for ($yy = 0; $yy -lt $fh; $yy++) { if ($rowC[$yy] -gt $maxRow) { $maxRow = $rowC[$yy] } }
    $rowThresh = [int]($maxRow * 0.85)
    $ayNum = 0; $ayDen = 0
    for ($yy = 0; $yy -lt $fh; $yy++) {
      if ($rowC[$yy] -ge $rowThresh) { $ayNum += $yy * $rowC[$yy]; $ayDen += $rowC[$yy] }
    }
    $anchorY = [int]($ayNum / $ayDen)

    [System.Runtime.InteropServices.Marshal]::Copy($obytes, 0, $od.Scan0, $obytes.Length)
    $out.UnlockBits($od)

    $processed += @{
      anim   = $name
      index  = $i
      bmp    = $out
      ax     = $anchorX
      ay     = $anchorY
      left   = $anchorX - $kx0    # distance from anchor to left edge of kept pixels
      right  = $kx1 - $anchorX
      top    = $anchorY - $ky0
      bot    = $ky1 - $anchorY
    }
  }
}

# ---------------------------------------------------------------------------
# Pass 2 — determine shared canvas + paint every frame with anchor aligned.
# ---------------------------------------------------------------------------
$maxL = 0; $maxR = 0; $maxT = 0; $maxB = 0
foreach ($p in $processed) {
  if ($p.left  -gt $maxL) { $maxL = $p.left }
  if ($p.right -gt $maxR) { $maxR = $p.right }
  if ($p.top   -gt $maxT) { $maxT = $p.top }
  if ($p.bot   -gt $maxB) { $maxB = $p.bot }
}
$pad = 4
# Make the canvas SYMMETRIC around the anchor on each axis. This is the key
# to no-jump direction flips — flip_h mirrors the texture around its center,
# so the anchor (= demon torso) MUST be at canvas center for the body to
# stay in place when the sprite flips.
$halfX = [Math]::Max($maxL, $maxR) + $pad
$halfY = [Math]::Max($maxT, $maxB) + $pad
$canvasW = 2 * $halfX + 1
$canvasH = 2 * $halfY + 1
$anchorInCanvasX = $halfX
$anchorInCanvasY = $halfY
Write-Output ("canvas: {0}x{1}  anchor=({2},{3})" -f $canvasW, $canvasH, $anchorInCanvasX, $anchorInCanvasY)

foreach ($p in $processed) {
  $canvas = [System.Drawing.Bitmap]::new($canvasW, $canvasH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
  $dstX = $anchorInCanvasX - $p.ax
  $dstY = $anchorInCanvasY - $p.ay
  $g.DrawImage($p.bmp, $dstX, $dstY)
  $g.Dispose()

  $path = Join-Path $outDir ("{0}_{1}.png" -f $p.anim, $p.index)
  $canvas.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
  $p.bmp.Dispose()
  Write-Output ("  wrote {0}" -f (Split-Path $path -Leaf))
}

$bmp.Dispose()
Write-Output "done"
