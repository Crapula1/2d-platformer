Add-Type -AssemblyName System.Drawing

# Build a Godot 4 TileSet resource from the sliced castle_pack PNGs.
# One TileSetAtlasSource per piece, each holding a single tile at (0,0)
# sized to the full image. World tile_size is 16x16 — pieces span multiple
# cells via size_in_atlas_coords.

$spriteDir = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\castle_pack"
$outFile   = "C:\Users\brade\Desktop\2d-platformer\assets\sprites\castle_pack\castle_pack.tres"
$resBase   = "res://assets/sprites/castle_pack"
$tileSize  = 16

$pngs = Get-ChildItem -Path $spriteDir -Filter "sprite_*.png" | Sort-Object Name
if (-not $pngs) { throw "no sprite_*.png files in $spriteDir" }
Write-Output ("found {0} sprites" -f $pngs.Count)

$sb = New-Object System.Text.StringBuilder
$loadSteps = $pngs.Count + 1
[void]$sb.AppendLine("[gd_resource type=`"TileSet`" load_steps=$loadSteps format=3]")
[void]$sb.AppendLine()

for ($i = 0; $i -lt $pngs.Count; $i++) {
  $name = $pngs[$i].Name
  [void]$sb.AppendLine("[ext_resource type=`"Texture2D`" path=`"$resBase/$name`" id=`"t_$i`"]")
}
[void]$sb.AppendLine()

for ($i = 0; $i -lt $pngs.Count; $i++) {
  $bmp = [System.Drawing.Bitmap]::new($pngs[$i].FullName)
  $w = $bmp.Width; $h = $bmp.Height
  $bmp.Dispose()
  $cx = [int][Math]::Ceiling($w / $tileSize)
  $cy = [int][Math]::Ceiling($h / $tileSize)
  $regionW = $cx * $tileSize
  $regionH = $cy * $tileSize

  [void]$sb.AppendLine("[sub_resource type=`"TileSetAtlasSource`" id=`"a_$i`"]")
  [void]$sb.AppendLine("texture = ExtResource(`"t_$i`")")
  [void]$sb.AppendLine("texture_region_size = Vector2i($regionW, $regionH)")
  [void]$sb.AppendLine("0:0/0 = 0")
  if ($cx -gt 1 -or $cy -gt 1) {
    [void]$sb.AppendLine("0:0/0/size_in_atlas_coords = Vector2i($cx, $cy)")
  }
  [void]$sb.AppendLine()
}

[void]$sb.AppendLine("[resource]")
[void]$sb.AppendLine("tile_size = Vector2i($tileSize, $tileSize)")
for ($i = 0; $i -lt $pngs.Count; $i++) {
  [void]$sb.AppendLine("sources/$i = SubResource(`"a_$i`")")
}

Set-Content -Path $outFile -Value $sb.ToString() -Encoding utf8
Write-Output ("wrote {0}" -f $outFile)
