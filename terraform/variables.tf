variable "region" {
 default     = "us-east-1"
}
variable "s3_bucket_name" {
 description = "create S3 bucket for image storing"
 default     = "flask-note-tools"
}
variable "note_table_name" {
 description = "DynamoDB table name for notes"
 default     = "NotesTable"
}
variable "contactus_table_name" {
 description = "DynamoDB table name for contact us"
 default     = "ContactUs"
}

