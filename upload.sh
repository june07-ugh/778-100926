#!/bin/bash

# Check if --no-sleep or -n was passed as an argument
SKIP_SLEEP=false
for arg in "$@"; do
    if [ "$arg" = "--no-sleep" ] || [ "$arg" = "-n" ]; then
        SKIP_SLEEP=true
        break
    fi
done

# Apply sleep delay unless skipped
if [ "$SKIP_SLEEP" = false ]; then
    sleep $((RANDOM % 30))
fi

HOSTNAME=`hostname`
# Define paths and repo details
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
REPO_DIR="/home/adrian/778-repo"
REPO_DIR_DAY="${REPO_DIR}/${YEAR}/${MONTH}/${DAY}"
IMAGE_DEST_PREFIX="$REPO_DIR_DAY/snapshot"
BRANCH="main" # Change to 'master' if your default branch is master
TIMESTAMP=`date +%s`
DATETIMESTAMP=$(TZ="America/Chicago" date +"%Y-%m-%d %H:%M:%S")
IMAGE1="${IMAGE_DEST_PREFIX}-${HOSTNAME}-${TIMESTAMP}-1.jpg"
IMAGE2="${IMAGE_DEST_PREFIX}-${HOSTNAME}-${TIMESTAMP}-2.jpg"

FLIP_ARG1=""
FLIP_ARG2=""
if [ "$HOSTNAME" = "art" ]; then
    FLIP_ARG1="--flip v,h"
    FLIP_ARG2="--flip v,h"
elif [ "$HOSTNAME" = "library" ]; then
    FLIP_ARG1="--flip v,h"
    FLIP_ARG2=""
fi

if [ ! -d "$REPO_DIR" ]; then
	mkdir $REPO_DIR
fi

# 2. Clone the repo if it doesn't exist locally yet (run this setup once beforehand)
if [ ! -d "$REPO_DIR/.git" ]; then
	cd $REPO_DIR

	git config --global init.defaultBranch $BRANCH
	git config --global user.name "adrian@${HOSTNAME}"
	git config --global user.email "778@onezerohosting.com"

	#git init
	git remote add origin git@github.com:june07/778.git

	# 2. Enable sparse checkout and target ONLY the snapshot file
	git clone --depth 1 --branch main https://github.com/june07/778.git $REPO_DIR
	git sparse-checkout init --cone
	if [ "$HOSTNAME" == "art" ]; then
		git sparse-checkout set snapshot-1.jpg snapshot-2.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
	elif [ "$HOSTNAME" == "library" ]; then
		git sparse-checkout set snapshot-3.jpg snapshot-4.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
	elif [ "$HOSTNAME" == "aaliyah" ]; then
		git sparse-checkout set snapshot-5.jpg snapshot-6.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
	fi

	git pull origin "$BRANCH"
else
	if [ "$HOSTNAME" == "art" ]; then
                git sparse-checkout set snapshot-1.jpg snapshot-2.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
        elif [ "$HOSTNAME" == "library" ]; then
                git sparse-checkout set snapshot-3.jpg snapshot-4.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
        elif [ "$HOSTNAME" == "aaliyah" ]; then
                git sparse-checkout set snapshot-5.jpg snapshot-6.jpg ${IMAGE1#${REPO_DIR}/} ${IMAGE2#${REPO_DIR}/}
        fi
fi

if [ ! -d $REPO_DIR_DAY ]; then
	mkdir -p $REPO_DIR_DAY
fi

# Define your camera pairs (Device, Flip argument, Image filename)
cameras=(
    "/dev/video0|$FLIP_ARG1|$IMAGE1"
    "/dev/video2|$FLIP_ARG2|$IMAGE2"
)

# 1. Overlay timestamp and save as the "live" pointer
for cam in "${cameras[@]}"; do
    IFS='|' read -r dev flip img <<< "$cam"
    IMAGE_NAME=$(basename $img)
    TEMP_IMAGE="/tmp/$IMAGE_NAME"
 
    # 1. Take snapshot
    fswebcam --set "auto_exposure=1" \
             --set "exposure_time_absolute=50" \
	     --set "focus_automatic_continuous=0" \
             --set "focus_absolute=0" \
             $flip -S 20 -F 2 -d "$dev" -r 1280x720 --no-banner "$TEMP_IMAGE"

    # 2. Overlay timestamp and save to final destination
    convert "$TEMP_IMAGE" \
      -gravity SouthEast \
      -background 'rgba(0, 0, 0, 0.5)' \
      -fill white \
      -font Helvetica \
      -pointsize 18 \
      -splice 0x28 \
      -annotate +10+5 " $DATETIMESTAMP " \
      "$img"

    rm $TEMP_IMAGE
done


# 3. Enter repo, commit, and push
cd "$REPO_DIR" || exit 1
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

cp /mnt/upload.sh "${REPO_DIR}"

if [ "$HOSTNAME" == "art" ]; then
	cp $IMAGE1 "${REPO_DIR}/snapshot-1.jpg"
	cp $IMAGE2 "${REPO_DIR}/snapshot-2.jpg"
elif [ "$HOSTNAME" == "library" ]; then
	cp $IMAGE1 "${REPO_DIR}/snapshot-3.jpg"
	cp $IMAGE2 "${REPO_DIR}/snapshot-4.jpg"
elif [ "$HOSTNAME" == "aaliyah" ]; then
	cp $IMAGE1 "${REPO_DIR}/snapshot-5.jpg"
	cp $IMAGE2 "${REPO_DIR}/snapshot-6.jpg"
fi

git add .
git commit -m "Auto-update snapshot: $(date -u)"
git push origin "$BRANCH"

# cleanup
du -sh "$REPO_DIR"
find "$REPO_DIR" -type f -name "*.jpg" -mmin +1440 -delete
du -sh "$REPO_DIR"
