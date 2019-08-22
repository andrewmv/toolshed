#!/usr/bin/python
# 2018 Andrew Villeneuve / Concur
# Make a Mongo DB backup and ship it to S3
# Rotation handled by preconfigured S3 lifecycle policy
# AWS Credentials stored in config file in boto3/awscli format

import boto3
import datetime
from subprocess import call
import sys
#import os.system

# Bucket information
bucket_name = 'concur-db-backup-<stage>-<region>'
backup_name_template = 'concur_<stage>-%Y-%m-%d_%H%M%S.mongo'

# DB information
db_host = 'localhost'
db_name = ''
sqluser = ''
sqlpass = ''

backup_name = datetime.datetime.now().strftime(backup_name_template)
zbackup_name = backup_name + ".gz"

### Perform Backup ###

print 'Running Mongo Backup...',
try:
	call([	"/usr/bin/mongodump",
        "--host",
        db_host,
		"--username",
		sqluser,
		"-p" + sqlpass,
		db_name,
        "--authenticationDatabase",
        auth_db,
        "--gzip",
		"--archive=" + zbackup_name])
except Exception as e:
	print 'Failure'
	print e
	sys.exit(1)
print 'Success'

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


