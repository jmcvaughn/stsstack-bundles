#!/bin/bash -eu
opts=(
--template swift-ha.yaml.template
--path $0
)
`dirname $0`/../common/generate-bundle.sh ${opts[@]} $@
