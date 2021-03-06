#!/bin/bash
source envs.sh

sudo apt-get install dialog
# yum install dialog

function cleanup {      
        if [ -d extracted_files ]; then
                rm -rfd extracted_files
        fi
        if [ -d resources ]; then
                rm -rfd resources
        fi
}
trap cleanup EXIT

cleanup
mkdir -p resources

MSG="Wish to download the required files?"
dialog --backtitle "Archiver configuration" --title "Configuration" --yesno "${MSG}" 0 0 
if [[ $? == 0 ]] ; then
	pushd resources
                wget ${TOMCAT_URL}
                tar -zxf ${TOMCAT_DISTRIBUTION}.tar.gz
                export TOMCAT_HOME=$(pwd)/${TOMCAT_DISTRIBUTION} 
                wget https://dev.mysql.com/get/Downloads/Connector-J/${MYSQL_CONNECTOR}.tar.gz --no-check-certificate
                tar -xvf ${MYSQL_CONNECTOR}.tar.gz
                mv ${MYSQL_CONNECTOR}/${MYSQL_CONNECTOR}-bin.jar .
	popd 
	
	MSG="Wish to clone and build epicsappliances repo?"
        dialog --backtitle "Archiver configuration" --title "Configuration" --yesno "${MSG}" 0 0 
	if [[ $? == 0 ]] ; then
	        pushd resources
                        git clone ${ARCHIVER_REPO}
                        cd epicsarchiverap
                        RES=$(dialog --stdout --menu 'Choose the tag to be used!' 0 0 0 $(git tag -l | awk '{printf "tags/%s %s\n", $1, $1}') master "Bleeding Edge")
                        git checkout RES
                        ant
	        popd
        else
                MSG="Downloading appliance from ${COMPILED_ARCHIVER_APPL} ..."
	        dialog --msgbox "${MSG}" 0 0 
                wget $COMPILED_ARCHIVER_APPL --no-check-certificate
                MSG="Download complete ! \n"$(ls)
	        dialog --msgbox "${MSG}" 0 0 
	fi
fi

MSG="Where is the epicsappliances build file (tar.gz)? Try the resources folder ..."
ARCH_TAR=$(dialog --stdout --title "$MSG" --fselect ${PWD} 0 0 )
if [[ ! -f ${ARCH_TAR} ]]; then
        MSG="${ARCH_TAR} does not seem to be a valid file"
	dialog --msgbox "${MSG}" 0 0 
        exit 1
fi

mkdir extracted_files
tar -C extracted_files -zxf  ${ARCH_TAR}
rm -rvfd extracted_files/install_scripts
mkdir -p extracted_files/install_scripts

cp -rf install_scripts/ extracted_files/
export SCRIPTS_DIR=$(pwd)/extracted_files/install_scripts
ls
pushd ${SCRIPTS_DIR}
        ls 
        . ./single_machine_install.sh
popd  

STARTUP_SH=${DEPLOY_DIR}/sampleStartup.sh

sed -i -e "14cexport JAVA_OPTS=\"${JAVA_OPTS}\"" ${STARTUP_SH}

sed -i -e "30cexport ARCHAPPL_SHORT_TERM_FOLDER=${ARCHAPPL_SHORT_TERM_FOLDER}" ${STARTUP_SH}
sed -i -e "31cexport ARCHAPPL_MEDIUM_TERM_FOLDER=${ARCHAPPL_MEDIUM_TERM_FOLDER}" ${STARTUP_SH}
sed -i -e "32cexport ARCHAPPL_LONG_TERM_FOLDER=${ARCHAPPL_LONG_TERM_FOLDER}" ${STARTUP_SH}

rm -rvfd extracted_files

for APPLIANCE_UNIT in "engine" "retrieval" "etl" "mgmt"
do
        if [ $APPLIANCE_UNIT == "mgmt" ]; then
                UI_DIR=${DEPLOY_DIR}/${APPLIANCE_UNIT}/webapps/mgmt/ui
		IMG_DIR=${UI_DIR}/comm/img
                for file in "appliance.html" "cacompare.html" "index.html" "integration.html" "metrics.html" "pvdetails.html" "redirect.html" "reports.html" "storage.html"
                do
                        sed -i "s/LCLS/LNLS/g" ${UI_DIR}/${file}
                        echo ${UI_DIR}/${file}
                done
                sed -i "s/Jingchen Zhou/LNLS CON group/g" ${UI_DIR}/index.html
                sed -i "s/Murali Shankar at 650 xxx xxxx or Bob Hall at 650 xxx xxxx/LNLS CON group/g" ${UI_DIR}/index.html

                cp -f labLogo.png ${IMG_DIR}
                cp -f labLogo2.png ${IMG_DIR}
        fi
        if [ $APPLIANCE_UNIT == "retrieval" ]; then
                cp -f redirect.html ${DEPLOY_DIR}/${APPLIANCE_UNIT}/webapps/retrieval/ui/redirect.html

                pushd ${DEPLOY_DIR}/${APPLIANCE_UNIT}/webapps/retrieval/ui
                        rm -rvfd viewer
                        git clone ${ARCHIVER_VIEWER_REPO}
                        mv archiver-viewer viewer
                        mv viewer/index.html viewer/archViewer.html
                        pushd viewer/js
                                sed -i "s/10\.0\.4\.57\:11998/10\.0\.6\.51\:17668/g" archiver-viewer.min.js
                                sed -i "s/10\.0\.6\.57\:11998/10\.0\.6\.51\:17668/g" archiver-viewer.min.js
                                sed -i "s/10\.0\.4\.57\:11998/10\.0\.6\.51\:17668/g" archiver-viewer.js
                                sed -i "s/10\.0\.6\.57\:11998/10\.0\.6\.51\:17668/g" archiver-viewer.js
                        popd
                popd

                pushd ${DEPLOY_DIR}/${APPLIANCE_UNIT}/webapps/retrieval/WEB-INF/
                        xmlstarlet ed --inplace --subnode "/web-app" --type elem -n welcome-file-list -v "" web.xml
                        xmlstarlet ed --inplace --subnode "/web-app/welcome-file-list" --type elem -n welcome-file -v "/ui/redirect.html" web.xml
                popd
        fi
done
