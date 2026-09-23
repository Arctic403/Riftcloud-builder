# RiftCloud Builder

Public, source-isolated Android build worker for the private RiftCloud application.

This repository contains build orchestration and APK verification only. The RiftCloud application source remains in the private repository:

- `Arctic403/Mobile-Cloudfare`

## Build model

1. A manual workflow dispatch selects a branch, tag, or commit from the private RiftCloud repository.
2. The worker resolves that ref to an exact source SHA.
3. The private source is checked out into the ephemeral GitHub Actions runner with a dedicated repository token.
4. Gradle compiles an unsigned release APK.
5. The APK is zip-aligned and signed with RiftCloud's persistent private signing identity.
6. The signed APK is verified for alignment, signature, package identity, SDK policy, minimum size, and ABI neutrality.
7. Verified outputs are published back to the private RiftCloud repository as a prerelease.
8. Private source, detailed logs, generated APKs, and the temporary signing keystore are deleted from the public runner.

The public workflow does not upload the private source as an artifact and the build script redirects detailed Gradle output into the private failure bundle instead of printing it into the public Actions log.

## Required GitHub Actions secrets

Configure these secrets in **Arctic403/Riftcloud-builder**:

- `RIFTCLOUD_PRIVATE_TOKEN`
  - GitHub token with read access to the private `Arctic403/Mobile-Cloudfare` repository.
  - It also needs permission to create prereleases and upload assets back to that private repository.
- `RIFTCLOUD_KEYSTORE_B64`
  - Base64 encoding of the permanent RiftCloud Android signing keystore.
- `RIFTCLOUD_KEYSTORE_PASSWORD`
  - Password for that keystore.
- `RIFTCLOUD_KEY_ALIAS`
  - Alias of the RiftCloud signing key.
- `RIFTCLOUD_KEY_PASSWORD`
  - Password for that signing key.

There is deliberately **no temporary/debug signing fallback**. Missing signing secrets fail the build.

## Signing identity rule

The same RiftCloud signing key must be used for every update APK.

Android update compatibility depends on the package name remaining `com.riftcloud.app`, the APK being signed by the same signing identity, and the new build having a higher `versionCode`.

Back up the keystore and its passwords securely. If the signing identity is lost, later APKs signed by a different key cannot update existing direct-installed RiftCloud builds.

Never commit the keystore, its Base64 form, passwords, or private-repository token to this repository.

## Verified outputs

A successful private prerelease receives:

- `RiftCloud-release.apk`
- `RiftCloud-release.apk.sha256`
- `RiftCloud-signing-certificate.txt`
- `RiftCloud-build-info.txt`

The verifier rejects APKs that:

- fail `zipalign` verification;
- fail `apksigner` verification;
- package native `.so` files, preserving RiftCloud's ABI-neutral 32/64-bit policy;
- no longer declare `com.riftcloud.app`;
- change the locked `minSdk 26` or `targetSdk 36`;
- are suspiciously small.

## Failure handling

Detailed Gradle output is kept out of normal public build output. If a build fails and publication is enabled, diagnostics are zipped and returned to a **private prerelease** on the source repository.

The ephemeral runner cleanup step always removes:

- the private source checkout;
- the reconstructed signing keystore;
- private build logs;
- transient APK and verification directories.

## Running a build

Open **Actions → RiftCloud Private Build Worker → Run workflow**.

Use:

- `source_ref = main` for the current private main branch, or provide an exact branch/tag/SHA;
- `publish = true` to return the verified result to the private RiftCloud repository.

The first successful release signed with the permanent RiftCloud identity establishes the signing lineage that later RiftCloud APK updates must keep.
