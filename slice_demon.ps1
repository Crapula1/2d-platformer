Add-Type -AssemblyName System.Drawing

$src = "C:\Users\brade\Downloads\ChatGPT Image May 20, 2026, 10_21_19 PM.png"
$outDir = "C:\Users\brade\projects\2d-platformer\assets\sprites\greater_demon"
$labelSkipX = 140
$threshold = 20
$minGapCols = 1

# Row centers detected from label positions (see probe2.ps1)
$rows = @(
  @{ name = "idle";         center = 92;   count = 4 },
  @{ name = "walk";         center = 230;  count = 7 },
  @{ name = "run";          center = 371;  count = 6 },
  @{ name = "lunge";        center = 504;  count = 4 },
  @{ name = "lunge_impact"; center = 629;  count = 1 },
  @{ name = "cleave";       center = 800;  count = 5 },
  @{ name = "hurt";         center = 954;  count = 3 },
  @{ name = "die";          center = 1091; count = 6 }
)

$bmp = [System.Drawing.Bitmap]::new($src)
$w = $bmp.Width; $h = $bmp.Height
$rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)

# Compute per-row Y bounds by midpoints between centers
$bounds = @()
for ($i = 0; $i -lt $rows.Count; $i++) {
  $c = $rows[$i].center
  if ($i -eq 0) { $top = 30 } else { $top = [int](($rows[$i-1].center + $c) / 2) + 1 }
  if ($i -eq $rows.Count - 1) { $bot = $h - 1 } else { $bot = [int](($c + $rows[$i+1].center) / 2) }
  $bounds += @{ name = $rows[$i].name; count = $rows[$i].count; y0 = $top; y1 = $bot }
}

$frameInfo = @()  # for tres

foreach ($band in $bounds) {
  # Compute content rows within band, then pick the contiguous segment closest to band center
  $rowHas = New-Object bool[] ($band.y1 - $band.y0 + 2)
  for ($y = $band.y0; $y -le $band.y1; $y++) {
    $rowOff = $y * $stride
    $hasContent = $false
    for ($x = $labelSkipX; $x -lt $w; $x++) {
      $i = $rowOff + $x * 3
      if ($bytes[$i] -gt $threshold -or $bytes[$i+1] -gt $threshold -or $bytes[$i+2] -gt $threshold) {
        $hasContent = $true; break
      }
    }
    $rowHas[$y - $band.y0] = $hasContent
  }
  $segments = @()
  $inS = $false; $sStart = 0
  for ($y = $band.y0; $y -le $band.y1; $y++) {
    if ($rowHas[$y - $band.y0]) {
      if (-not $inS) { $inS = $true; $sStart = $y }
    } else {
      if ($inS) { $segments += @{ y0 = $sStart; y1 = $y - 1 }; $inS = $false }
    }
  }
  if ($inS) { $segments += @{ y0 = $sStart; y1 = $band.y1 } }
  if ($segments.Count -eq 0) {
    Write-Output ("ERROR: no content in band {0}" -f $band.name); continue
  }
  # Pick segment whose center is closest to label center
  $best = $segments[0]; $bestD = [Math]::Abs((($best.y0 + $best.y1) / 2) - $band.center)
  if (-not $band.center) { $center = [int](($band.y0 + $band.y1) / 2) } else { $center = $band.center }
  # NOTE: $band has no 'center' key here — recompute from rows table
  $rcenter = ($rows | Where-Object { $_.name -eq $band.name } | Select-Object -First 1).center
  $best = $segments[0]; $bestD = [Math]::Abs((($best.y0 + $best.y1) / 2) - $rcenter)
  foreach ($s in $segments) {
    $d = [Math]::Abs((($s.y0 + $s.y1) / 2) - $rcenter)
    if ($d -lt $bestD) { $best = $s; $bestD = $d }
  }
  $cy0 = $best.y0; $cy1 = $best.y1

  # Per-column content count within band
  $colCount = New-Object int[] $w
  $colHas = New-Object bool[] $w
  for ($x = $labelSkipX; $x -lt $w; $x++) {
    $c = 0
    for ($y = $cy0; $y -le $cy1; $y++) {
      $i = $y * $stride + $x * 3
      if ($bytes[$i] -gt $threshold -or $bytes[$i+1] -gt $threshold -or $bytes[$i+2] -gt $threshold) {
        $c++
      }
    }
    $colCount[$x] = $c
    $colHas[$x] = ($c -gt 0)
  }

  # Overall content extent
  $contentX0 = -1; $contentX1 = -1
  for ($x = $labelSkipX; $x -lt $w; $x++) {
    if ($colHas[$x]) { if ($contentX0 -lt 0) { $contentX0 = $x }; $contentX1 = $x }
  }

  # First pass: group cols into "content runs" using all-black gaps
  $runs = @()
  $inF = $false; $fStart = 0
  for ($x = $contentX0; $x -le $contentX1; $x++) {
    if ($colHas[$x]) {
      if (-not $inF) { $inF = $true; $fStart = $x }
    } else {
      if ($inF) { $runs += @{ x0 = $fStart; x1 = $x - 1 }; $inF = $false }
    }
  }
  if ($inF) { $runs += @{ x0 = $fStart; x1 = $contentX1 } }

  # Drop tiny runs (label bleed / noise) less than 8 cols
  $runs = $runs | Where-Object { ($_.x1 - $_.x0 + 1) -ge 8 }

  $expected = $band.count
  $frames = @()

  # Peak-anchored cropping when multiple frames live inside one big run
  # (handles the case where adjacent demons overlap horizontally)
  $useDensity = $false
  if ($runs.Count -eq 1 -and $expected -gt 1) {
    $useDensity = $true
  } elseif ($runs.Count -lt $expected) {
    $useDensity = $true
  }

  if ($useDensity -and $expected -gt 1) {
    $runsArr = @($runs)
    $r0 = $runsArr[0].x0; $r1 = $runsArr[0].x1
    foreach ($rr in $runsArr) {
      if ($rr.x0 -lt $r0) { $r0 = $rr.x0 }
      if ($rr.x1 -gt $r1) { $r1 = $rr.x1 }
    }
    # Equal division — demons in idle/walk/run rows are uniformly spaced
    $segW = ($r1 - $r0 + 1) / $expected
    for ($k = 0; $k -lt $expected; $k++) {
      $fx0 = [int]($r0 + $k * $segW)
      if ($k -eq $expected - 1) { $fx1 = $r1 } else { $fx1 = [int]($r0 + ($k + 1) * $segW) - 1 }
      $frames += @{ x0 = $fx0; x1 = $fx1 }
    }
  }
  elseif ($runs.Count -eq $expected) {
    $frames = $runs
  } elseif ($runs.Count -eq 1 -and $expected -gt 1) {
    # Single wide run; split by valley-finding equal segments
    $r = $runs[0]
    $rw = $r.x1 - $r.x0 + 1
    $segW = $rw / $expected
    $splits = @()
    for ($k = 1; $k -lt $expected; $k++) {
      $target = [int]($r.x0 + $k * $segW)
      $halfWin = [int]($segW * 0.25)
      $lo = [Math]::Max($r.x0 + 1, $target - $halfWin)
      $hi = [Math]::Min($r.x1 - 1, $target + $halfWin)
      $bestX = $target; $bestC = [int]::MaxValue
      for ($xx = $lo; $xx -le $hi; $xx++) {
        if ($colCount[$xx] -lt $bestC) { $bestC = $colCount[$xx]; $bestX = $xx }
      }
      $splits += $bestX
    }
    $prev = $r.x0
    foreach ($s in $splits) {
      $frames += @{ x0 = $prev; x1 = $s - 1 }
      $prev = $s
    }
    $frames += @{ x0 = $prev; x1 = $r.x1 }
  } elseif ($runs.Count -gt $expected) {
    # Merge smallest-gap-separated adjacent runs until count matches
    $work = @($runs)
    while ($work.Count -gt $expected) {
      $bestI = 0; $bestGap = [int]::MaxValue
      for ($k = 0; $k -lt $work.Count - 1; $k++) {
        $gap = $work[$k+1].x0 - $work[$k].x1 - 1
        if ($gap -lt $bestGap) { $bestGap = $gap; $bestI = $k }
      }
      $merged = @{ x0 = $work[$bestI].x0; x1 = $work[$bestI + 1].x1 }
      $new = @()
      for ($k = 0; $k -lt $work.Count; $k++) {
        if ($k -eq $bestI) { $new += $merged }
        elseif ($k -eq $bestI + 1) { continue }
        else { $new += $work[$k] }
      }
      $work = $new
    }
    $frames = $work
  } else {
    # runs.Count < expected and > 1: split the widest runs by valleys
    $work = New-Object System.Collections.ArrayList
    foreach ($r in $runs) { [void]$work.Add(@{ x0 = $r.x0; x1 = $r.x1 }) }
    while ($work.Count -lt $expected) {
      # find widest run
      $wi = 0; $maxW = 0
      for ($k = 0; $k -lt $work.Count; $k++) {
        $rw = $work[$k].x1 - $work[$k].x0 + 1
        if ($rw -gt $maxW) { $maxW = $rw; $wi = $k }
      }
      $r = $work[$wi]
      # find valley column in middle 60%
      $lo = [int]($r.x0 + ($r.x1 - $r.x0) * 0.25)
      $hi = [int]($r.x0 + ($r.x1 - $r.x0) * 0.75)
      $bestX = [int](($r.x0 + $r.x1) / 2); $bestC = [int]::MaxValue
      for ($xx = $lo; $xx -le $hi; $xx++) {
        if ($colCount[$xx] -lt $bestC) { $bestC = $colCount[$xx]; $bestX = $xx }
      }
      $left = @{ x0 = $r.x0; x1 = $bestX - 1 }
      $right = @{ x0 = $bestX; x1 = $r.x1 }
      $work[$wi] = $left
      $work.Insert($wi + 1, $right)
    }
    $frames = @($work)
  }

  Write-Output ("{0}: y={1}..{2} frames={3} expected={4}" -f $band.name, $cy0, $cy1, $frames.Count, $band.count)
  foreach ($f in $frames) { Write-Output ("    x={0}..{1} w={2}" -f $f.x0, $f.x1, ($f.x1 - $f.x0 + 1)) }

  $bh = $cy1 - $cy0 + 1
  for ($fi = 0; $fi -lt $frames.Count; $fi++) {
    $f = $frames[$fi]
    $fw = $f.x1 - $f.x0 + 1
    $outBmp = [System.Drawing.Bitmap]::new($fw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($outBmp)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $srcRect = [System.Drawing.Rectangle]::new($f.x0, $cy0, $fw, $bh)
    $dstRect = [System.Drawing.Rectangle]::new(0, 0, $fw, $bh)
    $g.DrawImage($bmp, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    # turn near-black background transparent
    $od = $outBmp.LockBits([System.Drawing.Rectangle]::new(0,0,$fw,$bh), [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $obytes = New-Object byte[] ($od.Stride * $bh)
    [System.Runtime.InteropServices.Marshal]::Copy($od.Scan0, $obytes, 0, $obytes.Length)
    for ($yy = 0; $yy -lt $bh; $yy++) {
      for ($xx = 0; $xx -lt $fw; $xx++) {
        $i = $yy * $od.Stride + $xx * 4
        $b = $obytes[$i]; $gr = $obytes[$i+1]; $r = $obytes[$i+2]
        if ($r -le $threshold -and $gr -le $threshold -and $b -le $threshold) {
          $obytes[$i+3] = 0
        }
      }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($obytes, 0, $od.Scan0, $obytes.Length)
    $outBmp.UnlockBits($od)

    $outPath = Join-Path $outDir ("{0}_{1}.png" -f $band.name, $fi)
    $outBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $outBmp.Dispose()
    $frameInfo += @{ anim = $band.name; index = $fi; file = ("{0}_{1}.png" -f $band.name, $fi) }
  }
}

$bmp.Dispose()
Write-Output ("Wrote {0} frames" -f $frameInfo.Count)
