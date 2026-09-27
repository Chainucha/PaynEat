// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0
//
// node --test scripts/android-version.test.mjs (รันใน .github/workflows/android-release.yml)

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { androidVersion } from './android-version.mjs';

test('a vX.Y.Z tag gives its version and a versionCode that grows with it', () => {
  assert.deepEqual(androidVersion('refs/tags/v0.1.0'), { name: '0.1.0', code: 1000 });
  assert.deepEqual(androidVersion('refs/tags/v1.0.0'), { name: '1.0.0', code: 1_000_000 });
  assert.deepEqual(androidVersion('refs/tags/v1.2.3'), { name: '1.2.3', code: 1_002_003 });
  const order = ['v0.0.1', 'v0.1.0', 'v0.1.9', 'v0.2.0', 'v1.0.0', 'v1.0.10', 'v2.0.0'];
  const codes = order.map((tag) => androidVersion(`refs/tags/${tag}`).code);
  assert.deepEqual(codes, [...codes].sort((a, b) => a - b));
});

test('anything else than a tag is a CI build that never reaches the store', () => {
  assert.deepEqual(androidVersion('refs/pull/12/merge'), { name: '0.0.0-ci', code: 1 });
  assert.deepEqual(androidVersion(''), { name: '0.0.0-ci', code: 1 });
});

test('refuses a tag that is not plain semver, out of range, or gives 0', () => {
  for (const tag of ['demo', 'v1.0', 'v1.0.0-rc.1', 'v1.1000.0', 'v1.0.1000', 'v3000.0.0', 'v0.0.0']) {
    assert.throws(() => androidVersion(`refs/tags/${tag}`), /tag/);
  }
});
