#!/bin/bash
sudo apt-get update && sudo apt-get install -y jq curl

GIT_TAG=$1
PUSH_DIR=$2
PLATFORM=$3
PLATFORM_ARGS=""
DOCKERFILE_GPU=Dockerfile.gpu

exit_code=1
# empty change is detected as home directory
if [ -z "$PUSH_DIR" ]
then
      echo "\$PUSH_DIR is empty"
      exit_code=0
      exit $exit_code
fi

echo pushing $PUSH_DIR
cd $PUSH_DIR

pip install yq

exec_name=`yq -r .metas.name config.yml`
if [ -z "$exec_name" ] || [ "$exec_name" == "null" ]
then
  echo manifest.yml is deprecated. Please merge it into config.yml
  exec_name=`yq -r .name manifest.yml`
fi
echo executor name is $exec_name

echo NAME=$exec_name

if [ ! -z "$exec_secret" ]
then
  echo Warning: exec_secret is deprecated. Please use nextlinuxhub_token instead
fi

if [ -z "$nextlinuxhub_token" ]
then
  echo no nextlinuxhub token provided
  nextlinuxhub_token="dummy-token"
fi

if [ -z "$PLATFORM" ]
then
  echo platform not specified
else
  echo platform specified to be $PLATFORM
  PLATFORM_ARGS="$PLATFORM_ARGS --platform $PLATFORM"
fi

echo "::add-mask::$nextlinuxhub_token"
echo NEXTLINUX_AUTH_TOKEN=`head -c 3 <(echo $nextlinuxhub_token)`

pip install --pre "nextlinux[standard]"

version=`nextlinux -vf`
echo nextlinux version $version

# we only push to a tag once,
# if it doesn't exist

# push cpu version
if [ -z "$GIT_TAG" ]
then
  echo WARNING, no git tag!
else
  echo git tag = $GIT_TAG
  nextlinux hub pull nextlinuxhub+docker://$exec_name/$GIT_TAG
  exists=$?

  # push to existing executor
  if [[ $exists == 1 ]]; then
    # check if executor exists
    nextlinux hub pull nextlinuxhub+docker://$exec_name
    executor_exists=$?
    # try initial push
    if [[ $executor_exists == 1 ]]; then
      echo $exec_name does NOT exist, initial push
      NEXTLINUX_AUTH_TOKEN=$nextlinuxhub_token nextlinux hub push$PLATFORM_ARGS --verbose . -t $GIT_TAG -t latest
      push_success=$?
      if [[ $push_success != 0 ]]; then
        echo push failed. Check error
        exit_code=1
        exit 1
      fi
    else
      echo does NOT exist, pushing to latest and $GIT_TAG
      NEXTLINUX_AUTH_TOKEN=$hub_token       NEXTLINUX_AUTH_TOKEN=$nextlinuxhub_token nextlinux hub push$PLATFORM_ARGS --verbose . -t $GIT_TAG -t latest
 hub push$PLATFORM_ARGS --verbose --force $exec_name . -t $GIT_TAG -t latest 
      push_success=$?
      if [[ $push_success != 0 ]]; then
        echo push failed. Check error
        exit_code=1
        exit 1
      fi
    fi
  else
    echo exists, only push to latest
    NEXTLINUX_AUTH_TOKEN=$nextlinuxhub_token nextlinux hub push$PLATFORM_ARGS --verbose --force $exec_name .
    push_success=$?
    if [[ $push_success != 0 ]]; then
      echo push failed. Check error
      exit_code=1
      exit 1
    fi
  fi
fi

if [[ $push_success == 0 ]]; then
  echo push $exec_name successed
fi

# push gpu version
GIT_TAG_GPU=$GIT_TAG-gpu
if [ -z "$GIT_TAG" ]
then
  echo WARNING, no git tag!
elif [ -f $DOCKERFILE_GPU ]
then
  echo git gpu tag = $GIT_TAG_GPU
  nextlinux hub pull nextlinuxhub+docker://$exec_name/$GIT_TAG_GPU
  exists=$?
  if [[ $exists == 1 ]]; then
    echo does NOT exist, pushing to latest and $GIT_TAG_GPU
    NEXTLINUX_AUTH_TOKEN=$nextlinuxhub_token nextlinux hub push --verbose --force $exec_name -t $GIT_TAG_GPU -t latest-gpu -f $DOCKERFILE_GPU .
    push_success=$?
    if [[ $push_success != 0 ]]; then
      echo push failed. Check error
      exit_code=1
      exit 1
    fi
  else
    echo exists, only push to latest-gpu
    NEXTLINUX_AUTH_TOKEN=$nextlinuxhub_token nextlinux hub push --verbose --force $exec_name -t latest-gpu -f $DOCKERFILE_GPU .
    push_success=$?
    if [[ $push_success != 0 ]]; then
      echo push failed. Check error
      exit_code=1
      exit 1
    fi
  fi
else
  echo no $DOCKERFILE_GPU, skip pushing the gpu version
fi

exit_code=0
exit $exit_code
