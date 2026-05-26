Add-Type -AssemblyName System.Drawing

$dir = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\castle_pack"
$out = "C:\Users\brade\Desktop\2d-platformer\castle_preview.png"

$GY  = 400.0
$CX = 7220.0

$canvasX0 = $CX - 280.0
$canvasX1 = $CX + 280.0
$canvasY0 = 100.0
$canvasY1 = $GY + 40.0
$w = [int]($canvasX1 - $canvasX0)
$h = [int]($canvasY1 - $canvasY0)

$bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, 30, 36, 50))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

$band_y = [int]($GY - $canvasY0)
$band_h = [int]($canvasY1 - $GY)
$ground = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 60, 60, 70))
[void]$g.FillRectangle($ground, 0, $band_y, $w, $band_h)

$pieces = New-Object 'System.Collections.Generic.List[object]'
function Add-Piece($file, $dx, $dy, $z, $flip) {
  $pieces.Add([pscustomobject]@{ file = $file; cx = $CX + $dx; by = $GY + $dy; z = $z; flip = $flip })
}

Add-Piece "sprite_159_75x99.png"  -220.0    0.0  -2 $false
Add-Piece "sprite_175_61x55.png"  -170.0    0.0  -2 $false
Add-Piece "sprite_165_54x84.png"   215.0    0.0  -2 $false
Add-Piece "sprite_157_37x50.png"   175.0    0.0  -2 $false
Add-Piece "sprite_005_63x114.png"  -95.0    0.0  -1 $false
Add-Piece "sprite_048_64x85.png"     0.0    0.0  -1 $false
Add-Piece "sprite_005_63x114.png"   95.0    0.0  -1 $true
Add-Piece "sprite_054_78x84.png"     0.0  -78.0  -1 $false
Add-Piece "sprite_009_62x143.png" -165.0    0.0  -1 $false
Add-Piece "sprite_010_48x143.png"  165.0    0.0  -1 $true
Add-Piece "sprite_012_63x98.png"     0.0  -85.0  -1 $false
Add-Piece "sprite_002_112x128.png" -165.0 -143.0   0 $false
Add-Piece "sprite_003_108x129.png"  165.0 -143.0   0 $false
Add-Piece "sprite_030_65x82.png"     0.0 -183.0   0 $false
Add-Piece "sprite_084_15x30.png"   -40.0  -50.0   0 $false
Add-Piece "sprite_085_16x31.png"    40.0  -50.0   0 $false
Add-Piece "sprite_082_28x34.png"  -165.0  -90.0   0 $false
Add-Piece "sprite_083_32x36.png"   165.0  -90.0   0 $false
Add-Piece "sprite_155_26x27.png"   -75.0    0.0   0 $false
Add-Piece "sprite_156_25x24.png"    75.0    0.0   0 $true
Add-Piece "sprite_162_26x10.png"  -130.0    0.0   0 $false
Add-Piece "sprite_162_26x10.png"   130.0    0.0   0 $true

$sorted = $pieces | Sort-Object z
foreach ($p in $sorted) {
  $img = [System.Drawing.Bitmap]::new((Join-Path $dir $p.file))
  if ($p.flip) { $img.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
  $iw = $img.Width; $ih = $img.Height
  $dx = [int]($p.cx - $iw / 2.0 - $canvasX0)
  $dy = [int]($p.by - $ih - $canvasY0)
  [void]$g.DrawImage($img, $dx, $dy, $iw, $ih)
  $img.Dispose()
}

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("wrote {0} ({1}x{2})" -f $out, $w, $h)
