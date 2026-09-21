# This repository has moved

The Snicket Labs Terraform reference architecture now lives at
**https://github.com/snicketlabs/reference-architecture**

This repository is no longer updated and is being archived. Everything here is
a frozen copy of what was published before the move.

## If you have a clone of this repository

Repoint it and carry on — the histories are linked, so an ordinary pull works
and your own changes are preserved:

```bash
git remote set-url origin https://github.com/snicketlabs/reference-architecture.git
git pull origin main
```

Expect a conflict in this README, since you are holding this notice and the new
repository has the real one. Take theirs:

```bash
git checkout --theirs README.md && git add README.md && git commit
```

If you would rather start clean, a fresh clone of the new repository works too —
copy your own `.tfvars` and backend configuration across.

## The optional secrets charts

`optional-add-ons/secrets-configuration` is not in the new repository. Those
charts are published to the chart repository and you install them from there:

```bash
helm repo add ad-signalio https://ad-signalio.github.io/helm-charts
helm repo update
helm install secrets-configuration ad-signalio/secrets-configuration-aws -n match
```

The templates and values are readable at
https://github.com/ad-signalio/helm-charts/tree/main/charts

## Why

Ad Signal's public artifacts are moving to the Snicket Labs organisation. The
content is the same reference architecture, with the naming brought in line.
