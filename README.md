# AwsHealthKinesis
Terraform template for infrastructure needed to send AWS Health Notifications into a Kinesis Stream

Rather than poll every instance to determine it's health status (which doesn't scale well at all), this set-up uses Cloudwatch Alarms to notify when an instances' health status changes.  The notifications are ultimately fed into a Kinesis Stream, where they can be collected using a Kinesis Consumer.

There's no direct support for sending Cloudwatch alarm notifications to Kinesis, so this Terraform template builds the rather circuitous infrastructure neededed to achieve the goal, the flow is:
 
Cloudwatch Alarm -> SNS -> SQS -> (which triggers) Lambda -> (which logs the SQS message to) Cloudwatch Logs -> (which has a subscription filter for) Kinesis.

Current Limitations
-------------------
The Cloudwatch alarms have to be created on a per instance basis, and this Terraform template currently only creates the Alarm for a single hardcoded instance.  Later revisions will pull the list of instances from known Terraform state, or from an input file.
