#!/bin/bash

# This script prompts the user for a YouTube URL and downloads it using yt-dlp in MP4 format.

while true;
do
    # Prompt the user for the URL
    read -r -p "Enter YouTube URL to download (or press Enter to exit): " url

    # Check if the URL is not empty
    if [[ -n "$url" ]]; then
        echo "\n--- Starting download for: $url ---"
        
        # Execute yt-dlp with the specified options
        # -f mp4: Select the best pre-merged MP4 format
        # The output will be saved to the current directory (/home/kim/Desktop)
        yt-dlp -f bestvideo+bestaudio --merge-output-format mp4 "$url"
        
        # Check the exit status of yt-dlp
        if [ $? -eq 0 ]; then
            echo "\n======================================"
            echo "✅ SUCCESS! Download complete for: $url"
            echo "======================================"
        else
            echo "\n======================================"
            echo "❌ ERROR! Download failed for: $url"
            echo "(Check the output above for details like 'The page needs to be reloaded' or 'Unable to extract uploader id')"
            echo "======================================"
        fi
        
    else
        # If the user pressed Enter without a URL, break the loop
        echo "\nExiting download script. Goodbye! 👋"
        break
    fi
done