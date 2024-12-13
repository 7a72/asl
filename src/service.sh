#!/system/bin/sh

MODDIR=${0%/*}

[ ! -f "/data/local/asl/asl.conf" ] || source /data/local/asl/asl.conf

if [ "${ASL_AUTO_START}" = enable ]; then
    printf "[%s]: asl init\n" "$(${ASL_BUSYBOX} date '+%Y-%m-%d %H:%M:%S')" > /data/local/asl/log/asl.log
    sed -i "s/^description=.*/description=Android Subsystem for Linux (enable)/g" ${MODDIR}/module.prop
    ASL_QUIET=true /data/local/asl/asl_tools/asl_utils.sh -r "${ASL_FS_DIR}" -c "${ASL_INIT_CMD}"
else
    sed -i "s/^description=.*/description=Android Subsystem for Linux (disable)/g" ${MODDIR}/module.prop
    exit 0
fi
