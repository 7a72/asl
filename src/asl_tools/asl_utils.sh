#!/bin/sh

ASL_VERSION="_ASL_VERSION"
ASL_WORK_DIR="${ASL_WORK_DIR:-/data/local/asl}"
ASL_TOOLS_DIR="${ASL_WORK_DIR}/asl_tools"
ASL_UNSHARE="${ASL_TOOLS_DIR}/unshare"
ASL_BUSYBOX="${ASL_TOOLS_DIR}/busybox"
ASL_ROOTFS="${ASL_WORK_DIR}/fs"
ASL_LOGDIR="${ASL_WORK_DIR}/log"
ASL_QUIET=${ASL_QUIET:-false}

show_help()
{
    ${ASL_BUSYBOX} printf "
Android Subsystem of Linux (ASL) - %s\n
A lightweight Linux subsystem for Android devices.\n\n\
Usage: asl [COMMAND] [OPTIONS]\n\n\
Commands:\n\
    export      Export root filesystem from <dir> to <file>\n\
    import      Import root filesystem from <file> to <dir>\n\
    remove      Remove an existing ASL installation\n\
    fix_net     Fix network-related configurations\n\n\
Options:\n\
    -c, --exec <command> Execute a command inside the ASL environment.\n\
    -l, --login          Log into the ASL environment as root.\n\
    -r, --rootfs <path>  Specify the root filesystem path for ASL.\n\
    -m, --mount          Mount necessary filesystems for ASL.\n\
                          (This is automatically done when executing commands or logging in)\n\
    -u, --unmount        Unmount the ASL environment.\n\
    -h, --help           Display this help message.\n\
    -v, --version        Show the current version of ASL.\n\n\
Examples:\n\
    # Execute a command\n\
    asl -c 'echo Hello from ASL'\n\n\
    # Login to ASL\n\
    asl -l\n\n\
    # Unmount ASL\n\
    asl -u\n\n\
    # Use custom root filesystem\n\
    asl --rootfs /custom/path -c 'whoami'\n\n\
    # Export root filesystem\n\
    asl export -d /data/local/asl/fs -f /sdcard/asl_backup.tar.zst\n\n\
    # Import root filesystem\n\
    asl import --dir /data/local/asl/newfs --file /sdcard/asl_backup\
\n" "${ASL_VERSION}"
}

if [ ! -d "${ASL_LOGDIR}" ]; then
    ${ASL_BUSYBOX} mkdir -p "${ASL_LOGDIR}"
fi

asl_msg()
{
    [ "${ASL_QUIET}" = true ] || ${ASL_BUSYBOX} printf "%s\n" "$*"
    ${ASL_BUSYBOX} printf "[%s]: %s\n" "$(${ASL_BUSYBOX} date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${ASL_LOGDIR}/asl.log"
}

mount_status()
{
    mount_point="$1"
    if ${ASL_BUSYBOX} grep -q " ${mount_point%/} " /proc/mounts; then
        return 0
    else
        return 1
    fi
}

asl_mount()
{
    asl_msg "Mount: ${ASL_FS}"
    for _asl_mount_point in / /dev /proc /sys /tmp /dev/pts /dev/shm ;
    do
        if ! mount_status "${ASL_FS}${_asl_mount_point}"; then
            case ${_asl_mount_point} in
                /)
                    ${ASL_TOOLS_DIR}/mount --rbind "${ASL_FS}" "${ASL_FS}/"
                    ${ASL_TOOLS_DIR}/mount -o remount,exec,suid,dev "${ASL_FS}"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /dev)
                    [ -d "${ASL_FS}/dev" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/dev"
                    ${ASL_TOOLS_DIR}/mount -o bind /dev "${ASL_FS}/dev"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /proc)
                    [ -d "${ASL_FS}/proc" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/proc"
                    ${ASL_TOOLS_DIR}/mount -t proc proc "${ASL_FS}/proc"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /sys)
                    [ -d "${ASL_FS}/sys" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/sys"
                    ${ASL_TOOLS_DIR}/mount -t sysfs sys "${ASL_FS}/sys"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /tmp)
                    [ -d "${ASL_FS}/tmp" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/tmp"
                    ${ASL_TOOLS_DIR}/mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs "${ASL_FS}/tmp"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /dev/pts)
                    [ -d "/dev/pts" ] || ${ASL_BUSYBOX} mkdir -p /dev/pts
                    ${ASL_TOOLS_DIR}/mount -o rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
                    [ -d "${ASL_FS}/dev/pts" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/dev/pts"
                    ${ASL_TOOLS_DIR}/mount -o bind /dev/pts "${ASL_FS}/dev/pts"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
                /dev/shm)
                    [ -d "${ASL_FS}/dev/shm" ] || ${ASL_BUSYBOX} mkdir -p "${ASL_FS}/dev/shm"
                    ${ASL_TOOLS_DIR}/mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs "${ASL_FS}/dev/shm"
                    asl_msg "Mounting ${_asl_mount_point} completed"
                ;;
            esac
        else
            asl_msg "${_asl_mount_point} is already mounted, skipping this time."
        fi
    done
}

asl_unmount()
{
    asl_msg "Unmount: ${ASL_FS}"
    ${ASL_TOOLS_DIR}/umount -R -l "${ASL_FS}" >/dev/null 2>&1
}

asl_exec()
{
    asl_mount
    asl_msg "exec: $*"
    unset TMP TEMP TMPDIR LD_PRELOAD LD_DEBUG
    _PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    if [ -h "${ASL_FS}/bin/su" ] || [ -e "${ASL_FS}/bin/su" ] ; then
        PATH=${_PATH} ${ASL_UNSHARE} -R "${ASL_FS}" /bin/su - root -c "$*"
    else
        PATH=${_PATH} ${ASL_UNSHARE} -R "${ASL_FS}" $(${ASL_BUSYBOX} grep "^root:" "${ASL_FS}/etc/passwd" | cut -d ':' -f 7) -c "$*"
    fi
}

asl_login()
{
    asl_mount
    asl_msg "login"
    unset TMP TEMP TMPDIR LD_PRELOAD LD_DEBUG
    _PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    if [ -h "${ASL_FS}/bin/su" ] || [ -e "${ASL_FS}/bin/su" ] ; then
        PATH=${_PATH} ${ASL_UNSHARE} -R "${ASL_FS}" /bin/su - root
    else
        PATH=${_PATH} ${ASL_UNSHARE} -R "${ASL_FS}" $(${ASL_BUSYBOX} grep "^root:" "${ASL_FS}/etc/passwd" | cut -d ':' -f 7) -l
    fi
}

path_check() {
    [ "$#" -eq 2 ] || return 1

    _pc_type="$1"
    _pc_path="$2"

    [ -e "$_pc_path" ] || return 1

    case "$_pc_type" in
        "dir")
            [ -d "$_pc_path" ] || return 1
            ;;

        "file")
            [ -f "$_pc_path" ] || return 1
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

asl_import()
{
    _asl_rootfs_file=""
    _asl_rootfs_dir=""
    while [ "$#" -gt 0 ]; do
        case "${1}" in
            --dir|-d)
                if [ -n "${2}" ]; then
                    _asl_rootfs_dir="${2}"
                    shift
                else
                    asl_msg "Error: --dir requires an argument."
                    exit 1
                fi
                ;;
            --file|-f)
                if [ -n "${2}" ]; then
                    _asl_rootfs_file="${2}"
                    shift
                else
                    asl_msg "Error: --file requires an argument."
                    exit 1
                fi
                ;;
            *)
                asl_msg "Error: plz see asl -h."
                exit 1
                ;;
        esac
        shift
    done

    if [ -z "${_asl_rootfs_file}" ] || [ -z "${_asl_rootfs_dir}" ]; then
        asl_msg "Import error: Both file and directory must be specified"
        exit 1
    fi

    if ! path_check "file" "${_asl_rootfs_file}"; then
        asl_msg "Error: Invalid import file ${_asl_rootfs_file}"
        exit 1
    fi

    [ -d "${_asl_rootfs_dir}" ] || ${ASL_BUSYBOX} mkdir -p "${_asl_rootfs_dir}"

    if ! path_check "dir" "${_asl_rootfs_dir}"; then
        asl_msg "Error: Unable to create or access directory ${_asl_rootfs_dir}"
        exit 1
    fi

    asl_msg "Import ${_asl_rootfs_file} to ${_asl_rootfs_dir}"
    case "${_asl_rootfs_file}" in
        *zst)
            ${ASL_TOOLS_DIR}/zstd -d -c "${_asl_rootfs_file}" | ${ASL_BUSYBOX} tar axf - -C "${_asl_rootfs_dir}"
            ;;
        *)
            ${ASL_BUSYBOX} tar axf "${_asl_rootfs_file}" -C "${_asl_rootfs_dir}"
            ;;
    esac
    asl_msg "Import ${_asl_rootfs_dir} completed" 
}

asl_export()
{
    _asl_rootfs_dir=""
    _asl_rootfs_file=""
    while [ "$#" -gt 0 ]; do
        case "${1}" in
            --dir|-d)
                if [ -n "${2}" ]; then
                    _asl_rootfs_dir="${2}"
                    shift
                else
                    asl_msg "Error: --dir requires an argument."
                    exit 1
                fi
                ;;
            --file|-f)
                if [ -n "${2}" ]; then
                    _asl_rootfs_file="${2}.tar.zst"
                    shift
                else
                    asl_msg "Error: --file requires an argument."
                    exit 1
                fi
                ;;
            *)
                asl_msg "Error: plz see asl -h."
                exit 1
                ;;
        esac
        shift
    done

    if [ -z "${_asl_rootfs_file}" ] || [ -z "${_asl_rootfs_dir}" ]; then
        asl_msg "Export error: Both file and directory must be specified"
        exit 1
    fi

    if ! path_check "dir" "${_asl_rootfs_dir}"; then
        asl_msg "Error: Invalid export directory ${_asl_rootfs_dir}"
        exit 1
    fi

    asl_msg "Export ${_asl_rootfs_dir} to ${_asl_rootfs_file}"
    ${ASL_BUSYBOX} tar cf - --exclude='./dev' --exclude='./sys' --exclude='./proc' -C "${_asl_rootfs_dir}" . | ${ASL_TOOLS_DIR}/zstd -T0 -9 > "${_asl_rootfs_file}"
    asl_msg "Export ${_asl_rootfs_file} completed"
}

asl_remove()
{
    if [ $# -eq 0 ]; then
        asl_msg "Error: remove requires an argument."
        exit 1
    fi
    
    _asl_rootfs_dir="$1"
    
    if ! path_check "dir" "${_asl_rootfs_dir}"; then
        asl_msg "Directory ${_asl_rootfs_dir} does not exist"
        exit 1
    fi

    printf "Are you sure you want to permanently delete %s?\nThis action cannot be undone.\nWarning: This operation may cause damage to the equipment.\n" "${_asl_rootfs_dir}"
    printf "Type YES to confirm: "

    read confirm

    if [ "$confirm" != "YES" ]; then
        asl_msg "Deletion cancelled."
        return 1
    fi

    asl_msg "Proceeding with deletion of ${_asl_rootfs_dir}"
    ASL_FS="${_asl_rootfs_dir}" asl_unmount
    ${ASL_BUSYBOX} sleep 5
    rm -rf "${_asl_rootfs_dir}"
    asl_msg "Deleted ${_asl_rootfs_dir}"
    
    exit 0
}

asl_net_fix()
{

    groupadd aid_net_bt_admin -g 3001
    groupadd aid_net_bt -g 3002
    groupadd aid_inet -g 3003
    groupadd aid_net_raw -g 3004
    groupadd aid_net_admin -g 3005
    groupadd aid_net_bw_stats -g 3006
    groupadd aid_net_bw_acct -g 3007

    usermod -a -G aid_net_bt_admin,aid_net_bt,aid_inet,aid_net_raw,aid_net_admin,aid_net_bw_stats,aid_net_bw_acct root

    rm -f /etc/resolv.conf >>/dev/null 2>&1
    echo nameserver 8.8.8.8 >>/etc/resolv.conf
    echo nameserver 1.2.4.8 >>/etc/resolv.conf

}

_ASL_EXEC=""
_ASL_LOGIN=false
_ASL_MOUNT=false
_ASL_UNMOUNT=false
_ASL_ROOTFS=""

while [ "$#" -gt 0 ]; do
    case "${1}" in
        export)
            shift
            asl_export "$@"
            exit 0
            ;;
        fix_net)
            asl_net_fix
            exit 0
            ;;
        import)
            shift
            asl_import "$@"
            exit 0
            ;;
        remove)
            shift
            asl_remove "$@"
            ;;
        --exec|-c)
            _ASL_EXEC="${2}"
            shift
            ;;
        --login|-l)
            _ASL_LOGIN=true
            ;;
        --rootfs|-r)
            if [ -n "${2}" ]; then
                _ASL_ROOTFS="${2}"
                shift
            else
                asl_msg "Error: --rootfs requires an argument."
                exit 1
            fi
            ;;
        --mount|-m)
            _ASL_MOUNT=true
            ;;
        --unmount|-u)
            _ASL_UNMOUNT=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            asl_msg "ASL ${ASL_VERSION}"
            exit 0
            ;;
        *)
            asl_msg "try see asl -h"
            exit 1
            ;;
    esac
    shift
done

if [ -z "$_ASL_ROOTFS" ]; then
    ASL_FS="${ASL_ROOTFS}"
else
    ASL_FS="${_ASL_ROOTFS%/}"
    if ! path_check "dir" "${ASL_FS}"; then
        asl_msg "Error: Invalid path ${ASL_FS}"
        exit 1
    fi
fi

[ ! "${_ASL_MOUNT}" = true ] || asl_mount

[ -z "${_ASL_EXEC}" ] || asl_exec "${_ASL_EXEC}"

[ ! "${_ASL_LOGIN}" = true ] || asl_login

[ ! "${_ASL_UNMOUNT}" = true ] || asl_unmount

exit 0
