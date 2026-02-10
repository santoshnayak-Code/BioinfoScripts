#!/bin/bash

INPUT_FILE=$1
LOG_FILE="process.log"
MAX_CYCLES=5  # Maximum number of times to retry the entire list

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <filename.tsv>"
    exit 1
fi

run_download_cycle() {
    # We use a global variable so the outer loop can see it
    corruption_found=0
    
    # Using < <(...) instead of | while to avoid the subshell variable loss
    while IFS=$'\t' read -r accession md5_list ftp_list; do
        
        IFS=';' read -r -a md5_array <<< "$md5_list"
        IFS=';' read -r -a ftp_array <<< "$ftp_list"

        for i in "${!ftp_array[@]}"; do
            url="${ftp_array[$i]}"
            expected_hash=$(echo "${md5_array[$i]}" | tr -d '\r' | xargs)
            fname=$(basename "$url")

            # 1. Download/Resume with wget
            if [ ! -f "$fname" ]; then
                echo "$(date): Downloading $fname..." | tee -a "$LOG_FILE"
                wget -c -t 5 --waitretry=5 -O "$fname" "ftp://$url" 2>> "$LOG_FILE"
            fi

            # 2. Verification using Linux standard md5sum
            current_hash=$(md5sum "$fname" | awk '{print $1}' | tr -d '\r' | xargs)
            
            if [ "$current_hash" != "$expected_hash" ]; then
                echo "$(date): ERROR: Hash mismatch for $fname" | tee -a "$LOG_FILE"
                echo "  -> Expected: $expected_hash" | tee -a "$LOG_FILE"
                echo "  -> Actual:   $current_hash" | tee -a "$LOG_FILE"
                rm "$fname"
                corruption_found=1  # Signals that we need another cycle
            else
                echo "$(date): $fname Verified." | tee -a "$LOG_FILE"
            fi
        done
    done < <(tail -n +2 "$INPUT_FILE")
    
    return $corruption_found
}

# Main Supervisor Loop
cycle_count=1

while [ $cycle_count -le $MAX_CYCLES ]; do
    echo "$(date): Starting Cycle $cycle_count of $MAX_CYCLES..." | tee -a "$LOG_FILE"
    
    run_download_cycle
    status=$? # Captures the return value of corruption_found
    
    if [ $status -eq 0 ]; then
        echo "------------------------------------------------" | tee -a "$LOG_FILE"
        echo "SUCCESS: All files verified after $cycle_count cycle(s)." | tee -a "$LOG_FILE"
        exit 0
    else
        if [ $cycle_count -lt $MAX_CYCLES ]; then
            echo "Cycle $cycle_count found issues. Retrying in 10s..." | tee -a "$LOG_FILE"
            sleep 10
        fi
        ((cycle_count++))
    fi
done

echo "------------------------------------------------" | tee -a "$LOG_FILE"
echo "FAILED: Reached maximum limit of $MAX_CYCLES cycles. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
exit 1
