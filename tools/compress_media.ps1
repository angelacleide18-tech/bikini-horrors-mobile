param(
	[string[]]$Roots = @("mods\bikini-horrors\videos", "mods\bikini-horrors\songs", "assets\videos", "assets\songs"),
	[int]$MaxVideoWidth = 1280,
	[int]$MaxVideoHeight = 720,
	[int]$VideoCrf = 25,
	[ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow")]
	[string]$VideoPreset = "medium",
	[double]$AudioQuality = 5.0,
	[int]$MinVideoKB = 1024,
	[int]$MinAudioKB = 512,
	[double]$MinSavingPercent = 8.0,
	[int]$SkipVideoBitrateKbps = 2600,
	[int]$SkipAudioBitrateKbps = 210,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-RelativePath([string]$Path) {
	$root = (Get-Location).Path
	if ($Path.StartsWith($root)) {
		return $Path.Substring($root.Length + 1)
	}
	return $Path
}

function Get-MB([long]$Bytes) {
	return [math]::Round($Bytes / 1MB, 2)
}

function Test-Tool([string]$Name) {
	$tool = Get-Command $Name -ErrorAction SilentlyContinue
	if ($null -eq $tool) {
		throw "$Name was not found in PATH."
	}
}

function Invoke-Checked([string]$Tool, [string[]]$Arguments) {
	& $Tool @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Tool exited with code $LASTEXITCODE"
	}
}

function Remove-TempFile([string]$Path) {
	if (Test-Path -LiteralPath $Path) {
		try {
			Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
		} catch {
			Write-Warning "Could not remove temp file: $(Get-RelativePath $Path)"
		}
	}
}

function Read-ProbeJson([string[]]$Arguments) {
	$raw = & ffprobe @Arguments
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
		return $null
	}
	return ($raw -join "`n") | ConvertFrom-Json
}

function Get-Bitrate([object]$Probe) {
	if ($null -eq $Probe) {
		return 0L
	}

	$bitrate = 0L
	if ($Probe.streams.Count -gt 0 -and $Probe.streams[0].bit_rate) {
		[void][Int64]::TryParse([string]$Probe.streams[0].bit_rate, [ref]$bitrate)
	}
	if ($bitrate -le 0 -and $Probe.format.bit_rate) {
		[void][Int64]::TryParse([string]$Probe.format.bit_rate, [ref]$bitrate)
	}
	return $bitrate
}

function Test-VideoAlreadyOptimized([System.IO.FileInfo]$File) {
	$probe = Read-ProbeJson @(
		"-v", "error",
		"-select_streams", "v:0",
		"-show_entries", "stream=width,height,bit_rate:format=bit_rate",
		"-of", "json",
		$File.FullName
	)
	if ($null -eq $probe -or $probe.streams.Count -eq 0) {
		return $false
	}

	$stream = $probe.streams[0]
	$bitrate = Get-Bitrate $probe
	return ($stream.width -le $MaxVideoWidth -and $stream.height -le $MaxVideoHeight -and $bitrate -gt 0 -and $bitrate -le ($SkipVideoBitrateKbps * 1000))
}

function Test-AudioAlreadyOptimized([System.IO.FileInfo]$File) {
	$probe = Read-ProbeJson @(
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=bit_rate:format=bit_rate",
		"-of", "json",
		$File.FullName
	)
	$bitrate = Get-Bitrate $probe
	return ($bitrate -gt 0 -and $bitrate -le ($SkipAudioBitrateKbps * 1000))
}

function Replace-If-Smaller([System.IO.FileInfo]$Source, [string]$TempPath) {
	if (!(Test-Path -LiteralPath $TempPath)) {
		Write-Warning "No output produced for $(Get-RelativePath $Source.FullName)"
		return $false
	}

	$new = Get-Item -LiteralPath $TempPath
	$oldBytes = $Source.Length
	$newBytes = $new.Length
	$saving = 100.0 * ($oldBytes - $newBytes) / [math]::Max($oldBytes, 1)

	if ($newBytes -lt $oldBytes -and $saving -ge $MinSavingPercent) {
		if (!$DryRun) {
			Copy-Item -LiteralPath $TempPath -Destination $Source.FullName -Force
			Remove-TempFile $TempPath
		} else {
			Remove-TempFile $TempPath
		}
		Write-Host ("OK   {0}  {1} MB -> {2} MB  (-{3}%)" -f (Get-RelativePath $Source.FullName), (Get-MB $oldBytes), (Get-MB $newBytes), [math]::Round($saving, 1))
		return $true
	}

	Remove-TempFile $TempPath
	Write-Host ("SKIP {0}  {1} MB -> {2} MB  (-{3}%)" -f (Get-RelativePath $Source.FullName), (Get-MB $oldBytes), (Get-MB $newBytes), [math]::Round($saving, 1))
	return $false
}

Test-Tool "ffmpeg"
Test-Tool "ffprobe"

$resolvedRoots = @()
foreach ($root in $Roots) {
	if (Test-Path -LiteralPath $root) {
		$resolvedRoots += $root
	}
}

if ($resolvedRoots.Count -eq 0) {
	throw "No input roots exist."
}

$videoFiles = Get-ChildItem $resolvedRoots -Recurse -File -Include *.mp4,*.webm,*.ogv |
	Where-Object { $_.FullName -notmatch "\\export\\" -and $_.Length -ge ($MinVideoKB * 1024) } |
	Sort-Object Length -Descending

$audioFiles = Get-ChildItem $resolvedRoots -Recurse -File -Include *.ogg |
	Where-Object { $_.FullName -notmatch "\\export\\" -and $_.Length -ge ($MinAudioKB * 1024) } |
	Sort-Object Length -Descending

$videoChanged = 0
$audioChanged = 0
$oldTotal = 0L
$newTotal = 0L

foreach ($file in $videoFiles) {
	$oldTotal += $file.Length
	if (Test-VideoAlreadyOptimized $file) {
		Write-Host ("FASTSKIP video {0}  {1} MB" -f (Get-RelativePath $file.FullName), (Get-MB $file.Length))
		$newTotal += $file.Length
		continue
	}

	$temp = Join-Path $file.DirectoryName ($file.BaseName + ".compressed" + $file.Extension)
	if (Test-Path -LiteralPath $temp) {
		Remove-TempFile $temp
	}

	$vf = "scale='min($MaxVideoWidth,iw)':'min($MaxVideoHeight,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2"
	$args = @(
		"-hide_banner", "-loglevel", "error", "-y",
		"-i", $file.FullName,
		"-map", "0:v:0", "-map", "0:a?",
		"-vf", $vf,
		"-c:v", "libx264", "-preset", $VideoPreset, "-crf", [string]$VideoCrf,
		"-pix_fmt", "yuv420p", "-profile:v", "high",
		"-c:a", "aac", "-b:a", "96k", "-ar", "44100", "-ac", "2",
		"-movflags", "+faststart",
		$temp
	)

	try {
		Invoke-Checked "ffmpeg" $args
		if (Replace-If-Smaller $file $temp) {
			$videoChanged++
			$newTotal += (Get-Item -LiteralPath $file.FullName).Length
		} else {
			$newTotal += $file.Length
		}
	} catch {
		if (Test-Path -LiteralPath $temp) {
			Remove-TempFile $temp
		}
		Write-Warning "Video compression failed: $(Get-RelativePath $file.FullName) ($($_.Exception.Message))"
		$newTotal += $file.Length
	}
}

foreach ($file in $audioFiles) {
	$oldTotal += $file.Length
	if (Test-AudioAlreadyOptimized $file) {
		Write-Host ("FASTSKIP audio {0}  {1} MB" -f (Get-RelativePath $file.FullName), (Get-MB $file.Length))
		$newTotal += $file.Length
		continue
	}

	$temp = Join-Path $file.DirectoryName ($file.BaseName + ".compressed.ogg")
	if (Test-Path -LiteralPath $temp) {
		Remove-TempFile $temp
	}

	$args = @(
		"-hide_banner", "-loglevel", "error", "-y",
		"-i", $file.FullName,
		"-vn",
		"-c:a", "libvorbis", "-q:a", [string]$AudioQuality,
		"-ar", "44100", "-ac", "2",
		$temp
	)

	try {
		Invoke-Checked "ffmpeg" $args
		if (Replace-If-Smaller $file $temp) {
			$audioChanged++
			$newTotal += (Get-Item -LiteralPath $file.FullName).Length
		} else {
			$newTotal += $file.Length
		}
	} catch {
		if (Test-Path -LiteralPath $temp) {
			Remove-TempFile $temp
		}
		Write-Warning "Audio compression failed: $(Get-RelativePath $file.FullName) ($($_.Exception.Message))"
		$newTotal += $file.Length
	}
}

$saved = $oldTotal - $newTotal
Write-Host ""
Write-Host ("Compressed videos: {0}/{1}" -f $videoChanged, $videoFiles.Count)
Write-Host ("Compressed audio : {0}/{1}" -f $audioChanged, $audioFiles.Count)
Write-Host ("Total           : {0} MB -> {1} MB  saved {2} MB" -f (Get-MB $oldTotal), (Get-MB $newTotal), (Get-MB $saved))
