###############################################################################
# The values file for the match chart, generated from what this stack built.
#
#   terraform output -raw match_values_yaml > values.yaml
#
# Paste that into distr, or pass it with `helm -f values.yaml`. The point is
# that the customer does not fill anything in: this stack already decides the
# infrastructure AND the deployment shape -- whether KEDA is installed, whether
# monitoring is installed -- so it emits the chart values that match those
# decisions rather than leaving them to be re-stated by hand and drift.
#
# WHAT IS LEFT FOR THE CUSTOMER, on purpose:
#   image.tag          the release being deployed, which changes per deploy and
#                      does not belong in tfvars
#   environment size   layer <chart>/environment-sizes/<size>/<size>.yaml AFTER
#                      this file -- the preset merges LAST and silently wins
#                      over anything here that it also sets
#
# Chart knowledge lives HERE, in one file, and not in the modules. A module
# should report what it built; if each one also knew what a helm chart calls
# it, every chart schema change would mean re-releasing ten modules.
#
# NOT YET USABLE: the module source refs in main.tf still point at versions
# that predate the outputs this file reads. Bump them once
# terraform-utils-private#163 is released and synced to the public repo:
#
#   tf-dt-efs                          storage_class_name
#   tf-dt-ingress-resources            ingress_class_name
#   tf-dt-auto-mode-efs-storage-class  storage_class_name
#   tf-dt-s3-active-storage            bucket_name
#   tf-dt-iam-roles                    grafana_cloudwatch_role_arn
#   tf-dt-elasticache-redis            redis_url
#   tf-dt-rds-pg                       db_name, db_username, db_port
#
# Until then `terraform validate` fails with "unsupported attribute", naming
# whichever output is missing.
#
# A NOTE ON CONDITIONALS. Both branches of a terraform conditional must have the
# same type, so `var.x ? { a = 1 } : {}` is an error. The optional blocks below
# are expanded from a 0-or-1 element list instead, because merge() of an empty
# list is {}.
###############################################################################

locals {
  # Everything tf-dt-eks-secret-provider-classes owns: secretKeys, owningUser
  # and the postgres secret references. It emits YAML, so decode it rather than
  # duplicate its contents and let the two drift. coalesce because the module
  # returns "" when disabled.
  match_secret_values = yamldecode(coalesce(module.secret_provider_classes.match_helm_values, "{}"))

  # The synced secret carries host, password and db_name. These three are plain
  # values the chart reads directly, so they have to be set as well.
  # Same story as postgres: the module owns owningUser.secret, these are the
  # identity fields alongside it. Merged explicitly below for the same reason.
  owning_user_identity = {
    email            = var.owning_user_email
    firstName        = var.owning_user_first_name
    lastName         = var.owning_user_last_name
    organisationName = var.owning_user_organisation
  }

  postgres_literals = {
    database = module.rds-postgres.db_name
    username = module.rds-postgres.db_username
    port     = module.rds-postgres.db_port
  }

  match_infra_values = {
    domain      = var.external_domain
    honeybadger = { environment = module.label.env_name }

    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.iam_role_for_service_account.role_arn
      }
    }

    storage = {
      sharedStorage = {
        enabled = true
        # Overridable because renaming it on an existing install creates a NEW
        # PVC and orphans the old volume, media and all. Leave unset for new
        # deployments.
        claimName        = coalesce(var.shared_storage_claim_name, "${local.cluster_name}-pvc")
        storageClassName = module.efs.storage_class_name
        size             = var.shared_storage_size
      }
      # Node-local scratch. Transcodes write here before upload, so it has to
      # hold the largest proxy the workers will produce.
      tmpStorage = {
        emptyDir = { sizeLimit = var.tmp_storage_size }
      }
    }

    # This stack provides ElastiCache, so the chart's own redis stays off.
    # postgres.enabled is off for the same reason, via match_secret_values.
    redis = { enabled = false }

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
      ingressClassParams = { create = false }
    }

    # Tracks the same variable that gates module.keda. If this stack installed
    # KEDA, the chart runs its workers as ScaledJobs; if it did not, they run as
    # static Deployments. Stating it here is what stops the two disagreeing.
    kedaAutoScaling = { enabled = var.install_helm_charts }
  }

  # Monitoring, when this stack installs it. These are not customer choices --
  # they are what makes kube-prometheus-stack work on this infrastructure, and
  # every one of them is a thing an environment otherwise rediscovers.
  match_monitoring_values = merge([for _ in range(var.enable_monitoring ? 1 : 0) : {
    monitoring = {
      enabled            = true
      matchDashboards    = { enabled = true }
      postgresDashboards = { enabled = true }
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

    # Subchart values, so a root key.
    "kube-prometheus-stack" = {
      # Without this the subchart names resources after the release, so two
      # match installs in one cluster collide on cluster-scoped objects.
      fullnameOverride = "${local.cluster_name}-kube-prometheus-stack"

      crds = { upgradeJob = { enabled = true, forceConflicts = true } }

      # Nothing is wired to route alerts anywhere.
      alertmanager = { enabled = false }

      prometheus = {
        service = { enabled = true, type = "ClusterIP", port = 9090, targetPort = 9090 }
        prometheusSpec = {
          # Scrape PodMonitors and ServiceMonitors from every namespace whatever
          # their labels. Without the NilUsesHelmValues flags an empty selector
          # is read as "only my own release", which silently scrapes nothing.
          podMonitorSelector                      = {}
          podMonitorSelectorNilUsesHelmValues     = false
          podMonitorNamespaceSelector             = {}
          serviceMonitorSelector                  = {}
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorNamespaceSelector         = {}
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = module.auto_mode_storage_class.storage_class_name
                resources        = { requests = { storage = var.prometheus_storage_size } }
              }
            }
          }
        }
      }

      grafana = merge({
        enabled = true
        # Grafana lands in the match namespace so its datasource sidecar, which
        # only searches its own namespace, finds what the chart provisions.
        namespaceOverride = var.k8s_namespace
        adminUser         = "admin"
        # Recreate, not the chart's RollingUpdate default. Persistence below is
        # an EBS volume and so ReadWriteOnce: a rolling update schedules the new
        # pod before releasing the old one's volume, gets Multi-Attach error and
        # waits forever. The old pod keeps serving, so the release looks
        # deployed while the new config never takes effect.
        deploymentStrategy = { type = "Recreate" }
        persistence = {
          type        = "pvc"
          enabled     = true
          accessModes = ["ReadWriteOnce"]
          size        = var.grafana_storage_size
          # The storage class that works under EKS Auto Mode. The in-tree gp2
          # class provisions nothing, and the failure is a PVC that sits Pending
          # rather than an error.
          storageClassName = module.auto_mode_storage_class.storage_class_name
        }
        # Reuses the match service account, which carries the IRSA annotation
        # that lets Grafana assume the CloudWatch role above.
        serviceAccount = { create = false, name = var.k8s_service_account }
        # The postgres dashboards read the database credentials from the secret
        # the CSI driver syncs.
        extraSecretMounts = [{
          name       = "pg-secrets"
          secretName = module.secret_provider_classes.k8s_secret_names.rds_pg
          mountPath  = "/etc/secrets"
          readOnly   = true
          items      = [for k in ["username", "password", "db_name", "host", "port"] : { key = k, path = k }]
        }]
        },
        # Grafana on a path of the application host, so it needs nothing from
        # DNS. OFF by default: this publishes a monitoring UI on the
        # internet-facing ALB, which should be a deliberate choice rather than
        # something inherited from a reference architecture.
        merge([for _ in range(var.expose_grafana ? 1 : 0) : {
          # group.order is what makes the path work. Both ingresses join the
          # same ALB group and the application's "/" becomes a "/*" rule; with
          # no explicit order the controller puts that first and it swallows
          # /grafana, surfacing as the application's own 404 page.
          ingress = {
            enabled          = true
            ingressClassName = module.ingress_resources.ingress_class_name
            annotations      = { "alb.ingress.kubernetes.io/group.order" = "-100" }
            hosts            = [var.external_domain]
            path             = "/grafana"
            pathType         = "Prefix"
          }
          # Without these Grafana does not know it is under a subpath: it
          # answers /grafana with a 302 to /login, which the ALB then routes to
          # the application instead.
          "grafana.ini" = {
            server = {
              root_url            = "https://${var.external_domain}/grafana"
              serve_from_sub_path = true
            }
          }
      }]...))
    }
  }]...)

  # Shallow merge, so the parts must share no top-level key. postgres is the one
  # exception and is merged explicitly: lookup rather than a direct attribute,
  # because match_secret_values is {} when that module is disabled.
  match_values = merge(
    local.match_infra_values,
    local.match_secret_values,
    local.match_monitoring_values,
    { postgres = merge(lookup(local.match_secret_values, "postgres", {}), local.postgres_literals) },
    { owningUser = merge(lookup(local.match_secret_values, "owningUser", {}), local.owning_user_identity) },
  )
}
