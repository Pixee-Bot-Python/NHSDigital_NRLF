// TODO-NOW - Make sure this is set for the new test environment
data "aws_secretsmanager_secret_version" "identities_account_id" {
  secret_id = aws_secretsmanager_secret.identities_account_id.name
}
