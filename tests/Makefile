all: runtests

runtests:
	ruby test_builds.rb

clean:

.PHONY: neo-smoke neo-save-restore

# The scripts default NEO_FIRMWARE_ROOT to a sibling ../neo6502-firmware checkout.

neo-smoke:
	../tools/test-neo6502-smoke.sh

neo-save-restore:
	../tools/test-neo6502-save-restore.sh
