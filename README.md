# AwsHealthKinesis
Terraform template for infrastructure needed to send AWS Health Notifications into a Kinesis Stream

Rather than poll every instance to determine it's health status (which doesn't scale well at all), this set-up uses Cloudwatch Alarms to notify when an instances' health status changes.  The notifications are ultimately fed into a Kinesis Stream, where they can be collected using a Kinesis Consumer.

There's no direct support for sending Cloudwatch alarm notifications to Kinesis, so this Terraform template builds the rather circuitous infrastructure neededed to achieve the goal, the flow is:
 
Cloudwatch Alarm -> SNS -> SQS -> (which triggers) Lambda -> (which logs the SQS message to) Cloudwatch Logs -> (which has a subscription filter for) Kinesis.

Current Limitations
-------------------
The Cloudwatch alarms have to be created on a per instance basis, and this Terraform template currently only creates the Alarm for a single hardcoded instance.  Later revisions will pull the list of instances from known Terraform state, or from an input file.

Getting it working
-------------------
The Terraform template expects to find the AWS Access Key/Secret Key/Default Region in the environment variables.  These can be set as per the instructions here:

https://www.terraform.io/docs/providers/aws/
The IAM account that is associated with the Access and Secret Key needs to have appropriate permissions to create items in:

IAM
Cloudwatch Alarms
Cloudwatch Logs
SNS
SQS
Lambda
Kinesis

You will need to change the AMI ID to one that is available in the default region that you choose to use.
You will need to specify the correct name for a key pair that you have available.  It is currently set to 'my-key' in the .tf file.
