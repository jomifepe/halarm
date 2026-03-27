import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/halarm-panel.ts",
      formats: ["iife"],
      name: "HAlarmPanel",
      fileName: () => "halarm-panel.js",
    },
    outDir: "dist",
    emptyOutDir: true,
  },
});
