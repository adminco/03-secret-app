### 03-secret-app
## Home Assignment - Part III
# Introduction
This is an automated deployment of a static website on aws s3 with basic authentication. Terraform will be used as infrastructure-as-code (IAC) to achieve this.
Also, based on this design, direct access to the s3 bucket's source code files will be blocked.

**AWS Services Used**
- **S3**
- **IAM**
- **CloudFront**
- **Lambda**

# Project Design
<img src="./Design.png">

**Steps**
- A *viewer request* is sent from the browser to the Cloudfront distribution which triggers a Lambda function (this prompts the user for a username and password)
- The Lambda function is a javascript callback function that does the basic authentication (Note that this is a Lamda Edge service)
- Once the user is authenticated, the Cloudfront distribution sends an *origin request*  via a secret header to the S3 bucket serving the secret web app
- The S3 bucket sends back an *origin response* to the Cloudfront distribution once it validates the *origin request* via the secret header
- Cloudfront distribution sends back a viewer response to the end user which then serves secret web app page on the browser

# Usage
- Please note that a module used for this project to make it reusable, maintenable and testable in different environments
- Logon credentials: 
  ```
  Username: admin
  Password: admin
  ```
  
**Key directories and files**
- module/ ==> this directory contains the reusable terraform configuration files
- secret-app/ ==> this directory is the working directory for implementing the project
- src/ ==> this directory contains the source code files for the s3 bucket
- 03-secret-app.tf ==> this is the terraform config file
- vars.tf ==> this is the terraform variables file
- outputs.tf ==> this is the terraform output file
- provider.tf ==> this is terraform aws provider file
- index.js ==> this is the Lambda function code for basic authentication
- mime.json ==> this contains the mime content types






