#!/bin/bash
#v.1.0

tags=( $@ )
len=${#tags[@]}

printHelp() {
  echo
  echo "HELP for 'push-docker-image.sh'"
  echo 
  echo "Usage: ./push-docker-image.sh [<tag>] [,<tag>]"
  echo
  echo "Push a docker image to AWS ECS repository"
  echo
  echo "Script takes takes zero, one, or more tags."
  echo "It pushes the docker image from your local repository into our AWS ECS repository."
  echo "It tags the docker image with the tag(s) that you provide."
  echo "If no tags are provided, 'latest' is assumed to be the single tag to be used."
  echo
  echo "NOTE: Your local image must already be tagged with the *first* tag provided."
  echo "You can use the 'tag-docker-image.sh' script to add a needed tag to your local image."
  echo
  echo "Note: DockerImageName file is required to be in the same directory and contains the name of the docker image."
  echo
}

getAwsUrl() {
  awsloginmessage="$1"
  awsurl=$(echo "$awsloginmessage"|awk '{print $NF }')
  url=${awsurl#https://}
}

doesRepositoryExist() {
  if [[ "$1" =~ $image ]]
  then
    imageRepositoryExists=true
  else
    imageRepositoryExists=false
  fi
}

processOtherTags() {
  for otherTag in "$@" ; do
    echo "Tagging $image:$firstTag for remote push as $url/$image:$firstTag..."
    docker tag $url/$image:$firstTag $url/$image:$otherTag

    echo "Pushing image remotely..."
    docker push $url/$image:$otherTag

    echo "Removing remote url tagging of $url/$image:$otherTag..."
    docker rmi $url/$image:$otherTag
	done
}

if [ "$1" == "-?" ] || [ "$1" == "-h" ] ||  [ "$1" == "--h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]
then
  printHelp
  exit 0
fi

if [ $len == 0 ]
then
  echo
  echo "No tags provided, assuming at single tag of 'latest'."
  firstTag=latest
else
  firstTag=${tags[0]}
fi

#get the image name
image=$(<DockerImageName)
if [ -z "$image" ]
then
  echo
  echo "Cannot find an image name in the required file 'DockerImageName'."
  printHelp
  exit 1
fi

awslogin="$(aws ecr get-login --profile ecr_aws_write --region us-west-2 --no-include-email)"

getAwsUrl "$awslogin"

$awslogin

dockerRepositories="$(aws ecr describe-repositories --profile ecr_aws_write --region us-west-2)"

doesRepositoryExist "$dockerRepositories"

if [ "$imageRepositoryExists" = false ]
then
  echo "Creating repository..."
  aws ecr create-repository --repository-name $image --profile ecr_aws_write --region us-west-2
fi

imageid="$(docker images -q $image)"

echo "Tagging $image:$firstTag for remote push as $url/$image:$firstTag..."
docker tag $image:$firstTag $url/$image:$firstTag

echo "Pushing image remotely..."
docker push $url/$image:$firstTag

if [ $len -gt 1 ]
then
  otherTags=("${tags[@]:1:$len}")
  processOtherTags "${otherTags[@]}"
fi

echo "Removing remote url tagging of $url/$image:$firstTag..."
docker rmi $url/$image:$firstTag