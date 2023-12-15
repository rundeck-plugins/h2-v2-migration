#!/bin/sh

V1_JAR="h2-1.4.200.jar"
V2_JAR="h2-2.1.210.jar"
V3_JAR="h2-2.2.220.jar"
V1_URL="https://repo1.maven.org/maven2/com/h2database/h2/1.4.200/h2-1.4.200.jar"
V2_URL="https://repo1.maven.org/maven2/com/h2database/h2/2.1.210/h2-2.1.210.jar"
V3_URL="https://repo1.maven.org/maven2/com/h2database/h2/2.2.220/h2-2.2.220.jar"

sourceVer=v2
destVer=v3

while getopts f:u:p:s:d: flag
do
    case "${flag}" in
        f) file=${OPTARG};;
        u) username=${OPTARG};;
        p) password=${OPTARG};;
        s) sourceVer=${OPTARG};;
        d) destVer=${OPTARG};;
    esac
done

if [ ! -f "$file.mv.db" ]; then
    echo "===> $file.mv.db is not a valid path. Please use -f option to provide the path to the database file. e.g. migration.sh -f path/to/database/file without extension"
    exit 255
fi

# Check sourceVer has values v1, v2 or v3
if [ "$sourceVer" != "v1" ] && [ "$sourceVer" != "v2" ] && [ "$sourceVer" != "v3" ]; then
    echo "===> $sourceVer is not a valid source version. Please use -s option to provide the source version. e.g. migration.sh -s v2 -d v3"
    exit 255
fi

# Check destVer has values v1, v2 or v3
if [ "$destVer" != "v1" ] && [ "$destVer" != "v2" ] && [ "$destVer" != "v3" ]; then
    echo "===> $destVer is not a valid destination version. Please use -d option to provide the destination version. e.g. migration.sh -s v2 -d v3"
    exit 255
fi


echo "===> Start to migrate h2 $sourceVer database from file: $file to $destVer"
echo "===> Use db username: $username"
echo "===> Use db password: $password"

echo "===> Check output directory."

OUTPUT_DIR=output

if [ -d "$OUTPUT_DIR" ]; then
  # Take action if $DIR exists. #
  echo "===> $OUTPUT_DIR directory exists."
else
  mkdir $OUTPUT_DIR
  echo "===> Create the $OUTPUT_DIR."
fi

if [ -d "$OUTPUT_DIR/$destVer" ]; then
    echo "===> Remove generated data from last run"
    rm -rf "$OUTPUT_DIR/$destVer"
fi

echo "===> Start to download JDBC drivers: "
# Get source version driver
case $sourceVer in
    v1)
        SOURCE_JAR=$OUTPUT_DIR/$V1_JAR
        curl $V1_URL --output $SOURCE_JAR
        ;;
    v2)
        SOURCE_JAR=$OUTPUT_DIR/$V2_JAR
        curl $V2_URL --output $SOURCE_JAR
        ;;
    v3)
        SOURCE_JAR=$OUTPUT_DIR/$V3_JAR
        curl $V3_URL --output $SOURCE_JAR
        ;;
esac

# Get dest version driver
case $destVer in
    v1)
        DEST_JAR=$OUTPUT_DIR/$V1_JAR
        curl $V1_URL --output $DEST_JAR
        ;;
    v2)
        DEST_JAR=$OUTPUT_DIR/$V2_JAR
        curl $V2_URL --output $DEST_JAR
        ;;
    v3)
        DEST_JAR=$OUTPUT_DIR/$V3_JAR
        curl $V3_URL --output $DEST_JAR
        ;;
esac

echo "===> Jdbc drivers downloaded."
echo ""

echo "===> Start to export current database into SQL script: "
java -cp $SOURCE_JAR org.h2.tools.Script -url "jdbc:h2:$file" -user "$username" -password "$password" -script "./$OUTPUT_DIR/backup.$sourceVer.sql"
echo "===> Done export."
echo ""

echo "===> Start to create h2 $destVer database from the exported SQL script: "
java -cp $DEST_JAR org.h2.tools.RunScript -url "jdbc:h2:./$OUTPUT_DIR/$destVer/data/grailsdb" -user "$username" -password "$password" -script "./$OUTPUT_DIR/backup.$sourceVer.sql"
echo "===> $destVer database has been created at ./$OUTPUT_DIR/$destVer/data/grailsdb.mv.db"
echo ""


echo "================================================================================================================="
echo ""
echo "Please copy the new database file ./$OUTPUT_DIR/$destVer/data/grailsdb.mv.db to your {RUNDECK_HOME}/server/data/ folder to replace the old version database"
echo ""
echo "Please run command \`chown rundeck:root {RUNDECK_HOME}/server/data/grailsdb.mv.db\` to set the right permission on the new database file"
echo ""
echo "================================================================================================================="



