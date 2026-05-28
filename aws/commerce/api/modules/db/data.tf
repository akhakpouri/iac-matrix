data "aws_secretsmanager_secret" "db" {
  name = "arn:aws:secretsmanager:us-east-1:commerce-api:secret:/my-app/rds/psql"
}

data "aws_secretsmanager_secret_versions" "credentials" {
  secret_id = data.aws_secretsmanager_secret.db.id
}
