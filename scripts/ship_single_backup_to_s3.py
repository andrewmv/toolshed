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

# Bucket information
bucket_name = 'concur-db-backup-STAGE-TLD'
backup_name_template = 'concur_STAGE-%Y-%m-%d_%H%M%S.sql'

# DB information
db_host = ''
db_name = ''
sqluser = ''
sqlpass = ''

backup_name = datetime.datetime.now().strftime(backup_name_template)
zbackup_name = backup_name + ".tgz"

### Perform Backup ###

print 'Running MYSQL Backup...',
try:
	call([	"/usr/bin/mysqldump",
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
	sys.exit(1)
print 'Success'

### Compress Backup ###
print 'Compressing Backup...',
call([	"tar",
	"-czf",
	zbackup_name, 
	backup_name])
call([ "rm",
    "-f",
    backup_name])
print 'Done.'

### Send Backup to S3 ###
print 'Uploading to S3...',
try:
	session = boto3.Session()
	s3 = session.resource('s3')
	bucket = s3.Bucket(bucket_name)
	file = open(zbackup_name, 'rb')
	bucket.put_object(Key=zbackup_name, Body=file)
except Exception as e:
	print 'Failed.'
	print e
	sys.exit(1)
finally:
    call([ "rm",
        "-f",
        zbackup_name])
print 'Success'


