Welcome to little deploy Docker to Beanstalk helper scripts.

Your projects will need to have a Dockerfile and be ready to be built.

My project uses a GPG encrypted file stored on S3 that is then use as a .env file
If you don't, that might get in your way.

Your project will need a .deploy_vars file such as this one.

```
GPG_ENV_PREFIX="ABCDEF"
GPG_DEBUG=false
DOCKER_REMOTE="0123456789.dkr.ecr.us-east-1.amazonaws.com"
AWS_REGION="us-east-1"
AWS_CRED_PROFILE="default"
EB_STAGING_LIST="abcdef-staging-all"
EB_PRODUCTION_LIST="abcdef-production-worker1
  abcdef-production-worker2
  abcdef-production-web"
EB_STAGING_WATCH="abcdef-staging-all"
EB_PRODUCTION_WATCH="abcdef-production-web"
S3_URL_PREFIX="bucketname/beanstalk-config/abcdef"
S3_GPG_FILE_PREFIX="abcdef"
EB_APP_NAME=acme_abcdef
AWS_EC2_KEYNAME=ec2keyname
```

Your .bashrc will contain your GPG secret

```
export ABCDEF_STAGING_GPG_SECRET="secret1"
export ABCDEF_PRODUCTION_GPG_SECRET="secret2"
```

You can download and decrypt your config from S3 by doing

`./gpg_config ../project_app/ staging download`

After you modified your local config, you can do a compare like this

`./gpg_config ../project_app/ staging compare`

Finally, you can push your changes to S3 like this.

`./gpg_config ../project_app/ staging push`

Ready to build and deploy ?

`./docker-rebuild ../project_app/ staging "testing out mike's stuff"`

