# shellcheck shell=sh
# shellcheck disable=SC2034
SKIPUNZIP=1

ASL_WORK_DIR="/data/local/asl"

ui_print "- ASL _ASL_VERSION"

ui_print "- File integrity check"

unzip -o "${ZIPFILE}" -d "${TMPDIR}" >/dev/null 2>&1

sed -i "s|_ASL_FIC|${TMPDIR}|g" "${TMPDIR}/checksums"

if sha256sum -c -s "${TMPDIR}/checksums" >/dev/null 2>&1 ; then
    ui_print "- File integrity verification passed."
else
    ui_print "! File integrity verification failed. "
    ui_print "! This zip may be corrupted, please try downloading again "
    exit 1
fi

ui_print "- Extracting asl add-ons"

mkdir -p "${ASL_WORK_DIR}"
mkdir -p "${ASL_WORK_DIR}/fs"
mkdir -p "${ASL_WORK_DIR}/log"

if [ -d "${ASL_WORK_DIR}/asl_tools" ]; then
    rm -rf "${ASL_WORK_DIR}/asl_tools"
    mkdir -p "${ASL_WORK_DIR}/asl_tools"
  else
    mkdir -p "${ASL_WORK_DIR}/asl_tools"
fi

if [ -f "${ASL_WORK_DIR}/asl.conf" ]; then
    # "File exists"
    :
else
    cp "${TMPDIR}/asl.conf" "${ASL_WORK_DIR}/asl.conf"
fi

tar zxf "${TMPDIR}/asl_tools.tgz" -C "${ASL_WORK_DIR}/asl_tools"

ui_print "- Extracting module files"

cp "${TMPDIR}/module.prop"  "${MODPATH}/module.prop"
cp "${TMPDIR}/uninstall.sh" "${MODPATH}/uninstall.sh"
cp "${TMPDIR}/service.sh"   "${MODPATH}/service.sh"

mkdir -p "${MODPATH}/system/bin/"
cp "${ASL_WORK_DIR}/asl_tools/asl_utils.sh" "${MODPATH}/system/bin/asl"

ui_print "- Setting permissions"
set_perm_recursive "${ASL_WORK_DIR}/asl_tools" 0 0 0755 0755
set_perm_recursive "${MODPATH}" 0 0 0755 0755
