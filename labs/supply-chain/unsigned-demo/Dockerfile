# unsigned-demo - an image from the platform's own registry that is deliberately NOT signed and has no
# SBOM (Chapter 17). The supply-chain policy must refuse it in develop/staging/production and only
# report it elsewhere; the policy test (tests/kyverno-supply-chain.test.sh) uses it as its negative case.
# Built and pushed by .github/workflows/unsigned-demo.yml - by CI, so it is reproducible; the only
# difference from a real image is the missing signature. Never sign it, never deploy it outside a lab.
FROM docker.io/library/busybox:1.36@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662
LABEL org.opencontainers.image.title="unsigned-demo" \
      org.opencontainers.image.description="Deliberately unsigned lab image (SafeOps Chapter 17) - the supply-chain policy must refuse it" \
      org.opencontainers.image.source="https://github.com/safeops-course/sre"
USER 65532:65532
CMD ["sh", "-c", "echo 'unsigned-demo: this image has no signature'; while true; do sleep 3600; done"]
