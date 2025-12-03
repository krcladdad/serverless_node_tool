variable "region" {
  type    = string
  default = "us-east-1"
}

variable "s3_bucket_name" {
  description = "create S3 bucket for image storing"
  type        = string
  default     = "flask-note-tools"
}

variable "note_table_name" {
  description = "DynamoDB table name for notes"
  type        = string
  default     = "NotesTable"
}

variable "contactus_table_name" {
  description = "DynamoDB table name for contact us"
  type        = string
  default     = "ContactUs"
}

