#/bin/bash

AWS_CONF_DIR="$HOME/.aws"

[[ ! -z $AWS_CONF_DIR ]] && [[ ! -d "${AWS_CONF_DIR}" ]] && {
mkdir -p "${AWS_CONF_DIR}"
cat <<- 'EOF' >> "${AWS_CONF_DIR}/config"
[default]
region = <modifyMe>
output = json
EOF

cat <<- 'EOF' >> "${AWS_CONF_DIR}/credentials"
[default]
aws_access_key_id = <modifyMe>
aws_secret_access_key = <modifyMe>
EOF
} || echo -e "$AWS_CONF_DIR" exists, exit

