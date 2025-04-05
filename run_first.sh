#!/bin/bash

# --- Configuration ---
# Use the EXACT SAME configuration as your youtube_downloader.sh script
CHANNEL_URLS=(
    "https://www.youtube.com/@goosetheband" # Replace with actual Channel URL 1 (Must match youtube_downloader.sh)
    # Add more channel URLs as needed (Must match youtube_downloader.sh)
)

# --- Directories (Must match youtube_downloader.sh) ---
BASE_DIR="/home/neil/youtube_downloader" # Your base directory
LOG_DIR="${BASE_DIR}/logs"
ARCHIVE_FILE="${BASE_DIR}/downloaded_archive.txt" # ! Crucial: Must be the same archive file path !
LOG_FILE="${LOG_DIR}/prime_archive.log"

# --- Create directories ---
mkdir -p "$LOG_DIR"
mkdir -p "$BASE_DIR"

# --- Logging ---
log_message() {
    local type="$1" message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $message" | tee -a "$LOG_FILE" # Log and print to console
}

# --- Sanity Checks ---
if ! command -v yt-dlp &> /dev/null; then
    log_message "ERROR" "yt-dlp command could not be found. Please install it."
    exit 1
fi
if ! command -v sed &> /dev/null; then
    log_message "ERROR" "sed command could not be found. It is needed for formatting."
    exit 1
fi
if ! command -v sort &> /dev/null; then
    log_message "ERROR" "sort command could not be found. It is needed for deduplication."
    exit 1
fi

# --- Main Processing ---
log_message "INFO" "Starting archive priming process (Attempt: using --get-id and shell redirection)."
log_message "INFO" "Target archive file: $ARCHIVE_FILE"

# Clear the log file for this run
> "$LOG_FILE"
# Clear the archive file before populating to ensure a clean state
> "$ARCHIVE_FILE"
log_message "INFO" "Cleared existing archive file (if any): $ARCHIVE_FILE"

initial_count=0 # Should be 0 since we cleared it

for channel_url in "${CHANNEL_URLS[@]}"; do
    log_message "INFO" "Getting video IDs for channel: $channel_url"

    # Get all video IDs using --get-id and --flat-playlist (efficient for just IDs)
    # Pipe the IDs, format them with 'youtube ' prefix using sed, and append (>>) to the archive file
    yt-dlp \
        --get-id \
        --flat-playlist \
        --ignore-errors \
        --no-warnings \
        "$channel_url" | sed 's/^/youtube /' >> "$ARCHIVE_FILE"

    # Check the exit status of yt-dlp (the first command in the pipe)
    status=${PIPESTATUS[0]}
    if [ $status -ne 0 ]; then
        log_message "WARNING" "yt-dlp may have encountered errors (exit code $status) getting IDs for channel: $channel_url."
    else
        log_message "INFO" "Finished getting IDs for channel: $channel_url"
    fi
    # Small sleep to avoid potential rate limiting if processing many channels quickly
    sleep 1
done

# Remove duplicate lines that might occur if yt-dlp lists an ID multiple times (e.g., across tabs)
log_message "INFO" "Removing potential duplicate entries from archive file..."
sort -u "$ARCHIVE_FILE" -o "$ARCHIVE_FILE"

# Count lines in the archive file
ARCHIVE_COUNT=$(wc -l < "$ARCHIVE_FILE")
log_message "INFO" "Archive priming process finished. Archive file '$ARCHIVE_FILE' now contains $ARCHIVE_COUNT unique entries."
echo "------------------------------------------------------------------"
if [ "$ARCHIVE_COUNT" -gt "$initial_count" ]; then
     echo "SUCCESS: The archive file '$ARCHIVE_FILE' has been populated with $ARCHIVE_COUNT entries."
     echo "You can now run './youtube_downloader.sh' regularly."
else
     echo "ERROR: Failed to populate the archive file '$ARCHIVE_FILE'."
     echo "Please check the log file '$LOG_FILE' and yt-dlp output for errors."
     echo "Ensure the channel URL is correct and yt-dlp is up-to-date ('yt-dlp -U')."
fi
echo "------------------------------------------------------------------"

exit 0
