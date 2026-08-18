# AWS Marketplace attribution (optional, AWS only)

Off by default. Setting `aws_marketplace_product_code` tags resources `aws-apn-id = pc:<code>`, which AWS reads under [Partner Revenue Measurement](https://docs.aws.amazon.com/PRM/latest/aws-prm-onboarding-guide/resource-tagging.html) to attribute your AWS spend to the software vendor. It does not affect your bill or entitlements, and can be removed at any time.

Use the product code, not the `prod-...` Product ID — the variable validates this.

```hcl
aws_marketplace_product_code = "lqmsrnudbo3xempf2qjr2ffo"
```

## Coverage

Tagged: VPC, subnets, EIP, S3 endpoint, EKS cluster and its log group, RDS, ElastiCache, EFS, S3, IAM roles — and with managed node groups, EC2 instances, EBS volumes and ENIs.

Three gaps, none of which this variable can close:

| Gap | Why | Where to fix |
|---|---|---|
| **EKS Auto Mode nodes** (the default) | Auto Mode uses AWS's built-in node pools, so there is no launch template or NodeClass to tag | Needs a custom NodeClass with `tags` plus cluster-role IAM permission for [tag propagation](https://docs.aws.amazon.com/eks/latest/userguide/auto-cluster-iam-role.html#tag-prop) |
| **NAT gateway, route tables, internet gateway** | `tf-dt-vpc` does not forward top-level `tags` to the upstream VPC module | The `tf-dt-vpc` module |
| **Load balancers** | Created by the ALB controller, not Terraform | `ingress.ingressClassParams.tags` (Auto Mode) or the `alb.ingress.kubernetes.io/tags` annotation, in the `helm-match` chart |

[Tag Editor](https://docs.aws.amazon.com/tag-editor/latest/userguide/tag-editor.html) can bulk-apply the tag to existing resources.
