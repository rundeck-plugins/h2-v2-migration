#!/bin/sh

while getopts f:u:p: flag
do
    case "${flag}" in
        f) file=${OPTARG};;
        u) username=${OPTARG};;
        p) password=${OPTARG};;
    esac
done

if [ ! -f "$file.mv.db" ]; then
    echo "===> $file is not a valid path. Please use -f option to provide the path to the database file. e.g. migration.sh -f path/to/database/file without extension"
    exit 255
fi

echo "===> Start to migrate h2 v2.1 database from file: $file to v2.2"
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

if [ -d "$OUTPUT_DIR/v2" ]; then
    echo "===> Remove generated data from last run"
    rm -rf "$OUTPUT_DIR/v2"
fi

echo "===> Start to download JDBC drivers: "
SOURCE_JAR=$OUTPUT_DIR/h2-2.1.210.jar
DEST_JAR=$OUTPUT_DIR/h2-2.2.200.jar
curl https://repo1.maven.org/maven2/com/h2database/h2/2.1.210/h2-2.1.210.jar --output $SOURCE_JAR
curl https://repo1.maven.org/maven2/com/h2database/h2/2.2.220/h2-2.2.220.jar --output $DEST_JAR


echo "===> Jdbc drivers downloaded."
echo ""

echo "===> Start to export current database into SQL script: "
java -cp $SOURCE_JAR org.h2.tools.Script -url "jdbc:h2:$file" -user "$username" -password "$password" -script "./$OUTPUT_DIR/backup.sql"
echo "===> Done export."
echo ""

echo "===> Start to create h2 v2.2 database from the exported SQL script: "
java -cp $DEST_JAR org.h2.tools.RunScript -url "jdbc:h2:./$OUTPUT_DIR/v2.2/data/grailsdb" -user "$username" -password "$password" -script "./$OUTPUT_DIR/backup.sql"
echo "===> v2.2 database has been created at ./$OUTPUT_DIR/v2.2/data/grailsdb.mv.db"
echo ""


echo "================================================================================================================="
echo ""
echo "Please copy the new database file ./$OUTPUT_DIR/v2.2/data/grailsdb.mv.db to your {RUNDECK_HOME}/server/data/ folder to replace the old version database"
echo ""
echo "Please run command \`chown rundeck:root {RUNDECK_HOME}/server/data/grailsdb.mv.db\` to set the right permission on the new database file"
echo ""
echo "================================================================================================================="



