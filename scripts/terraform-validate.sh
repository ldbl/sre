#!/bin/bash
set -e
cd infra/terraform/hcloud_cluster && terraform validate
