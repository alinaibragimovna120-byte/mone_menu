# Встроить техкарты с этого компьютера в приложение (assets/menu):
# при первом запуске на новом устройстве они появятся сразу, без входа.
# Берутся только видимые техкарты; фото уменьшаются до 1280 px (JPEG).
#
#   powershell -ExecutionPolicy Bypass -File tool\bundle_menu.ps1
#   flutter build apk --release

param(
  [string]$Data = "$env:APPDATA\uz.mone\mone_menu\mone_menu",
  [int]$MaxSide = 1280
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot '..\assets\menu'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force (Join-Path $out 'photos') | Out-Null

$json = Get-Content -Raw -Encoding UTF8 (Join-Path $Data 'cards.json') | ConvertFrom-Json
$books = @($json.books | Where-Object { -not $_.deleted_at })
$ids = @{}; foreach ($b in $books) { $ids[$b.id] = $true }
$cards = @($json.cards | Where-Object { $ids.ContainsKey($_.book_id) })

$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 82L
$done = @{}

# Путь фото на этом компьютере → имя в assets/menu/photos.
function Pack([string]$path) {
  if (-not $path) { return '' }
  $src = Join-Path (Join-Path $Data 'photos') (Split-Path ($path -replace '/', '\') -Leaf)
  if (-not (Test-Path $src)) { return '' }
  $name = [IO.Path]::GetFileNameWithoutExtension($src) + '.jpg'
  if (-not $done.ContainsKey($name)) {
    $img = [System.Drawing.Image]::FromFile($src)
    $k = [Math]::Min(1.0, $MaxSide / [Math]::Max($img.Width, $img.Height))
    $w = [int]($img.Width * $k); $h = [int]($img.Height * $k)
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White) # прозрачный PNG → белый фон
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, 0, 0, $w, $h)
    $bmp.Save((Join-Path $out "photos\$name"), $jpeg, $params)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    $done[$name] = $true
  }
  return "photos/$name"
}

foreach ($b in $books) { $b.cover = Pack $b.cover }
foreach ($c in $cards) { $c.photos = @($c.photos | ForEach-Object { Pack $_ } | Where-Object { $_ }) }

$bundle = [ordered]@{ version = 2; bundled_at = (Get-Date).ToString('s'); books = $books; cards = $cards }
$text = $bundle | ConvertTo-Json -Depth 20 -Compress
[IO.File]::WriteAllText((Join-Path $out 'cards.json'), $text, (New-Object System.Text.UTF8Encoding $false))

$size = (Get-ChildItem (Join-Path $out 'photos') | Measure-Object Length -Sum).Sum / 1MB
"Техкарт: $($books.Count), позиций: $($cards.Count), фото: $($done.Count) ({0:N1} МБ)" -f $size
