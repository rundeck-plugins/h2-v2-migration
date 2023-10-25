# H2 V2 to V2.2 Migration Script
Migration Script and instructions for migrating Rundeck instances running using H2 database from V2.0 and V2.1 (version greater than 4.1.0 and less than 5.0.0) to V2.2 (versions 5.0.0 and older)

# Preparation:

1. Create a backup directory `${backup_directory}` in your local file system to host the backup database files
2. Clone the git repo [h2-v2-migration](https://github.com/rundeck-plugins/h2-v2-migration) into your local file system

# Backup
Before migration - copy and backup the database files somewhere safe:
1. Stop the Rundeck application
2. Copy the H2 database from the Rundeck application directory `{RUNDECK_HOME}/server/data` to the `${backup_directory}` There should be two files

        grailsdb.mv.db
        grailsdb.trace.db

# Migration

## STEP-1. Generate the new version database

Open a shell terminal and navigate into the `h2-v2-migration` git repo. Execute the `migration.sh` shell command.


    $_>/bin/sh migration.sh -f ${backup_directory}/grailsdb -u ${username} -p ${password}


- The `-f` parameter is required and should be the full path to the backup database file without the extension.
- The optional `-u` parameter is used for database username. If it is not provided, an empty string will be used.
    - If your Rundeck installation is RPM/Deb/War use `sa` for the user name.
    - If your Rundeck installation is from Docker the user name is blank. (leave `-u` out of command)
- The optional `-p` parameter is used for database password. If it is not provided, an empty string will be used.

By default, the `username` and `password` parameters are both empty string. If you have any custom setup, please use your customized values.

The migration.sh script will create a `output` folder at current location and put all generated files (including the v2 database file) into it.


## STEP-2. Deploy the new version database
- Use the generated database file `./output/v2.2/data/grails.mv.db` from the above step to replace your the target Rundeck application database at `{RUNDECK_HOME}/server/data/grails.mv.db`
- Set the permission of the file `{RUNDECK_HOME}/server/data/grails.mv.db` correctly, so Rundeck application can access it with write permission. Login to the docker container’s shell to change the ownership of the database files by executing the below command:

       sudo chown rundeck:root {RUNDECK_HOME}/server/data/grailsdb.mv.db
- Add the string `;NON_KEYWORDS=MONTH,HOUR,MINUTE,YEAR,SECONDS` to _datasource.url_ in rundeck-config.properties file, i.e., `datasource.url = jdbc:h2:file:[rdbase]/server/data/grailsdb;NON_KEYWORDS=MONTH,HOUR,MINUTE,YEAR,SECONDS;DB_CLOSE_ON_EXIT=FALSE`
- Restart the Rundeck application
