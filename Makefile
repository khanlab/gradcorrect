ORG=khanlab
NAME=gradcorrect
VERSION = 0.0.1h

SINGULARITY_NAME=$(ORG)_$(NAME)_$(VERSION)

BUILD_DIR=~/singularity
REMOTE_BUILD_DIR=~/graham/singularity/bids-apps
LOG_DIR=build_logs

LOCAL_UUID=9bc03c00-89ae-11e7-a97f-22000a92523b
GRAHAM_SINGULARITY_UUID=42df491c-52e1-11e8-9060-0a6d4e044368


fromlocal:
	rm -f $(BUILD_DIR)/$(SINGULARITY_NAME).img
	sudo singularity build $(BUILD_DIR)/$(SINGULARITY_NAME).img local.Singularity.$(VERSION) | tee $(LOG_DIR)/build_$(SINGULARITY_NAME).log
	globus transfer $(LOCAL_UUID):$(BUILD_DIR)/$(SINGULARITY_NAME).img $(GRAHAM_SINGULARITY_UUID):bids-apps/$(SINGULARITY_NAME).img


build:
	rm -f $(BUILD_DIR)/$(SINGULARITY_NAME).img
	sudo singularity build $(BUILD_DIR)/$(SINGULARITY_NAME).img Singularity.$(VERSION) | tee $(LOG_DIR)/build_$(SINGULARITY_NAME).log
	globus transfer $(LOCAL_UUID):$(BUILD_DIR)/$(SINGULARITY_NAME).img $(GRAHAM_SINGULARITY_UUID):bids-apps/$(SINGULARITY_NAME).img


sandbox:
	sudo singularity build --sandbox sandbox_$(SINGULARITY_NAME) Singularity | tee -a $(LOG_DIR)/sandbox_$(SINGULARITY_NAME).log
	

