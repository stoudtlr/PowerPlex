# Created by Lucas Stoudt
# April 10th 2019
#Version 1.0

# Change these variables to match your needs or preferences

$RippedFolderPath = 'G:\Ready For Handbrake'
$ConvertedFolderPath = 'G:\After Handbrake'
$PlexMovieFolderPath = '\\FreeNAS\PlexMedia\Movies'
$PlexTVShowFolderPath = '\\FreeNAS\PlexMedia\TV Shows'

# Handbrake Settings
# To use a built in preset, delete $null and provide a value in this format:
# ' --preset "HQ 1080p30 Surround"'
# Manual video settings will then be ignored and the preset used instead

    #HD Content is 720p or higher - determined by pixel height of content.
    #Includes anything over 520 pixels to account for 2.44 aspect ratio which is only 525, not 720
    $HDQualityPreset = $null
    $HDVideoSettings = '--encoder x264 --encoder-preset slow --encoder-profile high --encoder-level 4.1 --quality 20 --two-pass --vfr --auto-anamorphic -modulus 2 --decomb --no-detelecine --no-hqdn3d --no-nlmeans -no-unsharp --no-lapsharp --no-deblock --no-grayscale'
    
    #SD Content is anything lower than 720p
    $SDQualityPreset = $null
    $SDVideoSettings = '--encoder x264 --encoder-preset slow --encoder-profile high --encoder-level 3.1 --quality 18 --two-pass --vfr --auto-anamorphic -modulus 2 --decomb --no-detelecine --no-hqdn3d --no-nlmeans -no-unsharp --no-lapsharp --no-deblock --no-grayscale'

    #Audio and Subtitle settings are same for both SD and HD content
    $AudioSettings = ' --audio-lang-list eng --all-audio --aencoder copy --audio-copy-mask aac,ac3,eac3,truehd,dts,dtshd,mp3,flac'
    $SubtitleSettings = ' --subtitle-lang-list eng --all-subtitles --subtitle scan --subtitle-forced=scan --subtitle-burned=scan'

###################################
#DO NOT CHANGE ANYTHING BELOW THIS#
###################################

#Log and exe paths
$PowerPlexDIR = Split-Path $Script:MyInvocation.MyCommand.Path
$HandbrakeLogPath = "$PowerPlexDIR\Logs\Handbrake Info Logs"
$PowerPlexErrorLogPath = "$PowerPlexDIR\Logs\Error Logs"
$PowerPlexLogPath = "$PowerPlexDIR\Logs"
$HandbrakeCLI = "$PowerPlexDIR\HandBrakeCLI.exe"
$MediaInfoCLI = "$PowerPlexDIR\MediaInfoCLI\MediaInfo.exe"

#Check for files to transcode and add to Plex
$RippedFiles = Get-ChildItem -Path $RippedFolderPath
$InfoLogTime = Get-Date -Format d-MMM-yy-hh-mm-tt
$PowerPlexLog = "$PowerPlexLogPath\PowerPlex-Info-Log-$InfoLogTime.log"
If ($RippedFiles) {
    #check Prerequisites
    $HandbrakeCLIProcess = Get-Process -Name "HandbrakeCLI.exe"
    if ($HandbrakeCLIProcess) {
        $HandbrakeRunning = "An instance of handbrakecli.exe was already running`n"
    }
    if (!(Test-Path -Path "$HandbrakeCLI")) {
        $NoHandbrake = "Could not locate HandBrakeCLI.exe`nHandBrakeCLI needed at:  $HandbrakeCLI`n"
    }
    if (!(Test-Path -Path "$MediaInfoCLI")) {
        $NoMediaInfo = "Could not locate MediaInfoCLI.exe`nMediaInfoCLI needed at:  $MediaInfoCLI`n"
    }
    if ((!(Test-Path -Path "$HandbrakeCLI")) -or (!(Test-Path -Path "$MediaInfoCLI")) -or ($HandbrakeCLIProcess)) {
        New-Item -Path $PowerPlexErrorLogPath -Name "Error-$InfoLogTime.log" -ItemType "file" -Value "$HandbrakeRunning`n$NoHandbrake`n$NoMediaInfo"
    }


    New-Item -Path $PowerPlexLog -ItemType File -Force

    #Loop thru every file in the ready for handbrake folder
    :outer Foreach ($RippedFile in $RippedFiles) {
        $Convert = $null
        $TVShow = $null
        $Movie = $null
        $FileRetryCount = 1
        $FileRetryMax = 2
        :inner do {
            #Delete file and go to next if it has already failed 3 times
            If ($FileRetryCount -gt $FileRetryMax) {
                $Time = Get-Date -Format d-MMM-yy-hh-mm-tt
                Add-Content -Path $PowerPlexLog -Value "$RippedFile - Transcode failed twice. Deleting source file. Rip disc again before retrying.`n--------------------------------------------------------------------------------------"
                New-Item -Path $PowerPlexErrorLogPath -Name "Error-$RippedFile-$Time.log" -ItemType "file" -Value "Check Handbrake logs for $RippedFile.`nMultiple Failed Conversions`nSource file has been deleted.`nRip file again and retry." -Force
                Remove-Item -Path $RippedFile.fullname -Force
                break inner
            }
            #Check to see if file is TV Show or Movie and if it already exists in PLEX
            $RippedFileName = ($RippedFile.Name).TrimEnd(".mkv")
            If ($RippedFileName -like "*(*)") {
                #Movie
                Add-Content -Path $PowerPlexLog -Value "$RippedFile - is a movie"
                $Movie = $true
                if (Test-Path -Path "$PlexMovieFolderPath\$RippedFileName\$RippedFile") {
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - already exists on Plex, skipping and deleting source file`n--------------------------------------------------------------------------------------"
                    Remove-Item -Path $RippedFile.fullname -Force
                    break inner
                } else {
                    $Convert = $true
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - Continuing. File not found at: $PlexMovieFolderPath\$RippedFileName\$RippedFile"
                }
            } else {
                #TV Show
                Add-Content -Path $PowerPlexLog -Value "$RippedFile - is a TV Show"
                $TVShow = $true
                #Get Season and check if file already exists in PLEX
                $TVShowName = $RippedFileName.substring(0,$RippedFileName.length - 7)
                $SeasonAndEpisode = $RippedFileName.substring($RippedFileName.length - 6)
                $SeasonNumber = ($SeasonAndEpisode.substring(0,$SeasonAndEpisode.length-3)).substring(1)
                if (Test-Path -Path "$PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber\$RippedFile") {
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - already exists on Plex, skipping and deleting source file`n--------------------------------------------------------------------------------------"
                    Remove-Item -Path $RippedFile.fullname -Force
                    break inner
                } else {
                    $Convert = $true
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - Continuing. File not found at: $PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber\$RippedFile"
                }
            }

            If ($Convert) {
                #Check quality (SD or HD) then convert in handbrake
                $Height = . $MediaInfoCLI --Inform="Video;%Height%" $RippedFile.FullName
                If ([int]$Height -ge "520") {
                    #Use HD settings
                    $Bits = 1GB
                    $B = "GB"
                    if ($HDQualityPreset) {
                        $Options = $HDQualityPreset
                    } else {
                        $Options = $HDVideoSettings + $AudioSettings + $SubtitleSettings
                    }
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - is HD Quality"
                } else {
                    #Use SD settings
                    $Bits = 1MB
                    $B = "MB"
                    if ($SDQualityPreset) {
                        $Options = $SDQualityPreset
                    } else {
                        $Options = $SDVideoSettings + $AudioSettings + $SubtitleSettings
                    }
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - is Standard Quality"
                }

                $InputFile = $RippedFile.FullName
                $OutputFile = "$ConvertedFolderPath\$RippedFile"
                $Time = Get-Date -Format d-MMM-yy-hh-mm-tt
                $HandbrakeArguments = "--input `"$InputFile`" --output `"$OutputFile`" $Options"
                Add-Content -Path $PowerPlexLog -Value "$RippedFile - $HandbrakeCLI $HandbrakeArguments"
                
                $EncodeTime = Measure-Command -Expression {
                    Start-Process $HandbrakeCLI -ArgumentList $HandbrakeArguments -NoNewWindow -Wait -RedirectStandardError "$HandbrakeLogPath\$RippedFile-$Time.txt"
                }

                #Ensure encoding was successful and log time and sizes
                $EncodingLog = Get-Content -Path "$HandbrakeLogPath\$RippedFile-$Time.txt" -Tail 10
                if ($EncodingLog -contains "Encode done!") {
                    $OriginalSize = [math]::Round(((Get-Item $InputFile).Length/$Bits),1)
                    $NewSize = [math]::Round(((Get-Item $OutputFile).Length/$Bits),1)
                    $SpaceSaved = 100 - ([math]::Round(($NewSize * 100 / $OriginalSize),1))
                    $TimeMinutes = [math]::Round(($EncodeTime.TotalMinutes),1)
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - Encoding was successful"
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - $TimeMinutes minutes to reduce file from $OriginalSize $B to $NewSize $B saving $SpaceSaved% space"
                    If ($Movie) {
                        if (!(Test-Path -Path "$PlexMovieFolderPath\$RippedFileName")) {
                            New-Item -Path "$PlexMovieFolderPath\$RippedFileName" -ItemType Directory -Force
                        }
                        #Move file to Plex
                        Move-Item -Path $OutputFile -Destination "$PlexMovieFolderPath\$RippedFileName\$RippedFile" -Force
                        #Delete original file if encoding finished
                        if (Test-Path -Path "$PlexMovieFolderPath\$RippedFileName\$RippedFile") {
                            Add-Content -Path $PowerPlexLog -Value "$RippedFile - Successfully moved to $PlexMovieFolderPath\$RippedFileName\`n--------------------------------------------------------------------------------------"
                            Remove-Item -Path $RippedFile.fullname -Force
                            Break inner
                        }
                    }
                    If ($TVShow) {
                        if (!(Test-Path -Path "$PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber")) {
                            New-Item -Path "$PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber" -ItemType Directory -Force
                        }
                        #Move file to Plex
                        Move-Item -Path $OutputFile -Destination "$PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber\$RippedFile" -Force
                        #Delete original file if encoding finished
                        If (Test-Path -Path "$PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber\$RippedFile") {
                            Add-Content -Path $PowerPlexLog -Value "$RippedFile - Successfully moved to $PlexTVShowFolderPath\$TVShowName\Season $SeasonNumber\`n--------------------------------------------------------------------------------------"
                            Remove-Item -Path $RippedFile.fullname -Force
                            Break inner
                        }
                    }
                } else {
                    Add-Content -Path $PowerPlexLog -Value "$RippedFile - Encoding failed $FileRetryCount time(s). Deleting output file if it exists to try again."
                    $FileRetryCount++
                    if (Test-Path -Path $OutputFile) {
                        Remove-Item -Path $OutputFile -Force
                    }
                }
            }
        } while ($FileRetryCount -le $FileRetryMax)
    }
}
