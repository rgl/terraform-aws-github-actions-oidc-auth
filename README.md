# About

[![Build](https://github.com/rgl/terraform-aws-github-actions-oidc-auth/actions/workflows/build.yml/badge.svg)](https://github.com/rgl/terraform-aws-github-actions-oidc-auth/actions/workflows/build.yml)

Terraform example that configures an authentication federation between AWS IAM and GitHub Actions OIDC.

This lets us use AWS from a GitHub Actions Workflow Job without using static secrets.

It uses the GitHub Actions Workflow Job OIDC ID Token to authenticate in AWS IAM.

This will:

* Configure AWS IAM.
  * Create the GitHub Actions OIDC Identity Provider in AWS IAM.
  * Create a IAM Role to represent the GitHub Actions Workflow Identity.
    * This role will have `ReadOnlyAccess` permissions in the entire AWS Account.
* Configure GitHub Repository.
  * Add the AWS related environment variables as GitHub Actions Variables.
    * Please note that these values are not sensitive to me, as such, they are not saved as GitHub Actions Secrets, but YMMV.
* Show the [Build GitHub Actions Workflow](https://github.com/rgl/terraform-aws-github-actions-oidc-auth/actions/workflows/build.yml).
  * It has two example jobs:
    1. `build-with-aws-cli`: Login into AWS using the [aws-actions/configure-aws-credentials action](https://github.com/aws-actions/configure-aws-credentials), then use the AWS CLI to interact with AWS.
    2. `build-with-curl`: Use `curl` to request a GitHub Actions OIDC ID Token, exchange it for AWS Credentials, then interact with AWS using `curl` and also with the `boto3` library.

# Usage

Install the dependencies:

* [Visual Studio Code](https://code.visualstudio.com).
* [Dev Container plugin](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

Open this directory with the Dev Container plugin.

Open the Visual Studio Code Terminal.

Set the AWS Account credentials using SSO, e.g.:

```bash
# set the account credentials.
# NB get these details from IAM Identity Center.
# NB the aws cli stores these at ~/.aws/config.
# NB this is equivalent to manually configuring SSO using aws configure sso.
# see https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#sso-configure-profile-token-auto-sso
# see https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#sso-configure-profile-token-manual
cat >secrets-example.sh <<'EOF'
# set the environment variables to use a specific profile.
# NB use aws configure sso to configure these manually.
# e.g. use the pattern <aws-sso-session>-<aws-account-id>-<aws-role-name>
export aws_sso_session='example'
export aws_sso_start_url='https://example.awsapps.com/start'
export aws_sso_region='eu-west-1'
export aws_sso_account_id='123456'
export aws_sso_role_name='AdministratorAccess'
export AWS_PROFILE="$aws_sso_session-$aws_sso_account_id-$aws_sso_role_name"
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_DEFAULT_REGION
# configure the ~/.aws/config file.
# NB unfortunately, I did not find a way to create the [sso-session] section
#    inside the ~/.aws/config file using the aws cli. so, instead, manage that
#    file using python.
python3 <<'PY_EOF'
import configparser
import os
aws_sso_session = os.getenv('aws_sso_session')
aws_sso_start_url = os.getenv('aws_sso_start_url')
aws_sso_region = os.getenv('aws_sso_region')
aws_sso_account_id = os.getenv('aws_sso_account_id')
aws_sso_role_name = os.getenv('aws_sso_role_name')
aws_profile = os.getenv('AWS_PROFILE')
config = configparser.ConfigParser()
aws_config_directory_path = os.path.expanduser('~/.aws')
aws_config_path = os.path.join(aws_config_directory_path, 'config')
if os.path.exists(aws_config_path):
  config.read(aws_config_path)
config[f'sso-session {aws_sso_session}'] = {
  'sso_start_url': aws_sso_start_url,
  'sso_region': aws_sso_region,
  'sso_registration_scopes': 'sso:account:access',
}
config[f'profile {aws_profile}'] = {
  'sso_session': aws_sso_session,
  'sso_account_id': aws_sso_account_id,
  'sso_role_name': aws_sso_role_name,
  'region': aws_sso_region,
}
os.makedirs(aws_config_directory_path, mode=0o700, exist_ok=True)
with open(aws_config_path, 'w') as f:
  config.write(f)
PY_EOF
unset aws_sso_start_url
unset aws_sso_region
unset aws_sso_session
unset aws_sso_account_id
unset aws_sso_role_name
# show the user, user amazon resource name (arn), and the account id, of the
# profile set in the AWS_PROFILE environment variable.
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  aws sso login
fi
aws sts get-caller-identity
EOF
```

Or, set the AWS Account credentials using an Access Key, e.g.:

```bash
# set the account credentials.
# NB get these from your aws account iam console.
#    see Managing access keys (console) at
#        https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey
cat >secrets-example.sh <<'EOF'
export AWS_ACCESS_KEY_ID='TODO'
export AWS_SECRET_ACCESS_KEY='TODO'
unset AWS_PROFILE
# set the default region.
export AWS_DEFAULT_REGION='eu-west-1'
# show the user, user amazon resource name (arn), and the account id.
aws sts get-caller-identity
EOF
```

Load the secrets:

```bash
source secrets-example.sh
```

Login into GitHub:

```bash
gh auth login
gh auth status
```

Provision the aws infrastructure:

```bash
export CHECKPOINT_DISABLE=1
export TF_LOG=INFO # ERROR, WARN, INFO, DEBUG, TRACE.
export TF_LOG_PATH=terraform.log
rm -f "$TF_LOG_PATH"
terraform init
terraform apply
```

Manually trigger the [Build GitHub Actions Workflow](https://github.com/rgl/terraform-aws-github-actions-oidc-auth/actions/workflows/build.yml) execution and watch it use AWS without using any static secret.

When you are done, destroy everything:

```bash
terraform destroy
```

List this repository dependencies (and which have newer versions):

```bash
GITHUB_COM_TOKEN='YOUR_GITHUB_PERSONAL_TOKEN' ./renovate.sh
```

# References

* [GitHub: About security hardening with OpenID Connect](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect).
* [GitHub: Variables](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables).
* [GitHub: Secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions).
