
data "archive_file" "img" {
  type        = "zip"
  source_dir  = "${path.module}/../build/image"
  output_path = "${path.module}/img.zip"
}

resource "aws_iam_role" "img" {
  name = "edge-lab-img"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "img_logs" {
  role       = aws_iam_role.img.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "img" {
  role = aws_iam_role.img.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "s3:GetObject", Resource = "${aws_s3_bucket.originals.arn}/*" }]
  })
}

resource "aws_cloudwatch_log_group" "img" {
  name              = "/aws/lambda/edge-lab-img"
  retention_in_days = 3
}

resource "aws_lambda_function" "img" {
  function_name    = "edge-lab-img"
  runtime          = "python3.12"
  handler          = "handler.handler"
  role             = aws_iam_role.img.arn
  filename         = data.archive_file.img.output_path
  source_code_hash = data.archive_file.img.output_base64sha256
  memory_size      = 512
  timeout          = 10
  environment { variables = { BUCKET = aws_s3_bucket.originals.bucket } }
  depends_on = [aws_cloudwatch_log_group.img]
}

resource "aws_lambda_function_url" "img" {
  function_name      = aws_lambda_function.img.function_name
  authorization_type = "AWS_IAM" # only CloudFront (via OAC) can call it
}

resource "aws_lambda_permission" "cf_url" {
  statement_id           = "AllowCloudFrontUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.img.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.cdn.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "cf_invoke" { # newer function URLs need both permissions
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.img.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.cdn.arn
}