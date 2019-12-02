# L200labs

This is a set of scripts and tools use to generate a docker image that will have the l200labs binary used to evaluate your AKS troubleshooting skill.

It uses the shc_script_converter.sh (build using the following tool https://github.com/neurobin/shc) to abstract the lab scripts on binary format and then the use the Dockerfile to pack everyting on a Ubuntu container with az cli and kubectl.

Any time the L200 lab scripts require an update the github actions can be use to trigger a new build and push of the updated image.
This will take care of building a new script binary as well as new docker image that will get pushed to the corresponding registry.
The actions will get triggered any time a new release gets published.

Here is the general usage for the image and l200labs tool:

Run in docker
```docker run -it sturrent/l200labs:latest```

L200labs tool usage
```
$ l200labs -h
l200labs usage: l200labs -g <RESOURCE_GROUP> -n <CLUSTER_NAME> -l <LAB#> [-v|--validate] [-h|--help]

Here is the list of current labs available:

***************************************************************
*        1. Node not ready
*        2. Cluster is in failed state
*        3. Cluster Scaling issue
*        4. Problem with accessing dashboard
*        5. Cluster unable to communicate with API server
***************************************************************

"-g|--resource-group" resource group name
"-n|--name" AKS cluster name
"-l|--lab" Lab scenario to deploy (5 possible options)
"-v|--validate" Validate a particular scenario
"-h|--help" help info
```
