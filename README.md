# PowerPlex
Powershell script to automate handbrake encoding based on file properties and upload to correct location in Plex library
Lucas Stoudt
April 10th 2019
Version 1.0


Setup:
        1.     Create a folder to host PowerPlex.ps1 and the required additional files.  This folder can be named anything you want
                and can be saved in any location you want
        2.     Download handbrakecli.exe from:
                https://handbrake.fr/downloads2.php
        3.     Download MediaInfo CLI from:
                https://mediaarea.net/en/MediaInfo/Download/Windows
        4.     Handbrakeclie.exe and PowerPlex.ps1 must be in the same folder
        5.     Create a folder inside of the directory containing the above two files and name it "MediaInfo"
        6.     Extract the mediainfo zip file and copy the contents to the "MediaInfo" folder
        7.     Edit lines 7-10 of PowerPlex.ps1 by changing the default directories to your directories
        8.     Change lines 19 & 20 to match your desired handbrake options for HD content or leave at my default
        9.     Change lines 23 & 24 to match your desired handbrake options for SD content or leave at my default
        10.   Change lines  27 & 28 for your prefered audio and subtitle settings.
                Note: File sizes are a little larger, but I prefer, and have the script defaulted to this, to run ALL english audio and subtitles thru Handbrake.
                When ripping with MakeMKV I have accidentally chose a Director's Commentary track, Visually Impaired audio track, or a wrong
                subtitle track too many times.  When you have a lot of movies to do it is also too time consuming IMO to open every single file
                in VLC or some other media player before ripping  just to verify you are choosing the correct tracks.
        11.   Create a scheduled task for the script with a trigger of "At Startup" and set it to repeat.  I like 15 minutes.
                Note: Make sure that the account you choose to run the scheduled task as has the correct permissions to write to your Plex
                Media libraries.

What you do when using the script:
        1.      Change preferences in MakeMKV to English or your preferred language.  This saves many clicks when ripping your discs
        2.      Set a default folder to save the ripped files to
                 Note: Do NOT save them to the folder configured on Line 7 of PowerPlex.ps1
        3.      Rip the disc
        4.      Rename the ripped MKV file to match Plex's preferred naming conventions
                 Despicable Me 2 (2012).mkv  -  Movie example
                 Game of Thrones S03E06.mkv - TV episode example.  Season and Episode must be in the 6 character format as shown.  e.g.  SxxExx
        5.      Once the ripped files are named properly move them into the directory you configured on Line 7 of PowerPlex.ps1  e.g.  G:\Ready For Handbrake

What the script does for you:
        Example assumes all defaults from the script and above setup instructions are used
        1.      Every 15 minutes script searches G:\Ready For Handbrake for any files that have been added
        2.      If nothing is found nothing is done
        3.      If files are found it checks to make sure another instance of handbrakecli.exe isn't already running.  If there is then the script exits and will recheck next time the task runs.
        4.      it loops thru all of them and does the following
        5.      Determines if the file is a movie or TV show based on the name  (Looks for "(xxxx)" for movies)
        6.      Checks to see if the file already exists on Plex.  If it does it deletes the file from G:\Ready For Handbrake
        7.      Uses mediainfo.exe to check the pixel height of the file
        8.      If the pixel height is greater than 520 it starts handbrake and uses the HD settings.  520 was chosen because a 720p movie is actually ony 525 pixels tall if in the 2.44:1 format
        9.      If pixel height is less than 520 the SD settings are used to start handbrake
        10.    The stderr logging of handbrake is sent to a text file in C:\PowerPlex\Logs\Handbrake Info Logs
        11.    If there is a failure in the process it will retry the file a second time
        12.    If it fails again then an error log is created in C:\PowerPlex\Logs\Error Logs and the source file is deleted since it must be corrupted somehow
        13.    If handbrake was successful then the correct folders are created in your library and the file is moved
                 e.g. \\FreeNAS\PlexMedia\TV Shows\Game of Thrones\Season 1\Game of Thrones S03E06.mkv
        14.    If the file was successfully moved to Plex the original source file in G:\Ready For Handbrake is deleted
        15.    A log of all script activity is saved to C:\PowerPlex\Logs\PowerPlex-Info-Log-dd-MMM-yy-hh-mm.log
                 Example of a completed log that process 1 movie and 1 TV show:

                Marvel's The Avengers (2012).mkv - is a movie
                Marvel's The Avengers (2012).mkv - Continuing. File not found at: \\FreeNAS\PlexMedia\Movies\Marvel's The Avengers (2012)\Marvel's The Avengers (2012).mkv
                Marvel's The Avengers (2012).mkv - is HD Quality
                Marvel's The Avengers (2012).mkv - C:\PowerPlex\HandBrakeCLI.exe --input "G:\Ready For Handbrake\Marvel's The Avengers (2012).mkv" --output "G:\After Handbrake\Marvel's The Avengers (2012).mkv" --encoder x264 --encoder-preset slow --encoder-profile high --encoder-level 3.1 --quality 18 --two-pass --vfr --auto-anamorphic -modulus 2 --decomb --no-detelecine --no-hqdn3d --no-nlmeans -no-unsharp --no-lapsharp --no-deblock --no-grayscale --audio-lang-list eng --all-audio --aencoder copy --audio-copy-mask aac,ac3,eac3,truehd,dts,dtshd,mp3,flac --subtitle-lang-list eng --all-subtitles --subtitle scan --subtitle-forced=scan --subtitle-burned=scan
                Marvel's The Avengers (2012).mkv - Encoding was successful
                Marvel's The Avengers (2012).mkv - 109.4 minutes to reduce file from 34.4 GB to 13.2 GB saving 38.4% space
                Marvel's The Avengers (2012).mkv - Successfully moved to \\FreeNAS\PlexMedia\TV Shows\House\Season 01\
                --------------------------------------------------------------------------------------
                House S01E13.mkv - is a TV Show
                House S01E13.mkv - Continuing. File not found at: \\FreeNAS\PlexMedia\TV Shows\House\Season 01\House S01E13.mkv
                House S01E13.mkv - is Standard Quality
                House S01E13.mkv - C:\PowerPlex\HandBrakeCLI.exe --input "G:\Ready For Handbrake\House S01E13.mkv" --output "G:\After Handbrake\House S01E13.mkv" --encoder x264 --encoder-preset slow --encoder-profile high --encoder-level 3.1 --quality 18 --two-pass --vfr --auto-anamorphic -modulus 2 --decomb --no-detelecine --no-hqdn3d --no-nlmeans -no-unsharp --no-lapsharp --no-deblock --no-grayscale --audio-lang-list eng --all-audio --aencoder copy --audio-copy-mask aac,ac3,eac3,truehd,dts,dtshd,mp3,flac --subtitle-lang-list eng --all-subtitles --subtitle scan --subtitle-forced=scan --subtitle-burned=scan
                House S01E13.mkv - Encoding was successful
                House S01E13.mkv - 12.4 minutes to reduce file from 1718.7 MB to 525.3 MB saving 69.4% space
                House S01E13.mkv - Successfully moved to \\FreeNAS\PlexMedia\TV Shows\House\Season 01\
                --------------------------------------------------------------------------------------