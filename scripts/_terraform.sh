#!/bin/bash


function _terraform_help() {
    echo
    echo "nrlf terraform <command> [options]"
    echo
    echo "commands:"
    echo "  help          - this help screen"
    echo "  validate      - runs 'terraform validate'"
    echo "  fmt           - runs 'terraform fmt'"
    echo "  init <env>    - runs 'terraform init'"
    echo "  plan <env>    - runs 'terraform plan'"
    echo "  apply <env>   - runs 'terraform apply'"
    echo "  destroy <env> - runs 'terraform destroy'"
    echo "  bootstrap-non-mgmt <env>   - Creates account-wide resources in the provided env"
    echo "  destroy-bootstrap-non-mgmt - Destroys account-wide resources in the provided env"
    echo
    return 1
}

function _get_project_name(){
  python -c "import hcl; print(hcl.load(open('locals.tf'))['locals']['project'])"
  return $?
}

function _get_region_name(){
  python -c "import hcl; print(hcl.load(open('locals.tf'))['locals']['region'])"
  return $?
}

function _get_mgmt_account(){
  python -c "import os; from configparser import ConfigParser; parser = ConfigParser(); parser.read(os.environ['HOME'] + '/.aws/config'); print(parser['nhsd-nrlf-mgmt-admin']['aws_account_id'])"
  return $?
}

function _terraform() {
  local command=$1
  local env
  local aws_account_id
  local var_file
  local current_timestamp
  env=$(_get_environment_name "$2")
  aws_account_id=$(_get_aws_account_id "$env")
  var_file=$(_get_environment_vars_file "$env")
  current_timestamp="$(date '+%Y_%m_%d__%H_%M_%S')"
  local plan_file="./tfplan"
  local ci_log_bucket="${PROFILE_PREFIX}--mgmt--github-ci-logs"

  case $command in
    #----------------
    "validate")
      cd $root/terraform/infrastructure
      terraform validate "${@:3}" || return 1
    ;;
    #----------------
    "fmt")
      cd $root/terraform/infrastructure
      terraform fmt "${@:3}" || return 1
    ;;
    #----------------
    "init")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      cd $root/terraform/infrastructure
      _terraform_init "$env"
    ;;
    #----------------
    "plan")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      cd $root/terraform/infrastructure
      _terraform_plan "$env" "$var_file" "$plan_file" "$aws_account_id"
    ;;
    #----------------
    "apply")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      cd $root/terraform/infrastructure
      _terraform_apply "$env" "$plan_file"
    ;;
    #----------------
    "destroy")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      if [[ -z ${env} ]];
      then
          echo "Non-mgmt parameter required" >&2
          echo "Usage:    nrlf terraform bootstrap-non-mgmt <ENV>"
          return 1
      fi

      cd $root/terraform/infrastructure
      _terraform_destroy "$env" "$var_file" "$aws_account_id"
    ;;

     "ciinit")
      if [[ "$RUNNING_IN_CI" != 1 ]];
      then
          echo "Command should only be used by CI pipeline" >&2
          return 1
      fi

      echo "Init terraform for aws workspace: ${env}"

      local tf_init_output="${env}-tf-init-output_${current_timestamp}.txt"

      cd $root/terraform/infrastructure
      _terraform_init "$env" | tee "./${tf_init_output}" > /dev/null
      local tf_init_status="${PIPESTATUS[0]}"
      aws s3 cp "./${tf_init_output}" "s3://${ci_log_bucket}/${env}/${tf_init_output}"

      echo "Init complete. Uploaded output to: s3://${ci_log_bucket}/${env}/${tf_init_output}"
      return "$tf_init_status"
    ;;

    "ciplan")
      if [[ "$RUNNING_IN_CI" != 1 ]];
      then
          echo "Command should only be used by CI pipeline" >&2
          return 1
      fi

      echo "Creating plan for aws workspace: ${env}"

      local tf_plan_output="${env}-tf-plan-output_${current_timestamp}.txt"

      cd $root/terraform/infrastructure
      _terraform_plan "$env" "$var_file" "$plan_file" "$aws_account_id" | tee "./${tf_plan_output}" > /dev/null
      local tf_plan_status="${PIPESTATUS[0]}"
      aws s3 cp "./${tf_plan_output}" "s3://${ci_log_bucket}/${env}/${tf_plan_output}"

      echo "Plan complete. Uploaded output output to: s3://${ci_log_bucket}/${env}/${tf_plan_output}"
      return "$tf_plan_status"
    ;;

    "ciapply")
      if [[ "$RUNNING_IN_CI" != 1 ]];
      then
          echo "Command should only be used by CI pipeline" >&2
          return 1
      fi

      echo "Applying change to aws workspace: ${env}"

      local tf_apply_output="${env}-tf-apply-output_${current_timestamp}.txt"

      cd $root/terraform/infrastructure
      _terraform_apply "$env" "$plan_file" | tee "./${tf_apply_output}" > /dev/null
      local tf_apply_status="${PIPESTATUS[0]}"
      aws s3 cp "./${tf_apply_output}" "s3://${ci_log_bucket}/${env}/${tf_apply_output}"

      echo "Apply complete. Uploaded output output to: s3://${ci_log_bucket}/${env}/${tf_apply_output}"
      return "$tf_apply_status"
    ;;

    "cidestroy")
      if [[ "$RUNNING_IN_CI" != 1 ]];
      then
          echo "Command should only be used by CI pipeline" >&2
          return 1
      fi

      echo "Destroying aws workspace: ${env}"

      local tf_destroy_output="${env}-tf-destroy-output_${current_timestamp}.txt"

      cd $root/terraform/infrastructure
      _terraform_destroy "$env" "$var_file" "$aws_account_id" "-auto-approve" | tee "./${tf_destroy_output}" > /dev/null
      local tf_destroy_status="${PIPESTATUS[0]}"
      aws s3 cp "./${tf_destroy_output}" "s3://${ci_log_bucket}/${env}/${tf_destroy_output}"

      echo "Destroy complete. Uploaded output output to: s3://${ci_log_bucket}/${env}/${tf_destroy_output}"
      return "$tf_destroy_status"
    ;;

    #----------------
    "bootstrap-non-mgmt")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      if [[ -z ${env} ]];
      then
          echo "Non-mgmt parameter required" >&2
          echo "Usage:    nrlf terraform bootstrap-non-mgmt <ENV>"
          return 1
      fi

      cd $root/terraform/bootstrap/non-mgmt
      terraform init -upgrade || return 1
      terraform workspace select "$env" || terraform workspace new "$env" || return 1
      terraform init || return 1
      terraform plan -var-file=./etc/non-mgmt.tfvars -out="$plan_file" -var "assume_account=${aws_account_id}" || return 1
      terraform apply "$plan_file" || return 1
    ;;
    #----------------
    "destroy-bootstrap-non-mgmt")
      if [[ "$(aws sts get-caller-identity)" != *mgmt* ]];
      then
          echo "Please log in as the mgmt account" >&2
          return 1
      fi

      if [[ -z ${env} ]];
      then
          echo "Non-mgmt parameter required" >&2
          echo "Usage:    nrlf terraform destroy-non-mgmt <ENV>"
          return 1
      fi

      cd $root/terraform/bootstrap/non-mgmt
      terraform workspace select "$env" || terraform workspace new "$env" || return 1
      terraform init || return 1
      terraform plan -destroy -var-file=etc/non-mgmt.tfvars -out="$plan_file" -var "assume_account=${aws_account_id}" || return 1
      terraform apply -destroy ./tfplan || return 1
      if [ "$env" != "default" ];
      then
        terraform workspace select default || return 1
        terraform workspace delete "$env" || return 1
      fi
    ;;
    #----------------
    *) _terraform_help ;;
  esac
}

 function _get_environment_name() {
     local environment=$1

     if [[ -z $environment ]]; then
         if [[ -z $TERRAFORM_LOCAL_WORKSPACE_OVERRIDE ]]; then
             echo "$(whoami | openssl dgst -sha1 -binary | xxd -p | cut -c1-8)"
         else
             echo "$TERRAFORM_LOCAL_WORKSPACE_OVERRIDE"
         fi
     else
         echo "$environment"
     fi
 }

function _get_secret_name() {
  local environment=$1

  if [ "$environment" = "prod" ]; then
    echo "${PROFILE_PREFIX}--mgmt--prod-account-id"
  elif [ "$environment" = "uat" ]; then
    echo "${PROFILE_PREFIX}--mgmt--test-account-id"
  else
    echo "${PROFILE_PREFIX}--mgmt--dev-account-id"
  fi
}

function _get_aws_account_id() {
  local secret_name
  secret_name=$(_get_secret_name "$1")
  aws secretsmanager get-secret-value --secret-id $secret_name --query SecretString --output text
}

 function _get_environment_vars_file() {
     local environment=$1
     local vars_prefix="prod"

     if [[ $environment != "prod" ]]; then
         vars_prefix="dev"
     fi

     echo "./etc/${vars_prefix}.tfvars"
 }


function _terraform_init() {
  local env=$1

  terraform init || return 1
  terraform workspace select "$env" || terraform workspace new "$env" || return 1
}


function _terraform_plan() {
  local env=$1
  local var_file=$2
  local plan_file=$3
  local aws_account_id=$4

  terraform init || return 1
  terraform workspace select "$env" || terraform workspace new "$env" || return 1
  terraform plan -var-file="$var_file" -out="$plan_file" -var "assume_account=${aws_account_id}" || return 1
}


function _terraform_destroy() {
  local env=$1
  local var_file=$2
  local aws_account_id=$3

  terraform workspace select "$env" || terraform workspace new "$env" || return 1
  terraform destroy -var-file="$var_file" -var "assume_account=${aws_account_id}" "${@:4}" || return 1
  if [ "$env" != "default" ];
  then
    terraform workspace select default || return 1
    terraform workspace delete "$env" || return 1
  fi
}


function _terraform_apply() {
  local env=$1
  local plan_file=$2

  terraform workspace select "$env" || terraform workspace new "$env" || return 1
  terraform apply "$plan_file" || return 1
  terraform output -json > output.json || return 1
}
