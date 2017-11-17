#!/usr/bin/env bash

set -e

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
  echo "Usage: rpi-dualbootify <image-one.img> <image-two.img> <dual.img> [options]"
  echo
  echo "  --extra-sectors <expand-image-two-with-these-sectors>"
  echo "  --extra-bytes   <same-as-above-but-in-bytes>"
  echo
  exit 1
fi

EXTRA_SECTORS=0
IMAGE_ONE="$1"
IMAGE_TWO="$2"
IMAGE_DUAL="$3"

shift
shift
shift

while true; do
  case "$1" in
    --extra-sectors) EXTRA_SECTORS=$2; shift; shift ;;
    --extra-bytes)   EXTRA_SECTORS=$(($2 / 512)); shift; shift ;;
    *)               break ;;
  esac
done

echo "extra $EXTRA_SECTORS"

parse_image () {
  local IFS=$'\n'
  local first=true
  local NAME="$1_BOOT"

  for i in $(fdisk $2 -l | grep "^$2"); do
    eval "$NAME"_START=$(echo $i | awk '{print $2}')
    eval "$NAME"_SECTORS=$(($(echo $i | awk '{print $4}') - 1))
    local NAME="$1_ROOT"
  done
}

parse_image IMAGE_ONE $IMAGE_ONE
parse_image IMAGE_TWO $IMAGE_TWO

IMAGE_TWO_ROOT_SECTORS=$(($IMAGE_TWO_ROOT_SECTORS + $EXTRA_SECTORS))
FDISK_CMD="$FDISK_CMD""n\np\n1\n$IMAGE_ONE_BOOT_START\n+$IMAGE_ONE_BOOT_SECTORS\n"
FDISK_CMD="$FDISK_CMD""n\np\n2\n$IMAGE_ONE_ROOT_START\n+$IMAGE_ONE_ROOT_SECTORS\n"

EXTENDED_START=$(($IMAGE_ONE_ROOT_START + $IMAGE_ONE_ROOT_SECTORS))
EXTENDED_SECTORS=$(($IMAGE_TWO_BOOT_SECTORS + $IMAGE_TWO_ROOT_SECTORS + 4096 + 1))
LOGICAL_START=$(($EXTENDED_START + 2048))

IMAGE_TWO_BOOT_LOGICAL_START=$(($LOGICAL_START + 1))

FDISK_CMD="$FDISK_CMD""n\ne\n3\n$(($EXTENDED_START + 1))\n+$EXTENDED_SECTORS\n"
FDISK_CMD="$FDISK_CMD""n\nl\n$IMAGE_TWO_BOOT_LOGICAL_START\n+$IMAGE_TWO_BOOT_SECTORS\n"

LOGICAL_START=$(($LOGICAL_START + 2048 + $IMAGE_TWO_BOOT_SECTORS + 1))
IMAGE_TWO_ROOT_LOGICAL_START=$(($LOGICAL_START + 1))

FDISK_CMD="$FDISK_CMD""n\nl\n$(($LOGICAL_START + 1))\n+$IMAGE_TWO_ROOT_SECTORS\n"
FDISK_CMD="$FDISK_CMD""t\n1\nc\nt\n5\nc\n"

IMAGE_SIZE=$((512 * (1 + $LOGICAL_START + 1 + $IMAGE_TWO_ROOT_SECTORS + 1)))

echo Allocating "$IMAGE_DUAL"...
rm -f "$IMAGE_DUAL"
fallocate -l $IMAGE_SIZE "$IMAGE_DUAL"

echo Running fdisk to setup partitions
printf "$FDISK_CMD""w\n" | fdisk "$IMAGE_DUAL" >/dev/null

echo Copying image one...
dd skip=$IMAGE_ONE_BOOT_START seek=$IMAGE_ONE_BOOT_START count=$(($IMAGE_ONE_BOOT_SECTORS + 1)) ibs=512 obs=512 if=$IMAGE_ONE of=$IMAGE_DUAL conv=notrunc 2>/dev/null
dd skip=$IMAGE_ONE_ROOT_START seek=$IMAGE_ONE_ROOT_START count=$(($IMAGE_ONE_ROOT_SECTORS + 1)) ibs=512 obs=512 if=$IMAGE_ONE of=$IMAGE_DUAL conv=notrunc 2>/dev/null

echo Copying image two...
dd skip=$IMAGE_TWO_BOOT_START seek=$IMAGE_TWO_BOOT_LOGICAL_START count=$(($IMAGE_TWO_BOOT_SECTORS + 1)) ibs=512 obs=512 if=$IMAGE_TWO of=$IMAGE_DUAL conv=notrunc 2>/dev/null
dd skip=$IMAGE_TWO_ROOT_START seek=$IMAGE_TWO_ROOT_LOGICAL_START count=$(($IMAGE_TWO_ROOT_SECTORS + 1)) ibs=512 obs=512 if=$IMAGE_TWO of=$IMAGE_DUAL conv=notrunc 2>/dev/null

if [ "$EXTRA_SECTORS" != "0" ]; then
  echo Resizing image two...
  DEVICE=$(sudo losetup -f --show "$IMAGE_DUAL" --offset=$((512 * IMAGE_TWO_ROOT_LOGICAL_START)))
  sudo e2fsck -p -f $DEVICE >/dev/null
  sudo resize2fs $DEVICE >/dev/null 2>/dev/null
  sudo losetup -d $DEVICE >/dev/null
fi

echo Done. Run fdisk -l $IMAGE_DUAL to see the joint partitions
