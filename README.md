# RiftCloud Builder

Public Android debug builder for RiftCloud.

This repository intentionally contains only the public build pipeline and verification scripts. The RiftCloud application source lives in:

- `Arctic403/Mobile-Cloudfare`

## Current mode: automatic public builder with private-source prereleases

RiftCloud Builder currently produces **debug APKs only**.

The builder automatically checks `Arctic403/Mobile-Cloudfare/main` every 5 minutes. It resolves the exact source SHA and skips work when that SHA is already represented by a successful RiftCloud source-repo debug prerelease.

Changes to the builder workflow/scripts also trigger an immediate self-test build, and manual workflow dispatch remains available.

A build run:

1. checks out this public builder;
2. checks out the requested RiftCloud source ref;
3. records the exact RiftCloud source SHA;
4. builds `:app:assembleDebug` with Java 17, Android SDK 36 and Gradle 9.5;
5. verifies the APK signature, alignment, package identity, SDK levels and ABI-neutral policy;
6. creates a SHA-256 checksum and build metadata;
7. uploads the debug pack as a GitHub Actions artifact;
8. when `publish=true`, publishes the same pack back to `Arctic403/Mobile-Cloudfare` as a **prerelease**;
9. deletes the source checkout and transient build data from the ephemeral runner.

## Debug signing limitation

These APKs use Android's normal debug signing.

They are development/test packages and **do not establish a permanent Android update-signing lineage**. A debug APK from one clean GitHub runner is not guaranteed to install as an update over a debug APK produced by another run.

When RiftCloud eventually moves to production/updateable APKs, the builder can be switched back to a permanent signing identity.

No keystore or signing secrets are required in the current debug pipeline.

## Source repository access

While `Arctic403/Mobile-Cloudfare` is public, the builder can run without any repository secret.

When the source repository becomes private, add this GitHub Actions repository secret to **Arctic403/Riftcloud-builder**:

- `RIFTCLOUD_PRIVATE_TOKEN`

Use a fine-grained GitHub token that can access `Arctic403/Mobile-Cloudfare`.

The workflow uses the token only when it exists. If the source repository remains public, it uses the normal public checkout path.

The optional private failure-diagnostics path creates a prerelease in the private source repository, so a token used for that path needs sufficient Contents permission to create/upload release assets. If that behavior is not wanted later, it can be removed and the token can be read-only.

Never commit GitHub tokens to this repository.

## Public outputs

Each successful run produces:

- `RiftCloud-debug.apk`
- `RiftCloud-debug.apk.sha256`
- `RiftCloud-build-info.txt`
- `RiftCloud-debug-signing-certificate.txt`

The same files are uploaded as a 14-day Actions artifact.

When `publish=true`, they are also attached to a prerelease in `Arctic403/Mobile-Cloudfare` named from the exact RiftCloud source SHA.

## APK verification

The verifier rejects a debug APK if it:

- fails `zipalign` verification;
- fails `apksigner` verification;
- contains native `.so` files, preserving RiftCloud's ABI-neutral 32/64-bit Android policy;
- does not identify as package `com.riftcloud.app`;
- does not declare `minSdk 26`;
- does not declare `targetSdk 36`;
- is suspiciously small.

## Private-source hygiene

The builder does not publish the RiftCloud source tree as an artifact.

Detailed Gradle output is redirected to the runner's temporary private-log directory instead of being printed into the normal public build log. The cleanup step removes:

- the RiftCloud source checkout;
- temporary build logs;
- transient APK/output directories.

If `RIFTCLOUD_PRIVATE_TOKEN` is configured and a build fails after the source SHA is known, the current workflow can return the detailed failure bundle to the private source repository as a prerelease rather than exposing it publicly.

## Automatic and manual builds

Normal `main` development requires no manual builder action. The scheduled watcher checks the RiftCloud source SHA every 5 minutes and builds only when it sees a new SHA.

For an explicit rebuild or a non-main ref, open:

**Actions → RiftCloud Public Debug Builder → Run workflow**

Inputs:

- `source_ref`: `main`, another branch, a tag, or a commit SHA;
- `client_id`: optional correlation text;
- `publish`: whether to publish the debug prerelease back to the RiftCloud source repository.

For now this is the intended RiftCloud distribution path: **automatic public builder, debug APK packs, no permanent signing key**.
