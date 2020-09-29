# Last updated 7-21-20
$i = 0
$i++

Clear-Variable matches -ErrorAction SilentlyContinue

$MediaDir = "G:\Media\Youtube"
$LogDirectory = "C:\Scripts\Youtube_Downloader\Logs"
$YT = "C:\Scripts\Youtube_Downloader\youtube-dl.exe"
$plexTokenLocation = "C:\Scripts\Youtube_Downloader\PlexToken.txt"

$ageScope = "20" # Days to look back for videos, based on date published.
$repeatDelay = "3600"
# Read data file with the list of youtube channels to check xml
[xml]$YTIndex = Get-Content "C:\Scripts\Youtube_Downloader\youtubeData.xml" -ErrorAction SilentlyContinue
[string]$plexToken = Get-Content "$plexTokenLocation"


$date = (Get-Date -UFormat %Y-%m-%d).tostring()
$fileRenameOutput = "%(title)s - [$date] - [%(id)s].%(ext)s"

# Foreach channel in index
Foreach ($channel in $($YTIndex.opml.body.outline))
    {
        Clear-Variable ChannelID -ErrorAction SilentlyContinue

        # Read the video info from the youtube channel
        [xml]$ChannelInfo = iwr -uri $($channel.xmlUrl)

        # If the "folderOverride" value has been set in the xml for the folder name, respect that (this was for when youtube channels change ID's to keep consistent location/directory for plex)
        if (!$Channel.folderOverride)
            {
                # Grab the Channel ID as well from the url in the config file
                $channelID = $ChannelInfo.feed.ChannelID
            }
        Else
            {
                $channelID = $Channel.folderOverride
            }

        # Check to make sure each channel already has a folder in destination, if not, make it
        $pathExists = Test-Path -LiteralPath "$($MediaDir)\$($Channel.title) [$($channelID)]"
        if ($pathExists -eq $false) { mkdir "$($MediaDir)\$($Channel.title) [$($channelID)]" }

        # Check to make sure the log file exists, otherwise make one
        $logExists = Test-Path -LiteralPath "$($MediaDir)\$($Channel.title) [$($channelID)]\VideoLog.txt"
        if ($logExists -eq $false) { Out-File "$($MediaDir)\$($Channel.title) [$($channelID)]\VideoLog.txt"}

        # Move into directory just made, or one that already existed
        #$shutup = CD -LiteralPath "$($MediaDir)\$($Channel.title) [$($channelID)]"

        # Directory for which we will store files and logs
        [string]$CurrentMediaDir = "$($MediaDir)\$($Channel.title) [$($channelID)]"

        # Read log file
        $CurrentLog = Get-Content -LiteralPath "$CurrentMediaDir\VideoLog.txt"

        # Reduce the list of videos by the age scope set above
        $ChannelinfoFiltered = $ChannelInfo.feed.entry | Where {[datetime]$_.published -gt ((Get-Date).adddays(-$($ageScope)))}

        # For each video listed in the channelinfo
        Foreach ($video in $($ChannelinfoFiltered))
            {
                # Check to see if the video was already downloaded, in the log file
                if (!($CurrentLog -contains "$($Video.videoID)"))
                    {
                        # Video not already in log
                        # Check to see if there is a filter on the channel
                        if ($channel.filter)
                            {
                                # If it matches the blacklist filter, do nothing.
                                if ( $video.title -match $channel.filter)
                                    { }
                                Else
                                    {
                                        # set the arguments down here so that the variables expand with the right data
                                        $ARGS = @("$($video.link.href)",'-f','bestvideo[height<=1080]+bestaudio','--no-part', '--embed-subs', '--write-thumbnail', '--add-metadata', "-o", "`"$CurrentMediaDir\$fileRenameOutput`"","--cookies", "C:\Scripts\Youtube_Downloader\cookies.txt")
                                        $StartProcessResult = Start-process -FilePath "$YT" -NoNewWindow -PassThru -wait -ArgumentList $ARGS -RedirectStandardError "$LogDirectory\ErrorOutput\ErrorLog-$((Get-Date -Format yyy-MM-ddTHH-mm-ss).tostring()).log" -RedirectStandardOutput "$LogDirectory\StandardOutput\StandardOutput-$((Get-Date -Format yyy-MM-ddTHH-mm-ss).tostring()).log"
                                    }
                            }
                        Else
                            {
                                # set the arguments down here so that the variables expand with the right data
                                $ARGS = @("$($video.link.href)",'-f','bestvideo[height<=1080]+bestaudio','--no-part', '--embed-subs', '--write-thumbnail', '--add-metadata', "-o", "`"$CurrentMediaDir\$fileRenameOutput`"","--cookies", "C:\Scripts\Youtube_Downloader\cookies.txt")
                                $StartProcessResult = Start-process -FilePath "$YT" -NoNewWindow -PassThru -wait -ArgumentList $ARGS -RedirectStandardError "$LogDirectory\ErrorOutput\ErrorLog-$((Get-Date -Format yyy-MM-ddTHH-mm-ss).tostring()).log" -RedirectStandardOutput "$LogDirectory\StandardOutput\StandardOutput-$((Get-Date -Format yyy-MM-ddTHH-mm-ss).tostring()).log"
                            }

                        # If the download and merging of the file was succesful (exit code 0), add the video id to the videoLog file.
                        if ($StartProcessResult.ExitCode -eq '0')
                            {
                                # Add the videoID to the Log file
                                $video.videoId | Out-File -LiteralPath "$($MediaDir)\$($Channel.title) [$($channelID)]\VideoLog.txt" -Append

                                # Kick a library refresh
                                $shutup = Invoke-WebRequest -uri "http://127.0.0.1:32400/library/sections/all/refresh?X-Plex-Token=$($plexToken)"
                            }
                    }
            }

    }
