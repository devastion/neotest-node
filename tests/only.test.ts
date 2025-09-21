import { strict as assert } from "node:assert";
import { test, describe, only } from "node:test";


// Assume Node.js is run with the --test-only command-line option.
// The suite's 'only' option is set, so these tests are run.
test('this test is run', { only: true }, async (t) => {
  // Within this test, all subtests are run by default.
  await t.test('running subtest');

  // The test context can be updated to run subtests with the 'only' option.
  t.runOnly(true);
  await t.test('this subtest is now skipped');
  await t.test('this subtest is run', { only: true });

  // Switch the context back to execute all tests.
  t.runOnly(false);
  await t.test('this subtest is now run');

  // Explicitly do not run these tests.
  await t.test('skipped subtest 3', { only: false });
  await t.test('skipped subtest 4', { skip: true });
});

// The 'only' option is not set, so this test is skipped.
test('this test is not run', () => {
  // This code is not run.
  throw new Error('fail');
});

describe('a suite', () => {
  // The 'only' option is set, so this test is run.
  it('this test is run', { only: true }, () => {
    // This code is run.
  });

  it('this test is not run', () => {
    // This code is not run.
    throw new Error('fail');
  });
});

describe.only('a suite', () => {
  // The 'only' option is set, so this test is run.
  it('this test is run', () => {
    // This code is run.
  });

  it('this test is run', () => {
    // This code is run.
  });
});
