#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sources=(Sources/swift/Models.swift Sources/swift/LabelParser.swift Sources/swift/ReceiptModels.swift Sources/swift/ReceiptParser.swift)
for suite in DomainChecks ReceiptChecks; do
  swiftc "${sources[@]}" "Tests/$suite.swift" -o "$work/$suite"
  "$work/$suite"
done
