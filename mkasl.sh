#!/bin/sh

ASL_VERSION=$(sed 's/"/\ /g' ./update.json | awk '{print $3}' | sed -n '2p')
ASL_VERSION_CODE=$(sed 's/"/\ /g' ./update.json | awk '{print $3}' | sed -n '3p')

ASL_BUILD_DIR="${1:-./build}"

if [ -d "${ASL_BUILD_DIR}" ]; then
    rm -rf "${ASL_BUILD_DIR}"
    mkdir -p "${ASL_BUILD_DIR}"
else
    mkdir -p "${ASL_BUILD_DIR}"
fi

cp -r ./src/* "${ASL_BUILD_DIR}"

cp ./LICENSE "${ASL_BUILD_DIR}"

sed -i "s/_ASL_VERSION_CODE/${ASL_VERSION_CODE}/g" \
  "${ASL_BUILD_DIR}/asl_tools/asl_utils.sh"
sed -i "s/_ASL_VERSION/${ASL_VERSION}/g" \
  "${ASL_BUILD_DIR}/asl_tools/asl_utils.sh"

sed -i "s/_ASL_VERSION_CODE/${ASL_VERSION_CODE}/g" \
  "${ASL_BUILD_DIR}/module.prop"
sed -i "s/_ASL_VERSION/${ASL_VERSION}/g" \
  "${ASL_BUILD_DIR}/module.prop"

sed -i "s/_ASL_VERSION/${ASL_VERSION}/g" \
  "${ASL_BUILD_DIR}/customize.sh"

tar -czf "${ASL_BUILD_DIR}/asl_tools.tgz" \
  -C "${ASL_BUILD_DIR}/asl_tools" .

rm -rf "${ASL_BUILD_DIR}/asl_tools"

find "${ASL_BUILD_DIR}" -type f -print0 | \
  xargs -0 -I {} sha256sum "{}" | \
  sed "s|${ASL_BUILD_DIR}|_ASL_FIC|" \
  > "./checksums"

mv ./checksums "${ASL_BUILD_DIR}/checksums"

find "${ASL_BUILD_DIR}" -exec touch -m -t $(date '+%Y%m%d%H%M.%S') {} +

cd "${ASL_BUILD_DIR}" && zip -0 -q -r "../asl.zip" ./*

cd ../ && rm -rf "${ASL_BUILD_DIR}"

exit 0
