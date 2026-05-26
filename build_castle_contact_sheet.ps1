Add-Type -AssemblyName System.Drawing

# Build labeled contact sheets of every sliced castle_pack sprite.
# Splits into N pages so each renders large enough to read individual sprites
# and their index labels when viewed at typical screen scale.

$spriteDir = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\castle_pack"
$outBase   = "C:\Users\brade\Desktop\2d-platformer\castle_pack_contact"

$cell    = 128
$pad     = 6
$label   = 18
$cols    = 8
$pages   = 4
$bgColor = [System.Drawing.Color]::FromArgb(255, 20, 25, 35)

$pngs = @(Get-ChildItem -Path $spriteDir -Filter "sprite_*.png" | Sort-Object Name)
$perPage = [int][Math]::Ceiling($pngs.Count / $pages)
$cellH = $cell + $label

$font = [System.Drawing.Font]::new("Consolas", 11.0, [System.Drawing.FontStyle]::Bold)
$brush = [System.Drawing.Brushes]::White

for ($p = 0; $p -lt $pages; $p++) {
  $start = $p * $perPage
  $end = [Math]::Min($start + $perPage, $pngs.Count) - 1
  if ($start -gt $end) { break }
  $count = $end - $start + 1
  $rows = [int][Math]::Ceiling($count / $cols)
  $sheetW = $cols * ($cell + $pad) + $pad
  $sheetH = $rows * ($cellH + $pad) + $pad

  $sheet = [System.Drawing.Bitmap]::new($sheetW, $sheetH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.Clear($bgColor)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

  for ($k = 0; $k -lt $count; $k++) {
    $i = $start + $k
    $col = $k % $cols
    $row = [int][Math]::Floor($k / $cols)
    $cx = $pad + $col * ($cell + $pad)
    $cy = $pad + $row * ($cellH + $pad)

    $img = [System.Drawing.Bitmap]::new($pngs[$i].FullName)
    $iw = $img.Width; $ih = $img.Height
    $scale = [Math]::Min($cell / $iw, $cell / $ih)
    if ($scale -gt 1) { $scale = 1 }
    $dw = [int]($iw * $scale)
    $dh = [int]($ih * $scale)
    $dx = $cx + [int](($cell - $dw) / 2)
    $dy = $cy + [int](($cell - $dh) / 2)
    $g.DrawImage($img, $dx, $dy, $dw, $dh)
    $img.Dispose()

    $idx = ($i + 1).ToString("000")
    $g.DrawString($idx, $font, $brush, [float]($cx + 2), [float]($cy + $cell))
  }

  $g.Dispose()
  $outFile = "{0}_p{1}.png" -f $outBase, ($p + 1)
  $sheet.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $sheet.Dispose()
  Write-Output ("page {0}: sprites {1:000}-{2:000} -> {3} ({4}x{5})" -f ($p + 1), ($start + 1), ($end + 1), $outFile, $sheetW, $sheetH)
}
