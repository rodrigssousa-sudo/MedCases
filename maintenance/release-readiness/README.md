# R15 release readiness (local, not authorized for publication)

The consumed transaction and signed artifacts in Downloads are immutable.
`execution/transaction.py` is a working copy of that executor, not a new release.
It refuses publication without a new exact manifest and a matching real Linux
image receipt. The commit must be bound from `webCommit` in that final manifest.
The previous manifest MUST NOT be copied here to authorize a publication.

Local tests:

    python3 maintenance/release-readiness/test_pin_executor.py

Linux gate, on an existing authorized Docker Linux engine (no push/deploy):

    python3 maintenance/release-readiness/verify_linux_image.py --output /absolute/path/evidence

This builds only the exact Docker context inputs, runs the official entrypoint,
checks nginx, real HTTP, metadata and four bundle hashes, waits for health, and
restarts the container. It cleans up its own container/image. Exit 2 means BLOCKED,
not PASS. macOS-native nginx tests do not satisfy this gate.

The runtime PID is `/var/cache/nginx/nginx.pid`. The official image's root-owned
cache directory exists independently of its transient `/var/run -> /run` link.
The build verifies the expected directive and directory before changing the PID;
there is no blind directory creation or ignored nginx failure.

No Flutter runtime, clinical source, backend candidate, iOS build, IAM or productive
configuration is changed by this patch. A new manifest is intentionally absent
until the Linux gate and warm-client evidence are complete.
