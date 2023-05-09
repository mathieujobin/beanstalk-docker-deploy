Welcome to little deploy Docker to Beanstalk helper scripts.

Your projects will need to have a Dockerfile and be ready to be built.

My project uses a GPG encrypted file stored on S3 that is then use as a .env file
If you don't, that might get in your way.

## Getting-Started

Your project will need a .deploy_vars file such as this one.
double quotes are necessary as this file is both loaded in bash and ruby

```
# Docker image prefix, the stage is appended. and remote url usually ECR
DOCKER_TAG_PREFIX="abcdef"
DOCKER_REMOTE="0123456789.dkr.ecr.us-east-1.amazonaws.com"

# Aws region and credential profile
AWS_REGION="us-east-1"
AWS_CRED_PROFILE="default"

# Elastic Beanstalk environments to deploy to
# List allow to deploy to multiple at the same time, and after launching the deployment,
# it will watch the one you've set in *_WATCH
EB_STAGING_LIST="abcdef-staging-all"
EB_PRODUCTION_LIST="abcdef-production-worker1
  abcdef-production-worker2
  abcdef-production-web"
EB_STAGING_WATCH="abcdef-staging-all"
EB_PRODUCTION_WATCH="abcdef-production-web"

# Elastic Beanstalk Application name
EB_APP_NAME="acme_abcdef"

# The SSH key you want to set so you can access your instances
AWS_EC2_KEYNAME="ec2keyname"

# Only if you want to use the encrypt .env on S3
GPG_ENV_PREFIX="ABCDEF"
GPG_DEBUG=false
S3_URL_PREFIX="bucketname/beanstalk-config/abcdef"
S3_GPG_FILE_PREFIX="abcdef"

# If you want to auto push SSH keys onto each node, per environment
EB_STAGING_SSH_KEYS="keyone foo
key_two bar"
EB_PRODUCTION_SSH_KEYS=EB_STAGING_SSH_KEYS
```

## Initial push

before you run the script the first time, you want to make sure you create the Amazon ECR repository first
the path is built with the variables set above DOCKER_REMOTE/DOCKER_TAG_PREFIX-STAGE

then I should add some flag to my script, but you need to do `eb create app-stage`
so for example with the above, it should be `abcdef-staging` or `abcdef-production`

## Optional - .env automatically encrypted/decrypted and stored on S3

Your .bashrc will contain your GPG secret

```
export ABCDEF_STAGING_GPG_SECRET="secret1"
export ABCDEF_PRODUCTION_GPG_SECRET="secret2"
```

You can download and decrypt your config from S3 by doing

`./gpg_config ../project_app/ staging download`

You can create an empty file at the right location by doing

`./gpg_config ../project_app/ staging init`

After you modified your local config, you can do a compare like this

`./gpg_config ../project_app/ staging compare`

Finally, you can push your changes to S3 like this.

`./gpg_config ../project_app/ staging push`

## Optional - Get every ec2 node on Netvfy VPN

Sign up for an account at www.netvfy.com and create your network.

Call this endpoint via `curl` in order to get your APIKEY that will be used to provision nodes into the network.

```bash
curl -s -H 'Content-Type: application/json' -d '{"email":"'${EMAIL}'","password":"'${PASSWORD}'"}' \
    -X POST https://api.netvfy.com/v1/client/newapikey2 | jq -r '.client.apikey'
```

Then add these four variables to your beanstalk environment.

* netvfy_username    # your netvfy login user name
* netvfy_apikey      # the API you just got from the call above.
* netvfy_netdesc     # The network name you have created after signing in
* netvfy_node_prefix # a prefix of your choice to identify this beanstalk deploy environment from other nodes.

Note that disconnected nodes with the same prefix will automatically get deleted when a new node joins the network.
There is currently no option to disable that other than commenting out the lines 95-104 from the script.

https://github.com/mathieujobin/beanstalk-docker-deploy/blob/d2b10b6f4208d14d8dbcb329ddac11bdc5536111/.platform/hooks/postdeploy/050_setup_netvfy.sh#L95-L104


## Ready to build and deploy ?

`./docker-rebuild ../project_app/ staging "testing out mike's stuff"`

