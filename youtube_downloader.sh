#!/bin/bash

# --- Configuration ---
# IMPORTANT: Replace these placeholder URLs with ACTUAL YouTube channel URLs
# e.g., "https://www.youtube.com/@SpecificChannel" or "https://www.youtube.com/channel/UC..."
# The googleusercontent URLs provided are not standard YouTube channel URLs.
CHANNEL_URLS=(
    "https://www.youtube.com/@goosetheband" # Replace with actual Channel URL 1
    # Add more channel URLs as needed
)

# --- Directories (Make sure these exist or the script will create them) ---
BASE_DIR="/home/neil/youtube_downloader" # Base directory for all downloads
VIDEO_DIR="${BASE_DIR}/videos"
METADATA_DIR="${BASE_DIR}/metadata"
LOG_DIR="${BASE_DIR}/logs"
ARCHIVE_FILE="${BASE_DIR}/downloaded_archive.txt" # yt-dlp's archive file
LOG_FILE="${LOG_DIR}/downloader.log"
METADATA_PROCESSOR_SCRIPT="${BASE_DIR}/process_metadata.sh" # Path to the helper script

# --- Create directories if they don't exist ---
mkdir -p "$VIDEO_DIR"
mkdir -p "$METADATA_DIR"
mkdir -p "$LOG_DIR"

# --- Logging Function ---
log_message() {
    local type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $message" >> "$LOG_FILE"
}

# --- Sanity Checks ---
if ! command -v yt-dlp &> /dev/null; then
    log_message "ERROR" "yt-dlp command could not be found. Please install it."
    echo "ERROR: yt-dlp command could not be found. Please install it."
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    log_message "WARNING" "ffmpeg command could not be found. It might be needed for merging formats."
    echo "WARNING: ffmpeg command could not be found. It might be needed for merging formats."
    # Continue execution as yt-dlp might handle some cases without it or use ffprobe
fi

if ! command -v jq &> /dev/null; then
    log_message "ERROR" "jq command could not be found. Please install it (sudo apt install jq)."
    echo "ERROR: jq command could not be found. Please install it (sudo apt install jq)."
    exit 1
fi

if [ ! -f "$METADATA_PROCESSOR_SCRIPT" ]; then
    log_message "ERROR" "Metadata processor script not found at $METADATA_PROCESSOR_SCRIPT"
    echo "ERROR: Metadata processor script not found at $METADATA_PROCESSOR_SCRIPT"
    exit 1
fi

# --- Main Processing Loop ---
log_message "INFO" "Starting YouTube download check."

for channel_url in "${CHANNEL_URLS[@]}"; do
    log_message "INFO" "Checking channel: $channel_url"

    # Use yt-dlp to download new videos
    # -f: Select best video and audio, prefer mp4/m4a, merge if needed.
    # --merge-output-format: Ensure the final merged file is mp4.
    # --download-archive: Keep track of downloaded videos to avoid re-downloading.
    # --write-info-json: Create a .info.json file with metadata next to the video.
    # -o: Output template for video files. Organizes by channel name & date.
    # --exec: Run the metadata processor script AFTER successful download of each video.
    #         Passes the metadata directory and the video file path to the script.
    # --ignore-errors: Continue processing other videos in the channel list if one fails.
    # --no-warnings: Suppress yt-dlp warnings like "Falling back on generic information extractor".
    # --retries: Number of retries on download errors.
    # --fragment-retries: Number of retries for fragments (useful for live streams or unstable connections).

    /home/neil/.local/bin/yt-dlp \
        -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
        --merge-output-format mp4 \
        --download-archive "$ARCHIVE_FILE" \
        --write-info-json \
        -o "$VIDEO_DIR/%(channel)s/%(upload_date)s - %(title)s [%(id)s].%(ext)s" \
        --exec "bash '$METADATA_PROCESSOR_SCRIPT' '$METADATA_DIR' {}" \
        --ignore-errors \
        --no-warnings \
        --retries 5 \
        --fragment-retries 5 \
        "$channel_url"

    # Capture yt-dlp exit status
    status=$?
    if [ $status -ne 0 ]; then
        log_message "ERROR" "yt-dlp encountered errors (exit code $status) for channel: $channel_url"
    else
        log_message "INFO" "Finished checking channel: $channel_url"
    fi
done

log_message "INFO" "YouTube download check finished."
echo "YouTube download check finished. See $LOG_FILE for details."

exit 0
