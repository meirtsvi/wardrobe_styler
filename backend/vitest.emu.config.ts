import { defineConfig } from "vitest/config";

// Emulator-backed tests. Run with `npm run test:emulator` (firebase emulators:exec sets FIRESTORE_EMULATOR_HOST).
export default defineConfig({
  test: {
    include: ["src/**/*.emu.test.ts"],
    fileParallelism: false,
    testTimeout: 30_000,
  },
});
