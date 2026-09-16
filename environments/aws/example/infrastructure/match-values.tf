###############################################################################
# The values file for the match chart, generated from what this stack built.
#
#   terraform output -raw match_values_yaml > values.yaml
#
# Paste that into distr, or pass it with `helm -f values.yaml`. The point is
# that nothing in it has to be filled in by hand: every name, ARN, endpoint and
# class below is read back from a module rather than copied out of the console.
#
# WHAT THIS DOES NOT SET, on purpose:
#   image.*            the release you are deploying, not infrastructure
#   owningUser.email   who owns the instance, not infrastructure
#   environment size   layer <chart>/environment-sizes/<size>/<size>.yaml after
#                      this file -- the preset merges LAST and will silently
#                      win over anything here that it also sets
#
# Chart knowledge lives HERE, in one file, and not in the modules. A module
# should report what it built; if each one also knew what a helm chart calls
# it, every chart schema change would mean re-releasing ten modules.
#
# NOT YET USABLE: the module source refs in main.tf still point at versions
# that predate the outputs this file reads. Bump these once
# terraform-utils-private#163 is released and synced to the public repo:
#
#   tf-dt-efs                          storage_class_name
#   tf-dt-ingress-resources            ingress_class_name
#   tf-dt-auto-mode-efs-storage-class  storage_class_name
#   tf-dt-s3-active-storage            bucket_name
#   tf-dt-iam-roles                    grafana_cloudwatch_role_arn
#   tf-dt-elasticache-redis            redis_url
#
# Until then `terraform validate` fails here with "unsupported attribute",
# naming whichever output is missing.
###############################################################################


locals {
  # Everything the secret provider classes module owns: secretKeys, owningUser
  # and the whole postgres block. It emits YAML, so decode it rather than
  # duplicate its contents and let the two drift.
  #
  # The merge below is SHALLOW, which is safe only because this fragment and
  # local.match_infra_values share no top-level key. If you add postgres,
  # secretKeys or owningUser below, one of the two will vanish without warning.
  # coalesce, not a ternary: the two branches of a conditional must have the
  # same type, and an empty object does not match the decoded one. The module
  # returns "" when disabled, which coalesce skips.
  match_secret_values = yamldecode(coalesce(module.secret_provider_classes.match_helm_values, "{}"))

  match_infra_values = {
    domain = var.external_domain

    honeybadger = {
      environment = module.label.env_name
    }

    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.iam_role_for_service_account.role_arn
      }
    }

    storage = {
      sharedStorage = {
        enabled   = true
        claimName = "${local.cluster_name}-pvc"
        # EFS, ReadWriteMany. The workers share one volume.
        storageClassName = module.efs.storage_class_name
        size             = var.shared_storage_size
      }
    }

    # The chart can run its own redis; this stack provides ElastiCache instead.
    # postgres.enabled comes from match_secret_values for the same reason.
    redis = {
      enabled = false
    }

    sidekiq = {
      redisServerUrl = module.elasticache_redis.redis_url
      redisClientUrl = module.elasticache_redis.redis_url
    }

    s3 = {
      primaryBucket = module.s3-active-storage.bucket_name
      region        = var.region
    }

    ingress = {
      enabled   = true
      className = module.ingress_resources.ingress_class_name
      hosts = [{
        host  = var.external_domain
        paths = [{ path = "/", pathType = "Prefix" }]
      }]
      # Terraform owns the IngressClassParams of that name. It is cluster-scoped,
      # so a second one from the chart would collide.
      ingressClassParams = {
        create = false
      }
    }

    monitoring = {
      enabled = true
      awsDashboards = {
        enabled = true
        cloudwatch = {
          # tf-dt-iam-roles has always created this role. Until it gained an
          # output there was no way to discover its ARN, so environments carried
          # it as a hand-copied account-specific string.
          assumeRoleArn = module.iam_role_for_service_account.grafana_cloudwatch_role_arn
          defaultRegion = var.region
        }
      }
    }

    # Subchart values, so a root key. The storage class is the one that actually
    # works under EKS Auto Mode -- the in-tree gp2 class provisions nothing, and
    # the failure is a PVC that stays Pending rather than an error.
    "kube-prometheus-stack" = {
      grafana = {
        persistence = {
          enabled          = true
          storageClassName = module.auto_mode_storage_class.storage_class_name
        }
        serviceAccount = {
          create = false
          name   = var.k8s_service_account
        }
      }
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = module.auto_mode_storage_class.storage_class_name
              }
            }
          }
        }
      }
    }
  }

  match_values = merge(local.match_infra_values, local.match_secret_values)
}
