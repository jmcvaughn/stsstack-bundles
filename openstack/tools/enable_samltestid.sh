#!/usr/bin/env bash
set -ex

juju run-action --format=json keystone-saml-mellon/0 get-sp-metadata --wait | jq -r '."unit-keystone-saml-mellon-0".results.output' > keystone-metadata.xml && curl --form userfile=@"./keystone-metadata.xml" -s -o /dev/null -w "%{http_code}\n" --form "submit=OK" "https://samltest.id/upload.php" 2>&1 && rm keystone-metadata.xml

openstack domain create federated_domain
openstack group create federated_users --domain federated_domain

# Get the federated_users group id and assign the role Member
GROUP_ID=$(openstack group show federated_users --domain federated_domain | grep -v domain_id | grep id |awk '{print $4}')
openstack role add --group ${GROUP_ID} --domain federated_domain Member

# Use the URL for your idP's metadata for remote-id. The name can be
# arbitrary.
openstack identity provider create --remote-id https://samltest.id/saml/idp --domain federated_domain samltest

# Get the federated_domain id and add it to the rules.json map
DOMAIN_ID=$(openstack domain show federated_domain |grep id |awk '{print $4}')
cat > rules.json <<EOF
[{
        "local": [
            {
                "user": {
                    "name": "{0}"
                },
                "group": {
                    "domain": {
                        "id": "${DOMAIN_ID}"
                    },
                    "name": "federated_users"
                },
                "projects": [
                {
                    "name": "{0}_project",
                    "roles": [
                                 {
                                     "name": "Member"
                                 }
                             ]
                }
                ]
           }
        ],
        "remote": [
            {
                "type": "MELLON_NAME_ID"
            }
        ]
}]
EOF

# Use the rules.json created above.
openstack mapping create --rules rules.json samltest_mapping
# The name should be mapped or saml here and must match the configuration
# setting protocol-name. We recommend using "mapped"
openstack federation protocol create mapped --mapping samltest_mapping --identity-provider samltest
# list related projects
openstack federation project list
# Note and auto generated domain has been created. This is where auto
# generated users and projects will be created.
openstack domain list
