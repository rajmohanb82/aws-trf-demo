# =============================================================================
# Laptop workflow — uses ~/.aws/credentials (or AWS_PROFILE / env vars).
# =============================================================================

ENV          ?= dev
TF           ?= terraform
AWS_REGION   ?= us-east-1
TFVARS       := environments/$(ENV).tfvars
BACKEND      := backend-configs/$(ENV).hcl
PLAN_FILE    := tfplan-$(ENV)

.PHONY: help bootstrap init fmt validate plan apply destroy showcase output clean

help:
	@echo ""
	@echo "  Dual-VPC platform"
	@echo "  -----------------"
	@echo "  make bootstrap              Provision the S3 state bucket (once)"
	@echo "  make init ENV=dev           terraform init with remote state"
	@echo "  make plan ENV=dev           terraform plan  -> $(PLAN_FILE)"
	@echo "  make apply ENV=dev          terraform apply the saved plan"
	@echo "  make destroy ENV=dev        terraform destroy (confirmation)"
	@echo "  make showcase ENV=dev       Print live infra snapshot"
	@echo "  make fmt / make validate    Format & validate"
	@echo ""
	@echo "  AWS credentials: laptop profile (AWS_PROFILE) or env vars."
	@echo "  Override the state bucket: TF_STATE_BUCKET=my-bucket make init"
	@echo ""

bootstrap:
	$(TF) -chdir=bootstrap init
	$(TF) -chdir=bootstrap apply -auto-approve -var="aws_region=$(AWS_REGION)"
	@echo ""
	@echo ">>> Copy state_bucket into backend-configs/*.hcl and GitHub secret TF_STATE_BUCKET"

init:
	@if [ -n "$(TF_STATE_BUCKET)" ]; then \
	  $(TF) init -reconfigure \
	    -backend-config="$(BACKEND)" \
	    -backend-config="bucket=$(TF_STATE_BUCKET)" \
	    -backend-config="region=$(AWS_REGION)"; \
	else \
	  $(TF) init -reconfigure -backend-config="$(BACKEND)"; \
	fi

fmt:
	$(TF) fmt -recursive

validate: fmt
	$(TF) validate

plan: validate
	$(TF) plan -input=false -var-file="$(TFVARS)" -out="$(PLAN_FILE)"

apply:
	$(TF) apply -input=false "$(PLAN_FILE)"

destroy:
	$(TF) destroy -input=false -var-file="$(TFVARS)"

showcase:
	@chmod +x scripts/showcase.sh
	@./scripts/showcase.sh

output:
	$(TF) output

clean:
	rm -f tfplan-*
	rm -rf .terraform
