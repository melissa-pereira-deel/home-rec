import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    // The shadcn CLI writes Canvas UI components against the "@/" alias, so
    // the alias must exist even though this is a plain Vite project.
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
