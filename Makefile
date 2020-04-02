include common.mk

all: init

init:
	$(MAKE) -C infra

deploy:
	$(MAKE) -C infra COMPONENT=kubernetes apply
	$(MAKE) -C infra COMPONENT=server apply

plan:
	$(MAKE) -C infra plan-all

destroy:
	$(MAKE) -C infra COMPONENT=kubernetes destroy
	$(MAKE) -C infra COMPONENT=server destroy

clean:
	$(MAKE) -C infra clean-all

.PHONY: init deploy plan destroy clean

