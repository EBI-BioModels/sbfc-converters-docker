#!/bin/bash

RESOLVE_LINK=`readlink -f $0`
SBF_CONVERTER_HOME=`dirname ${RESOLVE_LINK}`
LIB_PATH=${SBF_CONVERTER_HOME}/lib

if [ $# -lt 3 ]
 then
     echo ""
     echo "Usage: "
     echo "    To convert a given file(s) of a specific model type using a provided converter"
     echo "       $0 InputModelType ConverterName [file | folder]"
     echo ""
     echo "    For instance, to convert an SBML file to XPP : "
     echo "       $0 SBMLModel SBML2XPP [file.xml | folder]"
     echo ""
     echo "    For retrieving the complete lists of the available models and converters, type the commands"
     echo "       ./sbfModelList.sh"
     echo "       ./sbfConverterList.sh"
     echo ""
     exit 1
fi

MODEL_NAME=$1
CONVERTER_NAME=$2
SBML_DIR=$3

LOG_FILE_FOLDER=${SBF_CONVERTER_HOME}/log/`basename $SBML_DIR .input`
LOG_FILE=${LOG_FILE_FOLDER}/`basename $SBML_DIR .input`-$CONVERTER_NAME-export-`date +%F`.log

# Use the container's JDK (JAVA_HOME is set by the tomcat:8.5.82-jdk8 base image).
# Falls back to /usr/local/openjdk-8 if JAVA_HOME is not set.
export JAVA_HOME=${JAVA_HOME:-/usr/local/openjdk-8}
export PATH=${JAVA_HOME}/bin:${PATH}

# libSBML native library — required only for SBML2SBML converters.
# Not pre-installed in this image; SBML2SBML will fail if attempted.
# Install via: apt-get install -y libsbml5-java  (adds .so to /usr/lib/jni/)
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-/usr/lib/jni}

COMMAND="java "

PATHVISIO_CONVERTER="no"

if [[ ${CONVERTER_NAME} == *GPML* ]];
then
    PATHVISIO_CONVERTER="yes"
fi

export CLASSPATH=

for jarFile in $LIB_PATH/*.jar
do
    export CLASSPATH=$CLASSPATH:$jarFile
done

if [ ${PATHVISIO_CONVERTER} == "no" ];
then
    for jarFile in $LIB_PATH/paxtools/*.jar
    do
        export CLASSPATH=$CLASSPATH:$jarFile
    done

else
    for jarFile in $LIB_PATH/pathvisio/*.jar
    do
	export CLASSPATH=$CLASSPATH:$jarFile
    done
    if [[ ${CONVERTER_NAME} == *BioPAX2GPML* ]];
    then
	echo "Using the BioPaxOldModel class for BioPAX2GPML"
	MODEL_NAME=BioPaxOldModel
    fi
fi

if [ -d $SBML_DIR ]
then
    for file in $SBML_DIR/*.xml
    do
        # Creating a log file specific to each file.
	LOG_FILE_FOLDER=${SBF_CONVERTER_HOME}/log/`basename $file .input`
	LOG_FILE_MULTI=${LOG_FILE_FOLDER}/`basename $file .input`-$CONVERTER_NAME-export-`date +%F`.log

	# checks that the model specific folder does exist and create it if not.
	if [ ! -d "$LOG_FILE_FOLDER" ]; then
	    mkdir -p $LOG_FILE_FOLDER
	fi

	echo "------------------------------------------------------------" >> $LOG_FILE_MULTI   2>&1
	echo "`date +"%F %R"`" >> $LOG_FILE_MULTI  2>&1
	echo "`basename $0`: Convertion, using $CONVERTER_NAME, for '$file'..." >> $LOG_FILE_MULTI  2>&1
	echo "------------------------------------------------------------" >> $LOG_FILE_MULTI  2>&1

	eval $COMMAND -Dmiriam.xml.export=${SBF_CONVERTER_HOME}/miriam.xml org.sbfc.converter.Converter $MODEL_NAME $CONVERTER_NAME $file >> $LOG_FILE_MULTI  2>&1
	sleep 0.1
    done
else

    file=$SBML_DIR

    # checks that the model specific folder does exist and create it if not.
    if [ ! -d "$LOG_FILE_FOLDER" ]; then
	mkdir -p $LOG_FILE_FOLDER
    fi

    echo "------------------------------------------------------------" >> $LOG_FILE  2>&1
    echo "`date +"%F %R"`" >> $LOG_FILE  2>&1
    echo "`basename $0`: Convertion, using $CONVERTER_NAME, for '$SBML_DIR'..." >> $LOG_FILE  2>&1
    echo "------------------------------------------------------------" >> $LOG_FILE  2>&1

    eval $COMMAND -Dmiriam.xml.export=${SBF_CONVERTER_HOME}/miriam.xml org.sbfc.converter.Converter $MODEL_NAME $CONVERTER_NAME $SBML_DIR >> $LOG_FILE  2>&1
    touch `dirname $file`/`basename $file .input`.done

fi
