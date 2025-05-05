#resource "aws_s3_bucket_notification" "log_archive_notification" {
#  count  = 0
#  bucket = aws_s3_bucket.log_archive.id
#  lambda_function {
#    lambda_function_arn = aws_lambda_function.log_processor.arn
#    events              = ["s3:ObjectCreated:*"]
#    filter_suffix       = ".gz"
#  }

#  depends_on = [aws_lambda_permission.allow_s3_invoke]
#}


# Remove the old permissions that reference non-existent functions
# resource "aws_lambda_permission" "allow_s3_invoke" {
#   statement_id  = "AllowS3Invoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.log_processor.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.log_archive.arn
# }

# resource "aws_lambda_permission" "allow_ingest_invoke" {
#   statement_id  = "AllowIngestInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.log_ingest_handler.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.log_archive.arn
# }
