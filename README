#L200labs

This is a set of scripts and tools use to generate a docker image that will have the l200labs binary used to evaluate your AKS troubleshooting skill.

It uses the shc_script_converter.sh (build using the following tools https://github.com/neurobin/shc) to abstract the lab scripts on binary format and then the use the Dockerfile to pack everyting on a Ubuntu container with az cli and kubectl.

Any time the L200 lab scripts require an update the shc_script_converter.sh can be use to generate the new binaries.
And after that the Dockerfile can be use to rebuild a new docker image.
