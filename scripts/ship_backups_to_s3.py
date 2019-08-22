#!/usr/bin/python
# 2018 Andrew Villeneuve / Concur
# Make a mysql DB backup and ship it to S3
# Rotation handled by preconfigured S3 lifecycle policy
# AWS Credentials stored in config file in boto3/awscli format

import boto3
import datetime
from subprocess import call
import sys
#import os.system
from subprocess import Popen, PIPE
import json

# Options
dry_run = False

# Bucket information
# S3 credentials go in .aws directory in boto format
bucket_name = 'concur-db-backup-prod-us'
backup_name_template = '%Y-%m-%d_%H%M%S.sql'

### Fucntion Definitions ###

def backup(site, db_host, db_name, sqluser, sqlpass):

    backup_name = site + '-' + datetime.datetime.now().strftime(backup_name_template)
    zbackup_name = backup_name + ".tgz"
    object_key = site + '/' + backup_name

    print 'Site: ' + site
    ### Perform Backup ###
    print '\tRunning MYSQL Backup...',
    try:
        rc = call([	"/usr/bin/mysqldump",
            "--host",
            db_host,
            "--user",
            sqluser,
            "-p" + sqlpass,
            db_name,
            "--result-file",
            backup_name])
        #Legacy
        #cmd = "mysqldump --user {sqluser} -p {db_name} > {backup_name})
        #os.system(cmd.format(sqluser, db_name, backup_name))
    except Exception as e:
        print 'Failure'
        print e
        return 1
    if (rc != 0):
        return rc
    print 'Success'

    ### Compress Backup ###
    print '\tCompressing Backup...',
    rc = call([	"tar",
        "-czf",
        zbackup_name, 
        backup_name])
    if (rc != 0):
        return 1
    call([ "rm",
        "-f",
        backup_name])
    print 'Done.'

    ### Send Backup to S3 ###
    print '\tUploading backup to S3...',
    try:
        session = boto3.Session()
        s3 = session.resource('s3')
        bucket = s3.Bucket(bucket_name)
        file = open(zbackup_name, 'rb')
        bucket.put_object(Key=object_key, Body=file)
    except Exception as e:
        print 'Failed.'
        print e
        return 1
    finally:
        call([ "rm",
            "-f",
            zbackup_name])
    print 'Success'
    return 0

### Begin ###

success_counter = 0
fail_counter = 0
counter = 0

### Get database configs ###
print 'Getting database configuration information from Wordpress install...',
try:
    p = Popen(['/usr/bin/php', './scrape_dbs_from_wordpress.php'], stdout=PIPE)
    creds = json.load(p.stdout)
except Exception as e:
    print 'Failure'
    print e
    sys.exit(1)
print 'Success'

for site in creds:
    if (dry_run):
        print('Backups to do (dry run)')
        print('Site: ' + site)
        print('\tHost: ' + creds[site]['host'])
        print('\tName: ' + creds[site]['database'])
        print('\tUser: ' + creds[site]['user'])
        print('\tPass: ' + creds[site]['pass'])
        print('\tBackup Name: ' + site + '/' + site + '-' + backup_name)
    else:
        counter+=1
        if (backup(site, creds[site]['host'], creds[site]['database'], creds[site]['user'], creds[site]['pass']) == 0):
            success_counter+=1
        else:
            fail_counter+=1

print("Successfully backed up %d / %d sites." % (success_counter, counter))
if (fail_counter == 0):
    sys.exit(0)
else:
    print "Warning: at least one backup failed to complete"
    sys.exit(1)


